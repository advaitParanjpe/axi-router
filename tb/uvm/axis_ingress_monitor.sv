class axis_ingress_monitor extends uvm_component;
  axis_router_config cfg;
  virtual axis_stream_if vif;
  int unsigned port_id;
  uvm_analysis_port #(axis_router_transaction) ap;

  `uvm_component_utils(axis_ingress_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(axis_router_config)::get(this, "", "cfg", cfg)) `uvm_fatal("NOCFG", "config not found")
    if (!uvm_config_db #(int unsigned)::get(this, "", "port_id", port_id)) port_id = 0;
    vif = cfg.ingress_vif[port_id];
    if (vif == null) `uvm_fatal("NOVIF", "ingress virtual interface not set")
  endfunction

  task run_phase(uvm_phase phase);
    axis_router_transaction tr;
    bit [31:0] first_dest;
    forever begin
      @(posedge vif.clk);
      if (vif.rst) begin
        tr = null;
      end else if (vif.tvalid && vif.tready) begin
        if (tr == null) begin
          tr = axis_router_transaction::type_id::create("ingress_observed");
          tr.ingress = port_id;
          tr.dest = vif.tdest;
          tr.invalid_dest = (vif.tdest > 3);
          tr.malformed = 1'b0;
          tr.oversize = 1'b0;
          tr.length = 0;
          tr.payload.delete();
          tr.inter_beat_gap.delete();
          first_dest = vif.tdest;
        end else if (!tr.invalid_dest && vif.tdest != first_dest) begin
          tr.malformed = 1'b1;
        end
        if (tr.length < cfg.ingress_max_pkt_beats) tr.payload.push_back(vif.tdata);
        tr.length++;
        if (tr.length > cfg.ingress_max_pkt_beats) tr.oversize = 1'b1;
        if (vif.tlast) begin
          ap.write(tr);
          tr = null;
        end
      end
    end
  endtask
endclass

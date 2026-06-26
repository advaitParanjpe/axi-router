class axis_egress_monitor extends uvm_component;
  axis_router_config cfg;
  virtual axis_stream_if vif;
  int unsigned port_id;
  uvm_analysis_port #(axis_router_transaction) ap;

  `uvm_component_utils(axis_egress_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(axis_router_config)::get(this, "", "cfg", cfg)) `uvm_fatal("NOCFG", "config not found")
    if (!uvm_config_db #(int unsigned)::get(this, "", "port_id", port_id)) port_id = 0;
    vif = cfg.egress_vif[port_id];
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
          tr = axis_router_transaction::type_id::create("egress_observed");
          tr.dest = vif.tdest;
          tr.length = 0;
          tr.payload.delete();
          tr.inter_beat_gap.delete();
          first_dest = vif.tdest;
        end else if (vif.tdest != first_dest) begin
          `uvm_error("PROTO", $sformatf("output %0d changed tdest within a packet", port_id))
        end
        tr.payload.push_back(vif.tdata);
        tr.length++;
        if (vif.tlast) begin
          tr.dest = port_id;
          ap.write(tr);
          tr = null;
        end
      end
    end
  endtask
endclass

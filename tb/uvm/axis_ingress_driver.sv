class axis_ingress_driver extends uvm_driver #(axis_router_transaction);
  axis_router_config cfg;
  virtual axis_stream_if vif;
  int unsigned port_id;

  `uvm_component_utils(axis_ingress_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(axis_router_config)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("NOCFG", "axis_router_config not found")
    end
    if (!uvm_config_db #(int unsigned)::get(this, "", "port_id", port_id)) port_id = 0;
    vif = cfg.ingress_vif[port_id];
  endfunction

  task run_phase(uvm_phase phase);
    axis_router_transaction tr;
    drive_idle();
    forever begin
      seq_item_port.get_next_item(tr);
      drive_packet(tr);
      seq_item_port.item_done();
    end
  endtask

  task drive_idle();
    vif.tvalid <= 1'b0;
    vif.tlast <= 1'b0;
    vif.tdata <= '0;
    vif.tdest <= '0;
  endtask

  task drive_packet(axis_router_transaction tr);
    bit [31:0] data_word;
    bit [31:0] dest_word;
    for (int unsigned i = 0; i < tr.length; i++) begin
      repeat (tr.inter_beat_gap[i]) @(posedge vif.clk);
      @(negedge vif.clk);
      data_word = tr.payload[i];
      dest_word = (tr.malformed && i > 0) ? (tr.dest ^ 1) : tr.dest;
      vif.tdata <= data_word;
      vif.tdest <= dest_word;
      vif.tlast <= (i == tr.length - 1);
      vif.tvalid <= 1'b1;
      do begin
        @(posedge vif.clk);
        if (vif.rst) begin
          drive_idle();
          wait (!vif.rst);
          @(posedge vif.clk);
        end
      end while (!vif.tready);
    end
    @(negedge vif.clk);
    drive_idle();
  endtask
endclass

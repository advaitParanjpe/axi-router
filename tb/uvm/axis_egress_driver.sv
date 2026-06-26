class axis_egress_driver extends uvm_component;
  axis_router_config cfg;
  virtual axis_stream_if vif;
  int unsigned port_id;
  int unsigned lfsr;
  int unsigned stall_count;

  `uvm_component_utils(axis_egress_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(axis_router_config)::get(this, "", "cfg", cfg)) `uvm_fatal("NOCFG", "config not found")
    if (!uvm_config_db #(int unsigned)::get(this, "", "port_id", port_id)) port_id = 0;
    vif = cfg.egress_vif[port_id];
    lfsr = cfg.seed + port_id + 1;
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(negedge vif.clk);
      if (vif.rst) begin
        vif.tready <= 1'b0;
        stall_count = 0;
      end else if (cfg.ready_mode[port_id] == 0) begin
        vif.tready <= 1'b1;
      end else if (stall_count != 0) begin
        vif.tready <= 1'b0;
        stall_count--;
      end else begin
        lfsr = ((lfsr * 1103515245) + 12345) & 32'h7fffffff;
        if (cfg.ready_mode[port_id] == 2 && (lfsr % 11) == 0) stall_count = 12;
        vif.tready <= ((lfsr % (3 + port_id)) != 0);
      end
    end
  endtask
endclass

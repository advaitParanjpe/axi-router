class axis_ingress_agent extends uvm_agent;
  axis_ingress_sequencer sequencer;
  axis_ingress_driver driver;
  axis_ingress_monitor monitor;
  int unsigned port_id;

  `uvm_component_utils(axis_ingress_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(int unsigned)::get(this, "", "port_id", port_id)) port_id = 0;
    monitor = axis_ingress_monitor::type_id::create("monitor", this);
    uvm_config_db #(int unsigned)::set(this, "monitor", "port_id", port_id);
    if (is_active == UVM_ACTIVE) begin
      sequencer = axis_ingress_sequencer::type_id::create("sequencer", this);
      driver = axis_ingress_driver::type_id::create("driver", this);
      uvm_config_db #(int unsigned)::set(this, "driver", "port_id", port_id);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (is_active == UVM_ACTIVE) driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

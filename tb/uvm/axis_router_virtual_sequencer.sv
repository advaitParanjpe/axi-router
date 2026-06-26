class axis_router_virtual_sequencer extends uvm_sequencer;
  axis_ingress_sequencer ingress_seqr[2];
  axis_router_config cfg;

  `uvm_component_utils(axis_router_virtual_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

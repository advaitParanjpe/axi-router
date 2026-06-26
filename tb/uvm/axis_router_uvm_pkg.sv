package axis_router_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "axis_router_transaction.sv"
  `include "axis_router_config.sv"
  `include "axis_ingress_sequencer.sv"
  `include "axis_ingress_driver.sv"
  `include "axis_ingress_monitor.sv"
  `include "axis_ingress_agent.sv"
  `include "axis_egress_driver.sv"
  `include "axis_egress_monitor.sv"
  `include "axis_egress_agent.sv"
  `include "axis_router_reference_model.sv"
  `include "axis_router_scoreboard.sv"
  `include "axis_router_coverage.sv"
  `include "axis_router_virtual_sequencer.sv"
  `include "axis_router_env.sv"
  `include "axis_router_sequences.sv"
  `include "axis_router_tests.sv"
endpackage

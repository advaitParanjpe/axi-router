class axis_router_config extends uvm_object;
  int unsigned num_ingress = 2;
  int unsigned num_egress = 4;
  int unsigned data_w = 8;
  int unsigned dest_w = 3;
  int unsigned ingress_max_pkt_beats = 4;
  int unsigned counter_w = 4;
  int unsigned timeout_cycles = 5000;
  int unsigned seed = 1;
  bit coverage_enable = 1'b1;
  bit scoreboard_enable = 1'b1;
  bit print_topology = 1'b0;
  bit force_scoreboard_error = 1'b0;
  bit counter_vif_valid = 1'b0;
  int unsigned ready_mode[4] = '{0, 0, 0, 0};

  virtual axis_stream_if ingress_vif[2];
  virtual axis_stream_if egress_vif[4];
  virtual axis_router_counter_if counter_vif;

  `uvm_object_utils(axis_router_config)

  function new(string name = "axis_router_config");
    super.new(name);
  endfunction
endclass

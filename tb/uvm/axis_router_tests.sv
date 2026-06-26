class axis_router_base_test extends uvm_test;
  axis_router_config cfg;
  axis_router_env env;

  `uvm_component_utils(axis_router_base_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg = axis_router_config::type_id::create("cfg");
    void'($value$plusargs("SEED=%0d", cfg.seed));
    cfg.force_scoreboard_error = $test$plusargs("FORCE_UVM_SCOREBOARD_ERROR");
    if (!uvm_config_db #(virtual axis_stream_if)::get(null, "", "ingress_vif0", cfg.ingress_vif[0])) `uvm_fatal("NOVIF", "ingress_vif0")
    if (!uvm_config_db #(virtual axis_stream_if)::get(null, "", "ingress_vif1", cfg.ingress_vif[1])) `uvm_fatal("NOVIF", "ingress_vif1")
    if (!uvm_config_db #(virtual axis_stream_if)::get(null, "", "egress_vif0", cfg.egress_vif[0])) `uvm_fatal("NOVIF", "egress_vif0")
    if (!uvm_config_db #(virtual axis_stream_if)::get(null, "", "egress_vif1", cfg.egress_vif[1])) `uvm_fatal("NOVIF", "egress_vif1")
    if (!uvm_config_db #(virtual axis_stream_if)::get(null, "", "egress_vif2", cfg.egress_vif[2])) `uvm_fatal("NOVIF", "egress_vif2")
    if (!uvm_config_db #(virtual axis_stream_if)::get(null, "", "egress_vif3", cfg.egress_vif[3])) `uvm_fatal("NOVIF", "egress_vif3")
    void'(uvm_config_db #(virtual axis_router_counter_if)::get(null, "", "counter_vif", cfg.counter_vif));
    configure();
    uvm_config_db #(axis_router_config)::set(this, "*", "cfg", cfg);
    env = axis_router_env::type_id::create("env", this);
  endfunction

  virtual function void configure();
  endfunction

  task run_named_sequence(uvm_phase phase, axis_router_base_vseq seq);
    phase.raise_objection(this);
    `uvm_info("TEST", $sformatf("starting %s seed=%0d", get_type_name(), cfg.seed), UVM_LOW)
    seq.start(env.vseqr);
    repeat (200) @(posedge cfg.ingress_vif[0].clk);
    phase.drop_objection(this);
  endtask
endclass

class axis_router_smoke_test extends axis_router_base_test;
  `uvm_component_utils(axis_router_smoke_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    axis_router_routing_vseq seq = axis_router_routing_vseq::type_id::create("seq");
    run_named_sequence(phase, seq);
  endtask
endclass

class axis_router_routing_test extends axis_router_smoke_test;
  `uvm_component_utils(axis_router_routing_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass

class axis_router_concurrency_test extends axis_router_base_test;
  `uvm_component_utils(axis_router_concurrency_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    axis_router_concurrency_vseq seq = axis_router_concurrency_vseq::type_id::create("seq");
    run_named_sequence(phase, seq);
  endtask
endclass

class axis_router_contention_test extends axis_router_base_test;
  `uvm_component_utils(axis_router_contention_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    axis_router_contention_vseq seq = axis_router_contention_vseq::type_id::create("seq");
    run_named_sequence(phase, seq);
  endtask
endclass

class axis_router_backpressure_test extends axis_router_contention_test;
  `uvm_component_utils(axis_router_backpressure_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void configure();
    foreach (cfg.ready_mode[i]) cfg.ready_mode[i] = 1;
  endfunction
endclass

class axis_router_drop_test extends axis_router_base_test;
  `uvm_component_utils(axis_router_drop_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    axis_router_drop_vseq seq = axis_router_drop_vseq::type_id::create("seq");
    run_named_sequence(phase, seq);
  endtask
endclass

class axis_router_reset_test extends axis_router_base_test;
  `uvm_component_utils(axis_router_reset_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    axis_router_concurrency_vseq seq = axis_router_concurrency_vseq::type_id::create("seq");
    run_named_sequence(phase, seq);
  endtask
endclass

class axis_router_random_test extends axis_router_base_test;
  `uvm_component_utils(axis_router_random_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void configure();
    foreach (cfg.ready_mode[i]) cfg.ready_mode[i] = 1;
  endfunction
  task run_phase(uvm_phase phase);
    axis_router_random_vseq seq = axis_router_random_vseq::type_id::create("seq");
    run_named_sequence(phase, seq);
  endtask
endclass

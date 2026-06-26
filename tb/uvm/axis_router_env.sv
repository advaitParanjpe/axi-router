class axis_router_env extends uvm_env;
  axis_router_config cfg;
  axis_ingress_agent ingress_agent[2];
  axis_egress_agent egress_agent[4];
  axis_router_reference_model ref_model;
  axis_router_scoreboard scoreboard;
  axis_router_coverage coverage;
  axis_router_virtual_sequencer vseqr;

  `uvm_component_utils(axis_router_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(axis_router_config)::get(this, "", "cfg", cfg)) `uvm_fatal("NOCFG", "config not found")
    for (int unsigned i = 0; i < 2; i++) begin
      ingress_agent[i] = axis_ingress_agent::type_id::create($sformatf("ingress_agent%0d", i), this);
      ingress_agent[i].is_active = UVM_ACTIVE;
      uvm_config_db #(int unsigned)::set(this, $sformatf("ingress_agent%0d", i), "port_id", i);
    end
    for (int unsigned o = 0; o < 4; o++) begin
      egress_agent[o] = axis_egress_agent::type_id::create($sformatf("egress_agent%0d", o), this);
      egress_agent[o].is_active = UVM_ACTIVE;
      uvm_config_db #(int unsigned)::set(this, $sformatf("egress_agent%0d", o), "port_id", o);
    end
    ref_model = axis_router_reference_model::type_id::create("ref_model", this);
    scoreboard = axis_router_scoreboard::type_id::create("scoreboard", this);
    coverage = axis_router_coverage::type_id::create("coverage", this);
    vseqr = axis_router_virtual_sequencer::type_id::create("vseqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    foreach (ingress_agent[i]) begin
      ingress_agent[i].monitor.ap.connect(ref_model.ingress_export);
      ingress_agent[i].monitor.ap.connect(coverage.ingress_export);
      vseqr.ingress_seqr[i] = ingress_agent[i].sequencer;
    end
    ref_model.expected_ap.connect(scoreboard.expected_export);
    foreach (egress_agent[o]) begin
      egress_agent[o].monitor.ap.connect(scoreboard.egress_export[o]);
      egress_agent[o].monitor.ap.connect(coverage.egress_export);
    end
    vseqr.cfg = cfg;
  endfunction
endclass

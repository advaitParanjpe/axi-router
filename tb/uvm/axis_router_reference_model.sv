`uvm_analysis_imp_decl(_ingress)

class axis_router_reference_model extends uvm_component;
  axis_router_config cfg;
  uvm_analysis_imp_ingress #(axis_router_transaction, axis_router_reference_model) ingress_export;
  uvm_analysis_port #(axis_router_transaction) expected_ap;
  int unsigned exp_accepted[2];
  int unsigned exp_invalid[2];
  int unsigned exp_oversize[2];
  int unsigned exp_malformed[2];
  int unsigned exp_forwarded[4];

  `uvm_component_utils(axis_router_reference_model)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ingress_export = new("ingress_export", this);
    expected_ap = new("expected_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db #(axis_router_config)::get(this, "", "cfg", cfg)) `uvm_fatal("NOCFG", "config not found")
  endfunction

  function void write_ingress(axis_router_transaction tr);
    axis_router_transaction exp;
    int unsigned src = tr.ingress;
    if (tr.invalid_dest) begin
      exp_invalid[src]++;
    end else if (tr.malformed) begin
      exp_malformed[src]++;
    end else if (tr.oversize) begin
      exp_oversize[src]++;
    end else begin
      exp = axis_router_transaction::type_id::create("expected_packet");
      exp.copy(tr);
      exp.dest = tr.expected_output();
      expected_ap.write(exp);
      exp_accepted[src]++;
      exp_forwarded[exp.dest]++;
    end
  endfunction

  function void reset_model();
    foreach (exp_accepted[i]) exp_accepted[i] = 0;
    foreach (exp_invalid[i]) exp_invalid[i] = 0;
    foreach (exp_oversize[i]) exp_oversize[i] = 0;
    foreach (exp_malformed[i]) exp_malformed[i] = 0;
    foreach (exp_forwarded[i]) exp_forwarded[i] = 0;
  endfunction

  function void check_phase(uvm_phase phase);
    int unsigned modulus;
    if (cfg.counter_vif == null) begin
      `uvm_warning("NOCOUNTER", "counter interface not available for UVM counter checks")
      return;
    end
    modulus = (cfg.counter_w >= 31) ? 32'h8000_0000 : (1 << cfg.counter_w);
    for (int unsigned i = 0; i < 2; i++) begin
      if (int'(cfg.counter_vif.accepted_pkt_count[i]) != (exp_accepted[i] % modulus)) begin
        `uvm_error("COUNT", $sformatf("accepted[%0d] exp=%0d act=%0d", i, exp_accepted[i], cfg.counter_vif.accepted_pkt_count[i]))
      end
      if (int'(cfg.counter_vif.drop_invalid_dest_count[i]) != (exp_invalid[i] % modulus)) begin
        `uvm_error("COUNT", $sformatf("invalid[%0d] exp=%0d act=%0d", i, exp_invalid[i], cfg.counter_vif.drop_invalid_dest_count[i]))
      end
      if (int'(cfg.counter_vif.drop_oversize_count[i]) != (exp_oversize[i] % modulus)) begin
        `uvm_error("COUNT", $sformatf("oversize[%0d] exp=%0d act=%0d", i, exp_oversize[i], cfg.counter_vif.drop_oversize_count[i]))
      end
      if (int'(cfg.counter_vif.drop_malformed_count[i]) != (exp_malformed[i] % modulus)) begin
        `uvm_error("COUNT", $sformatf("malformed[%0d] exp=%0d act=%0d", i, exp_malformed[i], cfg.counter_vif.drop_malformed_count[i]))
      end
    end
    for (int unsigned o = 0; o < 4; o++) begin
      if (int'(cfg.counter_vif.forwarded_pkt_count[o]) != (exp_forwarded[o] % modulus)) begin
        `uvm_error("COUNT", $sformatf("forwarded[%0d] exp=%0d act=%0d", o, exp_forwarded[o], cfg.counter_vif.forwarded_pkt_count[o]))
      end
    end
  endfunction
endclass

`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_egress)

class axis_router_scoreboard extends uvm_component;
  axis_router_config cfg;
  uvm_analysis_imp_expected #(axis_router_transaction, axis_router_scoreboard) expected_export;
  uvm_analysis_imp_egress #(axis_router_transaction, axis_router_scoreboard) egress_export[4];
  axis_router_transaction expected_q[4][$];
  int unsigned unexpected_count;
  int unsigned matched_count;

  `uvm_component_utils(axis_router_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    expected_export = new("expected_export", this);
    foreach (egress_export[i]) egress_export[i] = new($sformatf("egress_export%0d", i), this);
  endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db #(axis_router_config)::get(this, "", "cfg", cfg)) `uvm_fatal("NOCFG", "config not found")
  endfunction

  function void write_expected(axis_router_transaction tr);
    expected_q[tr.dest].push_back(tr);
  endfunction

  function void write_egress(axis_router_transaction tr);
    axis_router_transaction exp;
    int unsigned out = tr.dest;
    if (expected_q[out].size() == 0) begin
      unexpected_count++;
      `uvm_error("UNEXP", $sformatf("unexpected output packet out=%0d %s", out, tr.convert2string()))
      return;
    end
    exp = expected_q[out].pop_front();
    if (exp.length != tr.length) begin
      unexpected_count++;
      `uvm_error("LEN", $sformatf("length mismatch out=%0d exp=%0d act=%0d id=%0d", out, exp.length, tr.length, exp.tr_id))
      return;
    end
    foreach (exp.payload[i]) begin
      if (exp.payload[i] !== tr.payload[i]) begin
        unexpected_count++;
        `uvm_error("DATA", $sformatf("payload mismatch out=%0d beat=%0d exp=0x%0h act=0x%0h id=%0d",
                                     out, i, exp.payload[i], tr.payload[i], exp.tr_id))
        return;
      end
    end
    matched_count++;
  endfunction

  function void check_phase(uvm_phase phase);
    int unsigned pending;
    pending = 0;
    foreach (expected_q[i]) pending += expected_q[i].size();
    if (cfg.force_scoreboard_error) `uvm_error("FORCED", "forced UVM scoreboard error")
    if (pending != 0) `uvm_error("MISSING", $sformatf("expected packets remain unmatched=%0d", pending))
    if (unexpected_count != 0) `uvm_error("SUMMARY", $sformatf("scoreboard unexpected/mismatch count=%0d", unexpected_count))
    `uvm_info("SCOREBOARD", $sformatf("matched=%0d pending=%0d unexpected=%0d", matched_count, pending, unexpected_count), UVM_LOW)
  endfunction
endclass

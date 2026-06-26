`uvm_analysis_imp_decl(_cov_ingress)
`uvm_analysis_imp_decl(_cov_egress)

class axis_router_coverage extends uvm_component;
  uvm_analysis_imp_cov_ingress #(axis_router_transaction, axis_router_coverage) ingress_export;
  uvm_analysis_imp_cov_egress #(axis_router_transaction, axis_router_coverage) egress_export;
  int unsigned ingress_hits[2];
  int unsigned dest_hits[4];
  int unsigned single_hits;
  int unsigned multi_hits;
  int unsigned max_hits;
  int unsigned invalid_hits;
  int unsigned malformed_hits;
  int unsigned oversize_hits;

  `uvm_component_utils(axis_router_coverage)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ingress_export = new("ingress_export", this);
    egress_export = new("egress_export", this);
  endfunction

  function void write_cov_ingress(axis_router_transaction tr);
    if (tr.ingress < 2) ingress_hits[tr.ingress]++;
    if (tr.invalid_dest) invalid_hits++;
    if (tr.malformed) malformed_hits++;
    if (tr.oversize) oversize_hits++;
    if (tr.length == 1) single_hits++;
    else multi_hits++;
    if (tr.length == 4) max_hits++;
  endfunction

  function void write_cov_egress(axis_router_transaction tr);
    if (tr.dest < 4) dest_hits[tr.dest]++;
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COVERAGE", $sformatf("ingress=%0d/%0d dest=%0d/%0d/%0d/%0d len single/multi/max=%0d/%0d/%0d drops inv/mal/os=%0d/%0d/%0d",
      ingress_hits[0], ingress_hits[1], dest_hits[0], dest_hits[1], dest_hits[2], dest_hits[3],
      single_hits, multi_hits, max_hits, invalid_hits, malformed_hits, oversize_hits), UVM_LOW)
  endfunction
endclass

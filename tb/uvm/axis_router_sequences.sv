class axis_router_base_vseq extends uvm_sequence;
  axis_router_virtual_sequencer vseqr;
  int unsigned next_id;

  `uvm_object_utils(axis_router_base_vseq)
  `uvm_declare_p_sequencer(axis_router_virtual_sequencer)

  function new(string name = "axis_router_base_vseq");
    super.new(name);
  endfunction

  task pre_body();
    vseqr = p_sequencer;
  endtask

  task send_pkt(int unsigned src, int unsigned dst, int unsigned len, int unsigned base,
                bit invalid = 0, bit malformed = 0, bit oversize = 0, int unsigned gap = 0);
    axis_router_transaction tr;
    tr = axis_router_transaction::type_id::create("tr");
    tr.tr_id = next_id++;
    tr.ingress = src;
    tr.dest = invalid ? 7 : dst;
    tr.length = len;
    tr.invalid_dest = invalid;
    tr.malformed = malformed;
    tr.oversize = oversize;
    tr.payload.delete();
    tr.inter_beat_gap.delete();
    for (int unsigned i = 0; i < len; i++) begin
      tr.payload.push_back((base + i) & 32'hff);
      tr.inter_beat_gap.push_back(gap);
    end
    tr.start(vseqr.ingress_seqr[src]);
  endtask
endclass

class axis_router_routing_vseq extends axis_router_base_vseq;
  `uvm_object_utils(axis_router_routing_vseq)
  function new(string name = "axis_router_routing_vseq"); super.new(name); endfunction
  task body();
    for (int unsigned d = 0; d < 4; d++) begin
      send_pkt(0, d, d + 1, 8'h10 + (d * 8));
      send_pkt(1, d, 2, 8'h40 + (d * 8));
    end
  endtask
endclass

class axis_router_concurrency_vseq extends axis_router_base_vseq;
  `uvm_object_utils(axis_router_concurrency_vseq)
  function new(string name = "axis_router_concurrency_vseq"); super.new(name); endfunction
  task body();
    fork
      send_pkt(0, 0, 3, 8'h80);
      send_pkt(1, 2, 3, 8'ha0);
    join
  endtask
endclass

class axis_router_contention_vseq extends axis_router_base_vseq;
  `uvm_object_utils(axis_router_contention_vseq)
  function new(string name = "axis_router_contention_vseq"); super.new(name); endfunction
  task body();
    fork
      begin send_pkt(0, 1, 2, 8'h20); send_pkt(0, 1, 2, 8'h30); end
      begin send_pkt(1, 1, 2, 8'h40); send_pkt(1, 1, 2, 8'h50); end
    join
  endtask
endclass

class axis_router_drop_vseq extends axis_router_base_vseq;
  `uvm_object_utils(axis_router_drop_vseq)
  function new(string name = "axis_router_drop_vseq"); super.new(name); endfunction
  task body();
    send_pkt(0, 0, 2, 8'hd0, 1'b1, 1'b0, 1'b0);
    send_pkt(1, 2, 3, 8'he0, 1'b0, 1'b1, 1'b0);
    send_pkt(0, 3, 6, 8'hf0, 1'b0, 1'b0, 1'b1);
  endtask
endclass

class axis_router_random_vseq extends axis_router_base_vseq;
  `uvm_object_utils(axis_router_random_vseq)
  function new(string name = "axis_router_random_vseq"); super.new(name); endfunction
  task body();
    int unsigned state = vseqr.cfg.seed;
    for (int unsigned n = 0; n < 24; n++) begin
      state = ((state * 1103515245) + 12345) & 32'h7fffffff;
      send_pkt(state % 2, (state >> 3) % 4, 1 + ((state >> 5) % 4), state & 8'hff,
               ((state % 17) == 0), ((state % 19) == 0), ((state % 23) == 0), state % 3);
    end
  endtask
endclass

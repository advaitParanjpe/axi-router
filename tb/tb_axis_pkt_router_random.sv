`timescale 1ns/1ps

module tb_axis_pkt_router_random;
  localparam int DATA_W = 8;
  localparam int DEST_W = 3;
  localparam int IN_PORTS = 2;
  localparam int OUT_PORTS = 4;
  localparam int INGRESS_MAX_PKT_BEATS = 4;
  localparam int COUNTER_W = 4;
  localparam int MAX_PKTS = 256;
  localparam int MAX_BEATS = 8;
  localparam int RANDOM_PACKETS = 80;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst;
  axis_stream_if #(.DATA_W(DATA_W), .DEST_W(DEST_W)) s0_if (.clk(clk), .rst(rst));
  axis_stream_if #(.DATA_W(DATA_W), .DEST_W(DEST_W)) s1_if (.clk(clk), .rst(rst));
  axis_stream_if #(.DATA_W(DATA_W), .DEST_W(DEST_W)) m0_if (.clk(clk), .rst(rst));
  axis_stream_if #(.DATA_W(DATA_W), .DEST_W(DEST_W)) m1_if (.clk(clk), .rst(rst));
  axis_stream_if #(.DATA_W(DATA_W), .DEST_W(DEST_W)) m2_if (.clk(clk), .rst(rst));
  axis_stream_if #(.DATA_W(DATA_W), .DEST_W(DEST_W)) m3_if (.clk(clk), .rst(rst));

  logic [IN_PORTS-1:0][DATA_W-1:0] s_axis_tdata;
  logic [IN_PORTS-1:0] s_axis_tvalid;
  logic [IN_PORTS-1:0] s_axis_tready;
  logic [IN_PORTS-1:0] s_axis_tlast;
  logic [IN_PORTS-1:0][DEST_W-1:0] s_axis_tdest;
  logic [OUT_PORTS-1:0][DATA_W-1:0] m_axis_tdata;
  logic [OUT_PORTS-1:0] m_axis_tvalid;
  logic [OUT_PORTS-1:0] m_axis_tready;
  logic [OUT_PORTS-1:0] m_axis_tlast;
  logic [OUT_PORTS-1:0][DEST_W-1:0] m_axis_tdest;
  logic [IN_PORTS-1:0][COUNTER_W-1:0] accepted_pkt_count;
  logic [OUT_PORTS-1:0][COUNTER_W-1:0] forwarded_pkt_count;
  logic [IN_PORTS-1:0][COUNTER_W-1:0] drop_invalid_dest_count;
  logic [IN_PORTS-1:0][COUNTER_W-1:0] drop_oversize_count;
  logic [IN_PORTS-1:0][COUNTER_W-1:0] drop_malformed_count;

  integer seed;
  integer initial_seed;
  integer src_seed [0:IN_PORTS-1];
  integer sink_state [0:OUT_PORTS-1];
  integer sink_mode [0:OUT_PORTS-1];
  integer long_stall_count [0:OUT_PORTS-1];
  bit stop_sinks;

  reg [7:0] exp_data [0:OUT_PORTS-1][0:MAX_PKTS-1][0:MAX_BEATS-1];
  integer exp_len [0:OUT_PORTS-1][0:MAX_PKTS-1];
  integer exp_src [0:OUT_PORTS-1][0:MAX_PKTS-1];
  bit exp_valid [0:OUT_PORTS-1][0:MAX_PKTS-1];
  integer exp_wr [0:OUT_PORTS-1];
  integer exp_matched [0:OUT_PORTS-1];
  reg [7:0] in_data [0:IN_PORTS-1][0:MAX_BEATS-1];
  integer in_len [0:IN_PORTS-1];
  integer in_dest [0:IN_PORTS-1];
  bit in_active [0:IN_PORTS-1];
  bit in_invalid [0:IN_PORTS-1];
  bit in_malformed [0:IN_PORTS-1];
  bit in_oversize [0:IN_PORTS-1];
  integer out_len [0:OUT_PORTS-1];
  reg [7:0] out_data [0:OUT_PORTS-1][0:MAX_BEATS-1];

  integer exp_accepted [0:IN_PORTS-1];
  integer exp_invalid [0:IN_PORTS-1];
  integer exp_oversize [0:IN_PORTS-1];
  integer exp_malformed [0:IN_PORTS-1];
  integer exp_forwarded [0:OUT_PORTS-1];
  integer source_matched [0:IN_PORTS-1];
  integer fairness_sequence [0:15];
  integer fairness_count;

  integer cov_ingress [0:IN_PORTS-1];
  integer cov_dest [0:OUT_PORTS-1];
  integer cov_ingress_dest [0:IN_PORTS-1][0:OUT_PORTS-1];
  integer cov_invalid;
  integer cov_malformed;
  integer cov_oversize;
  integer cov_single;
  integer cov_multi;
  integer cov_max;
  integer cov_contention;
  integer cov_contention_winner [0:IN_PORTS-1];
  integer cov_rr_transition;
  integer cov_concurrent_outputs;
  integer cov_stall;
  integer cov_long_stall;
  integer cov_lock_stall;
  integer cov_reset_capture;
  integer cov_reset_transmit;
  integer cov_reset_final;
  integer cov_counter_wrap;
  integer cov_post_drop_valid;
  integer cov_hol_blocking;

  assign s_axis_tdata[0] = s0_if.tdata;
  assign s_axis_tvalid[0] = s0_if.tvalid;
  assign s_axis_tlast[0] = s0_if.tlast;
  assign s_axis_tdest[0] = s0_if.tdest;
  assign s0_if.tready = s_axis_tready[0];
  assign s_axis_tdata[1] = s1_if.tdata;
  assign s_axis_tvalid[1] = s1_if.tvalid;
  assign s_axis_tlast[1] = s1_if.tlast;
  assign s_axis_tdest[1] = s1_if.tdest;
  assign s1_if.tready = s_axis_tready[1];

  assign m0_if.tdata = m_axis_tdata[0];
  assign m0_if.tvalid = m_axis_tvalid[0];
  assign m_axis_tready[0] = m0_if.tready;
  assign m0_if.tlast = m_axis_tlast[0];
  assign m0_if.tdest = m_axis_tdest[0];
  assign m1_if.tdata = m_axis_tdata[1];
  assign m1_if.tvalid = m_axis_tvalid[1];
  assign m_axis_tready[1] = m1_if.tready;
  assign m1_if.tlast = m_axis_tlast[1];
  assign m1_if.tdest = m_axis_tdest[1];
  assign m2_if.tdata = m_axis_tdata[2];
  assign m2_if.tvalid = m_axis_tvalid[2];
  assign m_axis_tready[2] = m2_if.tready;
  assign m2_if.tlast = m_axis_tlast[2];
  assign m2_if.tdest = m_axis_tdest[2];
  assign m3_if.tdata = m_axis_tdata[3];
  assign m3_if.tvalid = m_axis_tvalid[3];
  assign m_axis_tready[3] = m3_if.tready;
  assign m3_if.tlast = m_axis_tlast[3];
  assign m3_if.tdest = m_axis_tdest[3];

  axis_pkt_router #(
    .DATA_W(DATA_W),
    .DEST_W(DEST_W),
    .INGRESS_MAX_PKT_BEATS(INGRESS_MAX_PKT_BEATS),
    .COUNTER_W(COUNTER_W)
  ) dut (
    .clk(clk),
    .rst(rst),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tdest(s_axis_tdest),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tdest(m_axis_tdest),
    .accepted_pkt_count(accepted_pkt_count),
    .forwarded_pkt_count(forwarded_pkt_count),
    .drop_invalid_dest_count(drop_invalid_dest_count),
    .drop_oversize_count(drop_oversize_count),
    .drop_malformed_count(drop_malformed_count)
  );

  axis_stream_protocol_checker #(
    .DATA_W(DATA_W),
    .DEST_W(DEST_W),
    .OUT_PORTS(OUT_PORTS)
  ) protocol_checker (
    .clk(clk),
    .rst(rst),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tdest(m_axis_tdest)
  );

  function automatic integer lcg_next(input integer value);
    begin
      lcg_next = ((value * 1103515245) + 12345) & 32'h7fffffff;
    end
  endfunction

  task automatic wait_cycles(input integer n);
    integer i;
    begin
      for (i = 0; i < n; i = i + 1) @(posedge clk);
    end
  endtask

  task automatic clear_expected;
    integer i, o, p, b;
    begin
      for (i = 0; i < IN_PORTS; i = i + 1) begin
        in_len[i] = 0;
        in_dest[i] = 0;
        in_active[i] = 1'b0;
        in_invalid[i] = 1'b0;
        in_malformed[i] = 1'b0;
        in_oversize[i] = 1'b0;
        exp_accepted[i] = 0;
        exp_invalid[i] = 0;
        exp_oversize[i] = 0;
        exp_malformed[i] = 0;
        source_matched[i] = 0;
        cov_ingress[i] = 0;
        for (o = 0; o < OUT_PORTS; o = o + 1) cov_ingress_dest[i][o] = 0;
        for (b = 0; b < MAX_BEATS; b = b + 1) in_data[i][b] = 8'h00;
      end
      for (o = 0; o < OUT_PORTS; o = o + 1) begin
        exp_wr[o] = 0;
        exp_matched[o] = 0;
        exp_forwarded[o] = 0;
        out_len[o] = 0;
        cov_dest[o] = 0;
        for (p = 0; p < MAX_PKTS; p = p + 1) begin
          exp_len[o][p] = 0;
          exp_src[o][p] = 0;
          exp_valid[o][p] = 1'b0;
          for (b = 0; b < MAX_BEATS; b = b + 1) exp_data[o][p][b] = 8'h00;
        end
        for (b = 0; b < MAX_BEATS; b = b + 1) out_data[o][b] = 8'h00;
      end
      fairness_count = 0;
      cov_invalid = 0;
      cov_malformed = 0;
      cov_oversize = 0;
      cov_single = 0;
      cov_multi = 0;
      cov_max = 0;
      cov_contention = 0;
      cov_contention_winner[0] = 0;
      cov_contention_winner[1] = 0;
      cov_rr_transition = 0;
      cov_concurrent_outputs = 0;
      cov_stall = 0;
      cov_long_stall = 0;
      cov_lock_stall = 0;
      cov_reset_capture = 0;
      cov_reset_transmit = 0;
      cov_reset_final = 0;
      cov_counter_wrap = 0;
      cov_post_drop_valid = 0;
      cov_hol_blocking = 0;
    end
  endtask

  task automatic drive_idle(input integer src);
    begin
      case (src)
        0: begin s0_if.tvalid = 1'b0; s0_if.tlast = 1'b0; s0_if.tdata = '0; s0_if.tdest = '0; end
        1: begin s1_if.tvalid = 1'b0; s1_if.tlast = 1'b0; s1_if.tdata = '0; s1_if.tdest = '0; end
      endcase
    end
  endtask

  task automatic source_send_packet(
    input integer src,
    input integer dst,
    input integer beats,
    input integer base,
    input bit malformed,
    input integer max_gap
  );
    integer i;
    integer gap;
    logic [DATA_W-1:0] held_data;
    logic [DEST_W-1:0] held_dest;
    logic held_last;
    begin
      if (beats <= 0 || beats > MAX_BEATS) $fatal(1, "source BFM: illegal packet length %0d", beats);
      for (i = 0; i < beats; i = i + 1) begin
        if (max_gap > 0) begin
          src_seed[src] = lcg_next(src_seed[src]);
          gap = src_seed[src] % (max_gap + 1);
          wait_cycles(gap);
        end
        @(negedge clk);
        held_data = DATA_W'((base + i) & 8'hff);
        held_dest = (malformed && i > 0) ? DEST_W'(dst ^ 1) : DEST_W'(dst);
        held_last = (i == beats - 1);
        case (src)
          0: begin s0_if.tdata = held_data; s0_if.tdest = held_dest; s0_if.tlast = held_last; s0_if.tvalid = 1'b1; end
          1: begin s1_if.tdata = held_data; s1_if.tdest = held_dest; s1_if.tlast = held_last; s1_if.tvalid = 1'b1; end
        endcase
        do begin
          @(posedge clk);
          if (rst) begin
            drive_idle(src);
            wait (!rst);
            @(posedge clk);
          end else begin
            case (src)
              0: if (s0_if.tvalid && !s0_if.tready) begin
                   if (s0_if.tdata !== held_data || s0_if.tdest !== held_dest || s0_if.tlast !== held_last) $fatal(1, "source BFM: source 0 changed while stalled");
                 end
              1: if (s1_if.tvalid && !s1_if.tready) begin
                   if (s1_if.tdata !== held_data || s1_if.tdest !== held_dest || s1_if.tlast !== held_last) $fatal(1, "source BFM: source 1 changed while stalled");
                 end
            endcase
          end
        end while ((src == 0 && !s0_if.tready) || (src == 1 && !s1_if.tready));
      end
      @(negedge clk);
      drive_idle(src);
    end
  endtask

  task automatic reset_dut(input bit clear_model);
    begin
      @(negedge clk);
      rst = 1'b1;
      drive_idle(0);
      drive_idle(1);
      m0_if.tready = 1'b0;
      m1_if.tready = 1'b0;
      m2_if.tready = 1'b0;
      m3_if.tready = 1'b0;
      wait_cycles(4);
      @(negedge clk);
      rst = 1'b0;
      m0_if.tready = 1'b1;
      m1_if.tready = 1'b1;
      m2_if.tready = 1'b1;
      m3_if.tready = 1'b1;
      wait_cycles(2);
      if (clear_model) clear_expected();
      if (accepted_pkt_count !== '0) $fatal(1, "reset: accepted counters not zero");
      if (forwarded_pkt_count !== '0) $fatal(1, "reset: forwarded counters not zero");
      if (drop_invalid_dest_count !== '0) $fatal(1, "reset: invalid counters not zero");
      if (drop_oversize_count !== '0) $fatal(1, "reset: oversize counters not zero");
      if (drop_malformed_count !== '0) $fatal(1, "reset: malformed counters not zero");
    end
  endtask

  task automatic enqueue_expected(input integer src, input integer dst, input integer beats);
    integer b;
    integer slot;
    begin
      if (dst < 0 || dst >= OUT_PORTS) $fatal(1, "reference model: illegal enqueue destination %0d", dst);
      slot = exp_wr[dst];
      if (slot >= MAX_PKTS) $fatal(1, "reference model: expected queue overflow on output %0d", dst);
      exp_valid[dst][slot] = 1'b1;
      exp_src[dst][slot] = src;
      exp_len[dst][slot] = beats;
      for (b = 0; b < beats; b = b + 1) exp_data[dst][slot][b] = in_data[src][b];
      exp_wr[dst] = exp_wr[dst] + 1;
      exp_accepted[src] = exp_accepted[src] + 1;
      exp_forwarded[dst] = exp_forwarded[dst] + 1;
      cov_ingress[src] = cov_ingress[src] + 1;
      cov_dest[dst] = cov_dest[dst] + 1;
      cov_ingress_dest[src][dst] = cov_ingress_dest[src][dst] + 1;
      if (beats == 1) cov_single = cov_single + 1;
      else cov_multi = cov_multi + 1;
      if (beats == INGRESS_MAX_PKT_BEATS) cov_max = cov_max + 1;
    end
  endtask

  task automatic classify_input_packet(input integer src);
    begin
      if (in_invalid[src]) begin
        exp_invalid[src] = exp_invalid[src] + 1;
        cov_invalid = cov_invalid + 1;
      end else if (in_malformed[src]) begin
        exp_malformed[src] = exp_malformed[src] + 1;
        cov_malformed = cov_malformed + 1;
      end else if (in_oversize[src]) begin
        exp_oversize[src] = exp_oversize[src] + 1;
        cov_oversize = cov_oversize + 1;
      end else begin
        enqueue_expected(src, in_dest[src], in_len[src]);
      end
      in_len[src] = 0;
      in_dest[src] = 0;
      in_active[src] = 1'b0;
      in_invalid[src] = 1'b0;
      in_malformed[src] = 1'b0;
      in_oversize[src] = 1'b0;
    end
  endtask

  task automatic match_output_packet(input integer out);
    integer p, b;
    bit matched;
    begin
      matched = 1'b0;
      if (out_len[out] <= 0) $fatal(1, "scoreboard: empty output packet on output %0d", out);
      for (p = 0; p < exp_wr[out]; p = p + 1) begin
        if (exp_valid[out][p] && exp_len[out][p] == out_len[out]) begin
          matched = 1'b1;
          for (b = 0; b < out_len[out]; b = b + 1) begin
            if (exp_data[out][p][b] !== out_data[out][b]) matched = 1'b0;
          end
          if (matched) begin
            exp_valid[out][p] = 1'b0;
            exp_matched[out] = exp_matched[out] + 1;
            source_matched[exp_src[out][p]] = source_matched[exp_src[out][p]] + 1;
            if (out == 1 && fairness_count < 16) begin
              fairness_sequence[fairness_count] = exp_src[out][p];
              fairness_count = fairness_count + 1;
            end
            p = exp_wr[out];
          end
        end
      end
      if (!matched) begin
      $fatal(1, "scoreboard: unexpected output packet out=%0d len=%0d seed=%0d first=0x%02x", out, out_len[out], initial_seed, out_data[out][0]);
      end
      out_len[out] = 0;
    end
  endtask

  task automatic wait_for_idle;
    integer timeout;
    integer outstanding;
    begin
      timeout = 5000;
      do begin
        outstanding = 0;
        for (int o = 0; o < OUT_PORTS; o = o + 1) outstanding = outstanding + (exp_wr[o] - exp_matched[o]);
        if (outstanding != 0) @(posedge clk);
        timeout = timeout - 1;
      end while (outstanding != 0 && timeout > 0);
      if (timeout == 0) $fatal(1, "timeout: undrained expected packets seed=%0d outstanding=%0d valid=%b ready=%b", initial_seed, outstanding, m_axis_tvalid, m_axis_tready);
      wait_cycles(10);
    end
  endtask

  task automatic check_counters;
    integer i, o;
    begin
      for (i = 0; i < IN_PORTS; i = i + 1) begin
        if (accepted_pkt_count[i] !== COUNTER_W'(exp_accepted[i])) $fatal(1, "counter: accepted[%0d] exp=%0d act=%0d", i, exp_accepted[i], accepted_pkt_count[i]);
        if (drop_invalid_dest_count[i] !== COUNTER_W'(exp_invalid[i])) $fatal(1, "counter: invalid[%0d] exp=%0d act=%0d", i, exp_invalid[i], drop_invalid_dest_count[i]);
        if (drop_oversize_count[i] !== COUNTER_W'(exp_oversize[i])) $fatal(1, "counter: oversize[%0d] exp=%0d act=%0d", i, exp_oversize[i], drop_oversize_count[i]);
        if (drop_malformed_count[i] !== COUNTER_W'(exp_malformed[i])) $fatal(1, "counter: malformed[%0d] exp=%0d act=%0d", i, exp_malformed[i], drop_malformed_count[i]);
        if (exp_accepted[i] >= (1 << COUNTER_W)) cov_counter_wrap = cov_counter_wrap + 1;
        if (exp_invalid[i] >= (1 << COUNTER_W)) cov_counter_wrap = cov_counter_wrap + 1;
        if (exp_oversize[i] >= (1 << COUNTER_W)) cov_counter_wrap = cov_counter_wrap + 1;
        if (exp_malformed[i] >= (1 << COUNTER_W)) cov_counter_wrap = cov_counter_wrap + 1;
      end
      for (o = 0; o < OUT_PORTS; o = o + 1) begin
        if (forwarded_pkt_count[o] !== COUNTER_W'(exp_forwarded[o])) $fatal(1, "counter: forwarded[%0d] exp=%0d act=%0d", o, exp_forwarded[o], forwarded_pkt_count[o]);
        if (exp_forwarded[o] >= (1 << COUNTER_W)) cov_counter_wrap = cov_counter_wrap + 1;
      end
    end
  endtask

  task automatic check_coverage;
    begin
      if (cov_ingress[0] == 0 || cov_ingress[1] == 0) $fatal(1, "coverage: missing ingress bin");
      if (cov_dest[0] == 0 || cov_dest[1] == 0 || cov_dest[2] == 0 || cov_dest[3] == 0) $fatal(1, "coverage: missing destination bin");
      for (int i = 0; i < IN_PORTS; i = i + 1) begin
        for (int o = 0; o < OUT_PORTS; o = o + 1) begin
          if (cov_ingress_dest[i][o] == 0) $fatal(1, "coverage: missing ingress x destination bin i=%0d o=%0d", i, o);
        end
      end
      if (cov_single == 0 || cov_multi == 0 || cov_max == 0) $fatal(1, "coverage: missing length bin");
      if (cov_invalid == 0 || cov_malformed == 0 || cov_oversize == 0) $fatal(1, "coverage: missing drop bin");
      if (cov_contention == 0 || cov_contention_winner[0] == 0 || cov_contention_winner[1] == 0 || cov_rr_transition == 0) $fatal(1, "coverage: missing contention winner/transition bin");
      if (cov_concurrent_outputs == 0) $fatal(1, "coverage: missing different-output concurrency bin");
      if (cov_stall == 0 || cov_long_stall == 0 || cov_lock_stall == 0) $fatal(1, "coverage: missing stall bin");
      if (cov_reset_capture == 0 || cov_reset_transmit == 0 || cov_reset_final == 0) $fatal(1, "coverage: missing reset bin");
      if (cov_counter_wrap == 0) $fatal(1, "coverage: missing counter wrap bin");
      if (cov_post_drop_valid == 0) $fatal(1, "coverage: missing valid traffic after drop bin");
      if (cov_hol_blocking == 0) $fatal(1, "coverage: missing head-of-line blocking bin");
      $display("COVERAGE seed=%0d ingress=%0d/%0d dest=%0d/%0d/%0d/%0d ixD=%0d/%0d/%0d/%0d:%0d/%0d/%0d/%0d len_single=%0d len_multi=%0d max=%0d drops inv/mal/os=%0d/%0d/%0d post_drop=%0d contention=%0d winners=%0d/%0d rr_trans=%0d concurrent=%0d stalls=%0d long=%0d lock=%0d reset cap/xmit/final=%0d/%0d/%0d counter_wrap=%0d hol=%0d",
               initial_seed, cov_ingress[0], cov_ingress[1], cov_dest[0], cov_dest[1], cov_dest[2], cov_dest[3],
               cov_ingress_dest[0][0], cov_ingress_dest[0][1], cov_ingress_dest[0][2], cov_ingress_dest[0][3],
               cov_ingress_dest[1][0], cov_ingress_dest[1][1], cov_ingress_dest[1][2], cov_ingress_dest[1][3],
               cov_single, cov_multi, cov_max, cov_invalid, cov_malformed, cov_oversize, cov_post_drop_valid, cov_contention,
               cov_contention_winner[0], cov_contention_winner[1], cov_rr_transition,
               cov_concurrent_outputs, cov_stall, cov_long_stall, cov_lock_stall, cov_reset_capture,
               cov_reset_transmit, cov_reset_final, cov_counter_wrap, cov_hol_blocking);
    end
  endtask

  task automatic run_fairness_directed;
    begin
      sink_mode[1] = 0;
      fork
        begin
          source_send_packet(0, 1, 2, 8'h10, 1'b0, 0);
          source_send_packet(0, 1, 2, 8'h20, 1'b0, 0);
          source_send_packet(0, 1, 2, 8'h30, 1'b0, 0);
          source_send_packet(0, 1, 2, 8'h40, 1'b0, 0);
        end
        begin
          source_send_packet(1, 1, 2, 8'h50, 1'b0, 0);
          source_send_packet(1, 1, 2, 8'h60, 1'b0, 0);
          source_send_packet(1, 1, 2, 8'h70, 1'b0, 0);
          source_send_packet(1, 1, 2, 8'h80, 1'b0, 0);
        end
      join
      cov_contention = cov_contention + 1;
      wait_for_idle();
      if (source_matched[0] < 4 || source_matched[1] < 4) $fatal(1, "fairness: both ingresses did not make progress");
      if (fairness_count < 8) $fatal(1, "fairness: expected 8 same-output packets, got %0d", fairness_count);
      if (fairness_sequence[0] != 0) $fatal(1, "fairness: documented initial winner was not ingress 0");
      cov_contention_winner[fairness_sequence[0]] = cov_contention_winner[fairness_sequence[0]] + 1;
      for (int i = 1; i < 8; i = i + 1) begin
        if (fairness_sequence[i] == fairness_sequence[i-1]) $fatal(1, "fairness: round-robin did not alternate at position %0d", i);
        cov_contention_winner[fairness_sequence[i]] = cov_contention_winner[fairness_sequence[i]] + 1;
        cov_rr_transition = cov_rr_transition + 1;
      end
    end
  endtask

  task automatic run_directed_extensions;
    begin
      for (int src = 0; src < IN_PORTS; src = src + 1) begin
        for (int dst = 0; dst < OUT_PORTS; dst = dst + 1) begin
          source_send_packet(src, dst, 1 + ((src + dst) % INGRESS_MAX_PKT_BEATS), 8'h08 + (src * 8) + dst, 1'b0, 0);
        end
      end
      wait_for_idle();

      fork
        source_send_packet(0, 0, 3, 8'h90, 1'b0, 0);
        source_send_packet(1, 2, 3, 8'ha0, 1'b0, 0);
      join
      cov_concurrent_outputs = cov_concurrent_outputs + 1;
      wait_for_idle();

      sink_mode[0] = 2;
      fork
        source_send_packet(0, 0, 4, 8'hb0, 1'b0, 0);
        source_send_packet(1, 3, 2, 8'hc0, 1'b0, 0);
      join
      cov_lock_stall = cov_lock_stall + 1;
      wait_for_idle();
      sink_mode[0] = 1;

      source_send_packet(0, 7, 2, 8'hd0, 1'b0, 0);
      source_send_packet(0, 0, 1, 8'hd8, 1'b0, 0);
      cov_post_drop_valid = cov_post_drop_valid + 1;
      source_send_packet(1, 2, 3, 8'he0, 1'b1, 0);
      source_send_packet(1, 1, 1, 8'he8, 1'b0, 0);
      cov_post_drop_valid = cov_post_drop_valid + 1;
      source_send_packet(0, 3, INGRESS_MAX_PKT_BEATS + 2, 8'hf0, 1'b0, 0);
      source_send_packet(0, 2, 1, 8'hf8, 1'b0, 0);
      cov_post_drop_valid = cov_post_drop_valid + 1;
      source_send_packet(1, 0, INGRESS_MAX_PKT_BEATS, 8'h21, 1'b0, 0);
      wait_for_idle();

      sink_mode[1] = 2;
      source_send_packet(0, 1, 4, 8'h61, 1'b0, 0);
      wait_cycles(4);
      if (s_axis_tready[0]) $fatal(1, "hol: ingress accepted a later packet while head packet was blocked");
      cov_hol_blocking = cov_hol_blocking + 1;
      wait_for_idle();
      sink_mode[1] = 1;
    end
  endtask

  task automatic run_reset_scenarios;
    begin
      fork
        source_send_packet(0, 0, 4, 8'h31, 1'b0, 1);
        begin
          wait_cycles(3);
          reset_dut(1'b1);
        end
      join
      cov_reset_capture = cov_reset_capture + 1;

      sink_mode[3] = 2;
      source_send_packet(0, 3, 4, 8'h41, 1'b0, 0);
      wait_cycles(6);
      if (m_axis_tvalid[3]) begin
        reset_dut(1'b1);
      end else begin
        $fatal(1, "reset: transmit reset scenario did not reach output valid");
      end
      cov_reset_capture = cov_reset_capture + 1;
      cov_reset_transmit = cov_reset_transmit + 1;
      sink_mode[3] = 1;

      source_send_packet(1, 2, 1, 8'h51, 1'b0, 0);
      wait_cycles(1);
      reset_dut(1'b1);
      cov_reset_capture = cov_reset_capture + 1;
      cov_reset_transmit = cov_reset_transmit + 1;
      cov_reset_final = cov_reset_final + 1;
    end
  endtask

  task automatic run_random_traffic;
    integer n;
    integer src;
    integer dst;
    integer len;
    integer kind;
    integer base;
    begin
      for (n = 0; n < RANDOM_PACKETS; n = n + 1) begin
        seed = lcg_next(seed);
        src = seed % IN_PORTS;
        seed = lcg_next(seed);
        kind = seed % 10;
        seed = lcg_next(seed);
        dst = seed % 5;
        seed = lcg_next(seed);
        len = 1 + (seed % 6);
        seed = lcg_next(seed);
        base = seed & 8'hff;
        if (kind == 0) dst = 7;
        if (kind == 1) len = INGRESS_MAX_PKT_BEATS + 1 + (seed % 2);
        if (kind == 2 && len < 2) len = 2;
        source_send_packet(src, dst, len, base, kind == 2, seed % 3);
        if ((n % 17) == 0) wait_for_idle();
      end
      wait_for_idle();
    end
  endtask

  always @(negedge clk) begin
    integer o;
    if (stop_sinks) begin
      m0_if.tready <= 1'b1;
      m1_if.tready <= 1'b1;
      m2_if.tready <= 1'b1;
      m3_if.tready <= 1'b1;
    end else if (rst) begin
      m0_if.tready <= 1'b0;
      m1_if.tready <= 1'b0;
      m2_if.tready <= 1'b0;
      m3_if.tready <= 1'b0;
      for (o = 0; o < OUT_PORTS; o = o + 1) long_stall_count[o] <= 0;
    end else begin
      for (o = 0; o < OUT_PORTS; o = o + 1) begin
        sink_state[o] = lcg_next(sink_state[o]);
        if (long_stall_count[o] > 0) begin
          long_stall_count[o] <= long_stall_count[o] - 1;
          case (o)
            0: m0_if.tready <= 1'b0;
            1: m1_if.tready <= 1'b0;
            2: m2_if.tready <= 1'b0;
            3: m3_if.tready <= 1'b0;
          endcase
        end else begin
          if (sink_mode[o] == 0) begin
            case (o)
              0: m0_if.tready <= 1'b1;
              1: m1_if.tready <= 1'b1;
              2: m2_if.tready <= 1'b1;
              3: m3_if.tready <= 1'b1;
            endcase
          end else if (sink_mode[o] == 2) begin
            long_stall_count[o] <= 12;
            sink_mode[o] <= 1;
            cov_long_stall = cov_long_stall + 1;
          end else begin
            case (o)
              0: m0_if.tready <= ((sink_state[o] % 4) != 0);
              1: m1_if.tready <= ((sink_state[o] % 5) != 0);
              2: m2_if.tready <= ((sink_state[o] % 3) != 0);
              3: m3_if.tready <= ((sink_state[o] % 6) != 0);
            endcase
          end
        end
      end
    end
  end

  always @(posedge clk) begin
    integer i;
    integer o;
    if (rst) begin
      for (i = 0; i < IN_PORTS; i = i + 1) begin
        in_len[i] = 0;
        in_active[i] = 1'b0;
      end
      for (o = 0; o < OUT_PORTS; o = o + 1) out_len[o] = 0;
    end else begin
      if (s_axis_tvalid[0] && s_axis_tready[0]) begin
        if (!in_active[0]) begin
          in_active[0] = 1'b1;
          in_dest[0] = s_axis_tdest[0];
          in_invalid[0] = (s_axis_tdest[0] > DEST_W'(3));
          in_malformed[0] = 1'b0;
          in_oversize[0] = 1'b0;
        end else if (!in_invalid[0] && s_axis_tdest[0] != in_dest[0]) begin
          in_malformed[0] = 1'b1;
        end
        if (in_len[0] < INGRESS_MAX_PKT_BEATS) in_data[0][in_len[0]] = s_axis_tdata[0];
        if (in_len[0] >= INGRESS_MAX_PKT_BEATS) in_oversize[0] = 1'b1;
        in_len[0] = in_len[0] + 1;
        if (s_axis_tlast[0]) classify_input_packet(0);
      end
      if (s_axis_tvalid[1] && s_axis_tready[1]) begin
        if (!in_active[1]) begin
          in_active[1] = 1'b1;
          in_dest[1] = s_axis_tdest[1];
          in_invalid[1] = (s_axis_tdest[1] > DEST_W'(3));
          in_malformed[1] = 1'b0;
          in_oversize[1] = 1'b0;
        end else if (!in_invalid[1] && s_axis_tdest[1] != in_dest[1]) begin
          in_malformed[1] = 1'b1;
        end
        if (in_len[1] < INGRESS_MAX_PKT_BEATS) in_data[1][in_len[1]] = s_axis_tdata[1];
        if (in_len[1] >= INGRESS_MAX_PKT_BEATS) in_oversize[1] = 1'b1;
        in_len[1] = in_len[1] + 1;
        if (s_axis_tlast[1]) classify_input_packet(1);
      end

      for (o = 0; o < OUT_PORTS; o = o + 1) begin
        if (m_axis_tvalid[o] && !m_axis_tready[o]) cov_stall = cov_stall + 1;
        if (m_axis_tvalid[o] && m_axis_tready[o]) begin
          if (m_axis_tdest[o] !== DEST_W'(o)) $fatal(1, "monitor: output %0d emitted tdest %0d", o, m_axis_tdest[o]);
          if (out_len[o] >= MAX_BEATS) $fatal(1, "monitor: output packet too long on output %0d", o);
          out_data[o][out_len[o]] = m_axis_tdata[o];
          out_len[o] = out_len[o] + 1;
          if (m_axis_tlast[o]) match_output_packet(o);
        end
      end
    end
  end

  initial begin
    if (!$value$plusargs("SEED=%d", seed)) seed = 32'd1;
    initial_seed = seed;
    if ($test$plusargs("FORCE_SCOREBOARD_ERROR")) begin
      $display("Intentional forced scoreboard failure for nonzero-exit validation");
      $fatal(1, "forced scoreboard failure");
    end

    $display("RANDOM TB seed=%0d", initial_seed);
    src_seed[0] = seed ^ 32'h1234;
    src_seed[1] = seed ^ 32'h5678;
    for (int o = 0; o < OUT_PORTS; o = o + 1) begin
      sink_state[o] = seed ^ (32'h1000 + o);
      sink_mode[o] = 1;
      long_stall_count[o] = 0;
    end
    stop_sinks = 1'b0;
    rst = 1'b1;
    drive_idle(0);
    drive_idle(1);
    m0_if.tready = 1'b0;
    m1_if.tready = 1'b0;
    m2_if.tready = 1'b0;
    m3_if.tready = 1'b0;
    clear_expected();
    reset_dut(1'b1);

    run_reset_scenarios();
    run_fairness_directed();
    run_directed_extensions();
    run_random_traffic();
    check_counters();
    check_coverage();

    stop_sinks = 1'b1;
    $display("RANDOM TB PASS seed=%0d", initial_seed);
    $finish;
  end
endmodule

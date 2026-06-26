`timescale 1ns/1ps

module tb_axis_pkt_router;

  localparam int DATA_W = 8;
  localparam int DEST_W = 3;
  localparam int INGRESS_MAX_PKT_BEATS = 4;
  localparam int COUNTER_W = 4;
  localparam int IN_PORTS = 2;
  localparam int OUT_PORTS = 4;
  localparam int MAX_PKTS = 64;
  localparam int MAX_BEATS = 8;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst;
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

  reg [7:0] exp_data [0:OUT_PORTS-1][0:MAX_PKTS-1][0:MAX_BEATS-1];
  integer exp_len [0:OUT_PORTS-1][0:MAX_PKTS-1];
  integer exp_src [0:OUT_PORTS-1][0:MAX_PKTS-1];
  integer exp_cnt [0:OUT_PORTS-1];
  reg [7:0] act_data [0:OUT_PORTS-1][0:MAX_PKTS-1][0:MAX_BEATS-1];
  integer act_len [0:OUT_PORTS-1][0:MAX_PKTS-1];
  integer act_dest [0:OUT_PORTS-1][0:MAX_PKTS-1];
  integer act_cnt [0:OUT_PORTS-1];
  integer cur_len [0:OUT_PORTS-1];

  integer exp_accepted [0:IN_PORTS-1];
  integer exp_invalid [0:IN_PORTS-1];
  integer exp_oversize [0:IN_PORTS-1];
  integer exp_malformed [0:IN_PORTS-1];

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

  initial begin
    string wave_file;
    if ($test$plusargs("WAVES")) begin
      if (!$value$plusargs("WAVE_FILE=%s", wave_file)) wave_file = "build/tb_axis_pkt_router.vcd";
      $dumpfile(wave_file);
      $dumpvars(0, tb_axis_pkt_router);
    end
  end

  task automatic wait_cycles(input integer n);
    integer i;
    begin
      for (i = 0; i < n; i = i + 1) @(posedge clk);
    end
  endtask

  task automatic clear_scoreboard;
    integer o, p, b, i;
    begin
      for (o = 0; o < OUT_PORTS; o = o + 1) begin
        exp_cnt[o] = 0;
        act_cnt[o] = 0;
        cur_len[o] = 0;
        for (p = 0; p < MAX_PKTS; p = p + 1) begin
          exp_len[o][p] = 0;
          exp_src[o][p] = 0;
          act_len[o][p] = 0;
          act_dest[o][p] = 0;
          for (b = 0; b < MAX_BEATS; b = b + 1) begin
            exp_data[o][p][b] = 8'h00;
            act_data[o][p][b] = 8'h00;
          end
        end
      end
      for (i = 0; i < IN_PORTS; i = i + 1) begin
        exp_accepted[i] = 0;
        exp_invalid[i] = 0;
        exp_oversize[i] = 0;
        exp_malformed[i] = 0;
      end
    end
  endtask

  task automatic reset_dut;
    begin
      @(negedge clk);
      rst = 1'b1;
      s_axis_tdata = '0;
      s_axis_tvalid = '0;
      s_axis_tlast = '0;
      s_axis_tdest = '0;
      m_axis_tready = '1;
      wait_cycles(3);
      @(negedge clk);
      rst = 1'b0;
      wait_cycles(2);
      clear_scoreboard();
      if (m_axis_tvalid !== '0) $fatal(1, "outputs valid after reset");
      if (accepted_pkt_count !== '0) $fatal(1, "accepted counters not reset");
      if (forwarded_pkt_count !== '0) $fatal(1, "forwarded counters not reset");
      if (drop_invalid_dest_count !== '0) $fatal(1, "invalid counters not reset");
      if (drop_oversize_count !== '0) $fatal(1, "oversize counters not reset");
      if (drop_malformed_count !== '0) $fatal(1, "malformed counters not reset");
    end
  endtask

  task automatic expect_packet(input integer src, input integer dst, input integer beats, input integer base);
    integer i;
    begin
      exp_src[dst][exp_cnt[dst]] = src;
      exp_len[dst][exp_cnt[dst]] = beats;
      for (i = 0; i < beats; i = i + 1) begin
        exp_data[dst][exp_cnt[dst]][i] = (base + i) & 8'hff;
      end
      exp_cnt[dst] = exp_cnt[dst] + 1;
      exp_accepted[src] = exp_accepted[src] + 1;
    end
  endtask

  task automatic send_packet(
    input integer src,
    input integer dst,
    input integer beats,
    input integer base,
    input bit malformed
  );
    integer i;
    begin
      if (beats <= 0) $fatal(1, "send_packet beats must be positive");
      for (i = 0; i < beats; i = i + 1) begin
        @(negedge clk);
        s_axis_tdata[src] = (base + i) & 8'hff;
        s_axis_tdest[src] = (malformed && i > 0) ? DEST_W'(dst ^ 1) : DEST_W'(dst);
        s_axis_tlast[src] = (i == beats - 1);
        s_axis_tvalid[src] = 1'b1;
        do @(posedge clk); while (!s_axis_tready[src]);
      end
      @(negedge clk);
      s_axis_tvalid[src] = 1'b0;
      s_axis_tlast[src] = 1'b0;
      s_axis_tdata[src] = '0;
      s_axis_tdest[src] = '0;
    end
  endtask

  task automatic wait_packets;
    integer timeout;
    begin
      timeout = 2000;
      while (((act_cnt[0] < exp_cnt[0]) || (act_cnt[1] < exp_cnt[1]) ||
              (act_cnt[2] < exp_cnt[2]) || (act_cnt[3] < exp_cnt[3])) && timeout > 0) begin
        @(posedge clk);
        timeout = timeout - 1;
      end
      if (timeout == 0) begin
        $fatal(1, "timeout waiting packets exp=%0d/%0d/%0d/%0d act=%0d/%0d/%0d/%0d valid=%b ready=%b accepted=%0d/%0d fwd=%0d/%0d/%0d/%0d drop_inv=%0d/%0d drop_os=%0d/%0d drop_mal=%0d/%0d",
               exp_cnt[0], exp_cnt[1], exp_cnt[2], exp_cnt[3],
               act_cnt[0], act_cnt[1], act_cnt[2], act_cnt[3],
               m_axis_tvalid, m_axis_tready,
               accepted_pkt_count[0], accepted_pkt_count[1],
               forwarded_pkt_count[0], forwarded_pkt_count[1], forwarded_pkt_count[2], forwarded_pkt_count[3],
               drop_invalid_dest_count[0], drop_invalid_dest_count[1],
               drop_oversize_count[0], drop_oversize_count[1],
               drop_malformed_count[0], drop_malformed_count[1]);
      end
      wait_cycles(2);
    end
  endtask

  task automatic check_all;
    integer o, p, b;
    begin
      wait_packets();
      for (o = 0; o < OUT_PORTS; o = o + 1) begin
        if (act_cnt[o] !== exp_cnt[o]) $fatal(1, "output %0d packet count exp=%0d act=%0d", o, exp_cnt[o], act_cnt[o]);
        if (forwarded_pkt_count[o] !== COUNTER_W'(exp_cnt[o])) $fatal(1, "forwarded counter %0d exp=%0d act=%0d", o, exp_cnt[o], forwarded_pkt_count[o]);
        for (p = 0; p < exp_cnt[o]; p = p + 1) begin
          if (act_len[o][p] !== exp_len[o][p]) $fatal(1, "output %0d packet %0d len exp=%0d act=%0d", o, p, exp_len[o][p], act_len[o][p]);
          if (act_dest[o][p] !== o) $fatal(1, "output %0d packet %0d tdest exp=%0d act=%0d", o, p, o, act_dest[o][p]);
          for (b = 0; b < exp_len[o][p]; b = b + 1) begin
            if (act_data[o][p][b] !== exp_data[o][p][b]) begin
              $fatal(1, "output %0d packet %0d beat %0d exp=0x%02x act=0x%02x",
                     o, p, b, exp_data[o][p][b], act_data[o][p][b]);
            end
          end
        end
      end
      if (accepted_pkt_count[0] !== COUNTER_W'(exp_accepted[0])) $fatal(1, "accepted[0] exp=%0d act=%0d", exp_accepted[0], accepted_pkt_count[0]);
      if (accepted_pkt_count[1] !== COUNTER_W'(exp_accepted[1])) $fatal(1, "accepted[1] exp=%0d act=%0d", exp_accepted[1], accepted_pkt_count[1]);
      if (drop_invalid_dest_count[0] !== COUNTER_W'(exp_invalid[0])) $fatal(1, "invalid[0] exp=%0d act=%0d", exp_invalid[0], drop_invalid_dest_count[0]);
      if (drop_invalid_dest_count[1] !== COUNTER_W'(exp_invalid[1])) $fatal(1, "invalid[1] exp=%0d act=%0d", exp_invalid[1], drop_invalid_dest_count[1]);
      if (drop_oversize_count[0] !== COUNTER_W'(exp_oversize[0])) $fatal(1, "oversize[0] exp=%0d act=%0d", exp_oversize[0], drop_oversize_count[0]);
      if (drop_oversize_count[1] !== COUNTER_W'(exp_oversize[1])) $fatal(1, "oversize[1] exp=%0d act=%0d", exp_oversize[1], drop_oversize_count[1]);
      if (drop_malformed_count[0] !== COUNTER_W'(exp_malformed[0])) $fatal(1, "malformed[0] exp=%0d act=%0d", exp_malformed[0], drop_malformed_count[0]);
      if (drop_malformed_count[1] !== COUNTER_W'(exp_malformed[1])) $fatal(1, "malformed[1] exp=%0d act=%0d", exp_malformed[1], drop_malformed_count[1]);
    end
  endtask

  genvar go;
  generate
    for (go = 0; go < OUT_PORTS; go = go + 1) begin : gen_monitors
      always_ff @(posedge clk) begin
        if (rst) begin
          act_cnt[go] <= 0;
          cur_len[go] <= 0;
        end else if (m_axis_tvalid[go] && m_axis_tready[go]) begin
          act_data[go][act_cnt[go]][cur_len[go]] <= m_axis_tdata[go];
          act_dest[go][act_cnt[go]] <= m_axis_tdest[go];
          if (m_axis_tlast[go]) begin
            act_len[go][act_cnt[go]] <= cur_len[go] + 1;
            act_cnt[go] <= act_cnt[go] + 1;
            cur_len[go] <= 0;
          end else begin
            cur_len[go] <= cur_len[go] + 1;
          end
        end
      end
    end
  endgenerate

  initial begin
    rst = 1'b1;
    s_axis_tdata = '0;
    s_axis_tvalid = '0;
    s_axis_tlast = '0;
    s_axis_tdest = '0;
    m_axis_tready = '1;
    clear_scoreboard();

    reset_dut();

    expect_packet(0, 0, 1, 8'h10); send_packet(0, 0, 1, 8'h10, 1'b0);
    expect_packet(0, 1, 3, 8'h20); send_packet(0, 1, 3, 8'h20, 1'b0);
    expect_packet(0, 2, 4, 8'h30); send_packet(0, 2, 4, 8'h30, 1'b0);
    expect_packet(0, 3, 2, 8'h40); send_packet(0, 3, 2, 8'h40, 1'b0);
    expect_packet(1, 0, 2, 8'h50); send_packet(1, 0, 2, 8'h50, 1'b0);
    expect_packet(1, 1, 1, 8'h60); send_packet(1, 1, 1, 8'h60, 1'b0);
    expect_packet(1, 2, 3, 8'h70); send_packet(1, 2, 3, 8'h70, 1'b0);
    expect_packet(1, 3, 4, 8'h80); send_packet(1, 3, 4, 8'h80, 1'b0);
    check_all();

    m_axis_tready[0] = 1'b0;
    expect_packet(0, 0, 3, 8'h90);
    expect_packet(1, 2, 3, 8'ha0);
    fork
      send_packet(0, 0, 3, 8'h90, 1'b0);
      send_packet(1, 2, 3, 8'ha0, 1'b0);
    join
    wait_cycles(20);
    if (act_cnt[2] < exp_cnt[2]) $fatal(1, "unrelated output did not continue while output 0 was stalled");
    if (act_cnt[0] == exp_cnt[0]) $fatal(1, "stalled output 0 drained while not ready");
    m_axis_tready[0] = 1'b1;
    check_all();

    expect_packet(0, 1, 3, 8'hb0);
    expect_packet(1, 1, 3, 8'hc0);
    fork
      send_packet(0, 1, 3, 8'hb0, 1'b0);
      send_packet(1, 1, 3, 8'hc0, 1'b0);
    join
    check_all();

    send_packet(0, 7, 2, 8'hd0, 1'b0); exp_invalid[0] = exp_invalid[0] + 1;
    send_packet(1, 2, 3, 8'he0, 1'b1); exp_malformed[1] = exp_malformed[1] + 1;
    send_packet(0, 3, INGRESS_MAX_PKT_BEATS + 1, 8'hf0, 1'b0); exp_oversize[0] = exp_oversize[0] + 1;
    expect_packet(1, 3, INGRESS_MAX_PKT_BEATS, 8'h21);
    send_packet(1, 3, INGRESS_MAX_PKT_BEATS, 8'h21, 1'b0);
    expect_packet(0, 2, 1, 8'h31);
    send_packet(0, 2, 1, 8'h31, 1'b0);
    check_all();

    @(negedge clk);
    s_axis_tdata[0] = 8'h44;
    s_axis_tdest[0] = 3'd0;
    s_axis_tlast[0] = 1'b0;
    s_axis_tvalid[0] = 1'b1;
    do @(posedge clk); while (!s_axis_tready[0]);
    reset_dut();

    m_axis_tready[3] = 1'b0;
    expect_packet(0, 3, 3, 8'h55);
    send_packet(0, 3, 3, 8'h55, 1'b0);
    wait_cycles(5);
    if (!m_axis_tvalid[3]) $fatal(1, "expected output 3 valid before stalled reset");
    reset_dut();

    expect_packet(0, 0, 1, 8'h66);
    send_packet(0, 0, 1, 8'h66, 1'b0);
    check_all();

    $display("TB PASS generalized 2x4 directed regression");
    $finish;
  end

endmodule

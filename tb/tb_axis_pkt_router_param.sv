`timescale 1ns/1ps

module tb_axis_pkt_router_param #(
  parameter int DATA_W         = 32,
  parameter int MAX_PKT_BEATS  = 4,
  parameter int OUT_FIFO_DEPTH = 4
);

  initial begin
    string wave_file;
    if ($test$plusargs("WAVES")) begin
      if (!$value$plusargs("WAVE_FILE=%s", wave_file)) begin
        wave_file = "build/tb_axis_pkt_router_param.vcd";
      end
      $dumpfile(wave_file);
      $dumpvars(0, tb_axis_pkt_router_param);
    end
  end

  localparam int NORMAL_PKT_LIMIT = (MAX_PKT_BEATS < OUT_FIFO_DEPTH) ? MAX_PKT_BEATS : OUT_FIFO_DEPTH;
  localparam int NORMAL_PKT_BEATS = (NORMAL_PKT_LIMIT >= 2) ? 2 : 1;
  localparam int OVERSIZE_BEATS   = MAX_PKT_BEATS + 1;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst;

  logic [DATA_W-1:0] s_axis_tdata;
  logic              s_axis_tvalid;
  logic              s_axis_tready;
  logic              s_axis_tlast;

  logic [DATA_W-1:0] m0_axis_tdata;
  logic              m0_axis_tvalid;
  logic              m0_axis_tready;
  logic              m0_axis_tlast;

  logic [DATA_W-1:0] m1_axis_tdata;
  logic              m1_axis_tvalid;
  logic              m1_axis_tready;
  logic              m1_axis_tlast;

  logic [31:0]       pkt_to_m0_count;
  logic [31:0]       pkt_to_m1_count;
  logic [31:0]       pkt_drop_count;

  integer            m0_pkt_seen;
  integer            m1_pkt_seen;
  integer            m0_beat_seen;
  integer            m1_beat_seen;

  axis_pkt_router #(
    .DATA_W(DATA_W),
    .MAX_PKT_BEATS(MAX_PKT_BEATS),
    .OUT_FIFO_DEPTH(OUT_FIFO_DEPTH)
  ) dut (
    .clk(clk),
    .rst(rst),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .m0_axis_tdata(m0_axis_tdata),
    .m0_axis_tvalid(m0_axis_tvalid),
    .m0_axis_tready(m0_axis_tready),
    .m0_axis_tlast(m0_axis_tlast),
    .m1_axis_tdata(m1_axis_tdata),
    .m1_axis_tvalid(m1_axis_tvalid),
    .m1_axis_tready(m1_axis_tready),
    .m1_axis_tlast(m1_axis_tlast),
    .pkt_to_m0_count(pkt_to_m0_count),
    .pkt_to_m1_count(pkt_to_m1_count),
    .pkt_drop_count(pkt_drop_count)
  );

  initial begin
    if (DATA_W < 8) $fatal(1, "DATA_W must be at least 8");
    if ((DATA_W % 8) != 0) $fatal(1, "DATA_W must be a multiple of 8");
    if (MAX_PKT_BEATS <= 0) $fatal(1, "MAX_PKT_BEATS must be > 0");
    if (OUT_FIFO_DEPTH <= 0) $fatal(1, "OUT_FIFO_DEPTH must be > 0");
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      m0_pkt_seen  <= 0;
      m0_beat_seen <= 0;
    end else if (m0_axis_tvalid && m0_axis_tready) begin
      m0_beat_seen <= m0_beat_seen + 1;
      if (m0_axis_tlast) m0_pkt_seen <= m0_pkt_seen + 1;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      m1_pkt_seen  <= 0;
      m1_beat_seen <= 0;
    end else if (m1_axis_tvalid && m1_axis_tready) begin
      m1_beat_seen <= m1_beat_seen + 1;
      if (m1_axis_tlast) m1_pkt_seen <= m1_pkt_seen + 1;
    end
  end

  task automatic wait_cycles(input integer n);
    integer i;
    begin
      for (i = 0; i < n; i = i + 1) @(posedge clk);
    end
  endtask

  task automatic reset_dut;
    begin
      rst            = 1'b1;
      s_axis_tdata   = '0;
      s_axis_tvalid  = 1'b0;
      s_axis_tlast   = 1'b0;
      m0_axis_tready = 1'b1;
      m1_axis_tready = 1'b1;
      wait_cycles(3);
      rst = 1'b0;
      wait_cycles(2);

      if (pkt_to_m0_count !== 0) $fatal(1, "m0 counter not reset");
      if (pkt_to_m1_count !== 0) $fatal(1, "m1 counter not reset");
      if (pkt_drop_count  !== 0) $fatal(1, "drop counter not reset");
    end
  endtask

  task automatic wait_input_ready;
    integer timeout;
    begin
      timeout = 200;
      while (!s_axis_tready && timeout > 0) begin
        @(posedge clk);
        timeout = timeout - 1;
      end
      if (timeout == 0) $fatal(1, "timeout waiting for s_axis_tready");
    end
  endtask

  task automatic send_packet(input integer beats, input logic route_odd, input int tag);
    integer i;
    logic [DATA_W-1:0] word;
    begin
      if (beats <= 0) $fatal(1, "send_packet called with beats=%0d", beats);

      for (i = 0; i < beats; i = i + 1) begin
        @(negedge clk);
        word = '0;
        if (i == 0) begin
          word[7:0] = route_odd ? 8'h03 : 8'h02;
        end else begin
          word[7:0] = tag[7:0] + i[7:0];
        end

        s_axis_tdata  = word;
        s_axis_tlast  = (i == beats - 1);
        s_axis_tvalid = 1'b1;

        wait_input_ready();
        @(posedge clk);
      end

      @(negedge clk);
      s_axis_tvalid = 1'b0;
      s_axis_tlast  = 1'b0;
      s_axis_tdata  = '0;
    end
  endtask

  task automatic wait_for_packets(input integer exp_m0, input integer exp_m1);
    integer timeout;
    begin
      timeout = 1000;
      while ((m0_pkt_seen < exp_m0 || m1_pkt_seen < exp_m1) && timeout > 0) begin
        @(posedge clk);
        timeout = timeout - 1;
      end
      if (timeout == 0) begin
        $fatal(1, "timeout waiting packets exp_m0=%0d act_m0=%0d exp_m1=%0d act_m1=%0d",
               exp_m0, m0_pkt_seen, exp_m1, m1_pkt_seen);
      end
    end
  endtask

  initial begin
    integer expected_m0_count;
    integer expected_m1_count;
    integer expected_drop_count;
    integer expected_m0_pkts;
    integer expected_m1_pkts;
    integer before_m1_pkts;
    integer i;

    expected_m0_count = 0;
    expected_m1_count = 0;
    expected_drop_count = 0;
    expected_m0_pkts = 0;
    expected_m1_pkts = 0;

    reset_dut();

    send_packet(NORMAL_PKT_BEATS, 1'b0, 8'h20);
    expected_m0_count = expected_m0_count + 1;
    expected_m0_pkts = expected_m0_pkts + 1;

    send_packet(NORMAL_PKT_BEATS, 1'b1, 8'h21);
    expected_m1_count = expected_m1_count + 1;
    expected_m1_pkts = expected_m1_pkts + 1;

    wait_for_packets(expected_m0_pkts, expected_m1_pkts);

    before_m1_pkts = m1_pkt_seen;
    m1_axis_tready = 1'b0;
    send_packet(1, 1'b1, 8'h31);
    expected_m1_count = expected_m1_count + 1;
    expected_m1_pkts = expected_m1_pkts + 1;
    wait_cycles(6);
    if (m1_pkt_seen != before_m1_pkts) $fatal(1, "m1 packet drained during backpressure");
    m1_axis_tready = 1'b1;
    wait_for_packets(expected_m0_pkts, expected_m1_pkts);

    m0_axis_tready = 1'b0;
    for (i = 0; i < OUT_FIFO_DEPTH; i = i + 1) begin
      send_packet(1, 1'b0, 8'h40 + i);
      expected_m0_count = expected_m0_count + 1;
      expected_m0_pkts = expected_m0_pkts + 1;
      wait_cycles(2);
    end

    send_packet(1, 1'b0, 8'h70);
    expected_drop_count = expected_drop_count + 1;
    wait_cycles(4);

    m0_axis_tready = 1'b1;
    wait_for_packets(expected_m0_pkts, expected_m1_pkts);

    send_packet(OVERSIZE_BEATS, 1'b1, 8'h55);
    expected_drop_count = expected_drop_count + 1;
    wait_cycles(8);

    if (pkt_to_m0_count !== expected_m0_count)
      $fatal(1, "m0 count mismatch exp=%0d act=%0d", expected_m0_count, pkt_to_m0_count);
    if (pkt_to_m1_count !== expected_m1_count)
      $fatal(1, "m1 count mismatch exp=%0d act=%0d", expected_m1_count, pkt_to_m1_count);
    if (pkt_drop_count !== expected_drop_count)
      $fatal(1, "drop count mismatch exp=%0d act=%0d", expected_drop_count, pkt_drop_count);

    $display("PARAM TB PASS DATA_W=%0d MAX_PKT_BEATS=%0d OUT_FIFO_DEPTH=%0d",
             DATA_W, MAX_PKT_BEATS, OUT_FIFO_DEPTH);
    $finish;
  end

endmodule

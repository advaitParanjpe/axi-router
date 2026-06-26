`timescale 1ns/1ps

module tb_axis_pkt_router_param #(
  parameter int DATA_W = 32,
  parameter int DEST_W = 2,
  parameter int INGRESS_MAX_PKT_BEATS = 4,
  parameter int COUNTER_W = 3,
  parameter int PACKETS_TO_SEND = 3
);

  localparam int IN_PORTS = 2;
  localparam int OUT_PORTS = 4;

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

  integer out_pkts [0:OUT_PORTS-1];

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

  task automatic wait_cycles(input integer n);
    integer i;
    begin
      for (i = 0; i < n; i = i + 1) @(posedge clk);
    end
  endtask

  task automatic reset_dut;
    integer o;
    begin
      @(negedge clk);
      rst = 1'b1;
      s_axis_tdata = '0;
      s_axis_tvalid = '0;
      s_axis_tlast = '0;
      s_axis_tdest = '0;
      m_axis_tready = '1;
      for (o = 0; o < OUT_PORTS; o = o + 1) out_pkts[o] = 0;
      wait_cycles(3);
      @(negedge clk);
      rst = 1'b0;
      wait_cycles(2);
    end
  endtask

  task automatic send_packet(input integer src, input integer dst, input integer beats, input integer base);
    integer i;
    logic [DATA_W-1:0] word;
    begin
      for (i = 0; i < beats; i = i + 1) begin
        @(negedge clk);
        word = '0;
        word[7:0] = (base + i) & 8'hff;
        s_axis_tdata[src] = word;
        s_axis_tdest[src] = DEST_W'(dst);
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

  always @(posedge clk) begin
    integer o;
    if (rst) begin
      for (o = 0; o < OUT_PORTS; o = o + 1) out_pkts[o] <= 0;
    end else begin
      for (o = 0; o < OUT_PORTS; o = o + 1) begin
        if (m_axis_tvalid[o] && m_axis_tready[o] && m_axis_tlast[o]) begin
          if (m_axis_tdest[o] !== DEST_W'(o)) $fatal(1, "tdest mismatch on output %0d", o);
          out_pkts[o] <= out_pkts[o] + 1;
        end
      end
    end
  end

  initial begin
    integer i;
    integer timeout;
    integer dst;
    logic [COUNTER_W-1:0] expected_wrap;

    rst = 1'b1;
    s_axis_tdata = '0;
    s_axis_tvalid = '0;
    s_axis_tlast = '0;
    s_axis_tdest = '0;
    m_axis_tready = '1;
    reset_dut();

    for (i = 0; i < PACKETS_TO_SEND; i = i + 1) begin
      dst = i % OUT_PORTS;
      send_packet(i % IN_PORTS, dst, INGRESS_MAX_PKT_BEATS, 8'h10 + i);
    end

    timeout = 1000;
    while ((out_pkts[0] + out_pkts[1] + out_pkts[2] + out_pkts[3] < PACKETS_TO_SEND) && timeout > 0) begin
      @(posedge clk);
      timeout = timeout - 1;
    end
    if (timeout == 0) $fatal(1, "timeout waiting for parameter packets");
    wait_cycles(2);

    expected_wrap = COUNTER_W'(PACKETS_TO_SEND);
    if ((forwarded_pkt_count[0] + forwarded_pkt_count[1] + forwarded_pkt_count[2] + forwarded_pkt_count[3]) !== expected_wrap) begin
      $fatal(1, "forwarded counter wrap sum mismatch exp=%0d", expected_wrap);
    end
    if ((accepted_pkt_count[0] + accepted_pkt_count[1]) !== expected_wrap) begin
      $fatal(1, "accepted counter wrap sum mismatch exp=%0d", expected_wrap);
    end

    $display("PARAM TB PASS DATA_W=%0d DEST_W=%0d INGRESS_MAX_PKT_BEATS=%0d COUNTER_W=%0d PACKETS=%0d",
             DATA_W, DEST_W, INGRESS_MAX_PKT_BEATS, COUNTER_W, PACKETS_TO_SEND);
    $finish;
  end

endmodule

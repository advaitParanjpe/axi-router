`timescale 1ns/1ps

module tb_axis_router_uvm;
  import uvm_pkg::*;
  import axis_router_uvm_pkg::*;

  localparam int DATA_W = 8;
  localparam int DEST_W = 3;
  localparam int IN_PORTS = 2;
  localparam int OUT_PORTS = 4;
  localparam int INGRESS_MAX_PKT_BEATS = 4;
  localparam int COUNTER_W = 4;

  logic clk = 1'b0;
  logic rst;
  always #5 clk = ~clk;

  axis_stream_if #(.DATA_W(DATA_W), .DEST_W(DEST_W)) s_if[IN_PORTS] (.clk(clk), .rst(rst));
  axis_stream_if #(.DATA_W(DATA_W), .DEST_W(DEST_W)) m_if[OUT_PORTS] (.clk(clk), .rst(rst));
  axis_router_counter_if #(.IN_PORTS(IN_PORTS), .OUT_PORTS(OUT_PORTS), .COUNTER_W(COUNTER_W)) counter_if (.clk(clk), .rst(rst));

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

  genvar i;
  generate
    for (i = 0; i < IN_PORTS; i++) begin : gen_ingress_connect
      assign s_axis_tdata[i] = s_if[i].tdata;
      assign s_axis_tvalid[i] = s_if[i].tvalid;
      assign s_axis_tlast[i] = s_if[i].tlast;
      assign s_axis_tdest[i] = s_if[i].tdest;
      assign s_if[i].tready = s_axis_tready[i];
    end
    for (i = 0; i < OUT_PORTS; i++) begin : gen_egress_connect
      assign m_if[i].tdata = m_axis_tdata[i];
      assign m_if[i].tvalid = m_axis_tvalid[i];
      assign m_axis_tready[i] = m_if[i].tready;
      assign m_if[i].tlast = m_axis_tlast[i];
      assign m_if[i].tdest = m_axis_tdest[i];
    end
  endgenerate

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
    .accepted_pkt_count(counter_if.accepted_pkt_count),
    .forwarded_pkt_count(counter_if.forwarded_pkt_count),
    .drop_invalid_dest_count(counter_if.drop_invalid_dest_count),
    .drop_oversize_count(counter_if.drop_oversize_count),
    .drop_malformed_count(counter_if.drop_malformed_count)
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

  initial begin
    rst = 1'b1;
    repeat (4) @(posedge clk);
    rst = 1'b0;
  end

  initial begin
    uvm_config_db #(virtual axis_stream_if)::set(null, "", "ingress_vif0", s_if[0]);
    uvm_config_db #(virtual axis_stream_if)::set(null, "", "ingress_vif1", s_if[1]);
    uvm_config_db #(virtual axis_stream_if)::set(null, "", "egress_vif0", m_if[0]);
    uvm_config_db #(virtual axis_stream_if)::set(null, "", "egress_vif1", m_if[1]);
    uvm_config_db #(virtual axis_stream_if)::set(null, "", "egress_vif2", m_if[2]);
    uvm_config_db #(virtual axis_stream_if)::set(null, "", "egress_vif3", m_if[3]);
    uvm_config_db #(virtual axis_router_counter_if)::set(null, "", "counter_vif", counter_if);
    run_test();
  end

  initial begin
    string wave_file;
    if ($test$plusargs("WAVES")) begin
      if (!$value$plusargs("WAVE_FILE=%s", wave_file)) wave_file = "build/tb_axis_router_uvm.vcd";
      $dumpfile(wave_file);
      $dumpvars(0, tb_axis_router_uvm);
    end
  end
endmodule

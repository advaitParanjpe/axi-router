`timescale 1ns/1ps

module axis_stream_protocol_checker #(
  parameter int DATA_W = 8,
  parameter int DEST_W = 3,
  parameter int OUT_PORTS = 4
) (
  input logic clk,
  input logic rst,
  input logic [OUT_PORTS-1:0][DATA_W-1:0] m_axis_tdata,
  input logic [OUT_PORTS-1:0]             m_axis_tvalid,
  input logic [OUT_PORTS-1:0]             m_axis_tready,
  input logic [OUT_PORTS-1:0]             m_axis_tlast,
  input logic [OUT_PORTS-1:0][DEST_W-1:0] m_axis_tdest
);
  logic [OUT_PORTS-1:0][DATA_W-1:0] held_tdata_q;
  logic [OUT_PORTS-1:0][DEST_W-1:0] held_tdest_q;
  logic [OUT_PORTS-1:0] held_tlast_q;
  logic [OUT_PORTS-1:0] held_valid_q;
  logic [OUT_PORTS-1:0] in_packet_q;
  logic [OUT_PORTS-1:0][DEST_W-1:0] packet_dest_q;

  always @(posedge clk) begin
    integer o;

    #1;
    if (rst) begin
      held_tdata_q <= '0;
      held_tdest_q <= '0;
      held_tlast_q <= '0;
      held_valid_q <= '0;
      in_packet_q <= '0;
      packet_dest_q <= '0;
      if (m_axis_tvalid !== '0) $fatal(1, "checker: output valid asserted during reset");
    end else begin
      for (o = 0; o < OUT_PORTS; o = o + 1) begin
        if (^m_axis_tvalid[o] === 1'bx) $fatal(1, "checker: unknown tvalid on output %0d", o);
        if (^m_axis_tready[o] === 1'bx) $fatal(1, "checker: unknown tready on output %0d", o);
        if (m_axis_tvalid[o] && (m_axis_tdest[o] > DEST_W'(3))) begin
          $fatal(1, "checker: invalid output destination %0d on output %0d", m_axis_tdest[o], o);
        end

        if (held_valid_q[o] && m_axis_tvalid[o] && !m_axis_tready[o]) begin
          if (m_axis_tdata[o] !== held_tdata_q[o]) $fatal(1, "checker: tdata changed while stalled on output %0d", o);
          if (m_axis_tdest[o] !== held_tdest_q[o]) $fatal(1, "checker: tdest changed while stalled on output %0d", o);
          if (m_axis_tlast[o] !== held_tlast_q[o]) $fatal(1, "checker: tlast changed while stalled on output %0d", o);
        end

        if (m_axis_tvalid[o] && m_axis_tready[o]) begin
          if (!in_packet_q[o]) begin
            in_packet_q[o] <= !m_axis_tlast[o];
            packet_dest_q[o] <= m_axis_tdest[o];
          end else begin
            if (m_axis_tdest[o] !== packet_dest_q[o]) begin
              $fatal(1, "checker: output %0d packet destination changed mid-packet", o);
            end
            if (m_axis_tlast[o]) in_packet_q[o] <= 1'b0;
          end
        end

        held_valid_q[o] <= m_axis_tvalid[o] && !m_axis_tready[o];
        held_tdata_q[o] <= m_axis_tdata[o];
        held_tdest_q[o] <= m_axis_tdest[o];
        held_tlast_q[o] <= m_axis_tlast[o];
      end
    end
  end
endmodule

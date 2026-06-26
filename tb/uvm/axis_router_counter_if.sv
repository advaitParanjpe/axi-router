interface axis_router_counter_if #(
  parameter int IN_PORTS = 2,
  parameter int OUT_PORTS = 4,
  parameter int COUNTER_W = 4
) (
  input logic clk,
  input logic rst
);
  logic [IN_PORTS-1:0][COUNTER_W-1:0] accepted_pkt_count;
  logic [OUT_PORTS-1:0][COUNTER_W-1:0] forwarded_pkt_count;
  logic [IN_PORTS-1:0][COUNTER_W-1:0] drop_invalid_dest_count;
  logic [IN_PORTS-1:0][COUNTER_W-1:0] drop_oversize_count;
  logic [IN_PORTS-1:0][COUNTER_W-1:0] drop_malformed_count;
endinterface

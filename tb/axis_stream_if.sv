`timescale 1ns/1ps

interface axis_stream_if #(
  parameter int DATA_W = 8,
  parameter int DEST_W = 3
) (
  input logic clk,
  input logic rst
);
  logic [DATA_W-1:0] tdata;
  logic              tvalid;
  logic              tready;
  logic              tlast;
  logic [DEST_W-1:0] tdest;

  modport source (
    input  clk, rst, tready,
    output tdata, tvalid, tlast, tdest
  );

  modport sink (
    input  clk, rst, tdata, tvalid, tlast, tdest,
    output tready
  );

  modport monitor (
    input clk, rst, tdata, tvalid, tready, tlast, tdest
  );
endinterface

# Architecture Notes

## Verified Current Baseline

The current RTL is a 1-input, 2-output AXI4-Stream subset packet router. It
supports `tdata`, `tvalid`, `tready`, and `tlast` on the input and both outputs.
Routing is fixed: the least significant bit of the first byte in the first beat
selects the destination. `0` routes to `m0`; `1` routes to `m1`.

The router uses store-and-forward packet capture. After a complete packet is
captured, the selected output FIFO is checked for enough space for the whole
packet. If the packet fits, the router replays it into that output FIFO. If it
does not fit, or if the packet exceeds `MAX_PKT_BEATS`, the packet is dropped.

Reset is synchronous active-high.

## Intended Future Direction

The planned portfolio target is a 2-input, 4-output AXI4-Stream packet router
with destination-based routing, packet-level arbitration, output backpressure,
SystemVerilog assertions, and UVM verification.

This future 2x4 architecture is not yet a frozen specification.

## Unfrozen Decisions

- Destination field encoding and whether it uses `tdest`, payload header bits,
  or a local sideband.
- Arbitration policy between ingress ports.
- Packet buffering depth and whether buffering remains store-and-forward.
- Drop, stall, or error behavior when egress resources are unavailable.
- Supported AXI4-Stream sideband signals beyond the current subset.
- Reset, flush, and error-reporting policy for the generalized design.

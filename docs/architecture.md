# Architecture Specification

## Current Verified Baseline

The executable RTL currently in `rtl/axis_pkt_router.sv` is the generalized
2-input, 4-output AXI4-Stream subset packet router implemented in Milestone 4.
It supports `tdata`, `tvalid`, `tready`, `tlast`, and `tdest`. Routing uses the
first accepted beat's `tdest`: values 0 through 3 map directly to outputs 0
through 3.

The implemented baseline uses one store-and-forward packet buffer per ingress,
independent round-robin arbitration per output, and packet-level output
locking. Reset is synchronous active-high. Unsupported features include
`tkeep`, `tstrb`, `tid`, `tuser`, partial final beats, arbitrary port counts,
virtual output queues, cut-through forwarding, AXI4 memory-mapped, AXI4-Lite,
and configurable routing.

## Generalized Router Architecture

Milestone 3 froze the architecture below. Milestone 4 implemented it as the
active RTL and focused conventional regression target.

### Supported AXI4-Stream Subset

The generalized router will implement a controlled AXI4-Stream subset:

- `tdata`: packet payload data.
- `tvalid`: source-presented beat validity.
- `tready`: sink-presented beat acceptance.
- `tlast`: end-of-packet marker.
- `tdest`: packet destination identifier.

The design will not claim full AXI4-Stream compliance. The first generalized
implementation intentionally omits `tkeep`, `tstrb`, `tid`, and `tuser`.
Without `tkeep`, all bytes of every transferred beat are meaningful and partial
final beats are unsupported.

### Top-Level Interface

The target top level will expose arrays rather than separately named per-port
signals:

- `input logic clk`
- `input logic rst`
- `input logic [IN_PORTS-1:0][DATA_W-1:0] s_axis_tdata`
- `input logic [IN_PORTS-1:0] s_axis_tvalid`
- `output logic [IN_PORTS-1:0] s_axis_tready`
- `input logic [IN_PORTS-1:0] s_axis_tlast`
- `input logic [IN_PORTS-1:0][DEST_W-1:0] s_axis_tdest`
- `output logic [OUT_PORTS-1:0][DATA_W-1:0] m_axis_tdata`
- `output logic [OUT_PORTS-1:0] m_axis_tvalid`
- `input logic [OUT_PORTS-1:0] m_axis_tready`
- `output logic [OUT_PORTS-1:0] m_axis_tlast`
- `output logic [OUT_PORTS-1:0][DEST_W-1:0] m_axis_tdest`

Reset is synchronous active-high. On reset, all internal packet buffers,
valid state, arbitration locks, round-robin priority state, and counters are
cleared. While reset is asserted, no output packet is valid and ingress
`tready` is deasserted.

### Parameters

The first generalized implementation will support a fixed structural shape and
parameterized widths/depths:

- `IN_PORTS = 2`; fixed for this implementation.
- `OUT_PORTS = 4`; fixed for this implementation.
- `DATA_W`; legal range is a positive multiple of 8, minimum 8.
- `DEST_W`; legal range is at least 2 bits. Default is 2.
- `INGRESS_MAX_PKT_BEATS`; legal range is at least 1.
- `COUNTER_W`; legal range is at least 1. Default is 32.

Arbitrary ingress or egress counts are intentionally unsupported in the first
generalized RTL. The module may keep `IN_PORTS` and `OUT_PORTS` as localparams
or guarded parameters, but elaboration-time checks must reject values other
than 2 and 4. Internal index and count widths must be explicitly sized so
minimum legal depths do not create zero-width vectors.

## Packet and Destination Semantics

Each packet contains one or more beats. A zero-length packet is not meaningful
because AXI4-Stream represents packet completion with a transferred beat where
`tlast` is high.

`tdest` is sampled on the first accepted beat of each ingress packet. The
sampled first-beat value is the packet route and is forwarded on `m_axis_tdest`
for every beat of the packet. `tdest` is required to remain constant for every
later beat of the same packet. The router will check later accepted beats
against the sampled value. A mismatch makes the packet malformed; the router
consumes the rest of that ingress packet, suppresses forwarding, and increments
the malformed/drop counter.

Legal destinations are:

- `tdest == 0`: output 0.
- `tdest == 1`: output 1.
- `tdest == 2`: output 2.
- `tdest == 3`: output 3.

Any `tdest` value greater than 3 is invalid. Invalid-destination packets are
consumed on the ingress side, not forwarded to any output, and counted as
dropped invalid-destination packets.

A packet that exceeds `INGRESS_MAX_PKT_BEATS` is oversize. The ingress buffer
marks it for drop, continues accepting that packet until its `tlast` beat
without storing beats beyond the configured capacity, suppresses forwarding,
and increments the oversize/drop counter. It must not emit a partial packet.

Reset during packet reception discards all partial packet state on every ingress.
Reset during output transmission invalidates any in-flight output state and
releases arbitration locks. Downstream logic must treat reset as aborting the
packet because the router does not guarantee completion across reset.

## Buffering Architecture

The generalized design uses one packet-capable ingress buffer per ingress port.
There is no permanent legacy 1x2 datapath, no virtual output queue structure,
and no cut-through mode in the first generalized version.

A packet must be fully received and validated before it becomes eligible for
arbitration. The ingress buffer stores beat data, beat `tlast`, and packet
metadata. Metadata includes sampled destination, packet length, and drop reason.
Packet boundaries are represented by stored `tlast` bits plus stored packet
length metadata.

Ingress admission is beat-by-beat. While an ingress is idle or capturing a
packet with free buffer space, it may assert `tready`. After a packet is marked
oversize, the ingress continues asserting `tready` to drain the remainder of
that packet because later beats are classified but not stored. The
implementation may deassert `tready` only when it cannot safely store or
classify the next beat.

Because there is one packet buffer per ingress and no virtual output queues,
head-of-line blocking is accepted. If an ingress buffer holds a complete packet
for a stalled or contended output, that ingress cannot accept a later packet for
a different output until the head packet forwards or is dropped.

## Routing and Arbitration

Each ingress buffer advertises at most one request: the sampled destination of
its complete, valid, non-dropped head packet. Each output has an independent
round-robin arbiter that considers only ingress requests targeting that output.

Round-robin priority resets to ingress 0 for every output. When multiple ingress
buffers request the same output in the same cycle, the requester at or after the
current priority pointer wins, wrapping to ingress 0 as needed. Priority
advances only after the granted packet completes transfer to that output.

Each output locks ownership to the granted ingress for the full packet. The
arbiter must not change owners until the locked packet's `tlast` beat is
accepted by the output (`m_axis_tvalid && m_axis_tready && m_axis_tlast`).
While an output has a locked packet with an available beat, it asserts
`m_axis_tvalid` and drives that beat's `tdata`, `tlast`, and sampled `tdest`.
Output stalls hold the lock and require `tdata`, `tdest`, and `tlast` to remain
stable while `tvalid` is asserted and `tready` is low.

Required invariants for the RTL and later assertions:

- At most one ingress drives a given output in any cycle.
- One ingress packet can request and drive only one output.
- Packet beats cannot interleave on an output.
- Arbitration ownership cannot change midway through a packet.
- Round-robin priority advances only after a completed packet transfer.

## Backpressure and Concurrency

Each ingress asserts `tready` when it can accept the next beat for its current
state. Both ingress ports may accept beats concurrently when their buffers can
accept data. Different outputs may transmit concurrently, each with independent
valid/ready handshakes and independent arbitration state.

When both ingress packets request the same output, one packet is granted and the
other remains buffered until the output arbiter can grant it. When the two
ingress packets request different outputs, both may be transmitted concurrently
subject to each output's `tready`.

An output stall affects only the packet and output that are locked to the
stalled transfer. It can indirectly block one ingress through head-of-line
blocking, but it must not stall unrelated output arbiters or unrelated ingress
buffers that have storage available.

## Counters and Status

The first generalized RTL will keep status simple and directly observable.
Required counters are `COUNTER_W` bits wide, synchronously reset to zero, and
wrap on overflow:

- Accepted packet count per ingress: increments when a complete packet is
  accepted without malformed, invalid-destination, or oversize classification.
- Forwarded packet count per output: increments when that output accepts the
  `tlast` beat of a forwarded packet.
- Dropped invalid-destination packet count per ingress: increments when the
  invalid packet reaches its terminating `tlast`.
- Dropped oversize packet count per ingress: increments when the oversize packet
  reaches its terminating `tlast`.
- Dropped malformed packet count per ingress: increments when a `tdest` change
  within a packet is detected and the malformed packet reaches `tlast`.

Optional contention or stall counters are deferred unless they are needed for
debug during implementation. No AXI4-Lite or other control/status bus is part
of this phase.

## Expected RTL Decomposition

The implementation should avoid unnecessary fragmentation while keeping
ownership boundaries clear:

- `axis_pkt_router_2x4`: top-level interface, per-ingress/per-output wiring,
  route request construction, counter aggregation, and reset policy.
- `axis_ingress_pkt_buffer`: one instance per ingress. Captures a packet,
  samples and checks `tdest`, stores beats and metadata, reports complete-packet
  requests, and replays the locked packet when granted.
- `axis_rr_arbiter`: one instance per output. Selects among ingress requests,
  holds packet-level ownership, and advances round-robin priority after packet
  completion.
- Optional package: shared parameter checks, local type definitions, and helper
  functions for safe width calculations.
- Counter/status logic: may live in the top level or a small helper if doing so
  avoids duplicated increment and reset code.

The first implementation should use conventional synthesizable SystemVerilog
and keep simulation-only checks separate from synthesizable RTL.

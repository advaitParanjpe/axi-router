`timescale 1ns/1ps

module axis_pkt_router #(
    parameter int DATA_W         = 32,
    parameter int MAX_PKT_BEATS  = 64,  // ingress packet capture buffer depth (beats)
    parameter int OUT_FIFO_DEPTH = 64   // per-output FIFO depth (beats)
) (
    input  logic              clk,
    input  logic              rst,   // synchronous active-high reset

    // AXI-Stream input (one packet at a time for v1)
    input  logic [DATA_W-1:0] s_axis_tdata,
    input  logic              s_axis_tvalid,
    output logic              s_axis_tready,
    input  logic              s_axis_tlast,

    // AXI-Stream output 0 (even first-byte parity)
    output logic [DATA_W-1:0] m0_axis_tdata,
    output logic              m0_axis_tvalid,
    input  logic              m0_axis_tready,
    output logic              m0_axis_tlast,

    // AXI-Stream output 1 (odd first-byte parity)
    output logic [DATA_W-1:0] m1_axis_tdata,
    output logic              m1_axis_tvalid,
    input  logic              m1_axis_tready,
    output logic              m1_axis_tlast,

    // Status counters (simple direct outputs for now)
    output logic [31:0]       pkt_to_m0_count,
    output logic [31:0]       pkt_to_m1_count,
    output logic [31:0]       pkt_drop_count
);

    localparam int PKT_CNT_W  = (MAX_PKT_BEATS  <= 1) ? 1 : $clog2(MAX_PKT_BEATS + 1);
    localparam int PKT_IDX_W  = (MAX_PKT_BEATS  <= 1) ? 1 : $clog2(MAX_PKT_BEATS);
    localparam int FIFO_CNT_W = (OUT_FIFO_DEPTH <= 1) ? 1 : $clog2(OUT_FIFO_DEPTH + 1);
    localparam int SPACE_W    = ((PKT_CNT_W > FIFO_CNT_W) ? PKT_CNT_W : FIFO_CNT_W) + 1;
    localparam logic [PKT_CNT_W-1:0] MAX_PKT_COUNT = PKT_CNT_W'(MAX_PKT_BEATS);

`ifndef SYNTHESIS
    initial begin
        if (DATA_W < 8) $fatal(1, "axis_pkt_router: DATA_W must be at least 8");
        if ((DATA_W % 8) != 0) $fatal(1, "axis_pkt_router: DATA_W must be a multiple of 8");
        if (MAX_PKT_BEATS <= 0) $fatal(1, "axis_pkt_router: MAX_PKT_BEATS must be > 0");
        if (OUT_FIFO_DEPTH <= 0) $fatal(1, "axis_pkt_router: OUT_FIFO_DEPTH must be > 0");
    end
`endif

    // ----------------------------
    // Ingress packet capture buffer
    // ----------------------------
    (* ram_style = "block" *) logic [DATA_W-1:0] cap_data [0:MAX_PKT_BEATS-1];
    (* ram_style = "block" *) logic              cap_last [0:MAX_PKT_BEATS-1];

    logic [PKT_CNT_W-1:0] pkt_len_beats_q; // valid only if !oversize_drop_q
    logic              oversize_drop_q;
    logic              first_byte_lsb_q;

    // target_sel_q: 0 => m0, 1 => m1
    logic              target_sel_q;

    // replay index for store-and-forward
    logic [PKT_IDX_W-1:0] replay_idx_q;

    // ----------------------------
    // FSM
    // ----------------------------
    typedef enum logic [2:0] {
        ST_IDLE        = 3'd0,
        ST_CAPTURE     = 3'd1,
        ST_DECIDE      = 3'd2,
        ST_REPLAY      = 3'd3,
        ST_SENT_COMMIT = 3'd4,
        ST_DROP_COMMIT = 3'd5
    } state_t;

    state_t state_q;

    // ----------------------------
    // Output FIFOs (one per output)
    // ----------------------------
    logic [DATA_W-1:0] m0_fifo_s_tdata, m1_fifo_s_tdata;
    logic              m0_fifo_s_tvalid, m1_fifo_s_tvalid;
    logic              m0_fifo_s_tready, m1_fifo_s_tready;
    logic              m0_fifo_s_tlast,  m1_fifo_s_tlast;
    logic [FIFO_CNT_W-1:0] m0_fifo_count, m1_fifo_count;

    axis_fifo_sync #(
        .DATA_W(DATA_W),
        .DEPTH (OUT_FIFO_DEPTH)
    ) u_fifo_m0 (
        .clk          (clk),
        .rst          (rst),
        .s_axis_tdata (m0_fifo_s_tdata),
        .s_axis_tvalid(m0_fifo_s_tvalid),
        .s_axis_tready(m0_fifo_s_tready),
        .s_axis_tlast (m0_fifo_s_tlast),
        .m_axis_tdata (m0_axis_tdata),
        .m_axis_tvalid(m0_axis_tvalid),
        .m_axis_tready(m0_axis_tready),
        .m_axis_tlast (m0_axis_tlast),
        .count_o      (m0_fifo_count)
    );

    axis_fifo_sync #(
        .DATA_W(DATA_W),
        .DEPTH (OUT_FIFO_DEPTH)
    ) u_fifo_m1 (
        .clk          (clk),
        .rst          (rst),
        .s_axis_tdata (m1_fifo_s_tdata),
        .s_axis_tvalid(m1_fifo_s_tvalid),
        .s_axis_tready(m1_fifo_s_tready),
        .s_axis_tlast (m1_fifo_s_tlast),
        .m_axis_tdata (m1_axis_tdata),
        .m_axis_tvalid(m1_axis_tvalid),
        .m_axis_tready(m1_axis_tready),
        .m_axis_tlast (m1_axis_tlast),
        .count_o      (m1_fifo_count)
    );

    // ----------------------------
    // Replay mux into selected FIFO
    // ----------------------------
    logic [DATA_W-1:0] replay_data_cur;
    logic              replay_last_cur;
    logic              replay_selected_fifo_ready;
    logic              replay_fire;

    assign replay_data_cur = cap_data[replay_idx_q];
    assign replay_last_cur = cap_last[replay_idx_q];

    assign m0_fifo_s_tvalid = (state_q == ST_REPLAY) && (target_sel_q == 1'b0);
    assign m1_fifo_s_tvalid = (state_q == ST_REPLAY) && (target_sel_q == 1'b1);

    assign m0_fifo_s_tdata  = replay_data_cur;
    assign m1_fifo_s_tdata  = replay_data_cur;

    assign m0_fifo_s_tlast  = replay_last_cur;
    assign m1_fifo_s_tlast  = replay_last_cur;

    assign replay_selected_fifo_ready = (target_sel_q == 1'b0) ? m0_fifo_s_tready : m1_fifo_s_tready;
    assign replay_fire = (state_q == ST_REPLAY) && replay_selected_fifo_ready;

    // ----------------------------
    // Input AXI backpressure (v1)
    // only accept while capturing one packet
    // ----------------------------
    assign s_axis_tready = (state_q == ST_IDLE) || (state_q == ST_CAPTURE);

    // ----------------------------
    // Helper wires for route decision
    // First byte LSB route:
    //   0 => m0 (even)
    //   1 => m1 (odd)
    // ----------------------------
    logic route_to_m1_w;  // 1 if odd
    logic can_send_m0_w, can_send_m1_w;

    assign route_to_m1_w = first_byte_lsb_q;

    localparam logic [SPACE_W-1:0] OUT_DEPTH_COUNT = SPACE_W'(OUT_FIFO_DEPTH);

    logic [SPACE_W-1:0] m0_used_w, m1_used_w, pkt_need_w;

    assign m0_used_w  = {{(SPACE_W-FIFO_CNT_W){1'b0}}, m0_fifo_count};
    assign m1_used_w  = {{(SPACE_W-FIFO_CNT_W){1'b0}}, m1_fifo_count};
    assign pkt_need_w = {{(SPACE_W-PKT_CNT_W ){1'b0}}, pkt_len_beats_q};

    assign can_send_m0_w = (!oversize_drop_q) && (pkt_need_w <= OUT_DEPTH_COUNT) && ((m0_used_w + pkt_need_w) <= OUT_DEPTH_COUNT);
    assign can_send_m1_w = (!oversize_drop_q) && (pkt_need_w <= OUT_DEPTH_COUNT) && ((m1_used_w + pkt_need_w) <= OUT_DEPTH_COUNT);

    // ----------------------------
    // Main sequential logic
    // ----------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            state_q          <= ST_IDLE;

            pkt_len_beats_q  <= '0;
            oversize_drop_q  <= 1'b0;
            first_byte_lsb_q <= 1'b0;

            target_sel_q     <= 1'b0;
            replay_idx_q     <= '0;

            pkt_to_m0_count  <= '0;
            pkt_to_m1_count  <= '0;
            pkt_drop_count   <= '0;
        end else begin
            unique case (state_q)

                // --------------------
                // Wait for first beat
                // --------------------
                ST_IDLE: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        // reset packet metadata
                        pkt_len_beats_q  <= '0;
                        oversize_drop_q  <= 1'b0;
                        first_byte_lsb_q <= s_axis_tdata[0];
                        replay_idx_q     <= '0;

                        // store first beat at index 0
                        cap_data[0] <= s_axis_tdata;
                        cap_last[0] <= s_axis_tlast;

                        // pkt length becomes 1 beat
                        pkt_len_beats_q <= 1;

                        // if single-beat packet, decide next cycle
                        if (s_axis_tlast) state_q <= ST_DECIDE;
                        else              state_q <= ST_CAPTURE;
                    end
                end

                // --------------------
                // Capture remaining beats
                // --------------------
                ST_CAPTURE: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        // Store beat only if still within capture capacity
                        if (!oversize_drop_q) begin
                            if (pkt_len_beats_q < MAX_PKT_COUNT) begin
                                cap_data[PKT_IDX_W'(pkt_len_beats_q)] <= s_axis_tdata;
                                cap_last[PKT_IDX_W'(pkt_len_beats_q)] <= s_axis_tlast;
                                pkt_len_beats_q <= pkt_len_beats_q + 1'b1;
                            end else begin
                                // oversize packet: consume remainder then drop
                                oversize_drop_q <= 1'b1;
                                // pkt_len_beats_q can stay saturated (not used if oversize_drop_q==1)
                            end
                        end

                        // End of packet -> route/drop decision next
                        if (s_axis_tlast) begin
                            state_q <= ST_DECIDE;
                        end
                    end
                end

                // --------------------
                // Decide route or drop
                // --------------------
                ST_DECIDE: begin
                    // Route by parity of first byte (header_q[7:0])
                    target_sel_q <= route_to_m1_w;

                    if (oversize_drop_q) begin
                        state_q <= ST_DROP_COMMIT;
                    end else if (route_to_m1_w == 1'b0) begin
                        // route to m0 (even)
                        if (can_send_m0_w) begin
                            replay_idx_q <= '0;
                            state_q      <= ST_REPLAY;
                        end else begin
                            state_q <= ST_DROP_COMMIT;
                        end
                    end else begin
                        // route to m1 (odd)
                        if (can_send_m1_w) begin
                            replay_idx_q <= '0;
                            state_q      <= ST_REPLAY;
                        end else begin
                            state_q <= ST_DROP_COMMIT;
                        end
                    end
                end

                // --------------------
                // Replay buffered packet into selected output FIFO
                // --------------------
                ST_REPLAY: begin
                    if (replay_fire) begin
                        if (replay_last_cur) begin
                            state_q <= ST_SENT_COMMIT;
                        end else begin
                            replay_idx_q <= replay_idx_q + 1'b1;
                        end
                    end
                end

                // --------------------
                // Increment success counter
                // --------------------
                ST_SENT_COMMIT: begin
                    if (target_sel_q == 1'b0) pkt_to_m0_count <= pkt_to_m0_count + 1'b1;
                    else                      pkt_to_m1_count <= pkt_to_m1_count + 1'b1;

                    state_q <= ST_IDLE;
                end

                // --------------------
                // Increment drop counter
                // --------------------
                ST_DROP_COMMIT: begin
                    pkt_drop_count <= pkt_drop_count + 1'b1;
                    state_q        <= ST_IDLE;
                end

                default: begin
                    state_q <= ST_IDLE;
                end
            endcase
        end
    end

endmodule

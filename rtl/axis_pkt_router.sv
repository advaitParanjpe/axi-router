`timescale 1ns/1ps

module axis_ingress_pkt_buffer #(
    parameter int DATA_W = 32,
    parameter int DEST_W = 2,
    parameter int INGRESS_MAX_PKT_BEATS = 64,
    parameter int COUNTER_W = 32
) (
    input  logic clk,
    input  logic rst,

    input  logic [DATA_W-1:0] s_axis_tdata,
    input  logic              s_axis_tvalid,
    output logic              s_axis_tready,
    input  logic              s_axis_tlast,
    input  logic [DEST_W-1:0] s_axis_tdest,

    output logic              req_valid,
    output logic [1:0]        req_dest,
    output logic [DATA_W-1:0] replay_tdata,
    output logic              replay_tlast,
    output logic [DEST_W-1:0] replay_tdest,
    input  logic              replay_fire,

    output logic [COUNTER_W-1:0] accepted_pkt_count,
    output logic [COUNTER_W-1:0] drop_invalid_dest_count,
    output logic [COUNTER_W-1:0] drop_oversize_count,
    output logic [COUNTER_W-1:0] drop_malformed_count
);

    localparam int COUNT_W = (INGRESS_MAX_PKT_BEATS <= 1) ? 1 : $clog2(INGRESS_MAX_PKT_BEATS + 1);
    localparam int IDX_W   = (INGRESS_MAX_PKT_BEATS <= 1) ? 1 : $clog2(INGRESS_MAX_PKT_BEATS);

    typedef enum logic [1:0] {
        ST_IDLE     = 2'd0,
        ST_CAPTURE  = 2'd1,
        ST_DROP     = 2'd2,
        ST_COMPLETE = 2'd3
    } state_t;

    typedef enum logic [1:0] {
        DROP_NONE      = 2'd0,
        DROP_INVALID   = 2'd1,
        DROP_OVERSIZE  = 2'd2,
        DROP_MALFORMED = 2'd3
    } drop_reason_t;

`ifndef SYNTHESIS
    initial begin
        if (DATA_W < 8) $fatal(1, "axis_ingress_pkt_buffer: DATA_W must be >= 8");
        if ((DATA_W % 8) != 0) $fatal(1, "axis_ingress_pkt_buffer: DATA_W must be a multiple of 8");
        if (DEST_W < 2) $fatal(1, "axis_ingress_pkt_buffer: DEST_W must be >= 2");
        if (INGRESS_MAX_PKT_BEATS < 1) $fatal(1, "axis_ingress_pkt_buffer: INGRESS_MAX_PKT_BEATS must be >= 1");
        if (COUNTER_W < 1) $fatal(1, "axis_ingress_pkt_buffer: COUNTER_W must be >= 1");
    end
`endif

    (* ram_style = "block" *) logic [DATA_W-1:0] mem_data [0:INGRESS_MAX_PKT_BEATS-1];
    (* ram_style = "block" *) logic              mem_last [0:INGRESS_MAX_PKT_BEATS-1];

    state_t state_q;
    drop_reason_t drop_reason_q;
    logic [COUNT_W-1:0] len_q;
    logic [IDX_W-1:0] rd_idx_q;
    logic [DEST_W-1:0] dest_q;

    logic input_fire;
    logic dest_invalid_w;
    logic dest_change_w;
    logic has_room_w;
    logic beat_causes_oversize_w;

    localparam logic [COUNT_W-1:0] MAX_COUNT = COUNT_W'(INGRESS_MAX_PKT_BEATS);

    assign input_fire = s_axis_tvalid && s_axis_tready;
    assign s_axis_tready = (state_q != ST_COMPLETE);

    generate
        if (DEST_W > 2) begin : gen_dest_invalid_check
            assign dest_invalid_w = (s_axis_tdest > DEST_W'(3));
        end else begin : gen_no_dest_invalid_check
            assign dest_invalid_w = 1'b0;
        end
    endgenerate
    assign dest_change_w = (state_q == ST_CAPTURE) && (s_axis_tdest != dest_q);
    assign has_room_w = (len_q < MAX_COUNT);
    assign beat_causes_oversize_w = ((state_q == ST_CAPTURE) && !has_room_w) ||
                                    ((state_q == ST_IDLE) && (INGRESS_MAX_PKT_BEATS < 1));

    assign req_valid = (state_q == ST_COMPLETE);
    assign req_dest = dest_q[1:0];
    assign replay_tdata = mem_data[rd_idx_q];
    assign replay_tlast = mem_last[rd_idx_q];
    assign replay_tdest = dest_q;
    task automatic count_drop(input drop_reason_t reason);
        begin
            case (reason)
                DROP_INVALID:   drop_invalid_dest_count <= drop_invalid_dest_count + COUNTER_W'(1);
                DROP_OVERSIZE:  drop_oversize_count <= drop_oversize_count + COUNTER_W'(1);
                DROP_MALFORMED: drop_malformed_count <= drop_malformed_count + COUNTER_W'(1);
                default:        accepted_pkt_count <= accepted_pkt_count;
            endcase
        end
    endtask

    always @(posedge clk) begin
        drop_reason_t next_drop_reason;

        if (rst) begin
            state_q <= ST_IDLE;
            drop_reason_q <= DROP_NONE;
            len_q <= '0;
            rd_idx_q <= '0;
            dest_q <= '0;
            accepted_pkt_count <= '0;
            drop_invalid_dest_count <= '0;
            drop_oversize_count <= '0;
            drop_malformed_count <= '0;
        end else begin
            case (state_q)
                ST_IDLE: begin
                    if (input_fire) begin
                        len_q <= '0;
                        rd_idx_q <= '0;
                        dest_q <= s_axis_tdest;
                        drop_reason_q <= DROP_NONE;

                        if (dest_invalid_w) begin
                            if (s_axis_tlast) begin
                                drop_invalid_dest_count <= drop_invalid_dest_count + COUNTER_W'(1);
                                state_q <= ST_IDLE;
                            end else begin
                                drop_reason_q <= DROP_INVALID;
                                state_q <= ST_DROP;
                            end
                        end else begin
                            mem_data[0] <= s_axis_tdata;
                            mem_last[0] <= s_axis_tlast;
                            len_q <= COUNT_W'(1);
                            if (s_axis_tlast) begin
                                accepted_pkt_count <= accepted_pkt_count + COUNTER_W'(1);
                                state_q <= ST_COMPLETE;
                            end else begin
                                state_q <= ST_CAPTURE;
                            end
                        end
                    end
                end

                ST_CAPTURE: begin
                    if (input_fire) begin
                        next_drop_reason = DROP_NONE;
                        if (dest_change_w) next_drop_reason = DROP_MALFORMED;
                        else if (beat_causes_oversize_w) next_drop_reason = DROP_OVERSIZE;

                        if (next_drop_reason != DROP_NONE) begin
                            if (s_axis_tlast) begin
                                count_drop(next_drop_reason);
                                state_q <= ST_IDLE;
                            end else begin
                                drop_reason_q <= next_drop_reason;
                                state_q <= ST_DROP;
                            end
                        end else begin
                            mem_data[IDX_W'(len_q)] <= s_axis_tdata;
                            mem_last[IDX_W'(len_q)] <= s_axis_tlast;
                            len_q <= len_q + COUNT_W'(1);
                            if (s_axis_tlast) begin
                                accepted_pkt_count <= accepted_pkt_count + COUNTER_W'(1);
                                state_q <= ST_COMPLETE;
                            end
                        end
                    end
                end

                ST_DROP: begin
                    if (input_fire && s_axis_tlast) begin
                        count_drop(drop_reason_q);
                        state_q <= ST_IDLE;
                        drop_reason_q <= DROP_NONE;
                    end
                end

                ST_COMPLETE: begin
                    if (replay_fire) begin
                        if (replay_tlast) begin
                            state_q <= ST_IDLE;
                            len_q <= '0;
                            rd_idx_q <= '0;
                        end else begin
                            rd_idx_q <= rd_idx_q + IDX_W'(1);
                        end
                    end
                end

                default: begin
                    state_q <= ST_IDLE;
                end
            endcase
        end
    end

endmodule

module axis_rr_arbiter #(
    parameter int IN_PORTS = 2
) (
    input  logic clk,
    input  logic rst,
    input  logic [IN_PORTS-1:0] req,
    input  logic                beat_fire,
    input  logic                beat_last,
    output logic                grant_valid,
    output logic [IN_PORTS-1:0] grant_oh
);

    logic priority_q;
    logic locked_q;
    logic owner_q;
    logic grant_sel_w;

`ifndef SYNTHESIS
    initial begin
        if (IN_PORTS != 2) $fatal(1, "axis_rr_arbiter: only IN_PORTS=2 is supported");
    end
`endif

    always @* begin
        if (locked_q) begin
            grant_sel_w = owner_q;
            grant_valid = req[owner_q];
        end else if (req[priority_q]) begin
            grant_sel_w = priority_q;
            grant_valid = 1'b1;
        end else if (req[~priority_q]) begin
            grant_sel_w = ~priority_q;
            grant_valid = 1'b1;
        end else begin
            grant_sel_w = priority_q;
            grant_valid = 1'b0;
        end

        grant_oh = '0;
        if (grant_valid) grant_oh[grant_sel_w] = 1'b1;
    end

    always @(posedge clk) begin
        if (rst) begin
            priority_q <= 1'b0;
            locked_q <= 1'b0;
            owner_q <= 1'b0;
        end else begin
            if (!locked_q && grant_valid) begin
                locked_q <= 1'b1;
                owner_q <= grant_sel_w;
            end

            if (beat_fire && beat_last) begin
                priority_q <= ~grant_sel_w;
                locked_q <= 1'b0;
                owner_q <= 1'b0;
            end
        end
    end

`ifndef SYNTHESIS
    always @(posedge clk) begin
        if (!rst && locked_q && grant_valid && (grant_sel_w != owner_q)) begin
            $fatal(1, "axis_rr_arbiter: owner changed while locked");
        end
    end
`endif

endmodule

module axis_pkt_router #(
    parameter int DATA_W = 32,
    parameter int DEST_W = 2,
    parameter int INGRESS_MAX_PKT_BEATS = 64,
    parameter int COUNTER_W = 32,
    parameter int IN_PORTS = 2,
    parameter int OUT_PORTS = 4
) (
    input  logic clk,
    input  logic rst,

    input  logic [IN_PORTS-1:0][DATA_W-1:0] s_axis_tdata,
    input  logic [IN_PORTS-1:0]             s_axis_tvalid,
    output logic [IN_PORTS-1:0]             s_axis_tready,
    input  logic [IN_PORTS-1:0]             s_axis_tlast,
    input  logic [IN_PORTS-1:0][DEST_W-1:0] s_axis_tdest,

    output logic [OUT_PORTS-1:0][DATA_W-1:0] m_axis_tdata,
    output logic [OUT_PORTS-1:0]             m_axis_tvalid,
    input  logic [OUT_PORTS-1:0]             m_axis_tready,
    output logic [OUT_PORTS-1:0]             m_axis_tlast,
    output logic [OUT_PORTS-1:0][DEST_W-1:0] m_axis_tdest,

    output logic [IN_PORTS-1:0][COUNTER_W-1:0]  accepted_pkt_count,
    output logic [OUT_PORTS-1:0][COUNTER_W-1:0] forwarded_pkt_count,
    output logic [IN_PORTS-1:0][COUNTER_W-1:0]  drop_invalid_dest_count,
    output logic [IN_PORTS-1:0][COUNTER_W-1:0]  drop_oversize_count,
    output logic [IN_PORTS-1:0][COUNTER_W-1:0]  drop_malformed_count
);

`ifndef SYNTHESIS
    initial begin
        if (IN_PORTS != 2) $fatal(1, "axis_pkt_router: only IN_PORTS=2 is supported");
        if (OUT_PORTS != 4) $fatal(1, "axis_pkt_router: only OUT_PORTS=4 is supported");
        if (DATA_W < 8) $fatal(1, "axis_pkt_router: DATA_W must be >= 8");
        if ((DATA_W % 8) != 0) $fatal(1, "axis_pkt_router: DATA_W must be a multiple of 8");
        if (DEST_W < 2) $fatal(1, "axis_pkt_router: DEST_W must be >= 2");
        if (INGRESS_MAX_PKT_BEATS < 1) $fatal(1, "axis_pkt_router: INGRESS_MAX_PKT_BEATS must be >= 1");
        if (COUNTER_W < 1) $fatal(1, "axis_pkt_router: COUNTER_W must be >= 1");
    end
`endif

    logic [IN_PORTS-1:0] req_valid;
    logic [IN_PORTS-1:0][1:0] req_dest;
    logic [IN_PORTS-1:0][DATA_W-1:0] replay_tdata;
    logic [IN_PORTS-1:0] replay_tlast;
    logic [IN_PORTS-1:0][DEST_W-1:0] replay_tdest;
    logic [IN_PORTS-1:0] replay_fire;

    logic [OUT_PORTS-1:0][IN_PORTS-1:0] out_req;
    logic [OUT_PORTS-1:0] arb_grant_valid;
    logic [OUT_PORTS-1:0][IN_PORTS-1:0] arb_grant_oh;
    logic [OUT_PORTS-1:0] out_fire;
    logic [OUT_PORTS-1:0] out_last;

    genvar gi;
    generate
        for (gi = 0; gi < IN_PORTS; gi = gi + 1) begin : gen_ingress
            axis_ingress_pkt_buffer #(
                .DATA_W(DATA_W),
                .DEST_W(DEST_W),
                .INGRESS_MAX_PKT_BEATS(INGRESS_MAX_PKT_BEATS),
                .COUNTER_W(COUNTER_W)
            ) u_ingress (
                .clk(clk),
                .rst(rst),
                .s_axis_tdata(s_axis_tdata[gi]),
                .s_axis_tvalid(s_axis_tvalid[gi]),
                .s_axis_tready(s_axis_tready[gi]),
                .s_axis_tlast(s_axis_tlast[gi]),
                .s_axis_tdest(s_axis_tdest[gi]),
                .req_valid(req_valid[gi]),
                .req_dest(req_dest[gi]),
                .replay_tdata(replay_tdata[gi]),
                .replay_tlast(replay_tlast[gi]),
                .replay_tdest(replay_tdest[gi]),
                .replay_fire(replay_fire[gi]),
                .accepted_pkt_count(accepted_pkt_count[gi]),
                .drop_invalid_dest_count(drop_invalid_dest_count[gi]),
                .drop_oversize_count(drop_oversize_count[gi]),
                .drop_malformed_count(drop_malformed_count[gi])
            );
        end
    endgenerate

    always @* begin
        out_req = '0;
        replay_fire = '0;
        m_axis_tdata = '0;
        m_axis_tvalid = '0;
        m_axis_tlast = '0;
        m_axis_tdest = '0;
        out_last = '0;

        if (req_valid[0]) begin
            case (req_dest[0])
                2'd0: out_req[0][0] = 1'b1;
                2'd1: out_req[1][0] = 1'b1;
                2'd2: out_req[2][0] = 1'b1;
                2'd3: out_req[3][0] = 1'b1;
                default: out_req[0][0] = 1'b0;
            endcase
        end
        if (req_valid[1]) begin
            case (req_dest[1])
                2'd0: out_req[0][1] = 1'b1;
                2'd1: out_req[1][1] = 1'b1;
                2'd2: out_req[2][1] = 1'b1;
                2'd3: out_req[3][1] = 1'b1;
                default: out_req[0][1] = 1'b0;
            endcase
        end

        if (arb_grant_valid[0] && arb_grant_oh[0][0]) begin
            m_axis_tvalid[0] = 1'b1;
            m_axis_tdata[0] = replay_tdata[0];
            m_axis_tlast[0] = replay_tlast[0];
            m_axis_tdest[0] = replay_tdest[0];
            out_last[0] = replay_tlast[0];
            replay_fire[0] = m_axis_tready[0];
        end else if (arb_grant_valid[0] && arb_grant_oh[0][1]) begin
            m_axis_tvalid[0] = 1'b1;
            m_axis_tdata[0] = replay_tdata[1];
            m_axis_tlast[0] = replay_tlast[1];
            m_axis_tdest[0] = replay_tdest[1];
            out_last[0] = replay_tlast[1];
            replay_fire[1] = m_axis_tready[0];
        end

        if (arb_grant_valid[1] && arb_grant_oh[1][0]) begin
            m_axis_tvalid[1] = 1'b1;
            m_axis_tdata[1] = replay_tdata[0];
            m_axis_tlast[1] = replay_tlast[0];
            m_axis_tdest[1] = replay_tdest[0];
            out_last[1] = replay_tlast[0];
            replay_fire[0] = m_axis_tready[1];
        end else if (arb_grant_valid[1] && arb_grant_oh[1][1]) begin
            m_axis_tvalid[1] = 1'b1;
            m_axis_tdata[1] = replay_tdata[1];
            m_axis_tlast[1] = replay_tlast[1];
            m_axis_tdest[1] = replay_tdest[1];
            out_last[1] = replay_tlast[1];
            replay_fire[1] = m_axis_tready[1];
        end

        if (arb_grant_valid[2] && arb_grant_oh[2][0]) begin
            m_axis_tvalid[2] = 1'b1;
            m_axis_tdata[2] = replay_tdata[0];
            m_axis_tlast[2] = replay_tlast[0];
            m_axis_tdest[2] = replay_tdest[0];
            out_last[2] = replay_tlast[0];
            replay_fire[0] = m_axis_tready[2];
        end else if (arb_grant_valid[2] && arb_grant_oh[2][1]) begin
            m_axis_tvalid[2] = 1'b1;
            m_axis_tdata[2] = replay_tdata[1];
            m_axis_tlast[2] = replay_tlast[1];
            m_axis_tdest[2] = replay_tdest[1];
            out_last[2] = replay_tlast[1];
            replay_fire[1] = m_axis_tready[2];
        end

        if (arb_grant_valid[3] && arb_grant_oh[3][0]) begin
            m_axis_tvalid[3] = 1'b1;
            m_axis_tdata[3] = replay_tdata[0];
            m_axis_tlast[3] = replay_tlast[0];
            m_axis_tdest[3] = replay_tdest[0];
            out_last[3] = replay_tlast[0];
            replay_fire[0] = m_axis_tready[3];
        end else if (arb_grant_valid[3] && arb_grant_oh[3][1]) begin
            m_axis_tvalid[3] = 1'b1;
            m_axis_tdata[3] = replay_tdata[1];
            m_axis_tlast[3] = replay_tlast[1];
            m_axis_tdest[3] = replay_tdest[1];
            out_last[3] = replay_tlast[1];
            replay_fire[1] = m_axis_tready[3];
        end
    end

    generate
        genvar go;
        for (go = 0; go < OUT_PORTS; go = go + 1) begin : gen_output
            assign out_fire[go] = m_axis_tvalid[go] && m_axis_tready[go];

            axis_rr_arbiter #(
                .IN_PORTS(IN_PORTS)
            ) u_arbiter (
                .clk(clk),
                .rst(rst),
                .req(out_req[go]),
                .beat_fire(out_fire[go]),
                .beat_last(out_last[go]),
                .grant_valid(arb_grant_valid[go]),
                .grant_oh(arb_grant_oh[go])
            );

            always_ff @(posedge clk) begin
                if (rst) begin
                    forwarded_pkt_count[go] <= '0;
                end else if (out_fire[go] && out_last[go]) begin
                    forwarded_pkt_count[go] <= forwarded_pkt_count[go] + COUNTER_W'(1);
                end
            end
        end
    endgenerate

`ifndef SYNTHESIS
    logic [OUT_PORTS-1:0][DATA_W-1:0] held_tdata_q;
    logic [OUT_PORTS-1:0][DEST_W-1:0] held_tdest_q;
    logic [OUT_PORTS-1:0] held_tlast_q;
    logic [OUT_PORTS-1:0] held_valid_q;

    always @(posedge clk) begin
        if (rst) begin
            held_valid_q <= '0;
            held_tdata_q <= '0;
            held_tdest_q <= '0;
            held_tlast_q <= '0;
        end else begin
            if (&arb_grant_oh[0]) $fatal(1, "axis_pkt_router: output 0 has multiple grants");
            if (&arb_grant_oh[1]) $fatal(1, "axis_pkt_router: output 1 has multiple grants");
            if (&arb_grant_oh[2]) $fatal(1, "axis_pkt_router: output 2 has multiple grants");
            if (&arb_grant_oh[3]) $fatal(1, "axis_pkt_router: output 3 has multiple grants");

            for (int unsigned o = 0; o < OUT_PORTS; o = o + 1) begin
                if (held_valid_q[o] && m_axis_tvalid[o] && !m_axis_tready[o]) begin
                    if (m_axis_tdata[o] !== held_tdata_q[o]) $fatal(1, "axis_pkt_router: tdata changed while stalled on output %0d", o);
                    if (m_axis_tdest[o] !== held_tdest_q[o]) $fatal(1, "axis_pkt_router: tdest changed while stalled on output %0d", o);
                    if (m_axis_tlast[o] !== held_tlast_q[o]) $fatal(1, "axis_pkt_router: tlast changed while stalled on output %0d", o);
                end

                held_valid_q[o] <= m_axis_tvalid[o] && !m_axis_tready[o];
                held_tdata_q[o] <= m_axis_tdata[o];
                held_tdest_q[o] <= m_axis_tdest[o];
                held_tlast_q[o] <= m_axis_tlast[o];
            end
        end
    end
`endif

endmodule

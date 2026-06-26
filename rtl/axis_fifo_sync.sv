`timescale 1ns/1ps

module axis_fifo_sync #(
    parameter int DATA_W = 32,
    parameter int DEPTH  = 16
) (
    input  logic              clk,
    input  logic              rst,   // synchronous active-high reset

    // AXI-Stream slave side (into FIFO)
    input  logic [DATA_W-1:0] s_axis_tdata,
    input  logic              s_axis_tvalid,
    output logic              s_axis_tready,
    input  logic              s_axis_tlast,

    // AXI-Stream master side (out of FIFO)
    output logic [DATA_W-1:0] m_axis_tdata,
    output logic              m_axis_tvalid,
    input  logic              m_axis_tready,
    output logic              m_axis_tlast,

    // Occupancy (beats currently stored)
    output logic [((DEPTH <= 1) ? 1 : $clog2(DEPTH + 1))-1:0] count_o
);

    localparam int PTR_W   = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
    localparam int COUNT_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH + 1);

`ifndef SYNTHESIS
    initial begin
        if (DATA_W <= 0) $fatal(1, "axis_fifo_sync: DATA_W must be > 0");
        if (DEPTH  <= 0) $fatal(1, "axis_fifo_sync: DEPTH must be > 0");
    end
`endif

    (* ram_style = "block" *) logic [DATA_W-1:0] mem_data [0:DEPTH-1];
    (* ram_style = "block" *) logic              mem_last [0:DEPTH-1];

    logic [PTR_W-1:0] wr_ptr_q, rd_ptr_q;
    logic [COUNT_W-1:0] count_q;

    logic push, pop;
    logic full, empty;

    localparam logic [PTR_W-1:0]   LAST_PTR = PTR_W'(DEPTH - 1);
    localparam logic [COUNT_W-1:0] DEPTH_COUNT = COUNT_W'(DEPTH);

    // Simple combinational read (fine for skeleton / sim)
    assign m_axis_tdata  = mem_data[rd_ptr_q];
    assign m_axis_tlast  = mem_last[rd_ptr_q];
    assign m_axis_tvalid = !empty;

    assign s_axis_tready = !full;

    assign push = s_axis_tvalid && s_axis_tready;
    assign pop  = m_axis_tvalid && m_axis_tready;

    assign full  = (count_q == DEPTH_COUNT);
    assign empty = (count_q == 0);

    assign count_o = count_q;

    function automatic [PTR_W-1:0] ptr_inc(input [PTR_W-1:0] ptr);
        if (ptr == LAST_PTR) ptr_inc = '0;
        else                ptr_inc = ptr + 1'b1;
    endfunction

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr_q <= '0;
            rd_ptr_q <= '0;
            count_q  <= '0;
        end else begin
            // write path
            if (push) begin
                mem_data[wr_ptr_q] <= s_axis_tdata;
                mem_last[wr_ptr_q] <= s_axis_tlast;
                wr_ptr_q           <= ptr_inc(wr_ptr_q);
            end

            // read path
            if (pop) begin
                rd_ptr_q <= ptr_inc(rd_ptr_q);
            end

            // occupancy update
            unique case ({push, pop})
                2'b10: count_q <= count_q + 1'b1;
                2'b01: count_q <= count_q - 1'b1;
                default: count_q <= count_q;
            endcase
        end
    end

endmodule

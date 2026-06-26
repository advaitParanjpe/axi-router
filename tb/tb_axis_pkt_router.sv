`timescale 1ns/1ps

module tb_axis_pkt_router;

  // ----------------------------
  // Waveform dump (Surfer / GTKWave)
  // ----------------------------
  initial begin
    string wave_file;
    if ($test$plusargs("WAVES")) begin
      if (!$value$plusargs("WAVE_FILE=%s", wave_file)) begin
        wave_file = "build/tb_axis_pkt_router.vcd";
      end

      $dumpfile(wave_file);

      // Dump DUT internals (FSM, replay, FIFO counts, etc.)
      $dumpvars(0, tb_axis_pkt_router.dut);

      // Dump top-level I/O explicitly
      $dumpvars(0, tb_axis_pkt_router.clk);
      $dumpvars(0, tb_axis_pkt_router.rst);

      $dumpvars(0, tb_axis_pkt_router.s_axis_tdata);
      $dumpvars(0, tb_axis_pkt_router.s_axis_tvalid);
      $dumpvars(0, tb_axis_pkt_router.s_axis_tready);
      $dumpvars(0, tb_axis_pkt_router.s_axis_tlast);

      $dumpvars(0, tb_axis_pkt_router.m0_axis_tdata);
      $dumpvars(0, tb_axis_pkt_router.m0_axis_tvalid);
      $dumpvars(0, tb_axis_pkt_router.m0_axis_tready);
      $dumpvars(0, tb_axis_pkt_router.m0_axis_tlast);

      $dumpvars(0, tb_axis_pkt_router.m1_axis_tdata);
      $dumpvars(0, tb_axis_pkt_router.m1_axis_tvalid);
      $dumpvars(0, tb_axis_pkt_router.m1_axis_tready);
      $dumpvars(0, tb_axis_pkt_router.m1_axis_tlast);

      $dumpvars(0, tb_axis_pkt_router.pkt_to_m0_count);
      $dumpvars(0, tb_axis_pkt_router.pkt_to_m1_count);
      $dumpvars(0, tb_axis_pkt_router.pkt_drop_count);
    end
  end

  // Keep DATA_W=8 for first bring-up (1 byte/beat)
  localparam int DATA_W         = 8;
  localparam int MAX_PKT_BEATS  = 16;
  localparam int OUT_FIFO_DEPTH = 9;

  localparam int MAX_BYTES = 256;
  localparam int MAX_PKTS  = 64;

  // Packet IDs for directed tests
  localparam int PKT0 = 0;
  localparam int PKT1 = 1;
  localparam int PKT2 = 2;
  localparam int PKT3 = 3;
  localparam int PKT4 = 4;
  localparam int PKT5 = 5;
  localparam int PKT6 = 6;

  // ----------------------------
  // Clock / Reset
  // ----------------------------
  logic clk = 1'b0;
  always #5 clk = ~clk;

  logic rst;

  // ----------------------------
  // DUT I/O
  // ----------------------------
  logic [DATA_W-1:0] s_axis_tdata;
  logic              s_axis_tvalid;
  logic              s_axis_tready;
  logic              s_axis_tlast;

  logic [DATA_W-1:0] m0_axis_tdata;
  logic              m0_axis_tvalid;
  logic              m0_axis_tready;
  logic              m0_axis_tlast;

  logic [DATA_W-1:0] m1_axis_tdata;
  logic              m1_axis_tvalid;
  logic              m1_axis_tready;
  logic              m1_axis_tlast;

  logic [31:0]       pkt_to_m0_count;
  logic [31:0]       pkt_to_m1_count;
  logic [31:0]       pkt_drop_count;

  // ----------------------------
  // DUT
  // ----------------------------
  axis_pkt_router #(
    .DATA_W        (DATA_W),
    .MAX_PKT_BEATS (MAX_PKT_BEATS),
    .OUT_FIFO_DEPTH(OUT_FIFO_DEPTH)
  ) dut (
    .clk            (clk),
    .rst            (rst),

    .s_axis_tdata   (s_axis_tdata),
    .s_axis_tvalid  (s_axis_tvalid),
    .s_axis_tready  (s_axis_tready),
    .s_axis_tlast   (s_axis_tlast),

    .m0_axis_tdata  (m0_axis_tdata),
    .m0_axis_tvalid (m0_axis_tvalid),
    .m0_axis_tready (m0_axis_tready),
    .m0_axis_tlast  (m0_axis_tlast),

    .m1_axis_tdata  (m1_axis_tdata),
    .m1_axis_tvalid (m1_axis_tvalid),
    .m1_axis_tready (m1_axis_tready),
    .m1_axis_tlast  (m1_axis_tlast),

    .pkt_to_m0_count(pkt_to_m0_count),
    .pkt_to_m1_count(pkt_to_m1_count),
    .pkt_drop_count (pkt_drop_count)
  );

  // ============================================================
  // Basic Scoreboard Storage
  // ============================================================

  // Expected packets per destination
  reg [7:0] exp_data [0:1][0:MAX_PKTS-1][0:MAX_BYTES-1];
  integer   exp_len  [0:1][0:MAX_PKTS-1];
  integer   exp_cnt  [0:1];
  integer   exp_drop;

  // Actual packets observed per destination
  reg [7:0] act_data [0:1][0:MAX_PKTS-1][0:MAX_BYTES-1];
  integer   act_len  [0:1][0:MAX_PKTS-1];
  integer   act_cnt  [0:1];

  // Current packet assembly lengths per output monitor
  integer   cur_pkt_len [0:1];

  // Lightweight manual coverage flags
  integer coverage_seen_route_m0;
  integer coverage_seen_route_m1;
  integer coverage_seen_drop;
  integer coverage_seen_bp_m0;
  integer coverage_seen_bp_m1;
  integer coverage_seen_short_pkt;
  integer coverage_seen_long_pkt;

  // ============================================================
  // Packet byte generator (Icarus-friendly: no array task args)
  // ============================================================
  function automatic [7:0] pkt_byte(input integer pkt_id, input integer idx);
    begin
      pkt_byte = 8'h00;

      case (pkt_id)
        // p0: even -> m0 (short)
        PKT0: begin
          case (idx)
            0: pkt_byte = 8'h02;
            1: pkt_byte = 8'hAA;
            default: pkt_byte = 8'h00;
          endcase
        end

        // p1: odd -> m1 (long >8 bytes)
        PKT1: begin
          case (idx)
            0: pkt_byte = 8'h03;
            1: pkt_byte = 8'h10;
            2: pkt_byte = 8'h11;
            3: pkt_byte = 8'h12;
            4: pkt_byte = 8'h13;
            5: pkt_byte = 8'h14;
            6: pkt_byte = 8'h15;
            7: pkt_byte = 8'h16;
            8: pkt_byte = 8'h17;
            default: pkt_byte = 8'h00;
          endcase
        end

        // p2: even -> m0 (backpressure)
        PKT2: begin
          case (idx)
            0: pkt_byte = 8'h20;
            1: pkt_byte = 8'h21;
            2: pkt_byte = 8'h22;
            default: pkt_byte = 8'h00;
          endcase
        end

        // p3: odd -> m1 (backpressure)
        PKT3: begin
          case (idx)
            0: pkt_byte = 8'h31;
            1: pkt_byte = 8'h32;
            2: pkt_byte = 8'h33;
            default: pkt_byte = 8'h00;
          endcase
        end

        // p4: even -> m0 (fits)
        PKT4: begin
          case (idx)
            0: pkt_byte = 8'h40;
            1: pkt_byte = 8'h41;
            2: pkt_byte = 8'h42;
            default: pkt_byte = 8'h00;
          endcase
        end

        // p5: even -> m0 (drop when m0 FIFO mostly full)
        PKT5: begin
          case (idx)
            0: pkt_byte = 8'h42;
            1: pkt_byte = 8'h43;
            2: pkt_byte = 8'h44;
            default: pkt_byte = 8'h00;
          endcase
        end

        // p6: odd -> m1 (post-drop sanity)
        PKT6: begin
          case (idx)
            0: pkt_byte = 8'h55;
            1: pkt_byte = 8'h56;
            default: pkt_byte = 8'h00;
          endcase
        end

        default: begin
          pkt_byte = 8'h00;
        end
      endcase
    end
  endfunction

  // ============================================================
  // Helpers / Tasks
  // ============================================================

  task automatic wait_cycles(input integer n);
    integer i;
    begin
      for (i = 0; i < n; i = i + 1) @(posedge clk);
    end
  endtask

  task automatic clear_scoreboard;
    integer d, p, b;
    begin
      exp_cnt[0] = 0; exp_cnt[1] = 0; exp_drop = 0;
      act_cnt[0] = 0; act_cnt[1] = 0;
      cur_pkt_len[0] = 0; cur_pkt_len[1] = 0;

      coverage_seen_route_m0  = 0;
      coverage_seen_route_m1  = 0;
      coverage_seen_drop      = 0;
      coverage_seen_bp_m0     = 0;
      coverage_seen_bp_m1     = 0;
      coverage_seen_short_pkt = 0;
      coverage_seen_long_pkt  = 0;

      for (d = 0; d < 2; d = d + 1) begin
        for (p = 0; p < MAX_PKTS; p = p + 1) begin
          exp_len[d][p] = 0;
          act_len[d][p] = 0;
          for (b = 0; b < MAX_BYTES; b = b + 1) begin
            exp_data[d][p][b] = 8'h00;
            act_data[d][p][b] = 8'h00;
          end
        end
      end
    end
  endtask

  task automatic sb_expect_pkt(
    input integer dst,
    input integer nbytes,
    input integer pkt_id
  );
    integer i;
    begin
      if (dst == 0) coverage_seen_route_m0 = 1;
      else          coverage_seen_route_m1 = 1;

      if (nbytes <= 2) coverage_seen_short_pkt = 1;
      if (nbytes >= 6) coverage_seen_long_pkt  = 1;

      exp_len[dst][exp_cnt[dst]] = nbytes;
      for (i = 0; i < nbytes; i = i + 1) begin
        exp_data[dst][exp_cnt[dst]][i] = pkt_byte(pkt_id, i);
      end
      exp_cnt[dst] = exp_cnt[dst] + 1;
    end
  endtask

  task automatic sb_expect_drop;
    begin
      exp_drop = exp_drop + 1;
      coverage_seen_drop = 1;
    end
  endtask

  // AXI-stream source driver (1 byte/beat because DATA_W=8 here)
  task automatic send_packet(
    input integer nbytes,
    input integer pkt_id
  );
    integer i;
    begin
      if (nbytes <= 0) $fatal(1, "send_packet called with nbytes=%0d", nbytes);

      for (i = 0; i < nbytes; i = i + 1) begin
        s_axis_tdata  <= pkt_byte(pkt_id, i);
        s_axis_tlast  <= (i == nbytes-1);
        s_axis_tvalid <= 1'b1;

        // Hold until handshake occurs
        do @(posedge clk); while (!s_axis_tready);
      end

      s_axis_tvalid <= 1'b0;
      s_axis_tlast  <= 1'b0;
      s_axis_tdata  <= '0;
    end
  endtask

  task automatic compare_pkts_for_dst(input integer dst);
    integer p, i;
    begin
      if (act_cnt[dst] !== exp_cnt[dst]) begin
        $fatal(1, "DST%0d packet count mismatch exp=%0d act=%0d",
               dst, exp_cnt[dst], act_cnt[dst]);
      end

      for (p = 0; p < exp_cnt[dst]; p = p + 1) begin
        if (act_len[dst][p] !== exp_len[dst][p]) begin
          $fatal(1, "DST%0d pkt%0d len mismatch exp=%0d act=%0d",
                 dst, p, exp_len[dst][p], act_len[dst][p]);
        end

        for (i = 0; i < exp_len[dst][p]; i = i + 1) begin
          if (act_data[dst][p][i] !== exp_data[dst][p][i]) begin
            $fatal(1, "DST%0d pkt%0d byte%0d mismatch exp=0x%02x act=0x%02x",
                   dst, p, i, exp_data[dst][p][i], act_data[dst][p][i]);
          end
        end
      end
    end
  endtask

  task automatic check_counters_and_scoreboard;
    begin
      compare_pkts_for_dst(0);
      compare_pkts_for_dst(1);

      if (pkt_to_m0_count !== exp_cnt[0])
        $fatal(1, "pkt_to_m0_count mismatch exp=%0d act=%0d", exp_cnt[0], pkt_to_m0_count);

      if (pkt_to_m1_count !== exp_cnt[1])
        $fatal(1, "pkt_to_m1_count mismatch exp=%0d act=%0d", exp_cnt[1], pkt_to_m1_count);

      if (pkt_drop_count !== exp_drop)
        $fatal(1, "pkt_drop_count mismatch exp=%0d act=%0d", exp_drop, pkt_drop_count);

      // Directed coverage checks
      if (!coverage_seen_route_m0)  $fatal(1, "Coverage miss: route m0");
      if (!coverage_seen_route_m1)  $fatal(1, "Coverage miss: route m1");
      if (!coverage_seen_drop)      $fatal(1, "Coverage miss: drop");
      if (!coverage_seen_bp_m0)     $fatal(1, "Coverage miss: backpressure m0");
      if (!coverage_seen_bp_m1)     $fatal(1, "Coverage miss: backpressure m1");
      if (!coverage_seen_short_pkt) $fatal(1, "Coverage miss: short pkt");
      if (!coverage_seen_long_pkt)  $fatal(1, "Coverage miss: long pkt");
    end
  endtask

  task automatic print_summary;
    begin
      $display("====================================");
      $display("TB PASS");
      $display("pkt_to_m0_count = %0d", pkt_to_m0_count);
      $display("pkt_to_m1_count = %0d", pkt_to_m1_count);
      $display("pkt_drop_count  = %0d", pkt_drop_count);
      $display("Coverage: route_m0=%0d route_m1=%0d drop=%0d bp_m0=%0d bp_m1=%0d short=%0d long=%0d",
               coverage_seen_route_m0, coverage_seen_route_m1, coverage_seen_drop,
               coverage_seen_bp_m0, coverage_seen_bp_m1, coverage_seen_short_pkt, coverage_seen_long_pkt);
      $display("====================================");
    end
  endtask

  // ============================================================
  // Output Monitors (capture actual packets)
  // ============================================================

  always_ff @(posedge clk) begin
    if (rst) begin
      cur_pkt_len[0] <= 0;
      act_cnt[0]     <= 0;
    end else if (m0_axis_tvalid && m0_axis_tready) begin
      act_data[0][act_cnt[0]][cur_pkt_len[0]] <= m0_axis_tdata;

      if (m0_axis_tlast) begin
        act_len[0][act_cnt[0]] <= cur_pkt_len[0] + 1;
        act_cnt[0]             <= act_cnt[0] + 1;
        cur_pkt_len[0]         <= 0;
      end else begin
        cur_pkt_len[0]         <= cur_pkt_len[0] + 1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      cur_pkt_len[1] <= 0;
      act_cnt[1]     <= 0;
    end else if (m1_axis_tvalid && m1_axis_tready) begin
      act_data[1][act_cnt[1]][cur_pkt_len[1]] <= m1_axis_tdata;

      if (m1_axis_tlast) begin
        act_len[1][act_cnt[1]] <= cur_pkt_len[1] + 1;
        act_cnt[1]             <= act_cnt[1] + 1;
        cur_pkt_len[1]         <= 0;
      end else begin
        cur_pkt_len[1]         <= cur_pkt_len[1] + 1;
      end
    end
  end

  // ============================================================
  // Coverage monitor (observed output backpressure)
  // ============================================================
  always_ff @(posedge clk) begin
    if (!rst) begin
      if (m0_axis_tvalid && !m0_axis_tready) coverage_seen_bp_m0 = 1;
      if (m1_axis_tvalid && !m1_axis_tready) coverage_seen_bp_m1 = 1;
    end
  end

  // ============================================================
  // Directed tests
  // ============================================================

  initial begin
    // defaults
    rst            = 1'b1;
    s_axis_tdata   = '0;
    s_axis_tvalid  = 1'b0;
    s_axis_tlast   = 1'b0;
    m0_axis_tready = 1'b1;
    m1_axis_tready = 1'b1;

    clear_scoreboard();

    // reset
    wait_cycles(3);
    @(posedge clk);
    rst <= 1'b0;
    wait_cycles(2);

    // ---------------- Test 1: even -> m0 ----------------
    sb_expect_pkt(0, 2, PKT0);
    send_packet(2, PKT0);
    wait_cycles(10);

    // ---------------- Test 2: odd -> m1 -----------------
    sb_expect_pkt(1, 9, PKT1);
    send_packet(9, PKT1);
    wait_cycles(14);

    // -------- Test 3: m0 backpressure / delayed drain ----
    m0_axis_tready <= 1'b0;
    sb_expect_pkt(0, 3, PKT2);
    send_packet(3, PKT2);
    wait_cycles(10);        // enqueued to m0 FIFO, not drained yet
    m0_axis_tready <= 1'b1; // now allow drain
    wait_cycles(10);

    // -------- Test 4: m1 backpressure / delayed drain ----
    m1_axis_tready <= 1'b0;
    sb_expect_pkt(1, 3, PKT3);
    send_packet(3, PKT3);
    wait_cycles(10);
    m1_axis_tready <= 1'b1;
    wait_cycles(10);

    // -------- Test 5: force drop on m0 due FIFO full -----
    // Hold m0 sink low so FIFO occupancy persists.
    // OUT_FIFO_DEPTH=9. Fill to 8 beats, then send 3-beat packet => drop.
    m0_axis_tready <= 1'b0;

    // enqueue 3 beats (occ = 3)
    sb_expect_pkt(0, 3, PKT4);
    send_packet(3, PKT4);
    wait_cycles(8);

    // enqueue 3 beats (occ = 6)
    sb_expect_pkt(0, 3, PKT2);
    send_packet(3, PKT2);
    wait_cycles(8);

    // enqueue 2 beats (occ = 8)
    sb_expect_pkt(0, 2, PKT0);
    send_packet(2, PKT0);
    wait_cycles(8);

    // now only 1 beat free; 3-beat packet should be dropped
    sb_expect_drop();
    send_packet(3, PKT5);
    wait_cycles(12);

    m0_axis_tready <= 1'b1;     // drain m0 FIFO
    wait_cycles(20);

    // -------- Test 6: sanity after drop ------------------
    sb_expect_pkt(1, 2, PKT6);
    send_packet(2, PKT6);
    wait_cycles(10);

    // Final checks
    check_counters_and_scoreboard();
    print_summary();

    $finish;
  end

endmodule

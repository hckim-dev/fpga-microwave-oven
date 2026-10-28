`timescale 1ns / 1ps

module tb_display_controller;
  reg clk = 0;
  reg reset = 1;
  reg tick_1ms = 0;
  reg [1:0] state = 0;
  reg [11:0] remaining_seconds = 754;
  reg select_minutes = 0;
  wire [7:0] seg;
  wire [3:0] an;
  wire alert_done;
  reg [3:0] scenario = 0;
  integer phase, value, k;
  reg [7:0] circle_expected;
  reg [3:0] prev_an = 4'b1111;
  reg [7:0] prev_seg = 8'hFF;
  integer blank_clocks = 0;
  integer scan_checks = 0;
  wire [7:0] seg_min;
  wire [3:0] an_min;
  wire done_min;
  reg [1:0] state_min = 0;

  display_controller dut (
      .clk(clk), .reset(reset), .tick_1ms(tick_1ms), .state(state),
      .remaining_seconds(remaining_seconds), .select_minutes(select_minutes),
      .seg(seg), .an(an), .alert_done(alert_done)
  );
  display_controller #(.BlinkHalfMs(1), .ScreenPeriodMs(1), .CircleStepMs(1)) u_min (
      .clk(clk), .reset(reset), .tick_1ms(tick_1ms), .state(state_min),
      .remaining_seconds(12'd0), .select_minutes(1'b0),
      .seg(seg_min), .an(an_min), .alert_done(done_min)
  );
  always #5 clk = ~clk;

  // 각 자리 사이 2클럭 소등과 패턴 선출력, active-low one-hot 선택 검사.
  always @(posedge clk) begin
    #2;
    if (reset) begin
      if (an !== 4'b1111 || seg !== 8'hFF) $fatal(1, "reset must blank FND");
      blank_clocks = 0;
    end else if (an == 4'b1111) begin
      blank_clocks = blank_clocks + 1;
    end else begin
      if (an !== 4'b1110 && an !== 4'b1101 && an !== 4'b1011 && an !== 4'b0111)
        $fatal(1, "multiple or unknown anodes enabled");
      if (prev_an == 4'b1111) begin
        if (blank_clocks < 2 || seg !== prev_seg) $fatal(1, "scan blank/settle interval");
      end else if (an !== prev_an) $fatal(1, "digit changed without blank interval");
      blank_clocks = 0;
      scan_checks = scan_checks + 1;
    end
    prev_an = an;
    prev_seg = seg;
  end

  function [7:0] encode;
    input integer digit;
    begin
      case (digit)
        0: encode = 8'hC0; 1: encode = 8'hF9; 2: encode = 8'hA4;
        3: encode = 8'hB0; 4: encode = 8'h99; 5: encode = 8'h92;
        6: encode = 8'h82; 7: encode = 8'hF8; 8: encode = 8'h80;
        9: encode = 8'h90; default: encode = 8'hFF;
      endcase
    end
  endfunction

  function [31:0] expected_time;
    input integer seconds;
    reg [7:0] minute_units;
    begin
      minute_units = encode((seconds / 60) % 10) & 8'h7F;
      expected_time = {encode(seconds / 600), minute_units,
                       encode((seconds % 60) / 10), encode(seconds % 10)};
    end
  endfunction

  task cycle;
    begin
      @(posedge clk); #1; @(negedge clk);
    end
  endtask

  task advance_ms;
    input integer count;
    integer n;
    begin
      for (n = 0; n < count; n = n + 1) begin
        tick_1ms = 1; cycle();
        tick_1ms = 0; repeat (4) cycle();
      end
    end
  endtask

  task check_frame;
    input [31:0] expected;
    integer n, digit;
    reg [3:0] seen;
    begin
      seen = 0;
      for (n = 0; n < 4; n = n + 1) begin
        tick_1ms = 1; cycle();
        tick_1ms = 0; cycle(); cycle();
        case (an)
          4'b1110: digit = 0; 4'b1101: digit = 1;
          4'b1011: digit = 2; 4'b0111: digit = 3;
          default: $fatal(1, "scan failed to enable digit");
        endcase
        seen[digit] = 1;
        if (seg !== ((expected >> (digit * 8)) & 32'hFF))
          $fatal(1, "frame mismatch: scenario=%0d digit=%0d expected=%h actual=%h",
                 scenario, digit, ((expected >> (digit * 8)) & 32'hFF), seg);
        cycle(); cycle();
      end
      if (seen !== 4'b1111) $fatal(1, "scan skipped a digit");
    end
  endtask

  task settle_mode;
    begin
      cycle(); cycle();
    end
  endtask

  initial begin
    repeat (3) @(negedge clk);
    reset = 0;
    settle_mode();
    scenario = 1;
    check_frame(32'hF924B099);  // 12.34: 분/초 자리와 DP 위치 고정 예제.
    advance_ms(495);
    if (!dut.r_blink_on) $fatal(1, "IDLE blink early");
    advance_ms(1);
    check_frame(32'hF924FFFF);
    select_minutes = 1; settle_mode();
    check_frame(32'hF924B099);
    advance_ms(496);
    check_frame(32'hFF7FB099);  // 선택한 분만 소등, 구분점 유지.

    scenario = 2;
    state = 2; settle_mode();
    check_frame(32'hF924B099);
    advance_ms(496);
    check_frame(32'hF9A4B099);  // PAUSED는 숫자 유지, 구분점만 소등.

    scenario = 3;
    state = 1; settle_mode();
    check_frame(32'hF924B099);
    advance_ms(995);
    if (dut.r_show_circle) $fatal(1, "RUN screen early");
    advance_ms(1);
    for (k = 0; k < 6; k = k + 1) begin
      case (k)
        0: circle_expected = 8'hEF; 1: circle_expected = 8'hDF;
        2: circle_expected = 8'hFE; 3: circle_expected = 8'hFD;
        4: circle_expected = 8'hFB; 5: circle_expected = 8'hF7;
      endcase
      check_frame({4{circle_expected}});
      advance_ms(96);
    end
    advance_ms(400);
    check_frame(32'hF924B099);

    scenario = 4;
    state = 3; settle_mode();
    for (phase = 0; phase < 6; phase = phase + 1) begin
      if ((phase % 2) == 0) check_frame(32'hC0C0C0C0);
      else check_frame(32'hFFFFFFFF);
      advance_ms(495);
      if (alert_done || dut.r_done_phase != phase) $fatal(1, "DONE half-period early");
      advance_ms(1);
    end
    if (!alert_done) $fatal(1, "DONE must finish after three ON/OFF cycles");
    advance_ms(20);
    check_frame(32'hFFFFFFFF);
    if (!alert_done) $fatal(1, "completion must remain until acknowledged");

    scenario = 5;
    state = 0; settle_mode();
    if (alert_done) $fatal(1, "completion leaked outside DONE");
    state = 3; settle_mode();
    check_frame(32'hC0C0C0C0);
    if (alert_done) $fatal(1, "second DONE inherited prior completion");
    state = 0; settle_mode();

    scenario = 6;
    // 전체 설정값의 각 자리를 출력에서 대조. 선택 전환으로 점멸 위상 초기화.
    for (value = 0; value <= 3599; value = value + 1) begin
      remaining_seconds = value;
      select_minutes = !select_minutes;
      settle_mode();
      check_frame(expected_time(value));
    end

    scenario = 7;
    state_min = 3; settle_mode();
    advance_ms(5);
    if (done_min) $fatal(1, "minimum parameter finished early");
    advance_ms(1);
    if (!done_min) $fatal(1, "minimum parameter completion");
    state = 3; settle_mode();
    advance_ms(123);
    #2 reset = 1; #1;
    if (an !== 4'b1111 || seg !== 8'hFF || alert_done || done_min)
      $fatal(1, "asynchronous reset during alert");
    if (scan_checks < 1000) $fatal(1, "insufficient scan coverage");
    $display("PASS: all 3600 MM:SS values, active-low scan/blanking, field blink, paused DP, time/circle pages, six circle steps, three DONE flashes, sticky completion, reset, minimum parameters");
    $finish;
  end
  initial begin
    #2_000_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

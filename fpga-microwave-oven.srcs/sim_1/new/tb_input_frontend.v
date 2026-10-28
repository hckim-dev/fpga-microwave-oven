`timescale 1ns / 1ps

module tb_input_frontend;
  reg clk = 0;
  reg reset = 1;
  reg [6:0] button_raw = 7'b1000001;  // KEY 미누름, 분/초 버튼 기동 시 누름.
  reg [1:0] ab = 2'b11;
  wire synced_reset, tick_1ms, ready;
  wire [6:0] button_down, button_pulse;
  wire cw, ccw, invalid;
  reg [3:0] scenario = 0;
  integer button_count [0:6];
  integer cw_count = 0;
  integer ccw_count = 0;
  integer invalid_count = 0;
  integer tick_count = 0;
  integer cycles = 0;
  integer last_tick = -1;
  integer i;
  integer n;
  integer saved;
  reg [6:0] prev_pulse = 0;

  input_frontend #(
      .TickCount(5), .ButtonDebounceCount(4), .RotaryDebounceCount(3)
  ) dut (
      .clk(clk), .reset(reset), .button_raw(button_raw), .rotary_ab_raw(ab),
      .synced_reset(synced_reset), .tick_1ms(tick_1ms), .ready(ready),
      .button_down(button_down), .button_pulse(button_pulse),
      .rotary_cw(cw), .rotary_ccw(ccw), .rotary_invalid(invalid)
  );

  // 최소 Parameter와 클릭당 2전이 설정도 독립적으로 확인.
  wire tick_one, clean_one;
  reg noisy_one = 0;
  tick_generator #(.TickCount(1)) u_tick_one (
      .clk(clk), .reset(reset), .tick(tick_one)
  );
  btn_debouncer #(.DebounceCount(1)) u_debounce_one (
      .clk(clk), .reset(reset), .noisy_btn(noisy_one), .clean_btn(clean_one)
  );
  reg [1:0] ab_two = 0;
  wire cw_two, ccw_two, invalid_two;
  integer cw_two_count = 0;
  integer ccw_two_count = 0;
  rotary_decoder #(.StepsPerDetent(2)) u_rotary_two (
      .clk(clk), .reset(reset), .enable(1'b1), .ab(ab_two),
      .cw_pulse(cw_two), .ccw_pulse(ccw_two), .invalid_pulse(invalid_two)
  );

  always #5 clk = ~clk;

  // 실제 소비 모듈과 같이 posedge에서 이벤트를 샘플링.
  always @(posedge clk) begin
    if (reset) begin
      cw_two_count = 0;
      ccw_two_count = 0;
    end else begin
      if (cw_two) cw_two_count = cw_two_count + 1;
      if (ccw_two) ccw_two_count = ccw_two_count + 1;
    end
    if (synced_reset) begin
      cycles = 0;
      last_tick = -1;
      prev_pulse = 0;
    end else begin
      cycles = cycles + 1;
      if (tick_1ms) begin
        if (last_tick >= 0 && cycles - last_tick != 5)
          $fatal(1, "tick interval");
        last_tick = cycles;
        tick_count = tick_count + 1;
      end
      if ((button_pulse & prev_pulse) != 0) $fatal(1, "button pulse wider than one clock");
      prev_pulse = button_pulse;
      if (!ready && (button_pulse != 0 || cw || ccw)) $fatal(1, "event before ready");
      if (cw && ccw) $fatal(1, "opposing rotary events");
      for (n = 0; n < 7; n = n + 1)
        if (button_pulse[n]) button_count[n] = button_count[n] + 1;
      if (cw) cw_count = cw_count + 1;
      if (ccw) ccw_count = ccw_count + 1;
      if (invalid) invalid_count = invalid_count + 1;
    end
  end

  task wait_cycles;
    input integer count;
    begin
      repeat (count) @(negedge clk);
    end
  endtask

  task set_ab;
    input [1:0] value;
    begin
      ab = value;
      wait_cycles(12);
    end
  endtask

  task rotate_cw;
    begin
      set_ab(2'b10); set_ab(2'b11); set_ab(2'b01); set_ab(2'b00);
    end
  endtask

  task rotate_ccw;
    begin
      set_ab(2'b01); set_ab(2'b11); set_ab(2'b10); set_ab(2'b00);
    end
  endtask

  initial begin
    for (i = 0; i < 7; i = i + 1) button_count[i] = 0;
    wait_cycles(3);
    reset = 0;

    scenario = 1;
    wait_cycles(2);
    if (synced_reset !== 0) $fatal(1, "reset release must take two clocks");
    if (ready !== 0) $fatal(1, "startup settling bypassed");
    wait_cycles(20);
    if (ready !== 1 || button_down !== 7'b0000001) $fatal(1, "startup held button level");
    if (button_count[0] != 0 || cw_count != 0 || ccw_count != 0 || invalid_count != 0)
      $fatal(1, "phantom startup event");
    button_raw = 7'b1000000;
    set_ab(2'b00);  // 초기 위상으로부터의 2비트 이동은 invalid로 처리.
    if (invalid_count != 1) $fatal(1, "initial phase recovery");
    if (tick_one !== 1 || clean_one !== 0) $fatal(1, "minimum parameter idle");
    noisy_one = 1;
    wait_cycles(4);
    if (clean_one !== 1) $fatal(1, "minimum debounce parameter");

    scenario = 2;
    // 버튼별 짧은 잡음, 실제 누름, 길게 누름, 떼기 바운스.
    for (i = 0; i < 7; i = i + 1) begin
      button_raw[i] = ~button_raw[i]; wait_cycles(2);
      button_raw[i] = ~button_raw[i]; wait_cycles(12);
      if (button_count[i] != 0) $fatal(1, "short noise accepted: %0d", i);
      button_raw[i] = ~button_raw[i]; wait_cycles(12);
      if (button_count[i] != 1 || button_down[i] !== 1) $fatal(1, "press lost: %0d", i);
      wait_cycles(30);
      if (button_count[i] != 1) $fatal(1, "held button repeated: %0d", i);
      button_raw[i] = ~button_raw[i]; wait_cycles(2);
      button_raw[i] = ~button_raw[i]; wait_cycles(2);
      button_raw[i] = ~button_raw[i]; wait_cycles(12);
      if (button_count[i] != 1 || button_down[i] !== 0) $fatal(1, "release bounce: %0d", i);
    end

    scenario = 3;
    button_raw = 7'b0111111;
    wait_cycles(12);
    if (button_down !== 7'b1111111) $fatal(1, "simultaneous levels");
    for (i = 0; i < 7; i = i + 1)
      if (button_count[i] != 2) $fatal(1, "simultaneous event lost: %0d", i);
    button_raw = 7'b1000000;
    wait_cycles(12);

    scenario = 4;
    rotate_cw(); rotate_cw(); rotate_ccw();
    if (cw_count != 2 || ccw_count != 1) $fatal(1, "rotary direction/count");
    set_ab(2'b10); set_ab(2'b11); set_ab(2'b10); set_ab(2'b00);
    if (cw_count != 2 || ccw_count != 1) $fatal(1, "partial reversal counted");
    // 유효한 한 전이를 왕복하는 접점 바운스는 서로 상쇄.
    set_ab(2'b10); set_ab(2'b00); rotate_cw();
    if (cw_count != 3 || ccw_count != 1) $fatal(1, "transition bounce cancellation");
    ab = 2'b10; wait_cycles(1); ab = 2'b00; wait_cycles(12);
    if (cw_count != 3 || ccw_count != 1) $fatal(1, "raw rotary glitch accepted");

    scenario = 5;
    saved = invalid_count;
    set_ab(2'b11); set_ab(2'b00);
    if (invalid_count != saved + 2 || cw_count != 3 || ccw_count != 1)
      $fatal(1, "invalid transition emitted rotation");
    rotate_ccw();
    if (ccw_count != 2) $fatal(1, "invalid transition recovery");
    // 미완료 회전량은 Reset으로 폐기.
    set_ab(2'b10); set_ab(2'b11);

    scenario = 6;
    ab_two = 2'b10; wait_cycles(2);
    ab_two = 2'b11; wait_cycles(2);
    if (cw_two_count != 1 || ccw_two_count != 0) $fatal(1, "two-step CW");
    ab_two = 2'b10; wait_cycles(2);
    ab_two = 2'b00; wait_cycles(2);
    if (cw_two_count != 1 || ccw_two_count != 1) $fatal(1, "two-step CCW");

    scenario = 7;
    #2 reset = 1;
    #1;
    if (synced_reset !== 1 || ready !== 0 || button_pulse !== 0 || tick_1ms !== 0)
      $fatal(1, "asynchronous reset assertion");
    if (tick_one !== 0 || clean_one !== 0 || cw !== 0 || ccw !== 0)
      $fatal(1, "reset outputs");
    wait_cycles(3);
    button_raw = 7'b0000000;  // active-low KEY를 누른 채 Reset 해제.
    reset = 0;
    wait_cycles(25);
    if (button_down !== 7'b1000000 || button_count[6] != 2)
      $fatal(1, "held KEY at reset release");
    saved = cw_count;
    // Reset 시 위상 11부터 CW 2전이만 입력하면 한 클릭에 미달.
    set_ab(2'b01); set_ab(2'b00);
    if (cw_count != saved) $fatal(1, "partial accumulator survived reset");
    button_raw = 7'b1000000; wait_cycles(12);
    button_raw = 7'b0000000; wait_cycles(12);
    if (button_count[6] != 3) $fatal(1, "KEY after reset release");
    if (tick_count < 10) $fatal(1, "tick not exercised");

    $display("PASS: reset, tick spacing, startup suppression, 7 buttons, bounce, hold, polarity, simultaneous inputs, rotary CW/CCW, reversal, invalid recovery, 1/2/4 parameters");
    $finish;
  end

  initial begin
    #100_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

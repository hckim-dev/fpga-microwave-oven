`timescale 1ns / 1ps

module tb_microwave_controller;
  localparam [1:0] IDLE = 0, RUN = 1, PAUSED = 2, DONE = 3;
  localparam [6:0] FIELD = 7'b0000001;
  localparam [6:0] CANCEL = 7'b0001000;
  localparam [6:0] OPEN = 7'b0010000;
  localparam [6:0] CLOSE = 7'b0100000;
  localparam [6:0] KEY = 7'b1000000;
  reg clk = 0;
  reg reset = 1;
  reg tick_1ms = 0;
  reg [6:0] button_pulse = 0;
  reg rotary_cw = 0;
  reg rotary_ccw = 0;
  reg door_closed = 1;
  reg alert_done = 0;
  wire [1:0] state;
  wire [11:0] remaining_seconds;
  wire select_minutes, run_enable, timeout_pulse;
  reg [3:0] scenario = 0;
  integer timeout_count = 0;
  integer saved_timeout;
  integer saved_fraction;

  microwave_controller dut (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .button_pulse(button_pulse),
      .rotary_cw(rotary_cw),
      .rotary_ccw(rotary_ccw),
      .door_closed(door_closed),
      .alert_done(alert_done),
      .state(state),
      .remaining_seconds(remaining_seconds),
      .select_minutes(select_minutes),
      .run_enable(run_enable),
      .timeout_pulse(timeout_pulse)
  );

  always #5 clk = ~clk;

  always @(posedge clk) begin
    #2;
    if (remaining_seconds > 3599 || dut.r_elapsed_ms > 999) $fatal(1, "range invariant");
    if (state == RUN && remaining_seconds == 0) $fatal(1, "zero-time RUN");
    if (run_enable && (state != RUN || !door_closed || reset))
      $fatal(1, "run permission invariant");
    if (!reset && timeout_pulse) timeout_count = timeout_count + 1;
  end

  task cycle;
    begin
      @(posedge clk);
      #1;
      @(negedge clk);
    end
  endtask

  task press;
    input [6:0] mask;
    begin
      button_pulse = mask;
      cycle();
      button_pulse = 0;
      #1;  // 조합 출력이 버튼 해제를 반영한 뒤 검사.
    end
  endtask

  task turn;
    input clockwise;
    input integer count;
    integer n;
    begin
      for (n = 0; n < count; n = n + 1) begin
        rotary_cw = clockwise;
        rotary_ccw = !clockwise;
        cycle();
        rotary_cw = 0;
        rotary_ccw = 0;
        cycle();
      end
    end
  endtask

  task advance_ms;
    input integer count;
    integer n;
    begin
      tick_1ms = 1;
      for (n = 0; n < count; n = n + 1) cycle();
      tick_1ms = 0;
    end
  endtask

  task expect_value;
    input [1:0] expected_state;
    input [11:0] expected_seconds;
    input expected_field;
    input [511:0] reason;
    begin
      if (state !== expected_state || remaining_seconds !== expected_seconds ||
          select_minutes !== expected_field)
        $fatal(
            1, "%0s: state=%0d time=%0d field=%b", reason, state, remaining_seconds, select_minutes
        );

    end
  endtask

  initial begin
    repeat (3) @(negedge clk);
    reset = 0;
    cycle();
    scenario = 1;
    expect_value(IDLE, 0, 0, "reset defaults");
    press(KEY);
    expect_value(IDLE, 0, 0, "zero start rejected");
    turn(1, 1);
    door_closed = 0;
    press(KEY);
    expect_value(IDLE, 1, 0, "open door start rejected");
    door_closed = 1;
    press(CLOSE | KEY);
    expect_value(IDLE, 1, 0, "close and start same cycle rejected");
    press(CANCEL);

    scenario = 2;
    turn(0, 2);
    expect_value(IDLE, 0, 0, "second lower saturation");
    turn(1, 60);
    expect_value(IDLE, 59, 0, "second upper saturation without carry");
    press(FIELD);
    turn(1, 60);
    expect_value(IDLE, 3599, 1, "59:59 upper boundary");
    press(FIELD);
    turn(1, 1);
    turn(0, 1);
    expect_value(IDLE, 3598, 0, "seconds independent of minutes");
    press(FIELD);
    turn(0, 60);
    expect_value(IDLE, 58, 1, "minute lower saturation preserves seconds");
    press(FIELD);
    turn(0, 60);
    expect_value(IDLE, 0, 0, "seconds lower saturation without borrow");

    scenario = 3;
    rotary_cw = 1;
    press(FIELD);
    rotary_cw = 0;
    expect_value(IDLE, 0, 1, "field over rotary priority");
    rotary_cw = 1;
    rotary_ccw = 1;
    cycle();
    rotary_cw = 0;
    rotary_ccw = 0;
    expect_value(IDLE, 0, 1, "opposing rotary ignored");
    turn(1, 1);
    press(FIELD);
    press(KEY);
    expect_value(RUN, 60, 0, "start 01:00");
    if (!run_enable) $fatal(1, "run permission missing");
    advance_ms(999);
    expect_value(RUN, 60, 0, "no early decrement");
    advance_ms(1);
    expect_value(RUN, 59, 0, "01:00 to 00:59");

    scenario = 4;
    press(FIELD);
    turn(1, 2);
    expect_value(RUN, 59, 0, "editing disabled in RUN");
    advance_ms(125);
    tick_1ms = 1;
    press(KEY);
    tick_1ms = 0;
    expect_value(PAUSED, 59, 0, "pause over nonfinal tick");
    if (dut.r_elapsed_ms !== 125 || run_enable) $fatal(1, "pause fraction");
    advance_ms(2000);
    press(FIELD);
    turn(0, 2);
    expect_value(PAUSED, 59, 0, "paused time and field preserved");
    door_closed = 0;
    press(KEY);
    expect_value(PAUSED, 59, 0, "open door resume rejected");
    door_closed = 1;
    press(CLOSE);
    cycle();
    expect_value(PAUSED, 59, 0, "no automatic resume");
    press(KEY);
    advance_ms(874);
    expect_value(RUN, 59, 0, "resume preserves fraction");
    advance_ms(1);
    expect_value(RUN, 58, 0, "resumed second boundary");
    press(CANCEL);
    expect_value(IDLE, 0, 0, "cancel clears time and selection");

    scenario = 5;
    turn(1, 1);
    press(KEY);
    advance_ms(999);
    saved_timeout = timeout_count;
    tick_1ms = 1;
    button_pulse = OPEN | CLOSE | KEY;
    #1;
    if (run_enable !== 0) $fatal(1, "open must gate run before state update");
    cycle();
    button_pulse = 0;
    tick_1ms = 0;
    expect_value(PAUSED, 1, 0, "open over close/key/expiration");
    if (timeout_count != saved_timeout || dut.r_elapsed_ms !== 999)
      $fatal(1, "open boundary must preserve remaining tick");
    door_closed = 0;
    press(KEY);
    door_closed = 1;
    press(CLOSE | KEY);
    expect_value(PAUSED, 1, 0, "close over resume");
    press(KEY);
    tick_1ms = 1;
    press(KEY);
    tick_1ms = 0;
    expect_value(DONE, 0, 0, "expiration over pause");
    if (timeout_pulse !== 1 || timeout_count != saved_timeout + 1 || run_enable)
      $fatal(1, "single timeout event");
    advance_ms(10);
    if (timeout_pulse !== 0 || timeout_count != saved_timeout + 1)
      $fatal(1, "timeout repeated or zero underflow");
    press(KEY);
    expect_value(IDLE, 0, 0, "DONE key acknowledges without restarting");

    scenario = 6;
    turn(1, 1);
    press(KEY);
    advance_ms(1000);
    expect_value(DONE, 0, 0, "natural expiration");
    alert_done = 1;
    cycle();
    alert_done = 0;
    expect_value(IDLE, 0, 0, "alert completion returns IDLE");
    turn(1, 1);
    press(KEY);
    advance_ms(999);
    saved_timeout = timeout_count;
    tick_1ms = 1;
    press(CANCEL | OPEN | CLOSE | KEY | FIELD);
    tick_1ms = 0;
    expect_value(IDLE, 0, 0, "cancel over all events");
    if (timeout_count != saved_timeout || timeout_pulse) $fatal(1, "cancel emitted timeout");

    scenario = 7;
    turn(1, 2);
    press(KEY);
    advance_ms(99);
    saved_fraction = dut.r_elapsed_ms;
    door_closed = 0;
    #1;
    if (run_enable !== 0) $fatal(1, "door status must gate run immediately");
    advance_ms(1);
    expect_value(PAUSED, 2, 0, "door closed status lost without button");
    if (dut.r_elapsed_ms != saved_fraction) $fatal(1, "door status loss consumed tick");
    door_closed = 1;
    press(KEY);
    button_pulse = 7'b0000110;  // 속도 입력은 시간 계수를 막지 않음.
    advance_ms(901);
    button_pulse = 0;
    expect_value(RUN, 1, 0, "independent speed inputs do not block time");

    scenario = 8;
    #2 reset = 1;
    #1;
    expect_value(IDLE, 0, 0, "asynchronous reset during RUN");
    if (run_enable !== 0 || timeout_pulse !== 0 || dut.r_elapsed_ms !== 0)
      $fatal(1, "reset outputs");
    cycle();
    reset = 0;
    advance_ms(1001);
    expect_value(IDLE, 0, 0, "idle tick cannot underflow");

    scenario = 9;
    turn(1, 1);
    press(KEY);
    press(KEY);
    expect_value(PAUSED, 1, 0, "pause before cancel");
    press(CANCEL);
    expect_value(IDLE, 0, 0, "cancel from PAUSED");
    turn(1, 1);
    press(KEY);
    alert_done = 1;
    advance_ms(1000);
    alert_done = 0;
    expect_value(DONE, 0, 0, "alert_done outside DONE cannot skip expiration");
    press(CANCEL);
    expect_value(IDLE, 0, 0, "cancel from DONE");
    if (timeout_pulse !== 0) $fatal(1, "cancel leaves stale timeout");

    $display(
        "PASS: time setting 00:00..59:59, field saturation, countdown, pause fraction, cancel, door interlock, DONE, timeout pulse, event priorities, reset");
    $finish;
  end

  initial begin
    #200_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

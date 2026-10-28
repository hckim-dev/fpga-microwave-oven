`timescale 1ns / 1ps

module tb_input_controller;
  reg clk = 0;
  reg reset = 1;
  reg [6:0] button_raw = 7'b1000000;
  reg [1:0] ab = 0;
  reg door_closed = 1;  // 도어 FSM 대신 TB에서 공급하는 논리 상태.
  wire synced_reset, tick_1ms, ready;
  wire [6:0] button_down, button_pulse;
  wire cw, ccw, invalid;
  wire [1:0] state;
  wire [11:0] remaining_seconds;
  wire select_minutes, run_enable, timeout_pulse;
  integer timeout_count = 0;
  reg [3:0] scenario = 0;

  input_frontend #(
      .TickCount(5), .ButtonDebounceCount(4), .RotaryDebounceCount(3)
  ) u_input (
      .clk(clk), .reset(reset), .button_raw(button_raw), .rotary_ab_raw(ab),
      .synced_reset(synced_reset), .tick_1ms(tick_1ms), .ready(ready),
      .button_down(button_down), .button_pulse(button_pulse),
      .rotary_cw(cw), .rotary_ccw(ccw), .rotary_invalid(invalid)
  );
  microwave_controller dut (
      .clk(clk), .reset(synced_reset), .tick_1ms(tick_1ms), .button_pulse(button_pulse),
      .rotary_cw(cw), .rotary_ccw(ccw), .door_closed(door_closed), .alert_done(1'b0),
      .state(state), .remaining_seconds(remaining_seconds), .select_minutes(select_minutes),
      .run_enable(run_enable), .timeout_pulse(timeout_pulse)
  );
  always #5 clk = ~clk;
  always @(posedge clk) if (!synced_reset && timeout_pulse) timeout_count = timeout_count + 1;

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

  task press;
    input [6:0] logical_mask;
    begin
      button_raw = logical_mask ^ 7'b1000000;
      wait_cycles(16);
      button_raw = 7'b1000000;
      wait_cycles(16);
    end
  endtask

  initial begin
    wait_cycles(3);
    reset = 0;
    wait_cycles(25);
    if (!ready || state !== 0 || remaining_seconds !== 0) $fatal(1, "input/controller startup");
    scenario = 1;
    // 짧은 A상 잡음 제거 후 CW 한 클릭을 입력.
    ab = 2'b10; wait_cycles(1); ab = 0; wait_cycles(12);
    set_ab(2'b10); set_ab(2'b11); set_ab(2'b01); set_ab(2'b00);
    if (remaining_seconds !== 1) $fatal(1, "raw rotary to time setting");

    scenario = 2;
    // KEY 바운스와 길게 누름에도 시작 이벤트는 한 번만 발생.
    button_raw[6] = 0; wait_cycles(2);
    button_raw[6] = 1; wait_cycles(12);
    if (state !== 0) $fatal(1, "raw KEY glitch accepted");
    button_raw[6] = 0; wait_cycles(50);
    if (state !== 1 || !run_enable) $fatal(1, "held KEY repeated start/pause");
    button_raw[6] = 1; wait_cycles(16);

    scenario = 3;
    press(7'b0010000);
    if (state !== 2 || run_enable) $fatal(1, "raw open input did not pause");
    door_closed = 0;
    press(7'b1000000);
    if (state !== 2) $fatal(1, "raw KEY resumed with open door");
    door_closed = 1;
    press(7'b0100000);
    if (state !== 2) $fatal(1, "raw close automatically resumed");
    press(7'b1000000);
    if (state !== 1) $fatal(1, "raw KEY resume");

    scenario = 4;
    wait_cycles(5100);
    if (state !== 3 || remaining_seconds !== 0 || timeout_count != 1 || run_enable)
      $fatal(1, "frontend tick to natural timeout");
    press(7'b1000000);
    if (state !== 0) $fatal(1, "raw DONE acknowledgment");
    set_ab(2'b10); set_ab(2'b11); set_ab(2'b01); set_ab(2'b00);
    press(7'b1000000);
    press(7'b0001000);
    if (state !== 0 || remaining_seconds !== 0 || run_enable)
      $fatal(1, "raw cancel input");

    $display("PASS: raw rotary/button debounce to controller, held KEY, door pause/resume, generated ticks to timeout, cancel");
    $finish;
  end
  initial begin
    #150_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

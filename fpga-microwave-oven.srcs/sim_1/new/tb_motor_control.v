`timescale 1ns / 1ps

module tb_motor_control;
  reg clk = 0, reset = 1;
  reg [2:0] r_tick_count = 0;
  wire tick_1ms = (r_tick_count == 4);
  reg [6:0] buttons = 0;
  reg rotary_cw = 0;
  wire [1:0] cook_state, speed_level;
  wire [ 2:0] door_state;
  wire [11:0] remaining_seconds;
  wire [ 6:0] duty;
  wire select_minutes, run_enable, timeout_pulse;
  wire door_closed, servo_enable, target_open, servo_pwm, applied, open_event, close_event;
  wire pwm, in1, in2;
  reg [3:0] scenario = 0;
  integer i, high_count;

  microwave_controller u_control (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .button_pulse(buttons),
      .rotary_cw(rotary_cw),
      .rotary_ccw(1'b0),
      .door_closed(door_closed),
      .alert_done(1'b0),
      .state(cook_state),
      .remaining_seconds(remaining_seconds),
      .select_minutes(select_minutes),
      .run_enable(run_enable),
      .timeout_pulse(timeout_pulse)
  );

  door_controller #(
      .MoveTimeMs(5)
  ) u_door (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .open_request(buttons[4]),
      .close_request(buttons[5]),
      .cancel(buttons[3]),
      .command_applied(applied),
      .state(door_state),
      .door_closed(door_closed),
      .servo_enable(servo_enable),
      .target_open(target_open),
      .open_event(open_event),
      .close_event(close_event)
  );

  servo_controller #(
      .FrameClocks(20),
      .ClosedPulseClocks(3),
      .OpenPulseClocks(5)
  ) u_servo (
      .clk(clk),
      .reset(reset),
      .enable(servo_enable),
      .target_open(target_open),
      .servo_pwm(servo_pwm),
      .command_applied(applied)
  );

  motor_controller #(
      .PwmPeriodClocks(20)
  ) u_motor (
      .clk(clk),
      .reset(reset),
      .cook_state(cook_state),
      .run_enable(run_enable),
      .button_pulse(buttons),
      .speed_level(speed_level),
      .duty_percent(duty),
      .motor_pwm(pwm),
      .motor_in1(in1),
      .motor_in2(in2)
  );

  always #5 clk = ~clk;
  always @(posedge clk) begin
    if (reset) r_tick_count <= 0;
    else if (tick_1ms) r_tick_count <= 0;
    else r_tick_count <= r_tick_count + 1'b1;
    #2;
    if ((!run_enable || cook_state != 1 || !door_closed || reset) && (pwm || in1 || in2))
      $fatal(1, "motor interlock violated");
    if (in2) $fatal(1, "unexpected direction");
  end
  task wait_cycles;
    input integer count;
    begin
      repeat (count) @(negedge clk);
    end
  endtask

  task press;
    input [6:0] mask;
    begin
      buttons = mask;
      #1;
      if ((|mask[6:3]) && (pwm || in1)) $fatal(1, "stop request not gated before state update");
      wait_cycles(1);
      buttons = 0;
      wait_cycles(3);
    end
  endtask

  task wait_door;
    input [2:0] expected;
    integer n;
    begin
      n = 0;
      while (door_state !== expected && n < 200) begin
        wait_cycles(1);
        n = n + 1;
      end
      if (door_state !== expected) $fatal(1, "door wait timeout");
      wait_cycles(2);
    end
  endtask

  task wait_high;
    integer n;
    begin
      n = 0;
      while (pwm !== 1 && n < 50) begin
        wait_cycles(1);
        n = n + 1;
      end
      if (pwm !== 1) $fatal(1, "motor never enabled");
    end
  endtask

  initial begin
    wait_cycles(3);
    reset = 0;
    wait_cycles(3);
    scenario = 1;
    press(7'b0000010);
    rotary_cw = 1;
    wait_cycles(1);
    rotary_cw = 0;
    press(7'b1000000);
    if (cook_state !== 0 || pwm || in1 || duty !== 70) $fatal(1, "unknown door start/idle speed");
    press(7'b1100000);
    wait_door(1);
    if (cook_state !== 0 || pwm || in1) $fatal(1, "close auto-started motor");
    press(7'b1000000);
    wait_high();
    if (cook_state !== 1 || !in1) $fatal(1, "start after door close");
    press(7'b0000010);
    wait_cycles(40);
    if (duty !== 90 || u_motor.r_applied_level !== 3) $fatal(1, "RUN speed change");
    high_count = 0;
    for (i = 0; i < 20; i = i + 1) begin
      if (pwm) high_count = high_count + 1;
      wait_cycles(1);
    end
    if (high_count != 18) $fatal(1, "applied 90 percent PWM");

    scenario = 2;
    wait_high();
    press(7'b1000000);
    if (cook_state !== 2 || pwm || in1) $fatal(1, "pause did not stop motor");
    press(7'b0000100);
    press(7'b0000110);
    if (duty !== 70 || pwm) $fatal(1, "paused speed setting/simultaneous hold");
    press(7'b1000000);
    wait_high();
    press(7'b0010010);  // 열기와 속도 증가 동시: 열기 우선.
    if (cook_state !== 2 || duty !== 70 || pwm || in1) $fatal(1, "open priority over speed/run");
    wait_door(3);
    press(7'b1000000);
    if (cook_state !== 2 || pwm) $fatal(1, "open door resume");
    press(7'b1100000);
    wait_door(1);
    if (cook_state !== 2 || pwm) $fatal(1, "close auto-resumed motor");
    press(7'b1000000);
    wait_high();
    press(7'b0001000);
    if (cook_state !== 0 || remaining_seconds !== 0 || pwm || in1 || duty !== 70)
      $fatal(1, "cancel stop and retained speed");

    scenario  = 3;
    rotary_cw = 1;
    wait_cycles(1);
    rotary_cw = 0;
    press(7'b1000000);
    i = 0;
    while (!(remaining_seconds == 1 && u_control.r_elapsed_ms == 999 && tick_1ms) && i < 6000) begin
      wait_cycles(1);
      i = i + 1;
    end
    if (i == 6000) $fatal(1, "expiration boundary watchdog");
    buttons = 7'b0000010;
    #1;
    if (run_enable || pwm || in1) $fatal(1, "expiration must gate run before state update");
    wait_cycles(1);
    buttons = 0;
    wait_cycles(3);
    if (cook_state !== 3 || remaining_seconds !== 0 || pwm || in1) $fatal(1, "timeout stop");
    if (duty !== 70) $fatal(1, "expiration must suppress simultaneous speed request");
    press(7'b0000010);
    if (duty !== 70) $fatal(1, "DONE speed change accepted");
    press(7'b1000000);
    rotary_cw = 1;
    wait_cycles(1);
    rotary_cw = 0;
    press(7'b1000000);
    wait_high();
    #2 reset = 1;
    #1;
    if (pwm || in1 || in2 || duty !== 50 || door_closed || servo_pwm)
      $fatal(1, "global reset during motor HIGH");
    $display(
        "PASS: motor with cooking/door/servo, speed updates, pause/open/cancel/timeout/reset stop, manual resume, fresh start and retained setting");
    $finish;
  end
  initial begin
    #100_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

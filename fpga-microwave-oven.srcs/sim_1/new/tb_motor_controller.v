`timescale 1ns / 1ps

module tb_motor_controller;
  reg clk = 0, reset = 1, run_enable = 0;
  reg  [1:0] cook_state = 0;
  reg  [6:0] buttons = 0;
  wire [1:0] speed_level;
  wire [6:0] duty;
  wire pwm, in1, in2;
  reg default_run = 0;
  reg [1:0] default_state = 0;
  reg [6:0] default_buttons = 0;
  wire [1:0] default_level;
  wire [6:0] default_duty;
  wire default_pwm, default_in1, default_in2;
  reg [3:0] scenario = 0;
  integer highs, i, level;

  motor_controller #(
      .PwmPeriodClocks(10)
  ) dut (
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

  motor_controller u_default (
      .clk(clk),
      .reset(reset),
      .cook_state(default_state),
      .run_enable(default_run),
      .button_pulse(default_buttons),
      .speed_level(default_level),
      .duty_percent(default_duty),
      .motor_pwm(default_pwm),
      .motor_in1(default_in1),
      .motor_in2(default_in2)
  );

  always #5 clk = ~clk;
  always @(posedge clk) begin
    #2;
    if (in2 || default_in2) $fatal(1, "unexpected reverse direction");
    if ((!run_enable || cook_state != 1 || reset) && (pwm || in1))
      $fatal(1, "motor permission invariant");
    if (speed_level > 3 || duty < 30 || duty > 90) $fatal(1, "speed range");
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
      buttons = mask;
      cycle();
      buttons = 0;
      #1;
    end
  endtask

  task check_period;
    input integer expected_highs;
    integer n;
    begin
      highs = 0;
      for (n = 0; n < 10; n = n + 1) begin
        if (pwm !== (n < expected_highs)) $fatal(1, "scaled PWM phase %0d", n);
        if (pwm) highs = highs + 1;
        cycle();
      end
      if (highs != expected_highs) $fatal(1, "scaled duty count");
    end
  endtask

  initial begin
    repeat (3) @(negedge clk);
    reset = 0;
    cycle();
    scenario = 1;
    if (speed_level !== 1 || duty !== 50 || pwm || in1) $fatal(1, "reset speed/default stop");
    press(7'b0000100);
    press(7'b0000100);
    if (duty !== 30) $fatal(1, "lower saturation");
    press(7'b0000110);
    if (duty !== 30) $fatal(1, "simultaneous speed inputs must hold at lower bound");
    for (level = 0; level < 4; level = level + 1) begin
      if (duty !== 30 + level * 20) $fatal(1, "speed level percentage");
      cook_state = 1;
      run_enable = 1;
      cycle();
      check_period(3 + level * 2);
      run_enable = 0;
      cycle();
      cook_state = 0;
      if (level < 3) press(7'b0000010);
    end
    press(7'b0000010);
    press(7'b0000110);
    if (duty !== 90) $fatal(1, "upper saturation/simultaneous hold");

    scenario = 2;
    press(7'b0000100);
    press(7'b0000100);
    cook_state = 1;
    run_enable = 1;
    cycle();
    cycle();
    cycle();  // 현재 HIGH 구간의 phase 2.
    press(7'b0000100);
    if (duty !== 30 || dut.r_applied_level !== 1 || !pwm)
      $fatal(1, "mid-HIGH change applied early");
    cycle();
    if (!pwm) $fatal(1, "old 50 percent HIGH truncated");
    cycle();
    if (pwm) $fatal(1, "old HIGH exceeded five clocks");
    repeat (5) cycle();
    check_period(3);
    repeat (3)
    cycle();  // phase 3, 즉시 50% 반영 시 HIGH가 재발생할 수 있는 LOW 구간.
    press(7'b0000010);
    if (duty !== 50 || dut.r_applied_level !== 0 || pwm) $fatal(1, "mid-LOW change applied early");
    repeat (6) cycle();
    check_period(5);

    scenario = 3;
    repeat (9) cycle();  // 주기 마지막 클럭.
    press(7'b0000010);
    if (duty !== 70 || dut.r_applied_level !== 2 || dut.r_pwm_count !== 0)
      $fatal(1, "boundary request not applied to new period");
    check_period(7);
    run_enable = 0;
    #1;
    if (pwm || in1) $fatal(1, "immediate stop");
    cycle();
    press(7'b0000100);
    if (duty !== 70) $fatal(1, "RUN without permission accepted speed input");
    cook_state = 2;
    press(7'b0000010);
    if (duty !== 90) $fatal(1, "paused speed setting");
    cook_state = 3;
    press(7'b0000100);
    if (duty !== 90) $fatal(1, "DONE speed setting must be ignored");
    cook_state = 0;
    press(7'b0001100);
    press(7'b0010100);
    press(7'b0100100);
    press(7'b1000100);
    if (duty !== 90) $fatal(1, "higher priority event did not suppress speed setting");
    run_enable = 1;
    cycle();
    if (pwm || in1) $fatal(1, "run_enable alone cannot drive outside RUN");
    cook_state = 1;
    cycle();
    if (!pwm || dut.r_pwm_count !== 0) $fatal(1, "restart must begin fresh period");
    #2 reset = 1;
    #1;
    if (pwm || in1 || duty !== 50) $fatal(1, "async reset during HIGH");
    cycle();
    run_enable = 0;
    cook_state = 0;
    reset = 0;
    cycle();

    scenario = 4;
    // 기본 100 MHz/100,000클럭 주기를 네 듀티 모두 축소 없이 검사.
    default_buttons = 7'b0000100;
    cycle();
    default_buttons = 0;
    for (level = 0; level < 4; level = level + 1) begin
      if (default_duty !== 30 + level * 20) $fatal(1, "default duty setting");
      default_state = 1;
      default_run   = 1;
      cycle();
      highs = 0;
      for (i = 0; i < 100_000; i = i + 1) begin
        if (default_pwm !== (i < (30 + level * 20) * 1000)) $fatal(1, "default PWM phase %0d", i);
        if (default_pwm) highs = highs + 1;
        cycle();
      end
      if (highs != (30 + level * 20) * 1000 || !default_in1) $fatal(1, "default HIGH total");
      default_run = 0;
      cycle();
      default_state = 0;
      if (default_pwm || default_in1) $fatal(1, "default stop outputs");
      if (level < 3) begin
        default_buttons = 7'b0000010;
        cycle();
        default_buttons = 0;
      end
    end
    $display(
        "PASS: default 1 kHz at 30/50/70/90 percent, saturation and simultaneous inputs, frame-boundary duty updates, stop/restart/reset, state/event priority");
    $finish;
  end
  initial begin
    #5_000_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

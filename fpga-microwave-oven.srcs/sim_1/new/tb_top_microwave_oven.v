`timescale 1ns / 1ps

module tb_top_microwave_oven;
  reg clk = 0;
  always #5 clk = ~clk;
  reg reset = 1;
  // 누름 상태는 1로 입력하고, 보드 포트에서 KEY만 active-low로 변환한다.
  reg [6:0] buttons = 7'b1000000;
  reg [1:0] ab = 0;
  wire [7:0] seg;
  wire [3:0] an;
  wire [15:0] led;
  wire servo_pwm, buzzer, motor_pwm, in1, in2;
  integer scenario = 0;
  integer pulse_count = 0, open_count = 0, close_count = 0;
  integer done_ticks = 0, timeout_count = 0;
  reg [11:0] saved_time;
  reg [ 9:0] saved_fraction;

  top_microwave_oven #(
      .TickCount(10),
      .ButtonDebounceCount(3),
      .RotaryDebounceCount(2),
      .ServoFrameClocks(40),
      .ClosedPulseClocks(4),
      .OpenPulseClocks(6),
      .MoveTimeMs(5),
      .PwmPeriodClocks(10)
  ) dut (
      .clk(clk),
      .lock_switch(1'b0),
      .btnC(reset),
      .btnL(buttons[0]),
      .btnU(buttons[1]),
      .btnD(buttons[2]),
      .btnR(buttons[3]),
      .door_open(buttons[4]),
      .door_close(buttons[5]),
      .rotary_key(!buttons[6]),
      .rotary_s1(ab[1]),
      .rotary_s2(ab[0]),
      .seg(seg),
      .an(an),
      .led(led),
      .servo_pwm(servo_pwm),
      .buzzer(buzzer),
      .motor_pwm(motor_pwm),
      .motor_in1(in1),
      .motor_in2(in2)
  );

  task clocks;
    input integer n;
    begin
      repeat (n) @(negedge clk);
    end
  endtask

  task check;
    input condition;
    input [511:0] message;
    begin
      if (condition !== 1'b1) $fatal(1, "scenario %0d: %0s", scenario, message);
    end
  endtask

  task press;
    input [6:0] mask;
    begin
      buttons = mask;
      clocks(20);
      buttons = 0;
      clocks(20);
    end
  endtask

  task phase;
    input [1:0] value;
    begin
      ab = value;
      clocks(12);
    end
  endtask

  task cw;
    begin
      phase(2'b10);
      phase(2'b11);
      phase(2'b01);
      phase(2'b00);
    end
  endtask

  task ccw;
    begin
      phase(2'b01);
      phase(2'b11);
      phase(2'b10);
      phase(2'b00);
    end
  endtask

  task wait_cook;
    input [1:0] value;
    input integer limit;
    integer count;
    begin
      count = 0;
      while ((dut.cook_state !== value) && (count < limit)) begin
        clocks(1);
        count = count + 1;
      end
      check(dut.cook_state == value, "cook state deadline");
    end
  endtask

  always @(posedge clk) begin
    if (!dut.reset) begin
      if (|dut.button_pulse) pulse_count = pulse_count + 1;
      if (dut.open_event) open_count = open_count + 1;
      if (dut.close_event) close_count = close_count + 1;
      if ((dut.cook_state == 3) && dut.tick_1ms) done_ticks = done_ticks + 1;
      if (dut.timeout_pulse) timeout_count = timeout_count + 1;
    end
    #1;
    if (!dut.run_enable) check(!motor_pwm && !in1 && !in2, "motor output without run permission");
    if (motor_pwm) check(dut.door_closed && (dut.cook_state == 1), "PWM requires closed RUN");
    if (!dut.servo_enable) check(!servo_pwm, "servo output without enable");
    check(
        (an == 4'b1111) || (an == 4'b1110) || (an == 4'b1101) || (an == 4'b1011) || (an == 4'b0111),
        "FND one active digit or blank");
    if (!dut.reset) begin
      check(led[1] == dut.run_enable && led[4] == dut.door_closed, "status LED wiring");
      check(led[9:8] == dut.speed_level, "speed LED wiring");
      if ((dut.cook_state == 3) && !dut.sound_busy)
        check(buzzer == dut.alert_on, "completion display/sound envelope");
    end
  end

  initial begin
    clocks(5);
    reset = 0;
    clocks(40);
    scenario = 1;
    check(led[0] && led[7] && !led[4], "boot UNKNOWN and input ready");
    check(dut.cook_state == 0 && !servo_pwm && !motor_pwm, "boot outputs");
    check(pulse_count == 0, "held KEY suppressed at startup");
    buttons = 0;
    clocks(20);
    buttons[0] = 1;
    clocks(1);
    buttons[0] = 0;
    clocks(20);
    check(pulse_count == 0 && !dut.select_minutes, "short raw bounce rejected");
    cw();
    check(dut.remaining_seconds == 1, "raw CW one second");
    press(1);
    cw();
    check(dut.remaining_seconds == 61, "minute selection and CW");
    ccw();
    press(1);
    check(dut.remaining_seconds == 1 && !dut.select_minutes, "CCW and seconds selection");
    press(7'b1000000);
    check(dut.cook_state == 0, "UNKNOWN blocks start");

    scenario = 2;
    press(7'b0100000);
    clocks(120);
    check(dut.door_closed && close_count == 1 && servo_pwm !== 1'bx,
          "close command applied and timed");
    press(7'b1000000);
    wait_cook(1, 50);
    clocks(100);
    check(in1 && dut.speed_level == 1, "start motor default 50 percent");
    press(7'b0000010);
    check(dut.speed_level == 2, "raw speed increase");
    press(7'b1000000);
    check(dut.cook_state == 2, "pause");
    saved_time = dut.remaining_seconds;
    saved_fraction = dut.u_control.r_elapsed_ms;
    clocks(15000);
    check(dut.remaining_seconds == saved_time && dut.u_control.r_elapsed_ms == saved_fraction,
          "pause preserves whole and fractional time");
    press(7'b0010000);
    clocks(120);
    check(dut.door_state == 3 && open_count == 1, "open while paused");
    press(7'b1000000);
    check(dut.cook_state == 2, "open door blocks resume");
    press(7'b0100000);
    clocks(120);
    check(dut.door_closed && dut.cook_state == 2, "close does not auto resume");
    press(7'b1000000);
    wait_cook(1, 50);
    press(7'b0010000);
    check(dut.cook_state == 2 && !in1, "raw open pauses RUN");
    clocks(120);
    press(7'b0100000);
    clocks(120);
    press(7'b1000000);
    wait_cook(1, 50);
    press(7'b0001000);
    check(dut.cook_state == 0 && dut.remaining_seconds == 0, "cancel RUN");
    check(dut.speed_level == 2, "cancel retains speed");

    scenario = 3;
    cw();
    press(7'b1000000);
    wait_cook(1, 50);
    done_ticks = 0;
    wait_cook(3, 11000);
    check(!motor_pwm && !in1 && dut.remaining_seconds == 0, "natural expiry stops motor");
    wait_cook(0, 31000);
    check(done_ticks == 3000 && timeout_count == 1, "three-second completion and one timeout");

    scenario = 4;
    cw();
    press(7'b1000000);
    wait_cook(1, 50);
    // 동일한 필터를 거친 취소·열기·닫기·KEY의 동시 입력을 검사한다.
    press(7'b1111000);
    check(dut.cook_state == 0 && dut.remaining_seconds == 0 && dut.door_state == 1,
          "simultaneous cancel wins over open close and KEY");
    press(7'b0110000);
    clocks(120);
    check(dut.door_state == 3, "simultaneous open wins over close");
    press(7'b0100000);
    check(dut.door_state == 4, "closing before moving cancellation");
    press(7'b0001000);
    check(dut.door_state == 0 && !servo_pwm, "moving cancellation returns UNKNOWN");
    press(7'b0100000);
    clocks(120);
    cw();
    press(7'b1000000);
    wait_cook(1, 50);
    reset = 1;
    clocks(2);
    check(!motor_pwm && !servo_pwm && !buzzer && an == 15, "reset gates all actuator outputs");
    reset = 0;
    clocks(40);
    check(dut.cook_state == 0 && dut.door_state == 0 && dut.speed_level == 1,
          "reset restores UNKNOWN IDLE and default speed");
    $display(
        "PASS: board top raw inputs, boot hold/bounce, rotary fields, door interlock, pause/resume, speed, cancel, expiry, shared alert, simultaneous priority, reset");
    $finish;
  end
  initial begin
    #2000000;
    $fatal(1, "watchdog");
  end
endmodule

`timescale 1ns / 1ps

module tb_top_control_lock;
  reg clk = 0, reset = 1, lock_switch = 1;
  reg  [ 6:0] buttons = 0;
  reg  [ 1:0] ab = 0;
  wire [ 7:0] seg;
  wire [ 3:0] an;
  wire [15:0] led;
  wire servo_pwm, buzzer, motor_pwm, in1, in2;
  integer scenario = 0, i, saved_fraction;
  reg [11:0] saved_time;

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
      .btnC(reset),
      .lock_switch(lock_switch),
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

  always #5 clk = ~clk;

  task cycles;
    input integer count;
    begin
      repeat (count) @(negedge clk);
    end
  endtask

  task check;
    input condition;
    input [511:0] reason;
    begin
      if (condition !== 1'b1) $fatal(1, "scenario %0d: %0s", scenario, reason);
    end
  endtask

  task press;
    input [6:0] mask;
    begin
      buttons = mask;
      cycles(20);
      buttons = 0;
      cycles(20);
    end
  endtask

  task phase;
    input [1:0] value;
    begin
      ab = value;
      cycles(12);
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

  task wait_cook;
    input [1:0] state;
    input integer limit;
    integer count;
    begin
      count = 0;
      while ((dut.cook_state !== state) && (count < limit)) begin
        cycles(1);
        count = count + 1;
      end
      check(dut.cook_state == state, "cooking state deadline");
    end
  endtask

  always @(posedge clk) begin
    #1;
    if (!dut.run_enable) check(!motor_pwm && !in1 && !in2, "motor permission invariant");
    if (!reset && !dut.reset) begin
      check(led[14] == dut.locked, "LD14 indicates control lock");
      if (dut.locked) begin
        check(dut.control_buttons[2:0] == 0 && !dut.control_cw && !dut.control_ccw,
              "locked settings must not reach consumers");
        if ((dut.cook_state == 0) || (dut.cook_state == 2))
          check(!dut.control_buttons[6], "locked start/resume must not reach controller");
      end
      check(dut.control_buttons[5:3] == dut.button_pulse[5:3], "stop and door remain available");
    end
  end

  initial begin
    cycles(5);
    reset = 0;
    cycles(40);
    scenario = 1;
    check(led[0] && led[14] && dut.locked, "SW0 high at startup locks controls");
    press(7'b0000001);
    check(buzzer && dut.sound_busy, "blocked physical button still requests BEEP");
    cw();
    press(7'b0000010);
    press(7'b1000000);
    check(
        dut.remaining_seconds == 0 && !dut.select_minutes && dut.speed_level == 1 &&
          dut.cook_state == 0,
        "locked editing and start ignored");
    press(7'b0010000);
    cycles(120);
    check(dut.door_state == 3, "open permitted while locked");
    press(7'b0100000);
    cycles(120);
    check(dut.door_closed, "close permitted while locked");
    cycles(4000);

    scenario = 2;
    lock_switch = 0;
    cycles(20);
    check(!dut.locked && !led[14] && dut.cook_state == 0, "unlock does not start");
    for (i = 0; i < 5; i = i + 1) cw();
    press(7'b0000010);
    check(dut.remaining_seconds == 5 && dut.speed_level == 2, "unlocked settings work");
    lock_switch = 1;
    cycles(20);
    // 잠금 해제와 KEY 누름이 같은 필터 경계에 도달해도 시작하지 않는다.
    lock_switch = 0;
    buttons = 7'b1000000;
    cycles(20);
    check(dut.cook_state == 0, "simultaneous unlock and KEY must not start");
    buttons = 0;
    cycles(20);
    lock_switch = 1;
    cycles(20);
    buttons = 7'b1000000;
    cycles(40);
    check(dut.cook_state == 0, "locked KEY cannot start a nonzero timer");
    // 잠금 해제 시 눌린 KEY를 새 시작 이벤트로 만들지 않는다.
    lock_switch = 0;
    cycles(40);
    check(dut.cook_state == 0, "held KEY cannot auto-start on unlock");
    buttons = 0;
    cycles(20);
    press(7'b1000000);
    check(dut.cook_state == 1 && in1, "fresh KEY starts after unlock");

    scenario = 3;
    lock_switch = 1;
    cycles(20);
    saved_fraction = dut.u_control.r_elapsed_ms;
    press(7'b0000011);
    press(7'b0000100);
    cw();
    cycles(1000);
    check(dut.cook_state == 1 && in1 && dut.speed_level == 2 && !dut.select_minutes,
          "locking does not stop RUN or permit setting changes");
    check(dut.u_control.r_elapsed_ms > saved_fraction, "countdown continues while locked");
    press(7'b1000000);
    check(dut.cook_state == 2 && !in1, "KEY pauses while locked");
    saved_time = dut.remaining_seconds;
    saved_fraction = dut.u_control.r_elapsed_ms;
    press(7'b1000111);
    cw();
    cycles(1000);
    check(
        dut.cook_state == 2 && dut.remaining_seconds == saved_time &&
          dut.u_control.r_elapsed_ms == saved_fraction && dut.speed_level == 2,
        "locked PAUSED cannot resume or edit");
    press(7'b0010000);
    cycles(120);
    check(dut.door_state == 3 && dut.cook_state == 2, "locked pause allows opening");
    press(7'b0100000);
    cycles(120);
    press(7'b1000000);
    check(dut.door_closed && dut.cook_state == 2, "closing does not bypass locked resume");
    lock_switch = 0;
    cycles(20);
    check(dut.cook_state == 2, "unlock does not auto-resume");
    press(7'b1000000);
    check(dut.cook_state == 1, "explicit resume after unlock");
    lock_switch = 1;
    cycles(20);
    press(7'b0001000);
    check(dut.cook_state == 0 && dut.remaining_seconds == 0 && !in1 && dut.speed_level == 2,
          "cancel remains available and retains speed");

    scenario = 4;
    press(7'b0010000);
    press(7'b0001000);
    check(dut.door_state == 0 && !servo_pwm, "locked moving cancellation returns UNKNOWN");
    reset   = 1;
    buttons = 7'b1000000;
    cycles(3);
    reset = 0;
    cycles(40);
    check(
        dut.locked && led[14] && dut.cook_state == 0 && dut.door_state == 0 && dut.speed_level == 1,
        "reset keeps physical lock and restores defaults");
    buttons = 0;
    cycles(20);

    scenario = 5;
    lock_switch = 0;
    cycles(20);
    press(7'b0100000);
    cycles(120);
    cw();
    press(7'b1000000);
    lock_switch = 1;
    cycles(20);
    wait_cook(3, 11000);
    check(dut.locked && !in1 && !motor_pwm, "natural expiry while locked");
    press(7'b1000000);
    check(dut.cook_state == 0 && dut.locked, "KEY acknowledges DONE while locked");
    lock_switch = 0;
    cycles(20);
    cw();
    press(7'b1000000);
    lock_switch = 1;
    cycles(20);
    wait_cook(3, 11000);
    wait_cook(0, 31000);
    check(dut.locked && !in1, "automatic alert completion remains available");
    $display(
        "PASS: SW0 lock through raw board inputs, startup/reset, blocked edits/start/resume, BEEP, held KEY unlock, RUN continues, pause/cancel/door remain available, locked expiry/ack/automatic return");
    $finish;
  end

  initial begin
    #2_000_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

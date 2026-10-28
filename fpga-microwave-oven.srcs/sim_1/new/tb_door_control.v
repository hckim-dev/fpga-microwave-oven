`timescale 1ns / 1ps

module tb_door_control;
  reg clk = 0, reset = 1;
  reg [2:0] r_tick_count = 0;
  wire tick_1ms = (r_tick_count == 4);
  reg [6:0] buttons = 0;
  reg rotary_cw = 0;
  wire [1:0] cook_state;
  wire [2:0] door_state;
  wire [11:0] remaining_seconds;
  wire select_minutes, run_enable, timeout_pulse;
  wire door_closed, servo_enable, target_open, servo_pwm, applied, open_event, close_event;
  wire buzzer, sound_active, sound_busy, overflow;
  integer opens = 0, closes = 0, saved_opens, saved_closes, saved_time;
  integer effect_starts = 0, saved_effect_starts;
  reg prev_effect_active = 0;
  reg [3:0] scenario = 0;

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
      .MoveTimeMs(20)
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
      .FrameClocks(100),
      .ClosedPulseClocks(5),
      .OpenPulseClocks(10)
  ) u_servo (
      .clk(clk),
      .reset(reset),
      .enable(servo_enable),
      .target_open(target_open),
      .servo_pwm(servo_pwm),
      .command_applied(applied)
  );

  sound_controller u_sound (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .button_pulse(buttons),
      .door_open_event(open_event),
      .door_close_event(close_event),
      .alert_active(1'b0),
      .alert_on(1'b0),
      .buzzer(buzzer),
      .sound_active(sound_active),
      .busy(sound_busy),
      .queue_overflow(overflow)
  );

  always #5 clk = ~clk;
  always @(posedge clk) begin
    if (reset) r_tick_count <= 0;
    else if (tick_1ms) r_tick_count <= 0;
    else r_tick_count <= r_tick_count + 1'b1;
    if (!reset) begin
      if (open_event) opens = opens + 1;
      if (close_event) closes = closes + 1;
    end
    #2;
    if (!reset && u_sound.r_effect_active && !prev_effect_active) effect_starts = effect_starts + 1;
    prev_effect_active = u_sound.r_effect_active;
    if (run_enable && (!door_closed || cook_state != 1)) $fatal(1, "door/cooking interlock");
    if (!servo_enable && servo_pwm) $fatal(1, "disabled servo pulse");
    if (overflow) $fatal(1, "normal door scenario overflowed sound queue");
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
      while (door_state !== expected && n < 1000) begin
        wait_cycles(1);
        n = n + 1;
      end
      if (door_state !== expected) $fatal(1, "door wait watchdog");
      wait_cycles(2);
    end
  endtask

  initial begin
    wait_cycles(3);
    reset = 0;
    wait_cycles(3);
    scenario  = 1;
    rotary_cw = 1;
    wait_cycles(1);
    rotary_cw = 0;
    press(7'b1000000);
    if (cook_state !== 0 || door_state !== 0 || run_enable || servo_enable)
      $fatal(1, "UNKNOWN startup must block cooking and servo");
    press(7'b1100000);
    if (door_state !== 4 || cook_state !== 0 || !servo_enable || closes != 1)
      $fatal(1, "close/start same-cycle handling");
    wait_door(1);
    if (cook_state !== 0 || !door_closed) $fatal(1, "close must not automatically start cooking");
    press(7'b1000000);
    wait_cycles(300);
    if (cook_state !== 1 || !run_enable) $fatal(1, "start after inferred close");

    scenario   = 2;
    saved_time = remaining_seconds;
    press(7'b1010000);
    if (cook_state !== 2 || run_enable || door_state !== 2 || opens != 1)
      $fatal(1, "open over pause/key during cooking");
    saved_closes = closes;
    press(7'b0100000);
    if (closes != saved_closes) $fatal(1, "opposite moving request accepted");
    wait_door(3);
    saved_opens = opens;
    press(7'b0010000);
    if (opens != saved_opens) $fatal(1, "redundant open generated effect event");
    press(7'b1000000);
    if (cook_state !== 2 || remaining_seconds != saved_time) $fatal(1, "resume with open door");
    press(7'b1100000);
    wait_door(1);
    if (cook_state !== 2) $fatal(1, "close auto-resumed cooking");
    press(7'b1000000);
    if (cook_state !== 1 || !run_enable) $fatal(1, "explicit resume after close");

    scenario = 3;
    press(7'b0010000);
    buttons = 7'b0001000;
    #1;
    if (servo_pwm || run_enable) $fatal(1, "cancel must immediately mute movement/run");
    wait_cycles(1);
    buttons = 0;
    wait_cycles(3);
    if (door_state !== 0 || servo_enable || cook_state !== 0 || remaining_seconds !== 0)
      $fatal(1, "cancel moving door and cooking");
    if (u_sound.r_effect_active || u_sound.r_effect_count) $fatal(1, "cancel retained door sound");
    press(7'b0100000);
    wait_door(1);
    if (cook_state !== 0 || remaining_seconds !== 0)
      $fatal(1, "recovery restarted cancelled cooking");

    scenario = 4;
    saved_opens = opens;
    saved_closes = closes;
    press(7'b0110000);
    if (opens != saved_opens + 1 || closes != saved_closes || door_state !== 2)
      $fatal(1, "simultaneous open/close acceptance");
    saved_opens  = opens;
    saved_closes = closes;
    press(7'b0111000);
    if (door_state !== 0 || opens != saved_opens || closes != saved_closes)
      $fatal(1, "cancel over simultaneous door requests");
    wait_cycles(400);
    if (sound_busy || buzzer || servo_pwm) $fatal(1, "cancelled work did not drain");

    scenario = 5;
    saved_effect_starts = effect_starts;
    press(7'b0100000);
    wait_door(1);
    wait_cycles(310);
    if (!u_sound.r_effect_active || !u_sound.r_effect_close || !buzzer)
      $fatal(1, "accepted close did not reach close sound after BEEP");
    wait_cycles(1100);
    if (sound_busy || effect_starts != saved_effect_starts + 1)
      $fatal(1, "accepted close effect completion/count");
    press(7'b0100000);
    wait_cycles(400);
    if (sound_busy || effect_starts != saved_effect_starts + 1)
      $fatal(1, "duplicate closed request generated a door effect");
    $display(
        "PASS: unknown-start interlock, servo apply/door settling, manual start/resume, open stops cooking, ignored/duplicate event filtering, door sounds, cancel and recovery");
    $finish;
  end
  initial begin
    #100_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

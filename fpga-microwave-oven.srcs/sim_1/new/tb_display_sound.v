`timescale 1ns / 1ps

module tb_display_sound;
  reg clk = 0, reset = 1;
  reg [2:0] r_tick_count = 0;
  wire tick_1ms = (r_tick_count == 4);
  reg [6:0] buttons = 0;
  reg rotary_cw = 0;
  reg open_event = 0, close_event = 0;
  wire [1:0] state;
  wire [11:0] remaining_seconds;
  wire select_minutes, run_enable, timeout_pulse;
  wire alert_done, alert_on;
  wire [7:0] seg;
  wire [3:0] an;
  wire buzzer, sound_active, busy, overflow;
  integer done_ticks = 0, alert_on_ticks = 0;
  integer last_done_ticks = 0, last_on_ticks = 0;
  reg [1:0] prev_state = 0;
  reg [3:0] scenario = 0;
  reg check_sync = 0;

  microwave_controller u_control (
      .clk(clk), .reset(reset), .tick_1ms(tick_1ms), .button_pulse(buttons),
      .rotary_cw(rotary_cw), .rotary_ccw(1'b0), .door_closed(1'b1), .alert_done(alert_done),
      .state(state), .remaining_seconds(remaining_seconds), .select_minutes(select_minutes),
      .run_enable(run_enable), .timeout_pulse(timeout_pulse)
  );
  display_controller u_display (
      .clk(clk), .reset(reset), .tick_1ms(tick_1ms), .state(state),
      .remaining_seconds(remaining_seconds), .select_minutes(select_minutes),
      .seg(seg), .an(an), .alert_done(alert_done), .alert_on(alert_on)
  );
  sound_controller u_sound (
      .clk(clk), .reset(reset), .tick_1ms(tick_1ms), .button_pulse(buttons),
      .door_open_event(open_event), .door_close_event(close_event),
      .alert_active(state == 3), .alert_on(alert_on), .buzzer(buzzer),
      .sound_active(sound_active), .busy(busy), .queue_overflow(overflow)
  );
  always #5 clk = ~clk;
  always @(posedge clk) begin
    if (reset) begin
      r_tick_count <= 0;
      done_ticks = 0;
      alert_on_ticks = 0;
      prev_state = 0;
    end else begin
      if (tick_1ms) r_tick_count <= 0;
      else r_tick_count <= r_tick_count + 1'b1;
      if (state == 3 && tick_1ms) begin
        done_ticks = done_ticks + 1;
        if (alert_on) alert_on_ticks = alert_on_ticks + 1;
      end
      if (state != 3 && prev_state == 3) begin
        last_done_ticks = done_ticks;
        last_on_ticks = alert_on_ticks;
        done_ticks = 0;
        alert_on_ticks = 0;
      end
      prev_state = state;
    end
    #2;
    if (check_sync && state == 3 && buzzer !== alert_on)
      $fatal(1, "display/sound alert envelope diverged");
    if (overflow) $fatal(1, "unexpected queue overflow in normal scenario");
  end

  task wait_cycles;
    input integer count;
    begin repeat (count) @(negedge clk); end
  endtask

  task start_one_second;
    begin
      rotary_cw = 1; wait_cycles(1); rotary_cw = 0; wait_cycles(1);
      buttons = 7'b1000000; wait_cycles(1); buttons = 0; wait_cycles(1);
      if (state !== 1) $fatal(1, "start");
    end
  endtask

  initial begin
    wait_cycles(3); reset = 0; wait_cycles(3);
    scenario = 1;
    start_one_second();
    check_sync = 1;
    wait (state == 3);
    wait (state == 0);
    wait_cycles(3);
    check_sync = 0;
    if (last_done_ticks != 3000 || last_on_ticks != 1500 || buzzer || busy || alert_on)
      $fatal(1, "shared three-second alert: total=%0d on=%0d", last_done_ticks, last_on_ticks);

    scenario = 2;
    start_one_second();
    wait (state == 3);
    wait_cycles(1000);
    buttons = 7'b0001000; wait_cycles(1); buttons = 0;
    wait_cycles(16000);
    if (state !== 0 || buzzer || busy || alert_done || alert_on)
      $fatal(1, "cancel retained stale alert work");

    scenario = 3;
    buttons = 7'b0010000; open_event = 1;
    wait_cycles(1); buttons = 0; open_event = 0;
    wait_cycles(5);
    if (u_sound.r_effect_active || !buzzer) $fatal(1, "door effect must follow button BEEP");
    wait_cycles(300);
    if (!u_sound.r_effect_active || u_sound.r_effect_close)
      $fatal(1, "accepted door event not played after BEEP");
    buttons = 7'b0001000; wait_cycles(1); buttons = 0;
    wait_cycles(400);
    if (busy || buzzer) $fatal(1, "door effect not cancelled");

    scenario = 4;
    start_one_second();
    wait (state == 3);
    wait_cycles(1000);
    buttons = 7'b1000000; wait_cycles(1); buttons = 0;
    wait_cycles(16000);
    if (state !== 0 || busy || buzzer || alert_on) $fatal(1, "KEY alert acknowledgment");
    $display("PASS: shared FND/sound envelope, 3000 DONE ticks/1500 ON ticks, automatic IDLE return, cancel/KEY acknowledgment, accepted door effect after BEEP");
    $finish;
  end
  initial begin
    #1_200_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

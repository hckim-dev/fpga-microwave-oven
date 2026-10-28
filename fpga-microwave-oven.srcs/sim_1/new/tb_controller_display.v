`timescale 1ns / 1ps

module tb_controller_display;
  reg clk = 0;
  reg reset = 1;
  reg [6:0] button_pulse = 0;
  reg rotary_cw = 0;
  reg [2:0] r_tick_count = 0;
  wire tick_1ms = (r_tick_count == 4);
  wire [1:0] state;
  wire [11:0] remaining_seconds;
  wire select_minutes, run_enable, timeout_pulse, alert_done;
  wire [7:0] seg;
  wire [3:0] an;
  reg [3:0] scenario = 0;
  integer done_ticks = 0;
  integer last_done_ticks = 0;
  integer completed_alerts = 0;
  reg [1:0] prev_state = 0;
  reg prev_alert_done = 0;

  microwave_controller u_control (
      .clk(clk), .reset(reset), .tick_1ms(tick_1ms), .button_pulse(button_pulse),
      .rotary_cw(rotary_cw), .rotary_ccw(1'b0), .door_closed(1'b1), .alert_done(alert_done),
      .state(state), .remaining_seconds(remaining_seconds), .select_minutes(select_minutes),
      .run_enable(run_enable), .timeout_pulse(timeout_pulse)
  );
  display_controller u_display (
      .clk(clk), .reset(reset), .tick_1ms(tick_1ms), .state(state),
      .remaining_seconds(remaining_seconds), .select_minutes(select_minutes),
      .seg(seg), .an(an), .alert_done(alert_done)
  );
  always #5 clk = ~clk;
  always @(posedge clk) begin
    if (reset) r_tick_count <= 0;
    else if (tick_1ms) r_tick_count <= 0;
    else r_tick_count <= r_tick_count + 1'b1;
    if (reset) begin
      done_ticks = 0;
      prev_state = 0;
      prev_alert_done = 0;
    end else begin
      if (state == 3 && tick_1ms) done_ticks = done_ticks + 1;
      if (alert_done && !prev_alert_done) completed_alerts = completed_alerts + 1;
      if (state != 3 && prev_state == 3) begin
        last_done_ticks = done_ticks;
        done_ticks = 0;
      end
      prev_state = state;
      prev_alert_done = alert_done;
    end
  end

  task wait_cycles;
    input integer count;
    begin
      repeat (count) @(negedge clk);
    end
  endtask

  task start_one_second;
    begin
      rotary_cw = 1; wait_cycles(1); rotary_cw = 0; wait_cycles(1);
      button_pulse = 7'b1000000; wait_cycles(1); button_pulse = 0;
      wait_cycles(1);
      if (state !== 1 || remaining_seconds !== 1) $fatal(1, "start one second");
    end
  endtask

  initial begin
    wait_cycles(3);
    reset = 0;
    wait_cycles(3);
    scenario = 1;
    start_one_second();
    wait (state == 3);
    @(negedge clk);
    if (remaining_seconds !== 0 || run_enable || !timeout_pulse)
      $fatal(1, "controller to display DONE entry");
    wait (state == 0);
    wait_cycles(2);
    if (last_done_ticks != 3000 || completed_alerts != 1 || alert_done)
      $fatal(1, "three-second display completion feedback: ticks=%0d", last_done_ticks);

    scenario = 2;
    start_one_second();
    wait (alert_done);
    @(negedge clk);
    button_pulse = 7'b0010000;
    wait_cycles(1);
    if (state !== 3 || !alert_done) $fatal(1, "door priority lost completion");
    button_pulse = 0;
    wait_cycles(2);
    if (state !== 0 || alert_done || completed_alerts != 2)
      $fatal(1, "completion not accepted after door event");

    scenario = 3;
    start_one_second();
    wait (state == 3);
    wait_cycles(2500);
    button_pulse = 7'b0001000; wait_cycles(1); button_pulse = 0;
    wait_cycles(16000);
    if (state !== 0 || alert_done || completed_alerts != 2)
      $fatal(1, "cancelled alert generated stale completion");

    scenario = 4;
    start_one_second();
    wait (state == 3);
    wait_cycles(2500);
    button_pulse = 7'b1000000; wait_cycles(1); button_pulse = 0;
    wait_cycles(16000);
    if (state !== 0 || alert_done || completed_alerts != 2)
      $fatal(1, "KEY acknowledged alert generated stale completion");
    $display("PASS: controller/display feedback, exactly 3000 DONE ticks, door-event completion retry, cancel and KEY abort without stale completion");
    $finish;
  end
  initial begin
    #1_200_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

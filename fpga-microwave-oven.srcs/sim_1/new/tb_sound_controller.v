`timescale 1ns / 1ps

module tb_sound_controller;
  reg clk = 0;
  reg reset = 1;
  reg tick_1ms = 0;
  reg [6:0] buttons = 0;
  reg open_event = 0, close_event = 0;
  reg alert_active = 0, alert_on = 0;
  wire buzzer, sound_active, busy, overflow;
  wire passive_buzzer, passive_active;
  reg carrier_enable = 0;
  wire carrier_buzzer;
  reg [6:0] min_buttons = 0;
  wire min_buzzer, min_active, min_busy;
  reg [3:0] scenario = 0;
  integer beep_starts = 0, beep_ticks = 0, last_beep_ticks = 0;
  reg [1:0] prev_phase = 0;
  reg check_full_beeps = 1;
  integer saved_starts, i;
  integer saved_effect_ms;

  sound_controller dut (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .button_pulse(buttons),
      .door_open_event(open_event),
      .door_close_event(close_event),
      .alert_active(alert_active),
      .alert_on(alert_on),
      .buzzer(buzzer),
      .sound_active(sound_active),
      .busy(busy),
      .queue_overflow(overflow)
  );

  sound_controller #(
      .PassiveBuzzer(1),
      .ToneHalfClocks(2)
  ) u_passive (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .button_pulse(buttons),
      .door_open_event(open_event),
      .door_close_event(close_event),
      .alert_active(alert_active),
      .alert_on(alert_on),
      .buzzer(passive_buzzer),
      .sound_active(passive_active),
      .busy(),
      .queue_overflow()
  );

  sound_controller #(
      .PassiveBuzzer(1)
  ) u_carrier (
      .clk(clk),
      .reset(reset),
      .tick_1ms(1'b0),
      .button_pulse(7'b0),
      .door_open_event(1'b0),
      .door_close_event(1'b0),
      .alert_active(carrier_enable),
      .alert_on(carrier_enable),
      .buzzer(carrier_buzzer),
      .sound_active(),
      .busy(),
      .queue_overflow()
  );

  sound_controller #(
      .BeepOnMs(1),
      .BeepGapMs(1),
      .DoorStepMs(1),
      .ToneHalfClocks(1)
  ) u_min (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .button_pulse(min_buttons),
      .door_open_event(1'b0),
      .door_close_event(1'b0),
      .alert_active(1'b0),
      .alert_on(1'b0),
      .buzzer(min_buzzer),
      .sound_active(min_active),
      .busy(min_busy),
      .queue_overflow()
  );

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (reset) begin
      prev_phase = 0;
      beep_ticks = 0;
    end else begin
      if (dut.r_beep_phase == 1 && prev_phase != 1) begin
        beep_starts = beep_starts + 1;
        beep_ticks = 0;
      end
      if (dut.r_beep_phase == 1 && tick_1ms) beep_ticks = beep_ticks + 1;
      if (dut.r_beep_phase != 1 && prev_phase == 1) begin
        last_beep_ticks = beep_ticks;
        if (check_full_beeps && last_beep_ticks != 40) $fatal(1, "BEEP ON duration");
      end
      prev_phase = dut.r_beep_phase;
    end
    #2;
    if (buzzer !== sound_active || passive_active !== sound_active)
      $fatal(1, "active/passive envelope mismatch");
    if (!sound_active && passive_buzzer) $fatal(1, "passive output outside envelope");
    if (dut.r_effect_count > 4 || dut.r_pending_beeps > 15) $fatal(1, "queue bounds");
  end

  task cycle;
    begin
      @(posedge clk);
      #1;
      @(negedge clk);
    end
  endtask

  task advance_ms;
    input integer count;
    integer n;
    begin
      for (n = 0; n < count; n = n + 1) begin
        tick_1ms = 1;
        cycle();
        tick_1ms = 0;
        repeat (3) cycle();
      end
    end
  endtask

  task press;
    input [6:0] mask;
    begin
      buttons = mask;
      cycle();
      buttons = 0;
      repeat (3) cycle();
    end
  endtask

  task request_open;
    begin
      open_event = 1;
      cycle();
      open_event = 0;
      repeat (3) cycle();
    end
  endtask

  task request_close;
    begin
      close_event = 1;
      cycle();
      close_event = 0;
      repeat (3) cycle();
    end
  endtask

  initial begin
    repeat (3) @(negedge clk);
    reset = 0;
    repeat (2) cycle();
    if (buzzer || busy || overflow) $fatal(1, "reset idle");

    scenario = 1;
    press(7'b0000001);
    if (!buzzer) $fatal(1, "single button BEEP");
    advance_ms(39);
    if (!buzzer) $fatal(1, "BEEP ended early");
    advance_ms(1);
    if (buzzer || dut.r_beep_phase != 2) $fatal(1, "BEEP gap missing");
    advance_ms(19);
    if (dut.r_beep_phase != 2) $fatal(1, "BEEP gap early");
    advance_ms(1);
    repeat (2) cycle();
    if (busy || last_beep_ticks != 40) $fatal(1, "BEEP completion");

    scenario = 2;
    saved_starts = beep_starts;
    press(7'b1110111);  // 취소를 제외한 6개 동시 입력.
    advance_ms(360);
    repeat (2) cycle();
    if (beep_starts != saved_starts + 6 || busy || overflow)
      $fatal(1, "simultaneous button events not preserved");

    scenario = 3;
    request_open();
    if (!buzzer || dut.r_effect_close) $fatal(1, "open effect start");
    advance_ms(69);
    if (!buzzer) $fatal(1, "open first segment early");
    advance_ms(1);
    if (buzzer) $fatal(1, "open effect gap");
    advance_ms(70);
    if (!buzzer) $fatal(1, "open second segment");
    advance_ms(70);
    if (busy) $fatal(1, "open effect completion");
    request_close();
    advance_ms(209);
    if (!buzzer || !dut.r_effect_close) $fatal(1, "close long effect");
    advance_ms(1);
    if (busy) $fatal(1, "close effect completion");

    scenario = 4;
    request_open();
    advance_ms(5);
    saved_effect_ms = dut.r_effect_ms;
    press(7'b0000001);
    advance_ms(60);
    if (dut.r_effect_ms != saved_effect_ms || dut.r_effect_step != 0)
      $fatal(1, "BEEP did not preserve interrupted effect");
    advance_ms(205);
    if (busy) $fatal(1, "interrupted effect did not finish");

    scenario = 5;
    press(7'b0000001);
    request_open();
    request_close();
    advance_ms(60);
    if (!dut.r_effect_active || dut.r_effect_close) $fatal(1, "effect FIFO order first");
    advance_ms(210);
    if (!dut.r_effect_active || !dut.r_effect_close) $fatal(1, "effect FIFO order second");
    advance_ms(210);
    if (busy) $fatal(1, "effect FIFO drain");

    scenario = 6;
    alert_active = 1;
    alert_on = 1;
    #1;
    if (!buzzer) $fatal(1, "shared alert ON");
    alert_on = 0;
    #1;
    if (buzzer || !busy) $fatal(1, "shared alert OFF");
    press(7'b0000001);
    if (!buzzer) $fatal(1, "BEEP priority during alert OFF");
    advance_ms(60);
    if (buzzer) $fatal(1, "BEEP did not return to alert OFF");
    alert_active = 0;

    scenario = 7;
    press(7'b1110111);
    press(7'b1110111);
    press(7'b1110111);
    if (!overflow || dut.r_pending_beeps != 15) $fatal(1, "BEEP queue overflow not reported");
    check_full_beeps = 0;
    saved_starts = beep_starts;
    buttons = 7'b1111111;
    open_event = 1;
    close_event = 1;
    cycle();
    buttons = 0;
    open_event = 0;
    close_event = 0;
    repeat (3) cycle();
    if (overflow || dut.r_effect_count || dut.r_effect_active)
      $fatal(1, "cancel did not discard old work");
    advance_ms(60);
    repeat (2) cycle();
    if (busy || beep_starts != saved_starts + 1) $fatal(1, "cancel must leave one BEEP");
    check_full_beeps = 1;
    press(7'b0000001);
    request_open();
    request_close();
    request_open();
    request_close();
    request_open();
    if (!overflow || dut.r_effect_count != 4) $fatal(1, "effect FIFO overflow not reported");
    check_full_beeps = 0;
    #2 reset = 1;
    #1;
    if (buzzer || passive_buzzer || busy || overflow) $fatal(1, "asynchronous reset during sound");
    cycle();
    reset = 0;
    repeat (2) cycle();
    check_full_beeps = 1;

    scenario = 8;
    saved_starts = beep_starts;
    press(7'b0000001);
    press(7'b0000001);
    advance_ms(59);
    tick_1ms = 1;
    cycle();
    tick_1ms = 0;
    if (dut.r_beep_phase != 0 || dut.r_pending_beeps != 1)
      $fatal(1, "BEEP simultaneous pop/push setup");
    buttons = 7'b0000001;
    cycle();
    buttons = 0;
    repeat (3) cycle();
    if (dut.r_beep_phase != 1 || dut.r_pending_beeps != 1)
      $fatal(1, "BEEP simultaneous pop/push lost request");
    advance_ms(120);
    repeat (2) cycle();
    if (busy || beep_starts != saved_starts + 3) $fatal(1, "BEEP simultaneous pop/push drain");

    press(7'b0000001);
    request_open();
    request_close();
    advance_ms(59);
    tick_1ms = 1;
    cycle();
    tick_1ms = 0;
    close_event = 1;
    cycle();
    close_event = 0;
    repeat (3) cycle();
    if (!dut.r_effect_active || dut.r_effect_close || dut.r_effect_count != 2 ||
        dut.r_effect_queue[1:0] !== 2'b11)
      $fatal(1, "effect FIFO simultaneous pop/push order");
    advance_ms(630);
    if (busy || overflow) $fatal(1, "effect FIFO simultaneous pop/push drain");

    scenario = 9;
    carrier_enable = 1;
    for (i = 1; i <= 75_000; i = i + 1) begin
      cycle();
      if (carrier_buzzer !== ((i / 25_000) % 2)) $fatal(1, "default 2 kHz half-period: %0d", i);
    end
    carrier_enable = 0;
    #1;
    if (carrier_buzzer) $fatal(1, "carrier mute must be immediate");

    scenario = 10;
    min_buttons = 1;
    cycle();
    min_buttons = 0;
    repeat (3) cycle();
    if (!min_active) $fatal(1, "minimum parameter BEEP start");
    advance_ms(1);
    if (min_active) $fatal(1, "minimum ON boundary");
    advance_ms(1);
    if (min_busy) $fatal(1, "minimum gap boundary");
    $display(
        "PASS: BEEP duration/gaps, simultaneous events and queue pop/push, door rhythms/FIFO, preemption/resume, alert envelope, cancel/reset, overflow, active/passive modes, default 2 kHz, minimum parameters");
    $finish;
  end
  initial begin
    #2_000_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

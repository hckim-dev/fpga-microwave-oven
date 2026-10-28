`timescale 1ns / 1ps

module tb_door_controller;
  localparam [2:0] UNKNOWN = 0, CLOSED = 1, OPENING = 2, OPEN = 3, CLOSING = 4;
  reg clk = 0, reset = 1, tick_1ms = 0;
  reg open_request = 0, close_request = 0, cancel = 0, applied = 0;
  wire [2:0] state;
  wire door_closed, servo_enable, target_open, open_event, close_event;
  reg min_close = 0, min_applied = 0;
  wire [2:0] min_state;
  wire min_closed, min_enable, min_target, min_open_event, min_close_event;
  reg [3:0] scenario = 0;

  door_controller dut (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .open_request(open_request),
      .close_request(close_request),
      .cancel(cancel),
      .command_applied(applied),
      .state(state),
      .door_closed(door_closed),
      .servo_enable(servo_enable),
      .target_open(target_open),
      .open_event(open_event),
      .close_event(close_event)
  );

  door_controller #(
      .MoveTimeMs(1)
  ) u_min (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .open_request(1'b0),
      .close_request(min_close),
      .cancel(1'b0),
      .command_applied(min_applied),
      .state(min_state),
      .door_closed(min_closed),
      .servo_enable(min_enable),
      .target_open(min_target),
      .open_event(min_open_event),
      .close_event(min_close_event)
  );

  always #5 clk = ~clk;
  always @(posedge clk) begin
    #2;
    if (open_event && close_event) $fatal(1, "both door requests accepted");
    if (door_closed && (state != CLOSED || reset)) $fatal(1, "closed invariant");
    if (state == UNKNOWN && servo_enable) $fatal(1, "UNKNOWN must disable servo");
    if (dut.r_move_count >= 500) $fatal(1, "move counter bounds");
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
        cycle();
      end
    end
  endtask

  task request;
    input want_open, want_close;
    begin
      open_request  = want_open;
      close_request = want_close;
      cycle();
      open_request  = 0;
      close_request = 0;
    end
  endtask

  task acknowledge;
    begin
      applied = 1;
      cycle();
      applied = 0;
      cycle();
    end
  endtask

  initial begin
    repeat (3) @(negedge clk);
    reset = 0;
    cycle();
    scenario = 1;
    if (state !== UNKNOWN || servo_enable || door_closed) $fatal(1, "initial unknown");
    request(0, 1);
    if (state !== CLOSING || !close_event || !servo_enable || target_open)
      $fatal(1, "close acceptance");
    advance_ms(1000);
    if (state !== CLOSING || dut.r_move_count != 0 || close_event)
      $fatal(1, "move wait began before servo applied command");
    applied  = 1;
    tick_1ms = 1;
    cycle();
    applied  = 0;
    tick_1ms = 0;
    if (dut.r_move_count != 0) $fatal(1, "apply edge consumed move tick");
    advance_ms(499);
    if (state !== CLOSING || door_closed) $fatal(1, "close finished early");
    advance_ms(1);
    if (state !== CLOSED || !door_closed || !servo_enable) $fatal(1, "close completion/hold");
    request(0, 1);
    if (state !== CLOSED || close_event) $fatal(1, "duplicate close accepted");

    scenario = 2;
    request(1, 1);
    if (state !== OPENING || !open_event || close_event || door_closed || !target_open)
      $fatal(1, "open priority");
    applied = 1;
    close_request = 1;
    cycle();
    applied = 0;
    close_request = 0;
    if (dut.r_waiting_command || close_event) $fatal(1, "ignored request swallowed acknowledgment");
    open_request  = 1;
    close_request = 1;
    advance_ms(499);
    open_request  = 0;
    close_request = 0;
    if (state !== OPENING || open_event || close_event)
      $fatal(1, "moving requests restarted/blocked timer");
    tick_1ms = 1;
    cancel   = 1;
    #1;
    if (servo_enable) $fatal(1, "cancel must immediately disable moving servo");
    cycle();
    tick_1ms = 0;
    cancel   = 0;
    if (state !== UNKNOWN || servo_enable || open_event || close_event)
      $fatal(1, "cancel over movement completion");

    scenario = 3;
    request(0, 1);
    acknowledge();
    advance_ms(500);
    if (state !== CLOSED) $fatal(1, "recover unknown by closing");
    request(1, 0);
    acknowledge();
    advance_ms(500);
    if (state !== OPEN || !servo_enable || !target_open || door_closed)
      $fatal(1, "open completion/hold");
    request(1, 1);
    if (state !== OPEN || open_event || close_event)
      $fatal(1, "duplicate open suppresses simultaneous close");
    cancel = 1;
    cycle();
    cancel = 0;
    if (state !== OPEN || !servo_enable || !target_open)
      $fatal(1, "cancel stable position must hold");
    request(0, 1);
    cancel = 1;
    open_request = 1;
    close_request = 1;
    cycle();
    cancel = 0;
    open_request = 0;
    close_request = 0;
    if (state !== UNKNOWN || servo_enable || open_event || close_event)
      $fatal(1, "cancel while waiting for servo acknowledgment");

    scenario  = 4;
    min_close = 1;
    cycle();
    min_close = 0;
    if (!min_close_event || min_state !== CLOSING) $fatal(1, "minimum close request");
    min_applied = 1;
    cycle();
    min_applied = 0;
    if (min_closed) $fatal(1, "minimum move wait skipped");
    advance_ms(1);
    if (!min_closed || min_state !== CLOSED || !min_enable || min_target || min_open_event)
      $fatal(1, "minimum move counter");

    scenario = 5;
    request(1, 0);
    acknowledge();
    advance_ms(5);
    #2 reset = 1;
    #1;
    if (state !== UNKNOWN || servo_enable || door_closed || open_event || close_event)
      $fatal(1, "async reset during movement");
    $display(
        "PASS: unknown startup, accepted events, command acknowledgment before 500 ticks, duplicate/moving requests, open priority, cancel/reset, inferred position hold, minimum wait");
    $finish;
  end
  initial begin
    #200_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

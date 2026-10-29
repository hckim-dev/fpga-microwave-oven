`timescale 1ns / 1ps

module tb_control_lock;
  reg clk = 0, reset = 1;
  reg lock_switch = 0, inputs_ready = 0;
  reg [1:0] cook_state = 0;
  reg [6:0] buttons = 0;
  reg cw = 0, ccw = 0;
  wire locked, min_locked, control_cw, control_ccw;
  wire [6:0] control_buttons;
  reg  [6:0] expected;
  integer state_index, mask, scenario = 0;

  control_lock #(
      .DebounceCount(3)
  ) dut (
      .clk(clk),
      .reset(reset),
      .lock_switch(lock_switch),
      .inputs_ready(inputs_ready),
      .cook_state(cook_state),
      .button_pulse(buttons),
      .rotary_cw(cw),
      .rotary_ccw(ccw),
      .locked(locked),
      .control_buttons(control_buttons),
      .control_cw(control_cw),
      .control_ccw(control_ccw)
  );

  control_lock #(
      .DebounceCount(1)
  ) u_min (
      .clk(clk),
      .reset(reset),
      .lock_switch(lock_switch),
      .inputs_ready(inputs_ready),
      .cook_state(cook_state),
      .button_pulse(buttons),
      .rotary_cw(cw),
      .rotary_ccw(ccw),
      .locked(min_locked),
      .control_buttons(),
      .control_cw(),
      .control_ccw()
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

  task check_states;
    input want_locked;
    begin
      for (state_index = 0; state_index < 4; state_index = state_index + 1) begin
        cook_state = state_index;
        for (mask = 0; mask < 128; mask = mask + 1) begin
          buttons  = mask;
          expected = buttons;
          if (want_locked) begin
            expected[2:0] = 0;
            if ((state_index == 0) || (state_index == 2)) expected[6] = 0;
          end
          #1;
          check(locked == want_locked && control_buttons === expected,
                "all button combinations in all cooking states");
        end
      end
      buttons = 0;
      cw = 1;
      ccw = 0;
      #1;
      check(control_cw == !want_locked && !control_ccw, "CW permission");
      cw  = 0;
      ccw = 1;
      #1;
      check(control_ccw == !want_locked && !control_cw, "CCW permission");
      cw  = 0;
      ccw = 0;
      @(negedge clk);
    end
  endtask

  initial begin
    cycles(3);
    reset = 0;
    cycles(8);
    scenario = 1;
    check(locked && min_locked, "startup blocks settings until frontend ready");
    check_states(1);
    inputs_ready = 1;
    cycles(1);
    check_states(0);

    scenario = 2;
    lock_switch = 1;
    cycles(1);
    lock_switch = 0;
    cycles(8);
    check(!locked, "short switch noise rejected");
    lock_switch = 1;
    cycles(2);
    check(!locked && !min_locked, "two synchronization clocks before assertion");
    cycles(1);
    check(!locked && min_locked, "minimum debounce boundary");
    cycles(1);
    check(!locked, "three-sample filter must not finish early");
    cycles(1);
    check(locked, "lock assertion boundary");
    check_states(1);

    scenario = 3;
    lock_switch = 0;
    cycles(1);
    lock_switch = 1;
    cycles(8);
    check(locked, "short unlock noise rejected");
    lock_switch = 0;
    cycles(4);
    check(locked, "unlock not early");
    cycles(1);
    cook_state = 0;
    buttons = 7'b1000111;
    cw = 1;
    #1;
    check(!locked && control_buttons == 0 && !control_cw, "unlock boundary suppresses settings");
    cycles(1);
    buttons = 0;
    cw = 0;
    check_states(0);

    scenario = 4;
    reset = 1;
    inputs_ready = 0;
    lock_switch = 1;
    cycles(3);
    reset = 0;
    cycles(8);
    inputs_ready = 1;
    check_states(1);
    reset = 1;
    inputs_ready = 0;
    cycles(2);
    check(locked, "frontend not ready after reset must hold the lock");
    $display(
        "PASS: control lock startup, 128 masks in four states, stop/door/pause/ack permissions, rotary filtering, switch bounce, exact/minimum debounce, reset with SW0 high");
    $finish;
  end

  initial begin
    #100_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

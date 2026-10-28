`timescale 1ns / 1ps

module tb_servo_controller;
  reg clk = 0, reset = 1;
  reg enable = 0, target_open = 0;
  wire servo_pwm, applied, min_pwm, min_applied;
  reg default_reset = 1, default_target = 0;
  wire default_pwm, default_applied;
  reg [3:0] scenario = 0;
  integer scaled_pos = -1, min_pos = -1;
  reg scaled_target = 0, min_target = 0;
  reg scaled_ack, min_ack;
  integer default_cycles = 0, default_highs = 0, default_acks = 0;
  integer default_pos;
  reg default_latched_target = 0;
  reg default_ack_expected;
  reg default_complete = 0;

  servo_controller #(
      .FrameClocks(20),
      .ClosedPulseClocks(3),
      .OpenPulseClocks(5)
  ) dut (
      .clk(clk),
      .reset(reset),
      .enable(enable),
      .target_open(target_open),
      .servo_pwm(servo_pwm),
      .command_applied(applied)
  );

  servo_controller #(
      .FrameClocks(4),
      .ClosedPulseClocks(1),
      .OpenPulseClocks(2)
  ) u_min (
      .clk(clk),
      .reset(reset),
      .enable(enable),
      .target_open(target_open),
      .servo_pwm(min_pwm),
      .command_applied(min_applied)
  );

  servo_controller u_default (
      .clk(clk),
      .reset(default_reset),
      .enable(1'b1),
      .target_open(default_target),
      .servo_pwm(default_pwm),
      .command_applied(default_applied)
  );

  always #5 clk = ~clk;

  // 사양의 프레임 위치로 출력과 적용 통지를 매 클럭 대조.
  always @(posedge clk) begin
    if (reset || !enable) begin
      scaled_pos = -1;
      min_pos = -1;
      scaled_ack = 0;
      min_ack = 0;
    end else begin
      scaled_ack = 0;
      min_ack = 0;
      scaled_pos = (scaled_pos + 1) % 20;
      min_pos = (min_pos + 1) % 4;
      if (scaled_pos == 0) begin
        scaled_ack = !dut.r_started || (scaled_target != target_open);
        scaled_target = target_open;
      end
      if (min_pos == 0) begin
        min_ack = !u_min.r_started || (min_target != target_open);
        min_target = target_open;
      end
    end
    #1;
    if (reset || !enable) begin
      if (servo_pwm || applied || min_pwm || min_applied) $fatal(1, "disabled servo output");
    end else begin
      if (servo_pwm !== (scaled_pos < (scaled_target ? 5 : 3)) || applied !== scaled_ack)
        $fatal(1, "scaled frame/width/apply at phase %0d", scaled_pos);
      if (min_pwm !== (min_pos < (min_target ? 2 : 1)) || min_applied !== min_ack)
        $fatal(1, "minimum frame/width/apply");
    end
  end

  always @(posedge clk) begin
    if (default_reset) begin
      default_cycles = 0;
      default_highs = 0;
      default_acks = 0;
      default_latched_target = 0;
    end else if (!default_complete) begin
      default_pos = default_cycles % 2_000_000;
      default_ack_expected = 0;
      if (default_pos == 0) begin
        default_ack_expected = (default_cycles == 0) || (default_latched_target != default_target);
        default_latched_target = default_target;
      end
      #1;
      if (default_pwm !== (default_pos < (default_latched_target ? 150_000 : 100_000)))
        $fatal(1, "default 20 ms frame/pulse at clock %0d", default_cycles);
      if (default_applied !== default_ack_expected) $fatal(1, "default command apply");
      if (default_pwm) default_highs = default_highs + 1;
      if (default_applied) default_acks = default_acks + 1;
      default_cycles = default_cycles + 1;
      if (default_cycles == 4_000_000) default_complete = 1;
    end
  end

  task cycle;
    begin
      @(posedge clk);
      #2;
      @(negedge clk);
    end
  endtask

  initial begin
    repeat (3) @(negedge clk);
    default_reset = 0;
    repeat (10) @(negedge clk);
    // HIGH 도중 변경해도 첫 프레임은 1 ms, 다음 프레임은 1.5 ms.
    default_target = 1;
  end

  initial begin
    repeat (3) @(negedge clk);
    reset = 0;
    scenario = 1;
    repeat (5) cycle();
    enable = 1;
    cycle();
    if (!servo_pwm || !applied) $fatal(1, "first enabled frame");
    cycle();
    target_open = 1;
    repeat (45) cycle();
    scenario = 2;
    target_open = 0;
    repeat (45) cycle();
    // 현재 프레임 내에서 바뀌었다가 원래 목표로 돌아오면 중간 명령은 적용하지 않음.
    target_open = 1;
    cycle();
    target_open = 0;
    repeat (40) cycle();
    scenario = 3;
    enable   = 0;
    #1;
    if (servo_pwm || min_pwm) $fatal(1, "enable must immediately mute");
    repeat (2) cycle();
    enable = 1;
    target_open = 1;
    cycle();
    if (!servo_pwm || !applied) $fatal(1, "reenable must start a new frame");
    scenario = 4;
    #2 reset = 1;
    #1;
    if (servo_pwm || applied || min_pwm || min_applied) $fatal(1, "async reset during HIGH");
    cycle();
    reset = 0;
    repeat (30) cycle();
    enable   = 0;
    scenario = 5;
    wait (default_complete);
    @(negedge clk);
    if (default_highs != 250_000 || default_acks != 2) $fatal(1, "default complete frame totals");
    $display(
        "PASS: default 100 MHz/20 ms frames, 1 ms/1.5 ms widths, frame-boundary target apply, one-shot acknowledgment, disable/reset/restart, minimum counters");
    $finish;
  end
  initial begin
    #45_000_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

`timescale 1ns / 1ps

module tb_timebase;
  reg clk = 0;
  reg reset = 1;
  reg noisy_btn = 0;
  wire tick, clean_btn;
  integer cycles = 0;
  integer ticks = 0;
  wire startup_reset;

  // 외부 Reset을 누르지 않아도 구성 직후 두 클럭 동안 초기화.
  reset_synchronizer u_startup_reset (
      .clk(clk),
      .reset(1'b0),
      .synced_reset(startup_reset)
  );

  tick_generator u_tick (
      .clk(clk),
      .reset(reset),
      .tick(tick)
  );

  btn_debouncer u_debounce (
      .clk(clk),
      .reset(reset),
      .noisy_btn(noisy_btn),
      .clean_btn(clean_btn)
  );

  always #5 clk = ~clk;

  initial begin
    #1;
    if (startup_reset !== 1) $fatal(1, "power-on reset assertion");
    @(posedge clk);
    #1;
    if (startup_reset !== 1) $fatal(1, "power-on first clock");
    @(posedge clk);
    #1;
    if (startup_reset !== 0) $fatal(1, "power-on second clock");
  end

  initial begin
    repeat (3) @(negedge clk);
    reset = 0;
    noisy_btn = 1;
    // 기본 100 MHz / 1 ms tick, 10 ms debounce를 축소 없이 검사.
    repeat (1_000_002) begin
      @(posedge clk);
      #1;
      cycles = cycles + 1;
      if (tick !== ((cycles % 100_000) == 0)) $fatal(1, "default tick boundary: %0d", cycles);
      if (tick) ticks = ticks + 1;
      if (clean_btn !== (cycles == 1_000_002)) $fatal(1, "default debounce boundary: %0d", cycles);
    end
    if (ticks != 10) $fatal(1, "default tick count");
    $display(
        "PASS: default 100 MHz, exact 100000-clock tick and 1000000-clock stable debounce after two synchronizer clocks");
    $finish;
  end

  initial begin
    #11_000_000;
    $fatal(1, "watchdog timeout");
  end
endmodule

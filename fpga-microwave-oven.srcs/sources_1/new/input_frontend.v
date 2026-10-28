`timescale 1ns / 1ps

module input_frontend #(
    parameter integer TickCount = 100_000,
    parameter integer ButtonDebounceCount = 1_000_000,
    parameter integer RotaryDebounceCount = 200_000,
    parameter integer StepsPerDetent = 4,
    parameter [6:0] ButtonActiveLow = 7'b1000000
) (
    input wire clk,
    input wire reset,
    // [0] 분/초, [1] 속도+, [2] 속도-, [3] 취소,
    // [4] 열기(J3), [5] 닫기(L3), [6] EC11 KEY.
    input wire [6:0] button_raw,
    input wire [1:0] rotary_ab_raw,
    output wire synced_reset,
    output wire tick_1ms,
    output wire ready,
    output wire [6:0] button_down,
    output wire [6:0] button_pulse,
    output wire rotary_cw,
    output wire rotary_ccw,
    output wire rotary_invalid
);
  localparam integer SettleCount =
      ((ButtonDebounceCount > RotaryDebounceCount) ?
       ButtonDebounceCount : RotaryDebounceCount) + 4;
  localparam integer SettleWidth = $clog2(SettleCount + 1);
  reg [SettleWidth-1:0] r_settle_count;
  reg [6:0] r_prev_button;
  wire [6:0] w_clean_button;
  wire [1:0] w_clean_ab;
  wire w_decoder_reset;

  reset_synchronizer u_reset (
      .clk(clk),
      .reset(reset),
      .synced_reset(synced_reset)
  );
  tick_generator #(
      .TickCount(TickCount)
  ) u_tick (
      .clk  (clk),
      .reset(synced_reset),
      .tick (tick_1ms)
  );

  genvar i;
  generate
    for (i = 0; i < 7; i = i + 1) begin : g_button
      btn_debouncer #(
          .DebounceCount(ButtonDebounceCount)
      ) u_debounce (
          .clk(clk),
          .reset(synced_reset),
          .noisy_btn(button_raw[i] ^ ButtonActiveLow[i]),
          .clean_btn(w_clean_button[i])
      );
    end
    for (i = 0; i < 2; i = i + 1) begin : g_rotary
      btn_debouncer #(
          .DebounceCount(RotaryDebounceCount)
      ) u_debounce (
          .clk(clk),
          .reset(synced_reset),
          .noisy_btn(rotary_ab_raw[i]),
          .clean_btn(w_clean_ab[i])
      );
    end
  endgenerate

  // 기동 시 눌린 버튼과 엔코더 초기 위상을 새 이벤트로 세지 않음.
  always @(posedge clk or posedge synced_reset) begin
    if (synced_reset) begin
      r_settle_count <= 0;
      r_prev_button  <= 0;
    end else begin
      if (!ready) r_settle_count <= r_settle_count + 1'b1;
      r_prev_button <= w_clean_button;
    end
  end

  assign ready = !synced_reset && (r_settle_count == SettleCount);
  assign button_down = ready ? w_clean_button : 7'b0;
  assign button_pulse = ready ? (w_clean_button & ~r_prev_button) : 7'b0;
  assign w_decoder_reset = synced_reset || !ready;

  rotary_decoder #(
      .StepsPerDetent(StepsPerDetent)
  ) u_rotary (
      .clk(clk),
      .reset(w_decoder_reset),
      .ab(w_clean_ab),
      .cw_pulse(rotary_cw),
      .ccw_pulse(rotary_ccw),
      .invalid_pulse(rotary_invalid)
  );
endmodule

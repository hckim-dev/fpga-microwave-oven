`timescale 1ns / 1ps

module control_lock #(
    parameter integer DebounceCount = 1_000_000
) (
    input wire clk,
    input wire reset,
    input wire lock_switch,
    input wire inputs_ready,
    input wire [1:0] cook_state,
    input wire [6:0] button_pulse,
    input wire rotary_cw,
    input wire rotary_ccw,
    output wire locked,
    output wire [6:0] control_buttons,
    output wire control_cw,
    output wire control_ccw
);
  localparam [1:0] RUN = 2'd1, DONE = 2'd3;
  wire w_clean_lock;
  reg r_was_locked;
  wire w_settings_allowed = !locked && !r_was_locked;

  btn_debouncer #(
      .DebounceCount(DebounceCount)
  ) u_switch (
      .clk(clk),
      .reset(reset),
      .noisy_btn(lock_switch),
      .clean_btn(w_clean_lock)
  );

  // 입력 안정화 전에는 잠금으로 취급해 SW0를 올린 채 기동해도 시작을 막는다.
  assign locked = !inputs_ready || w_clean_lock;
  // 해제와 같은 클럭의 누름을 시작으로 해석하지 않도록 한 클럭 더 차단한다.
  always @(posedge clk or posedge reset) begin
    if (reset) r_was_locked <= 1;
    else r_was_locked <= locked;
  end

  assign control_buttons[2:0] = w_settings_allowed ? button_pulse[2:0] : 3'b000;
  // 취소·문 개폐는 항상 허용하고 KEY의 일시정지·종료 확인도 유지한다.
  assign control_buttons[5:3] = button_pulse[5:3];
  assign control_buttons[6] = button_pulse[6] &&
                             (w_settings_allowed || (cook_state == RUN) || (cook_state == DONE));
  assign control_cw = rotary_cw && w_settings_allowed;
  assign control_ccw = rotary_ccw && w_settings_allowed;
endmodule

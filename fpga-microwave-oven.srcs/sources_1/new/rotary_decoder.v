`timescale 1ns / 1ps

module rotary_decoder #(
    parameter integer StepsPerDetent = 4
) (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [1:0] ab,
    output reg cw_pulse,
    output reg ccw_pulse,
    output reg invalid_pulse
);
  localparam integer AccWidth = $clog2(StepsPerDetent + 1) + 1;
  reg [1:0] r_prev_ab;
  reg r_seeded;
  reg signed [AccWidth-1:0] r_steps;
  reg signed [1:0] w_delta;
  reg w_invalid;

  // {S1,S2}: CW 00 -> 10 -> 11 -> 01 -> 00.
  always @(*) begin
    w_delta = 0;
    w_invalid = 0;
    case ({r_prev_ab, ab})
      4'b0010, 4'b1011, 4'b1101, 4'b0100: w_delta = 1;
      4'b0001, 4'b0111, 4'b1110, 4'b1000: w_delta = -1;
      4'b0000, 4'b0101, 4'b1010, 4'b1111: w_delta = 0;
      default: w_invalid = 1;
    endcase
  end

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_prev_ab <= 0;
      r_seeded <= 0;
      r_steps <= 0;
      cw_pulse <= 0;
      ccw_pulse <= 0;
      invalid_pulse <= 0;
    end else begin
      r_prev_ab <= ab;
      r_seeded <= 1;
      cw_pulse <= 0;
      ccw_pulse <= 0;
      invalid_pulse <= 0;

      // 초기 위상을 먼저 저장하여 Reset 해제 자체를 회전으로 세지 않음.
      if (!enable) begin
        r_seeded <= 0;
        r_steps <= 0;
      end else if (!r_seeded) begin
        r_steps <= 0;
      end else if (w_invalid) begin
        r_steps <= 0;
        invalid_pulse <= 1;
      end else if (w_delta == 1) begin
        if (r_steps == StepsPerDetent - 1) begin
          r_steps <= 0;
          cw_pulse <= 1;
        end else r_steps <= r_steps + 1'b1;
      end else if (w_delta == -1) begin
        if (r_steps == -(StepsPerDetent - 1)) begin
          r_steps <= 0;
          ccw_pulse <= 1;
        end else r_steps <= r_steps - 1'b1;
      end
    end
  end
endmodule

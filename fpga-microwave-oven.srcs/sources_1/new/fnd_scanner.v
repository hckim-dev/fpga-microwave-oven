`timescale 1ns / 1ps

module fnd_scanner (
    input wire clk,
    input wire reset,
    input wire tick_1ms,
    // 낮은 바이트부터 오른쪽 자리. 각 바이트는 {DP,g,f,e,d,c,b,a}.
    input wire [31:0] digit_segments,
    output reg [7:0] seg,
    output reg [3:0] an
);
  reg [1:0] r_digit;
  reg [1:0] r_blank_phase;
  reg [7:0] w_selected;

  always @(*) begin
    case (r_digit)
      0: w_selected = digit_segments[7:0];
      1: w_selected = digit_segments[15:8];
      2: w_selected = digit_segments[23:16];
      3: w_selected = digit_segments[31:24];
      default: w_selected = 8'hFF;
    endcase
  end

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_digit <= 3;
      r_blank_phase <= 0;
      seg <= 8'hFF;
      an <= 4'b1111;
    end else if (tick_1ms) begin
      r_digit <= r_digit + 1'b1;
      r_blank_phase <= 1;
      seg <= 8'hFF;
      an <= 4'b1111;
    end else if (r_blank_phase == 1) begin
      // 모든 자리가 꺼진 상태에서 다음 패턴을 먼저 출력.
      seg <= w_selected;
      r_blank_phase <= 2;
    end else if (r_blank_phase == 2) begin
      an <= ~(4'b0001 << r_digit);
      r_blank_phase <= 0;
    end else if (an != 4'b1111) begin
      seg <= w_selected;
    end
  end
endmodule

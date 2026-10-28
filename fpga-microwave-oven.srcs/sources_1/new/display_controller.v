`timescale 1ns / 1ps

module display_controller #(
    parameter integer BlinkHalfMs = 500,
    parameter integer ScreenPeriodMs = 1000,
    parameter integer CircleStepMs = 100
) (
    input wire clk,
    input wire reset,
    input wire tick_1ms,
    input wire [1:0] state,
    input wire [11:0] remaining_seconds,
    input wire select_minutes,
    output wire [7:0] seg,
    output wire [3:0] an,
    output wire alert_done
);
  localparam [1:0] IDLE = 0, RUN = 1, PAUSED = 2, DONE = 3;
  localparam integer BlinkWidth = (BlinkHalfMs > 1) ? $clog2(BlinkHalfMs) : 1;
  localparam integer ScreenWidth = (ScreenPeriodMs > 1) ? $clog2(ScreenPeriodMs) : 1;
  localparam integer CircleWidth = (CircleStepMs > 1) ? $clog2(CircleStepMs) : 1;

  reg [1:0] r_prev_state;
  reg r_prev_select;
  reg [BlinkWidth-1:0] r_blink_count;
  reg [ScreenWidth-1:0] r_screen_count;
  reg [CircleWidth-1:0] r_circle_count;
  reg r_blink_on;
  reg r_show_circle;
  reg [2:0] r_circle_step;
  reg [2:0] r_done_phase;
  reg r_finished;
  reg [31:0] w_patterns;
  reg [7:0] w_circle_pattern;
  reg [7:0] w_pattern;
  reg [3:0] w_digit;
  reg w_hide_digit;
  integer i;
  wire [5:0] w_minutes = remaining_seconds / 12'd60;
  wire [5:0] w_seconds = remaining_seconds % 12'd60;

  function [7:0] number_segments;
    input [3:0] value;
    begin
      case (value)
        0: number_segments = 8'hC0;
        1: number_segments = 8'hF9;
        2: number_segments = 8'hA4;
        3: number_segments = 8'hB0;
        4: number_segments = 8'h99;
        5: number_segments = 8'h92;
        6: number_segments = 8'h82;
        7: number_segments = 8'hF8;
        8: number_segments = 8'h80;
        9: number_segments = 8'h90;
        default: number_segments = 8'hFF;
      endcase
    end
  endfunction

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_prev_state <= IDLE;
      r_prev_select <= 0;
      r_blink_count <= 0;
      r_screen_count <= 0;
      r_circle_count <= 0;
      r_blink_on <= 1;
      r_show_circle <= 0;
      r_circle_step <= 0;
      r_done_phase <= 0;
      r_finished <= 0;
    end else begin
      r_prev_state <= state;
      r_prev_select <= select_minutes;
      if ((state != r_prev_state) ||
          ((state == IDLE) && (select_minutes != r_prev_select))) begin
        r_blink_count <= 0;
        r_screen_count <= 0;
        r_circle_count <= 0;
        r_blink_on <= 1;
        r_show_circle <= 0;
        r_circle_step <= 0;
        r_done_phase <= 0;
        r_finished <= 0;
      end else if (tick_1ms) begin
        case (state)
          IDLE, PAUSED: begin
            if (r_blink_count == BlinkHalfMs - 1) begin
              r_blink_count <= 0;
              r_blink_on <= !r_blink_on;
            end else r_blink_count <= r_blink_count + 1'b1;
          end
          RUN: begin
            if (r_screen_count == ScreenPeriodMs - 1) begin
              r_screen_count <= 0;
              r_show_circle <= !r_show_circle;
            end else r_screen_count <= r_screen_count + 1'b1;
            if (r_circle_count == CircleStepMs - 1) begin
              r_circle_count <= 0;
              if (r_circle_step == 5) r_circle_step <= 0;
              else r_circle_step <= r_circle_step + 1'b1;
            end else r_circle_count <= r_circle_count + 1'b1;
          end
          DONE: begin
            if (!r_finished) begin
              if (r_blink_count == BlinkHalfMs - 1) begin
                r_blink_count <= 0;
                if (r_done_phase == 5) r_finished <= 1;
                else r_done_phase <= r_done_phase + 1'b1;
              end else r_blink_count <= r_blink_count + 1'b1;
            end
          end
          default: begin
            r_finished <= 0;
          end
        endcase
      end
    end
  end

  // 제어부가 DONE을 떠날 때까지 유지하여 높은 우선순위 이벤트와 겹쳐도 보존.
  assign alert_done = !reset && (state == DONE) && r_finished;

  always @(*) begin
    case (r_circle_step)
      0: w_circle_pattern = 8'hFE;
      1: w_circle_pattern = 8'hFD;
      2: w_circle_pattern = 8'hFB;
      3: w_circle_pattern = 8'hF7;
      4: w_circle_pattern = 8'hEF;
      5: w_circle_pattern = 8'hDF;
      default: w_circle_pattern = 8'hFF;
    endcase

    w_patterns = 32'hFFFFFFFF;
    w_digit = 0;
    w_pattern = 8'hFF;
    w_hide_digit = 0;
    for (i = 0; i < 4; i = i + 1) begin
      case (i)
        0: w_digit = w_seconds % 6'd10;
        1: w_digit = w_seconds / 6'd10;
        2: w_digit = w_minutes % 6'd10;
        3: w_digit = w_minutes / 6'd10;
        default: w_digit = 0;
      endcase
      w_pattern = number_segments(w_digit);
      w_hide_digit = (state == IDLE) && !r_blink_on &&
                     (select_minutes ? (i >= 2) : (i < 2));
      if (w_hide_digit) w_pattern = 8'hFF;
      // 분·초 구분점은 왼쪽에서 두 번째 자리의 DP.
      if ((i == 2) && ((state == IDLE) || (state == RUN) ||
                      ((state == PAUSED) && r_blink_on))) w_pattern[7] = 0;
      if ((state == RUN) && r_show_circle) w_pattern = w_circle_pattern;
      if (state == DONE) begin
        if (!r_done_phase[0] && !r_finished) w_pattern = 8'hC0;
        else w_pattern = 8'hFF;
      end
      w_patterns[i*8 +: 8] = w_pattern;
    end
  end

  fnd_scanner u_scan (
      .clk(clk), .reset(reset), .tick_1ms(tick_1ms), .digit_segments(w_patterns),
      .seg(seg), .an(an)
  );
endmodule

`timescale 1ns / 1ps

module microwave_controller (
    input wire clk,
    input wire reset,
    input wire tick_1ms,
    input wire [6:0] button_pulse,
    input wire rotary_cw,
    input wire rotary_ccw,
    input wire door_closed,
    input wire alert_done,
    output reg [1:0] state,
    output reg [11:0] remaining_seconds,
    output reg select_minutes,
    output wire run_enable,
    output reg timeout_pulse
);
  localparam [1:0] IDLE = 2'd0;
  localparam [1:0] RUN = 2'd1;
  localparam [1:0] PAUSED = 2'd2;
  localparam [1:0] DONE = 2'd3;

  reg [9:0] r_elapsed_ms;
  wire [5:0] w_minutes;
  wire [5:0] w_seconds;
  wire w_cancel = button_pulse[3];
  wire w_open = button_pulse[4];
  wire w_close = button_pulse[5];
  wire w_key = button_pulse[6];
  wire w_expire = tick_1ms && (r_elapsed_ms == 10'd999) && (remaining_seconds == 12'd1);

  assign w_minutes = remaining_seconds / 12'd60;
  assign w_seconds = remaining_seconds % 12'd60;

  // 상태 갱신을 기다리지 않고 정지 요청과 닫힘 조건으로 구동 허가 차단.
  assign run_enable = !reset && (state == RUN) && door_closed &&
                      !w_cancel && !w_open && !w_close && !w_key && !w_expire;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= IDLE;
      remaining_seconds <= 0;
      select_minutes <= 0;
      r_elapsed_ms <= 0;
      timeout_pulse <= 0;
    end else begin
      timeout_pulse <= 0;

      // Reset > 취소 > 열기 > 닫기 > 닫힘 조건 상실 > 만료 > KEY > 설정.
      if (w_cancel) begin
        state <= IDLE;
        remaining_seconds <= 0;
        select_minutes <= 0;
        r_elapsed_ms <= 0;
      end else if (w_open) begin
        if (state == RUN) state <= PAUSED;
      end else if (w_close) begin
        // 닫기 요청과 같은 클럭에는 시작/재개 및 계수를 수행하지 않음.
      end else if ((state == RUN) && !door_closed) begin
        state <= PAUSED;
      end else begin
        case (state)
          IDLE: begin
            r_elapsed_ms <= 0;
            if (w_key) begin
              if (door_closed && (remaining_seconds != 0)) state <= RUN;
            end else if (button_pulse[0]) begin
              select_minutes <= !select_minutes;
            end else if (rotary_cw ^ rotary_ccw) begin
              // 분과 초를 각각 0~59로 포화. 설정 시 자리 간 carry/borrow 없음.
              if (select_minutes) begin
                if (rotary_cw && (w_minutes < 6'd59))
                  remaining_seconds <= remaining_seconds + 12'd60;
                else if (rotary_ccw && (w_minutes != 0))
                  remaining_seconds <= remaining_seconds - 12'd60;
              end else begin
                if (rotary_cw && (w_seconds < 6'd59))
                  remaining_seconds <= remaining_seconds + 12'd1;
                else if (rotary_ccw && (w_seconds != 0))
                  remaining_seconds <= remaining_seconds - 12'd1;
              end
            end
          end

          RUN: begin
            if (w_expire) begin
              state <= DONE;
              remaining_seconds <= 0;
              r_elapsed_ms <= 0;
              timeout_pulse <= 1;
            end else if (w_key) begin
              state <= PAUSED;
            end else if (tick_1ms) begin
              if (r_elapsed_ms == 10'd999) begin
                r_elapsed_ms <= 0;
                remaining_seconds <= remaining_seconds - 12'd1;
              end else r_elapsed_ms <= r_elapsed_ms + 1'b1;
            end
          end

          PAUSED: begin
            if (w_key && door_closed && (remaining_seconds != 0)) state <= RUN;
          end

          DONE: begin
            if (alert_done || w_key) state <= IDLE;
          end

          default: begin
            state <= IDLE;
            remaining_seconds <= 0;
            select_minutes <= 0;
            r_elapsed_ms <= 0;
          end
        endcase
      end
    end
  end
endmodule

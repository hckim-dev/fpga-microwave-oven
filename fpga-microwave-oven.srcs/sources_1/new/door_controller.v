`timescale 1ns / 1ps

module door_controller #(
    parameter integer MoveTimeMs = 500
) (
    input wire clk,
    input wire reset,
    input wire tick_1ms,
    input wire open_request,
    input wire close_request,
    input wire cancel,
    input wire command_applied,
    output reg [2:0] state,
    output wire door_closed,
    output wire servo_enable,
    output wire target_open,
    output reg open_event,
    output reg close_event
);
  localparam [2:0] UNKNOWN = 0, CLOSED = 1, OPENING = 2, OPEN = 3, CLOSING = 4;
  localparam integer MoveWidth = (MoveTimeMs > 1) ? $clog2(MoveTimeMs) : 1;
  reg [MoveWidth-1:0] r_move_count;
  reg r_waiting_command;
  wire w_moving = (state == OPENING) || (state == CLOSING);

  assign door_closed = !reset && (state == CLOSED) && !open_request;
  assign servo_enable = !reset && (state != UNKNOWN) && !(cancel && w_moving);
  assign target_open = (state == OPENING) || (state == OPEN);

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= UNKNOWN;
      r_move_count <= 0;
      r_waiting_command <= 0;
      open_event <= 0;
      close_event <= 0;
    end else begin
      open_event <= 0;
      close_event <= 0;
      if (cancel) begin
        if (w_moving) state <= UNKNOWN;
        r_move_count <= 0;
        r_waiting_command <= 0;
      end else begin
        case (state)
          UNKNOWN, CLOSED, OPEN: begin
            if (open_request) begin
              if (state != OPEN) begin
                state <= OPENING;
                r_move_count <= 0;
                r_waiting_command <= 1;
                open_event <= 1;
              end
            end else if (close_request && (state != CLOSED)) begin
              state <= CLOSING;
              r_move_count <= 0;
              r_waiting_command <= 1;
              close_event <= 1;
            end
          end

          OPENING, CLOSING: begin
            // 이동 중 새 요청은 무시하되 명령 확인/대기 계수는 계속 처리.
            if (r_waiting_command) begin
              if (command_applied) begin
                r_waiting_command <= 0;
                r_move_count <= 0;
              end
            end else if (tick_1ms) begin
              if (r_move_count == MoveTimeMs - 1) begin
                r_move_count <= 0;
                if (state == OPENING) state <= OPEN;
                else state <= CLOSED;
              end else r_move_count <= r_move_count + 1'b1;
            end
          end

          default: begin
            state <= UNKNOWN;
            r_move_count <= 0;
            r_waiting_command <= 0;
          end
        endcase
      end
    end
  end
endmodule

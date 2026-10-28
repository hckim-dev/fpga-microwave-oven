`timescale 1ns / 1ps

module sound_controller #(
    parameter integer BeepOnMs = 40,
    parameter integer BeepGapMs = 20,
    parameter integer DoorStepMs = 70,
    parameter integer PassiveBuzzer = 0,
    parameter integer ToneHalfClocks = 25_000  // 100 MHz에서 2 kHz 반송파
) (
    input wire clk,
    input wire reset,
    input wire tick_1ms,
    input wire [6:0] button_pulse,
    input wire door_open_event,
    input wire door_close_event,
    input wire alert_active,
    input wire alert_on,
    output wire buzzer,
    output wire sound_active,
    output wire busy,
    output reg queue_overflow
);
  localparam [1:0] BEEP_IDLE = 0, BEEP_ON = 1, BEEP_GAP = 2;
  localparam integer BeepLimit = (BeepOnMs > BeepGapMs) ? BeepOnMs : BeepGapMs;
  localparam integer BeepWidth = (BeepLimit > 1) ? $clog2(BeepLimit) : 1;
  localparam integer DoorWidth = (DoorStepMs > 1) ? $clog2(DoorStepMs) : 1;
  localparam integer ToneWidth = (ToneHalfClocks > 1) ? $clog2(ToneHalfClocks) : 1;

  reg [3:0] r_pending_beeps;
  reg [1:0] r_beep_phase;
  reg [BeepWidth-1:0] r_beep_count;
  reg [3:0] r_effect_queue;
  reg [2:0] r_effect_count;
  reg r_effect_active;
  reg r_effect_close;
  reg [1:0] r_effect_step;
  reg [DoorWidth-1:0] r_effect_ms;
  reg [ToneWidth-1:0] r_tone_count;
  reg r_tone;

  integer w_beep_requests;
  integer w_pending_next;
  integer w_effect_count_next;
  integer i;
  reg [3:0] w_effect_queue_next;
  reg w_overflow;
  wire w_cancel = button_pulse[3];
  wire w_beep_pop = (r_beep_phase == BEEP_IDLE) && (r_pending_beeps != 0);
  wire w_beep_busy = (r_beep_phase != BEEP_IDLE) || (r_pending_beeps != 0) || (|button_pulse);
  wire w_effect_pop = !w_beep_busy && !r_effect_active && (r_effect_count != 0);
  wire w_effect_on = r_effect_active && (r_effect_close || (r_effect_step != 1));

  // 버튼마다 한 번씩 보존. 효과음은 열기=0, 닫기=1인 4개 FIFO.
  always @(*) begin
    w_beep_requests = 0;
    for (i = 0; i < 7; i = i + 1) if (button_pulse[i]) w_beep_requests = w_beep_requests + 1;
    w_pending_next = r_pending_beeps + w_beep_requests - (w_beep_pop ? 1 : 0);
    w_overflow = (w_pending_next > 15);
    if (w_pending_next > 15) w_pending_next = 15;

    w_effect_queue_next = r_effect_queue;
    w_effect_count_next = r_effect_count;
    if (w_effect_pop) begin
      w_effect_queue_next = w_effect_queue_next >> 1;
      w_effect_count_next = w_effect_count_next - 1;
    end
    if (door_open_event) begin
      if (w_effect_count_next < 4) begin
        w_effect_queue_next[w_effect_count_next] = 0;
        w_effect_count_next = w_effect_count_next + 1;
      end else w_overflow = 1;
    end
    if (door_close_event) begin
      if (w_effect_count_next < 4) begin
        w_effect_queue_next[w_effect_count_next] = 1;
        w_effect_count_next = w_effect_count_next + 1;
      end else w_overflow = 1;
    end
  end

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_pending_beeps <= 0;
      r_beep_phase <= BEEP_IDLE;
      r_beep_count <= 0;
      r_effect_queue <= 0;
      r_effect_count <= 0;
      r_effect_active <= 0;
      r_effect_close <= 0;
      r_effect_step <= 0;
      r_effect_ms <= 0;
      queue_overflow <= 0;
    end else if (w_cancel) begin
      // 취소 시 현재·대기 소리를 폐기하고 취소 BEEP 하나만 남긴다.
      r_pending_beeps <= 1;
      r_beep_phase <= BEEP_IDLE;
      r_beep_count <= 0;
      r_effect_queue <= 0;
      r_effect_count <= 0;
      r_effect_active <= 0;
      r_effect_close <= 0;
      r_effect_step <= 0;
      r_effect_ms <= 0;
      queue_overflow <= 0;
    end else begin
      r_pending_beeps <= w_pending_next;
      r_effect_queue  <= w_effect_queue_next;
      r_effect_count  <= w_effect_count_next;
      if (w_overflow) queue_overflow <= 1;

      case (r_beep_phase)
        BEEP_IDLE: begin
          r_beep_count <= 0;
          if (w_beep_pop) r_beep_phase <= BEEP_ON;
        end
        BEEP_ON: begin
          if (tick_1ms) begin
            if (r_beep_count == BeepOnMs - 1) begin
              r_beep_count <= 0;
              r_beep_phase <= BEEP_GAP;
            end else r_beep_count <= r_beep_count + 1'b1;
          end
        end
        BEEP_GAP: begin
          if (tick_1ms) begin
            if (r_beep_count == BeepGapMs - 1) begin
              r_beep_count <= 0;
              r_beep_phase <= BEEP_IDLE;
            end else r_beep_count <= r_beep_count + 1'b1;
          end
        end
        default: r_beep_phase <= BEEP_IDLE;
      endcase

      if (w_effect_pop) begin
        r_effect_close <= r_effect_queue[0];
        r_effect_active <= 1;
        r_effect_step <= 0;
        r_effect_ms <= 0;
      end else if (r_effect_active && !w_beep_busy && tick_1ms) begin
        if (r_effect_ms == DoorStepMs - 1) begin
          r_effect_ms <= 0;
          if (r_effect_step == 2) begin
            r_effect_step   <= 0;
            r_effect_active <= 0;
          end else r_effect_step <= r_effect_step + 1'b1;
        end else r_effect_ms <= r_effect_ms + 1'b1;
      end
    end
  end

  // 종료음은 표시부의 시간 기준을 그대로 사용하며 BEEP 중에도 기준은 진행.
  assign sound_active = !reset && !w_cancel &&
                        (w_beep_busy ? (r_beep_phase == BEEP_ON) :
                         r_effect_active ? w_effect_on : (alert_active && alert_on));
  assign busy = !reset && (w_beep_busy || r_effect_active || (r_effect_count != 0) || alert_active);

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_tone_count <= 0;
      r_tone <= 0;
    end else if (!sound_active) begin
      r_tone_count <= 0;
      r_tone <= 0;
    end else if (r_tone_count == ToneHalfClocks - 1) begin
      r_tone_count <= 0;
      r_tone <= !r_tone;
    end else r_tone_count <= r_tone_count + 1'b1;
  end
  assign buzzer = sound_active && ((PassiveBuzzer != 0) ? r_tone : 1'b1);
endmodule

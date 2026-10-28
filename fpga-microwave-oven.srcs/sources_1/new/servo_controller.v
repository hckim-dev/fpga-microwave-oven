`timescale 1ns / 1ps

module servo_controller #(
    parameter integer FrameClocks = 2_000_000,
    parameter integer ClosedPulseClocks = 100_000,
    parameter integer OpenPulseClocks = 150_000
) (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire target_open,
    output wire servo_pwm,
    output reg command_applied
);
  localparam integer FrameWidth = (FrameClocks > 1) ? $clog2(FrameClocks) : 1;
  reg [FrameWidth-1:0] r_frame_count;
  reg r_started;
  reg r_target_open;
  wire [FrameWidth-1:0] w_pulse_clocks = r_target_open ? OpenPulseClocks : ClosedPulseClocks;

  // 목표는 프레임 시작에서만 반영해 진행 중인 HIGH 펄스 폭을 바꾸지 않음.
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_frame_count <= 0;
      r_started <= 0;
      r_target_open <= 0;
      command_applied <= 0;
    end else begin
      command_applied <= 0;
      if (!enable) begin
        r_frame_count <= 0;
        r_started <= 0;
      end else if (!r_started) begin
        r_frame_count <= 0;
        r_started <= 1;
        r_target_open <= target_open;
        command_applied <= 1;
      end else if (r_frame_count == FrameClocks - 1) begin
        r_frame_count <= 0;
        r_target_open <= target_open;
        if (target_open != r_target_open) command_applied <= 1;
      end else r_frame_count <= r_frame_count + 1'b1;
    end
  end

  // 취소/Reset으로 enable이 내려가면 프레임 중간이라도 즉시 차단.
  assign servo_pwm = !reset && enable && r_started && (r_frame_count < w_pulse_clocks);
endmodule

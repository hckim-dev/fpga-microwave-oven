`timescale 1ns / 1ps

module motor_controller #(
    parameter integer PwmPeriodClocks = 100_000  // 100 MHz에서 1 kHz
) (
    input wire clk,
    input wire reset,
    input wire [1:0] cook_state,
    input wire run_enable,
    input wire [6:0] button_pulse,
    output reg [1:0] speed_level,
    output reg [6:0] duty_percent,
    output wire motor_pwm,
    output wire motor_in1,
    output wire motor_in2
);
  localparam integer CountWidth = $clog2(PwmPeriodClocks);
  localparam integer TenthClocks = PwmPeriodClocks / 10;
  reg [CountWidth-1:0] r_pwm_count;
  reg [1:0] r_applied_level;
  reg r_running;
  reg [1:0] w_next_level;
  reg [CountWidth-1:0] w_high_clocks;
  wire w_run = !reset && run_enable && (cook_state == 2'd1);
  wire w_setting_allowed = (cook_state != 2'd3) && !(|button_pulse[6:3]) &&
                           ((cook_state != 2'd1) || run_enable);

  always @(*) begin
    w_next_level = speed_level;
    if (w_setting_allowed && (button_pulse[1] ^ button_pulse[2])) begin
      if (button_pulse[1] && (speed_level != 2'd3)) w_next_level = speed_level + 1'b1;
      else if (button_pulse[2] && (speed_level != 2'd0)) w_next_level = speed_level - 1'b1;
    end
    case (speed_level)
      0: duty_percent = 7'd30;
      1: duty_percent = 7'd50;
      2: duty_percent = 7'd70;
      3: duty_percent = 7'd90;
      default: duty_percent = 7'd50;
    endcase
    case (r_applied_level)
      0: w_high_clocks = TenthClocks * 3;
      1: w_high_clocks = TenthClocks * 5;
      2: w_high_clocks = TenthClocks * 7;
      3: w_high_clocks = TenthClocks * 9;
      default: w_high_clocks = TenthClocks * 5;
    endcase
  end

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      speed_level <= 1;
      r_applied_level <= 1;
      r_pwm_count <= 0;
      r_running <= 0;
    end else begin
      speed_level <= w_next_level;
      if (!w_run) begin
        r_pwm_count <= 0;
        r_running <= 0;
        r_applied_level <= w_next_level;
      end else if (!r_running) begin
        r_pwm_count <= 0;
        r_running <= 1;
        r_applied_level <= w_next_level;
      end else if (r_pwm_count == PwmPeriodClocks - 1) begin
        r_pwm_count <= 0;
        r_applied_level <= w_next_level;
      end else r_pwm_count <= r_pwm_count + 1'b1;
    end
  end

  // 방향을 먼저 설정하고 다음 클럭에 첫 PWM 주기를 시작.
  assign motor_in1 = w_run;
  assign motor_in2 = 1'b0;
  assign motor_pwm = w_run && r_running && (r_pwm_count < w_high_clocks);
endmodule

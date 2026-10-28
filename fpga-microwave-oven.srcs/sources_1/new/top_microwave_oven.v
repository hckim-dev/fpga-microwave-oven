`timescale 1ns / 1ps

module top_microwave_oven #(
    parameter integer TickCount = 100_000,
    parameter integer ButtonDebounceCount = 1_000_000,
    parameter integer RotaryDebounceCount = 200_000,
    parameter integer StepsPerDetent = 4,
    parameter integer ServoFrameClocks = 2_000_000,
    parameter integer ClosedPulseClocks = 100_000,
    parameter integer OpenPulseClocks = 150_000,
    parameter integer MoveTimeMs = 500,
    parameter integer PwmPeriodClocks = 100_000,
    parameter integer PassiveBuzzer = 0
) (
    input wire clk,
    input wire btnC,
    input wire btnL,
    input wire btnU,
    input wire btnD,
    input wire btnR,
    input wire door_open,
    input wire door_close,
    input wire rotary_s1,
    input wire rotary_s2,
    input wire rotary_key,
    output wire [7:0] seg,
    output wire [3:0] an,
    output wire [15:0] led,
    output wire servo_pwm,
    output wire buzzer,
    output wire motor_pwm,
    output wire motor_in1,
    output wire motor_in2
);
  wire reset, tick_1ms, ready;
  wire [6:0] button_down, button_pulse;
  wire rotary_cw, rotary_ccw, rotary_invalid;
  wire [1:0] cook_state, speed_level;
  wire [2:0] door_state;
  wire [11:0] remaining_seconds;
  wire [6:0] duty_percent;
  wire select_minutes, run_enable, timeout_pulse;
  wire door_closed, servo_enable, target_open, command_applied;
  wire open_event, close_event, alert_done, alert_on;
  wire sound_active, sound_busy, queue_overflow;

  input_frontend #(
      .TickCount(TickCount),
      .ButtonDebounceCount(ButtonDebounceCount),
      .RotaryDebounceCount(RotaryDebounceCount),
      .StepsPerDetent(StepsPerDetent)
  ) u_input (
      .clk(clk),
      .reset(btnC),
      .button_raw({rotary_key, door_close, door_open, btnR, btnD, btnU, btnL}),
      .rotary_ab_raw({rotary_s1, rotary_s2}),
      .synced_reset(reset),
      .tick_1ms(tick_1ms),
      .ready(ready),
      .button_down(button_down),
      .button_pulse(button_pulse),
      .rotary_cw(rotary_cw),
      .rotary_ccw(rotary_ccw),
      .rotary_invalid(rotary_invalid)
  );

  microwave_controller u_control (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .button_pulse(button_pulse),
      .rotary_cw(rotary_cw),
      .rotary_ccw(rotary_ccw),
      .door_closed(door_closed),
      .alert_done(alert_done),
      .state(cook_state),
      .remaining_seconds(remaining_seconds),
      .select_minutes(select_minutes),
      .run_enable(run_enable),
      .timeout_pulse(timeout_pulse)
  );

  door_controller #(
      .MoveTimeMs(MoveTimeMs)
  ) u_door (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .open_request(button_pulse[4]),
      .close_request(button_pulse[5]),
      .cancel(button_pulse[3]),
      .command_applied(command_applied),
      .state(door_state),
      .door_closed(door_closed),
      .servo_enable(servo_enable),
      .target_open(target_open),
      .open_event(open_event),
      .close_event(close_event)
  );

  servo_controller #(
      .FrameClocks(ServoFrameClocks),
      .ClosedPulseClocks(ClosedPulseClocks),
      .OpenPulseClocks(OpenPulseClocks)
  ) u_servo (
      .clk(clk),
      .reset(reset),
      .enable(servo_enable),
      .target_open(target_open),
      .servo_pwm(servo_pwm),
      .command_applied(command_applied)
  );

  motor_controller #(
      .PwmPeriodClocks(PwmPeriodClocks)
  ) u_motor (
      .clk(clk),
      .reset(reset),
      .cook_state(cook_state),
      .run_enable(run_enable),
      .button_pulse(button_pulse),
      .speed_level(speed_level),
      .duty_percent(duty_percent),
      .motor_pwm(motor_pwm),
      .motor_in1(motor_in1),
      .motor_in2(motor_in2)
  );

  display_controller u_display (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .state(cook_state),
      .remaining_seconds(remaining_seconds),
      .select_minutes(select_minutes),
      .seg(seg),
      .an(an),
      .alert_done(alert_done),
      .alert_on(alert_on)
  );

  sound_controller #(
      .PassiveBuzzer(PassiveBuzzer)
  ) u_sound (
      .clk(clk),
      .reset(reset),
      .tick_1ms(tick_1ms),
      .button_pulse(button_pulse),
      .door_open_event(open_event),
      .door_close_event(close_event),
      .alert_active(cook_state == 2'd3),
      .alert_on(alert_on),
      .buzzer(buzzer),
      .sound_active(sound_active),
      .busy(sound_busy),
      .queue_overflow(queue_overflow)
  );

  // 도어 위치는 센서 피드백 없이 서보 명령과 대기 시간으로 추정한다.
  assign led[0] = ready && !reset;
  assign led[1] = run_enable;
  assign led[2] = !reset && (cook_state == 2'd2);
  assign led[3] = !reset && (cook_state == 2'd3);
  assign led[4] = door_closed;
  assign led[5] = !reset && (door_state == 3'd3);
  assign led[6] = !reset && ((door_state == 3'd2) || (door_state == 3'd4));
  assign led[7] = !reset && (door_state == 3'd0);
  assign led[9:8] = reset ? 2'd0 : speed_level;
  assign led[10] = !reset && select_minutes;
  assign led[11] = servo_enable;
  assign led[12] = sound_active;
  assign led[13] = !reset && queue_overflow;
  assign led[14] = rotary_invalid;
  assign led[15] = reset;
endmodule

`timescale 1ns / 1ps

module btn_debouncer #(
    parameter integer DebounceCount = 1_000_000
) (
    input  wire clk,
    input  wire reset,
    input  wire noisy_btn,
    output reg  clean_btn
);
  localparam integer CountWidth = (DebounceCount > 1) ? $clog2(DebounceCount) : 1;
  reg [CountWidth-1:0] r_count;
  (* ASYNC_REG = "TRUE" *) reg r_sync_ff1;
  (* ASYNC_REG = "TRUE" *) reg r_sync_ff2;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_sync_ff1 <= 0;
      r_sync_ff2 <= 0;
    end else begin
      r_sync_ff1 <= noisy_btn;
      r_sync_ff2 <= r_sync_ff1;
    end
  end

  // 반대 값이 연속으로 안정된 시간만 계수.
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_count   <= 0;
      clean_btn <= 0;
    end else if (r_sync_ff2 == clean_btn) begin
      r_count <= 0;
    end else if (r_count == DebounceCount - 1) begin
      r_count   <= 0;
      clean_btn <= r_sync_ff2;
    end else begin
      r_count <= r_count + 1'b1;
    end
  end
endmodule

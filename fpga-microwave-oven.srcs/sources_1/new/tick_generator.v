`timescale 1ns / 1ps

module tick_generator #(
    parameter integer TickCount = 100_000  // 100 MHz에서 1 ms
) (
    input  wire clk,
    input  wire reset,
    output reg  tick
);
  localparam integer CountWidth = (TickCount > 1) ? $clog2(TickCount) : 1;
  reg [CountWidth-1:0] r_count;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      r_count <= 0;
      tick <= 0;
    end else if (r_count == TickCount - 1) begin
      r_count <= 0;
      tick <= 1;
    end else begin
      r_count <= r_count + 1'b1;
      tick <= 0;
    end
  end
endmodule

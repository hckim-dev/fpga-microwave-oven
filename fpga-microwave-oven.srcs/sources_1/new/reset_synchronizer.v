`timescale 1ns / 1ps

module reset_synchronizer (
    input  wire clk,
    input  wire reset,
    output wire synced_reset
);
  // FPGA 구성 직후 초기화, 비동기 인가 및 동기 해제.
  (* ASYNC_REG = "TRUE" *) reg [1:0] r_reset_sync = 2'b11;

  always @(posedge clk or posedge reset) begin
    if (reset) r_reset_sync <= 2'b11;
    else r_reset_sync <= {r_reset_sync[0], 1'b0};
  end

  assign synced_reset = r_reset_sync[1];
endmodule

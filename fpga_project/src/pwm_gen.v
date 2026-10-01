`timescale 1ns/1ps
// ============================================================================
// pwm_gen.v -- fixed-frequency PWM generator
//
//   clk     : system clock (50 MHz on LCKFB LogicPi FPGA-G1)
//   rst_n   : asynchronous reset, active low
//   pwm_out : PWM output, high for DUTY_PCT percent of every period
//
//   PERIOD   = CLK_FREQ / PWM_FREQ      (clocks per PWM period)
//   DUTY_CNT = PERIOD * DUTY_PCT / 100  (clocks high per period)
//
//   All counters are synchronous to clk; reset is asynchronous.
//   Counter width 32 bits is oversized but synthesis trims unused bits.
// ============================================================================
module pwm_gen #(
    parameter integer CLK_FREQ = 50_000_000,   // Hz
    parameter integer PWM_FREQ = 20_000,       // Hz
    parameter integer DUTY_PCT = 30            // 0 .. 100
) (
    input  wire clk,
    input  wire rst_n,
    output reg  pwm_out
);

    localparam [31:0] PERIOD   = CLK_FREQ / PWM_FREQ;             // 2500 @ 50MHz / 20kHz
    localparam [31:0] DUTY_CNT = (CLK_FREQ / PWM_FREQ) * DUTY_PCT / 100;  // 750 @ 30%

    reg [31:0] cnt;

    // ---- period counter: 0 .. PERIOD-1 ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= 32'd0;
        else if (cnt >= PERIOD - 32'd1)
            cnt <= 32'd0;
        else
            cnt <= cnt + 32'd1;
    end

    // ---- compare: high while cnt < DUTY_CNT ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_out <= 1'b0;
        else
            pwm_out <= (cnt < DUTY_CNT) ? 1'b1 : 1'b0;
    end

endmodule

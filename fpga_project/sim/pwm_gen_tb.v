// ============================================================================
// pwm_gen_tb.v -- self-checking testbench for pwm_gen
//
//   Kept OUT of the Gowin project (lives in sim/, never added to the .gprj).
//   Parameters are scaled down 50000x so the whole check runs in a few us:
//       CLK_FREQ = 1000, PWM_FREQ = 10, DUTY_PCT = 30
//       -> PERIOD = 100 clocks, DUTY = 30 clocks
//
//   Run:
//       iverilog -o pwm_gen_tb.vvp pwm_gen_tb.v ../src/pwm_gen.v
//       vvp pwm_gen_tb.vvp
//
//   Prints PASS / FAIL. pwm_out is sampled on negedges, i.e. half a clock
//   after each posedge, so there is no race with the DUT's nonblocking
//   assignment.
// ============================================================================
`timescale 1ns/1ps

module pwm_gen_tb;

    localparam integer TB_CLK_FREQ = 1000;
    localparam integer TB_PWM_FREQ = 10;
    localparam integer TB_DUTY_PCT = 30;

    localparam integer EXP_PERIOD = TB_CLK_FREQ / TB_PWM_FREQ;              // 100
    localparam integer EXP_HIGH   = EXP_PERIOD * TB_DUTY_PCT / 100;         // 30
    localparam integer EXP_LOW    = EXP_PERIOD - EXP_HIGH;                  // 70

    reg  clk   = 1'b0;
    reg  rst_n = 1'b0;
    wire pwm_out;

    integer errors = 0;
    integer high_cnt;
    integer low_cnt;
    integer p;

    pwm_gen #(
        .CLK_FREQ (TB_CLK_FREQ),
        .PWM_FREQ (TB_PWM_FREQ),
        .DUTY_PCT (TB_DUTY_PCT)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .pwm_out (pwm_out)
    );

    always #5 clk = ~clk;      // 10 ns period -> 100 MHz "clock", 10 clocks per PWM period

    initial begin
        $dumpfile("pwm_gen_tb.vcd");
        $dumpvars(0, pwm_gen_tb);

        // ---- 1. output must stay low while reset is asserted ----
        repeat (5) @(negedge clk);
        if (pwm_out !== 1'b0) begin
            $display("FAIL: pwm_out = %b during reset, expected 0", pwm_out);
            errors = errors + 1;
        end

        rst_n = 1'b1;

        // ---- 2. align to the first high phase ----
        @(negedge clk);
        while (pwm_out !== 1'b1) @(negedge clk);

        // ---- 3. measure 3 consecutive periods ----
        for (p = 0; p < 3; p = p + 1) begin
            high_cnt = 0;
            low_cnt  = 0;

            while (pwm_out === 1'b1) begin
                high_cnt = high_cnt + 1;
                @(negedge clk);
            end
            while (pwm_out === 1'b0) begin
                low_cnt = low_cnt + 1;
                @(negedge clk);
            end

            $display("period %0d : high = %0d, low = %0d  (expect %0d / %0d)",
                     p, high_cnt, low_cnt, EXP_HIGH, EXP_LOW);

            if (high_cnt !== EXP_HIGH) begin
                $display("FAIL: high phase is %0d clocks, expected %0d", high_cnt, EXP_HIGH);
                errors = errors + 1;
            end
            if (low_cnt !== EXP_LOW) begin
                $display("FAIL: low phase is %0d clocks, expected %0d", low_cnt, EXP_LOW);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: pwm_gen verified - %0d clocks high / %0d clocks low per period",
                     EXP_HIGH, EXP_LOW);
        else
            $display("FAIL: %0d check(s) failed", errors);

        $finish;
    end

endmodule

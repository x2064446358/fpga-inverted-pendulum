// ============================================================================
// top.v -- bring-up, LCKFB LogicPi FPGA-G1 (Gowin GW2A-18C, PBGA256)
//
//   IO allocation follows 排针映射与IO分配.md (M1): the J280 driver-board
//   interface sits on the IOT / bank 0 pins (3.3 V); IOL / bank 7 is left
//   free on purpose for stage-5 expansion.
//
//   Behaviour in this revision -- deliberately "nothing moves on power-up":
//       led      R9 : 1 Hz heartbeat                      (board is alive)
//       led2     N6 : lit only while KEY1 is held         (test mode)
//       PWMA     G15: 20 kHz / 30 % duty, ONLY while KEY1 is held,
//                    0 otherwise -- programming the board must not spin the arm
//       AIN1/AIN2   : both 0 -> driver in stop/coast
//       ADC_CS   J16: held high (inactive)
//       ADC_SCK  J14: 0     ADC_MOSI H15: 0
//       uart_txd F12: idle high
//
//   Board facts:
//       sys_clk T7  50 MHz (20 ns)   rst_n D11 KEY0   key1 F10 KEY1
//       led     R9  LED0 red         led2  N6  LED1 red   (both active LOW)
//   NOTE: keep comments in English; the Gowin editor garbles Chinese text.
//   Every port here must also appear in yingjiao.cst, and vice versa.
// ============================================================================
module top (
    input  wire sys_clk,        // T7   50 MHz
    input  wire rst_n,          // D11  KEY0, active low
    input  wire key1,           // F10  KEY1, active low = PWM test enable
    // ---- on-board UART debug link (F12 / F13) ----
    input  wire uart_rxd,
    output wire uart_txd,
    // ---- on-board LEDs (active low) ----
    output wire led,            // R9  heartbeat
    output wire led2,           // N6  PWM test mode
    // ---- J280 driver board: motor PWM + direction (bank 0) ----
    output wire PWMA,           // G15  20 kHz PWM
    output wire AIN1,           // G14
    output wire AIN2,           // G16
    // ---- J280 driver board: encoder input (bank 0) ----
    input  wire EA,             // J15
    input  wire EB,             // K16
    // ---- J280 driver board: SPI ADC (bank 0) ----
    output wire ADC_CS,         // J16
    output wire ADC_SCK,        // J14
    output wire ADC_MOSI,       // H15
    input  wire ADC_MISO        // F14
);

    // ------------------------------------------------------------------
    // 1 Hz heartbeat at 50 MHz: 50_000_000 / 2 - 1
    // ------------------------------------------------------------------
    localparam [25:0] BLINK_MAX = 26'd24_999_999;

    reg [25:0] blink_cnt;
    reg        led_r;

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            blink_cnt <= 26'd0;
            led_r     <= 1'b0;
        end
        else if (blink_cnt >= BLINK_MAX) begin
            blink_cnt <= 26'd0;
            led_r     <= ~led_r;
        end
        else begin
            blink_cnt <= blink_cnt + 26'd1;
        end
    end

    assign led = ~led_r;                 // active low

    // ------------------------------------------------------------------
    // Motor PWM, gated by KEY1 (active low -> held down enables the test)
    // ------------------------------------------------------------------
    wire pwm_raw;
    wire test_en = ~key1;

    pwm_gen #(
        .CLK_FREQ (50_000_000),
        .PWM_FREQ (20_000),
        .DUTY_PCT (30)
    ) u_pwm_gen (
        .clk     (sys_clk),
        .rst_n   (rst_n),
        .pwm_out (pwm_raw)
    );

    assign PWMA = test_en ? pwm_raw : 1'b0;   // zero duty unless KEY1 is held
    assign led2 = ~test_en;                   // LED lit while testing

    // ------------------------------------------------------------------
    // Everything else parked in its safe state
    // ------------------------------------------------------------------
    assign AIN1     = 1'b0;   // 00 = stop / coast
    assign AIN2     = 1'b0;
    assign ADC_CS   = 1'b1;   // SPI chip select inactive
    assign ADC_SCK  = 1'b0;
    assign ADC_MOSI = 1'b0;
    assign uart_txd = 1'b1;   // UART idle level

endmodule

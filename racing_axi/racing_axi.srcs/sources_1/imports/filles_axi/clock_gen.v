// ============================================================================
// Module: clock_gen
// ============================================================================
// Generates the two clocks we need from the PYNQ-Z1's 125 MHz system clock:
//   - 25 MHz  pixel clock (for VGA timing, tile lookup, etc.)
//   - 125 MHz serial clock (for TMDS serialization, 5x pixel clock)
//
// Uses Xilinx MMCME2_BASE (Mixed-Mode Clock Manager).
// The MMCM is a PLL-like block built into the FPGA that can multiply
// and divide clocks to create new frequencies.
//
// Math: 125 MHz input
//   MMCM VCO = 125 * (MULT/DIV) = 125 * (8/1) = 1000 MHz
//   Output 0 = 1000 / 8  = 125 MHz  (serial clock)
//   Output 1 = 1000 / 40 = 25 MHz   (pixel clock)
// ============================================================================

module clock_gen (
    input  wire  clk_125mhz_in,   // 125 MHz from board
    input  wire  reset,
    output wire  clk_25mhz,       // pixel clock
    output wire  clk_125mhz,      // serial clock (phase-aligned)
    output wire  locked            // HIGH when clocks are stable
);

    wire clk_fb;
    wire clk_125_unbuf;
    wire clk_25_unbuf;

    // MMCM: generates both clocks from 125 MHz input
    MMCME2_BASE #(
        .CLKFBOUT_MULT_F  (8.0),     // VCO = 125 * 8 = 1000 MHz
        .CLKIN1_PERIOD     (8.0),     // 125 MHz = 8 ns period
        .CLKOUT0_DIVIDE_F  (8.0),     // 1000 / 8 = 125 MHz
        .CLKOUT1_DIVIDE    (40),      // 1000 / 40 = 25 MHz
        .DIVCLK_DIVIDE     (1)
    ) mmcm_inst (
        .CLKFBOUT  (clk_fb),
        .CLKFBIN   (clk_fb),
        .CLKIN1    (clk_125mhz_in),
        .CLKOUT0   (clk_125_unbuf),
        .CLKOUT1   (clk_25_unbuf),
        .CLKOUT2   (),
        .CLKOUT3   (),
        .CLKOUT4   (),
        .CLKOUT5   (),
        .CLKOUT6   (),
        .CLKFBOUTB (),
        .CLKOUT0B  (),
        .CLKOUT1B  (),
        .CLKOUT2B  (),
        .CLKOUT3B  (),
        .LOCKED    (locked),
        .PWRDWN    (1'b0),
        .RST       (reset)
    );

    // Buffer the outputs (required by Xilinx for clock distribution)
    BUFG bufg_125 (.I(clk_125_unbuf), .O(clk_125mhz));
    BUFG bufg_25  (.I(clk_25_unbuf),  .O(clk_25mhz));

endmodule

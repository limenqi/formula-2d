// Takes parallel RGB + sync signals and outputs TMDS differential signals
// for the HDMI connector on the PYNQ-Z1.

// HOW HDMI OUTPUT WORKS:
//   1. Our renderer produces 8-bit R, G, B + hsync + vsync at 25 MHz
//   2. Three TMDS encoders convert each color to 10-bit encoded values
//   3. OSERDES blocks serialize each 10-bit value at 125 MHz (5x pixel clock)
//      sending 2 bits per 125 MHz clock (DDR) = 10 bits per pixel clock
//   4. OBUFDS converts single-ended to differential for the HDMI cable

// The blue channel carries hsync/vsync during blanking
// Red and green channels carry 0,0 control bits during blanking

module hdmi_out (
    input  wire       clk_25mhz,     // pixel clock
    input  wire       clk_125mhz,    // serial clock (5x pixel clock)
    input  wire       reset,
    
    // Video input from our renderer
    input  wire [7:0] red,
    input  wire [7:0] green,
    input  wire [7:0] blue,
    input  wire       hsync,
    input  wire       vsync,
    input  wire       active,         // data enable
    
    // TMDS differential outputs (active active active to HDMI connector pins)
    output wire [2:0] tmds_data_p,
    output wire [2:0] tmds_data_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n
);

    // ── TMDS encode each channel ──
    wire [9:0] tmds_red, tmds_green, tmds_blue;
    
    tmds_encoder enc_red (
        .clk   (clk_25mhz),
        .reset (reset),
        .din   (red),
        .c0    (1'b0),      // red: no control bits
        .c1    (1'b0),
        .de    (active),
        .dout  (tmds_red)
    );
    
    tmds_encoder enc_green (
        .clk   (clk_25mhz),
        .reset (reset),
        .din   (green),
        .c0    (1'b0),      // green: no control bits
        .c1    (1'b0),
        .de    (active),
        .dout  (tmds_green)
    );
    
    tmds_encoder enc_blue (
        .clk   (clk_25mhz),
        .reset (reset),
        .din   (blue),
        .c0    (hsync),     // blue channel carries hsync
        .c1    (vsync),     // blue channel carries vsync
        .de    (active),
        .dout  (tmds_blue)
    );

    // Serialize 10-bit TMDS to differential output
    // Using Xilinx OSERDESE2 (output serializer) in DDR mode
    // 5:1 serialization with DDR = 10 bits per pixel clock cycle
    
    wire [2:0] tmds_data_serial;
    wire       tmds_clk_serial;
    
    // Serialize red channel (data[2])
    tmds_serializer ser_red (
        .clk_fast  (clk_125mhz),
        .clk_slow  (clk_25mhz),
        .reset     (reset),
        .data_in   (tmds_red),
        .serial_out(tmds_data_serial[2])
    );
    
    // Serialize green channel (data[1])
    tmds_serializer ser_green (
        .clk_fast  (clk_125mhz),
        .clk_slow  (clk_25mhz),
        .reset     (reset),
        .data_in   (tmds_green),
        .serial_out(tmds_data_serial[1])
    );
    
    // Serialize blue channel (data[0])
    tmds_serializer ser_blue (
        .clk_fast  (clk_125mhz),
        .clk_slow  (clk_25mhz),
        .reset     (reset),
        .data_in   (tmds_blue),
        .serial_out(tmds_data_serial[0])
    );
    
    // Serialize clock (just toggles: 1111100000 pattern at 125 MHz)
    tmds_serializer ser_clk (
        .clk_fast  (clk_125mhz),
        .clk_slow  (clk_25mhz),
        .reset     (reset),
        .data_in   (10'b0000011111),
        .serial_out(tmds_clk_serial)
    );
    
    // ── Differential output buffers ──
    // OBUFDS converts single-ended → differential pair for HDMI cable
    
    OBUFDS #(.IOSTANDARD("TMDS_33")) obuf_d0 (
        .I (tmds_data_serial[0]),
        .O (tmds_data_p[0]),
        .OB(tmds_data_n[0])
    );
    
    OBUFDS #(.IOSTANDARD("TMDS_33")) obuf_d1 (
        .I (tmds_data_serial[1]),
        .O (tmds_data_p[1]),
        .OB(tmds_data_n[1])
    );
    
    OBUFDS #(.IOSTANDARD("TMDS_33")) obuf_d2 (
        .I (tmds_data_serial[2]),
        .O (tmds_data_p[2]),
        .OB(tmds_data_n[2])
    );
    
    OBUFDS #(.IOSTANDARD("TMDS_33")) obuf_clk (
        .I (tmds_clk_serial),
        .O (tmds_clk_p),
        .OB(tmds_clk_n)
    );

endmodule


// Serializes a 10-bit TMDS word using Xilinx OSERDESE2 primitive.
// Runs at 5x pixel clock in DDR mode: 5 * 2 = 10 bits per pixel clock.
module tmds_serializer (
    input  wire       clk_fast,    // 125 MHz serial clock
    input  wire       clk_slow,    // 25 MHz pixel clock
    input  wire       reset,
    input  wire [9:0] data_in,     // 10-bit parallel input
    output wire       serial_out   // serial output
);

    // OSERDESE2: 10:1 serialization (5:1 DDR)
    // D1 is transmitted first, D8 is transmitted last (for 8:1)
    // We use master+slave cascade for 10:1
    
    wire shift1, shift2;
    
    OSERDESE2 #(
        .DATA_RATE_OQ ("DDR"),
        .DATA_RATE_TQ ("SDR"),
        .DATA_WIDTH   (10),
        .SERDES_MODE  ("MASTER"),
        .TRISTATE_WIDTH(1)
    ) master (
        .OQ       (serial_out),
        .OFB      (),
        .TQ       (),
        .TFB      (),
        .SHIFTOUT1(),
        .SHIFTOUT2(),
        .TBYTEOUT (),
        .CLK      (clk_fast),
        .CLKDIV   (clk_slow),
        .D1       (data_in[0]),
        .D2       (data_in[1]),
        .D3       (data_in[2]),
        .D4       (data_in[3]),
        .D5       (data_in[4]),
        .D6       (data_in[5]),
        .D7       (data_in[6]),
        .D8       (data_in[7]),
        .TCE      (1'b0),
        .OCE      (1'b1),
        .TBYTEIN  (1'b0),
        .RST      (reset),
        .SHIFTIN1 (shift1),
        .SHIFTIN2 (shift2),
        .T1       (1'b0),
        .T2       (1'b0),
        .T3       (1'b0),
        .T4       (1'b0)
    );
    
    OSERDESE2 #(
        .DATA_RATE_OQ ("DDR"),
        .DATA_RATE_TQ ("SDR"),
        .DATA_WIDTH   (10),
        .SERDES_MODE  ("SLAVE"),
        .TRISTATE_WIDTH(1)
    ) slave (
        .OQ       (),
        .OFB      (),
        .TQ       (),
        .TFB      (),
        .SHIFTOUT1(shift1),
        .SHIFTOUT2(shift2),
        .TBYTEOUT (),
        .CLK      (clk_fast),
        .CLKDIV   (clk_slow),
        .D1       (1'b0),
        .D2       (1'b0),
        .D3       (data_in[8]),
        .D4       (data_in[9]),
        .D5       (1'b0),
        .D6       (1'b0),
        .D7       (1'b0),
        .D8       (1'b0),
        .TCE      (1'b0),
        .OCE      (1'b1),
        .TBYTEIN  (1'b0),
        .RST      (reset),
        .SHIFTIN1 (),
        .SHIFTIN2 (),
        .T1       (1'b0),
        .T2       (1'b0),
        .T3       (1'b0),
        .T4       (1'b0)
    );

endmodule

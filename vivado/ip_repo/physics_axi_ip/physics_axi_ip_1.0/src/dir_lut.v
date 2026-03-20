`timescale 1ns / 1ps

module dir_lut #(
    parameter integer LUT_ADDR_BITS = 4,  // 16 entries in the LUT  
    parameter integer LUT_DATA_BITS = 12    // each entry is 12 bits
) (
    input  wire [9:0] heading,
    output reg  signed [LUT_DATA_BITS-1:0] cos_val,
    output reg  signed [LUT_DATA_BITS-1:0] sin_val
);

    localparam integer LUT_DEPTH = 1 << LUT_ADDR_BITS;  // depth = 16

    // implements using BRAM 
    (* rom_style = "block" *) reg signed [LUT_DATA_BITS-1:0] sin_rom [0:LUT_DEPTH-1];
    (* rom_style = "block" *) reg signed [LUT_DATA_BITS-1:0] cos_rom [0:LUT_DEPTH-1];

    wire [LUT_ADDR_BITS-1:0] lut_index = heading[9 -: LUT_ADDR_BITS];
    // essentially takes the top 4 bits of the 10 bits heading
    // the circle is divided in 16 sectors, so the 10 bits heading is mapped into the 16 sectors

    initial begin
        $readmemh("sin_lut.mem", sin_rom);
        $readmemh("cos_lut.mem", cos_rom);
    end

    always @(*) begin
        cos_val = cos_rom[lut_index];   // maps to x movement (we treat 0 degrees as pointing right)
        sin_val = sin_rom[lut_index];   // maps to y movement
    end

endmodule

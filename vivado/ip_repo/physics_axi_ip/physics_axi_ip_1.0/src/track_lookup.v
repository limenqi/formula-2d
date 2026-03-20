`timescale 1ns / 1ps

module track_lookup #(
    parameter integer MAP_WIDTH  = 20,  // corresponding to our current map size
    parameter integer MAP_HEIGHT = 15,
    parameter integer TILE_SHIFT = 6    // each tile is 2^6 pixels high/wide
) (
    input  wire [23:0] x_pos,
    input  wire [23:0] y_pos,
    output reg  [7:0]  surface_meta
);

    localparam integer MAP_SIZE = MAP_WIDTH * MAP_HEIGHT;

    (* ram_style = "block" *) reg [7:0] track_meta [0:MAP_SIZE-1];  // per-cell map memory

    wire [15:0] pixel_x = x_pos[23:8];  // convert fixed point coordinates into pixel coordinates (disregard the fractions)
    wire [15:0] pixel_y = y_pos[23:8];
    wire [7:0] cell_x = pixel_x >> TILE_SHIFT;  // convert pixel coordinates into tile coordinates
    wire [7:0] cell_y = pixel_y >> TILE_SHIFT;
    integer addr;

    initial begin
        $readmemh("track_meta.mem", track_meta);    // should contain 20x15 (=300) lines - one hex byte per line
    end

    // track meta [bits 1:0]
    // 00 - road
    // 01 - grass
    // 10 - wall
    // 11 - unused

    // bit [2] - checkpoint flag 

    always @(*) begin
        if (cell_x >= MAP_WIDTH || cell_y >= MAP_HEIGHT) begin
            surface_meta = 8'h02;   // outside the map (treat as wall)
        end else begin
            addr = (cell_y * MAP_WIDTH) + cell_x;
            surface_meta = track_meta[addr];
        end
    end

endmodule
// ============================================================================
// Module: tile_renderer (64x64 TILES)
// ============================================================================
// 64x64 pixel tiles with 5-bit tile index (up to 32 unique tiles).
//
// SPECIFICATIONS:
//   - Tile size:      64x64 pixels
//   - Tile index:     5-bit (0-31, supports 32 unique tiles)
//   - Map grid:       20 columns x 15 rows (1280x960 world pixels)
//   - Tilemap BRAM:   300 entries x 5-bit
//   - Tileset BRAM:   131072 entries x 16-bit (32 tiles x 64x64)
//   - Tileset addr:   17-bit {tile_index[4:0], py[5:0], px[5:0]}
//   - Pipeline:       2 cycles (tilemap read -> tileset read)
//   - Pixel format:   RGB565 (16-bit)
//
// BRAM USAGE:
//   Tilemap: 300 x 5-bit  = ~188 bytes   (negligible)
//   Tileset: 131072 x 16-bit = 262,144 bytes = 256 KB
//   Total:   ~256 KB (within 630 KB budget)
// ============================================================================

module tile_renderer (
    input  wire        clk,
    input  wire        reset,
    input  wire [9:0]  h_count,
    input  wire [9:0]  v_count,
    input  wire        active,
    input  wire [10:0] cam_x,
    input  wire [9:0]  cam_y,
    output reg  [15:0] pixel_rgb565,
    output reg         pixel_valid
);

    // World-space coordinates (screen + camera offset)
    wire [10:0] world_x = h_count + cam_x;
    wire [9:0]  world_y = v_count + cam_y;

    // Tile grid position
    // For 64x64 tiles: divide by 64 = shift right by 6
    wire [4:0]  tile_col = world_x[10:6];  // 0-19 (20 columns)
    wire [3:0]  tile_row = world_y[9:6];   // 0-14 (15 rows)

    // Pixel offset within the tile
    // For 64x64 tiles: lower 6 bits
    wire [5:0]  px = world_x[5:0];         // 0-63
    wire [5:0]  py = world_y[5:0];         // 0-63

    // Tilemap BRAM
    // 20 columns x 15 rows = 300 entries
    // Each entry is a 5-bit tile index (0-31)
    wire [8:0] tilemap_addr = tile_row * 20 + tile_col;

    (* ram_style = "block" *)
    reg [4:0] tilemap_bram [0:299];

    // Pipeline stage 1: Read tile index from tilemap
    reg [4:0] tile_index;
    always @(posedge clk) begin
        tile_index <= tilemap_bram[tilemap_addr];
    end

    // Delay pixel coordinates and active signal to match pipeline
    reg [5:0] px_d1, py_d1;
    reg       active_d1;
    always @(posedge clk) begin
        px_d1     <= px;
        py_d1     <= py;
        active_d1 <= active;
    end

    // Tileset BRAM
    // 32 tiles x 64x64 pixels = 131072 entries
    // Address: {tile_index[4:0], py[5:0], px[5:0]} = 17 bits
    wire [16:0] tileset_addr = {tile_index, py_d1, px_d1};

    (* ram_style = "block" *)
    reg [15:0] tileset_bram [0:131071];

    // Pipeline stage 2: Read pixel color from tileset
    reg [15:0] tile_color;
    always @(posedge clk) begin
        tile_color <= tileset_bram[tileset_addr];
    end

    // Delay active signal one more cycle
    reg active_d2;
    always @(posedge clk) begin
        active_d2 <= active_d1;
    end

    // Output
    always @(*) begin
        if (active_d2) begin
            pixel_rgb565 = tile_color;
            pixel_valid  = 1'b1;
        end else begin
            pixel_rgb565 = 16'h0000;
            pixel_valid  = 1'b0;
        end
    end

    // Load hex data
    // UPDATE THESE PATHS to match your project directory
    initial begin
        $readmemh("C:/Users/yilka/programming/infoproc/InfoProcTopLevel/tilemap.hex", tilemap_bram);
        $readmemh("C:/Users/yilka/programming/infoproc/InfoProcTopLevel/tileset.hex", tileset_bram);
    end
    

endmodule

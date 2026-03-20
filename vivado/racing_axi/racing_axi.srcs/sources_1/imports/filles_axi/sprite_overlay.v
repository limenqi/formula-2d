// ============================================================================
// Module: sprite_overlay 
// ============================================================================

module sprite_overlay (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] tile_color,
    input  wire        tile_valid,
    input  wire [9:0]  h_count_d2,
    input  wire [9:0]  v_count_d2,
    input  wire [10:0] cam_x,
    input  wire [9:0]  cam_y,
    input  wire [10:0] car1_x,
    input  wire [9:0]  car1_y,
    input  wire [10:0] car2_x,
    input  wire [9:0]  car2_y,
    input  wire [9:0]  car1_heading,
    input  wire [9:0]  car2_heading,
    output reg  [15:0] pixel_out,
    output reg         pixel_out_valid
);

    (* ram_style = "block" *)
    reg [15:0] sprite_bram [0:4095];

    wire [10:0] world_x = h_count_d2 + cam_x;
    wire [10:0] world_y = v_count_d2 + cam_y;

    wire signed [11:0] dx1 = world_x - car1_x;
    wire signed [11:0] dy1 = world_y - car1_y;
    wire car1_hit = (dx1 >= -8) && (dx1 < 8) && (dy1 >= -8) && (dy1 < 8);
    wire [3:0] car1_px = dx1[3:0] + 4'd8;
    wire [3:0] car1_py = dy1[3:0] + 4'd8;

    wire signed [11:0] dx2 = world_x - car2_x;
    wire signed [11:0] dy2 = world_y - car2_y;
    wire car2_hit = (dx2 >= -8) && (dx2 < 8) && (dy2 >= -8) && (dy2 < 8);
    wire [3:0] car2_px = dx2[3:0] + 4'd8;
    wire [3:0] car2_py = dy2[3:0] + 4'd8;

    wire [11:0] sprite_addr;
    wire [2:0]  car1_frame;
    wire [2:0]  car2_frame;
    wire        any_hit;
    assign car1_frame = car1_heading[9:7];
    assign car2_frame = car2_heading[9:7];
    assign any_hit = car1_hit | car2_hit;
    assign sprite_addr = car1_hit ? {1'b0, car1_frame, car1_py, car1_px} :
                         car2_hit ? {1'b1, car2_frame, car2_py, car2_px} :
                                    12'd0;

    reg [15:0] sprite_color;
    reg        any_hit_d1;
    reg [15:0] tile_color_d1;
    reg        tile_valid_d1;

    always @(posedge clk) begin
        sprite_color  <= sprite_bram[sprite_addr];
        any_hit_d1    <= any_hit;
        tile_color_d1 <= tile_color;
        tile_valid_d1 <= tile_valid;
    end

    wire sprite_opaque = (sprite_color != 16'h0000);

    always @(*) begin
        if (any_hit_d1 && sprite_opaque)
            pixel_out = sprite_color;
        else
            pixel_out = tile_color_d1;
        pixel_out_valid = tile_valid_d1;
    end

    initial begin
    $readmemh("C:/Users/yilka/programming/infoproc/InfoProcTopLevel/sprites.hex", sprite_bram);
    end


endmodule

// ============================================================================
// Module: racing_renderer_axi
// ============================================================================
// Split-screen renderer for 2-player racing.
//   - Top half (lines 0-238): Player 1 viewport (cam1)
//   - Divider (lines 239-240): white line
//   - Bottom half (lines 241-479): Player 2 viewport (cam2)
// ============================================================================

module racing_renderer_axi #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 7
)(
    // AXI4-Lite slave interface
    input  wire                                S_AXI_ACLK,
    input  wire                                S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_AWADDR,
    input  wire [2:0]                          S_AXI_AWPROT,
    input  wire                                S_AXI_AWVALID,
    output wire                                S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   S_AXI_WSTRB,
    input  wire                                S_AXI_WVALID,
    output wire                                S_AXI_WREADY,
    output wire [1:0]                          S_AXI_BRESP,
    output wire                                S_AXI_BVALID,
    input  wire                                S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_ARADDR,
    input  wire [2:0]                          S_AXI_ARPROT,
    input  wire                                S_AXI_ARVALID,
    output wire                                S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_RDATA,
    output wire [1:0]                          S_AXI_RRESP,
    output wire                                S_AXI_RVALID,
    input  wire                                S_AXI_RREADY,

    // Clock input
    input  wire                                clk_125mhz,

    // HDMI output
    output wire [2:0]                          tmds_data_p,
    output wire [2:0]                          tmds_data_n,
    output wire                                tmds_clk_p,
    output wire                                tmds_clk_n
);

    // AXI registers -> position values
    wire [10:0] cam1_x, car1_x, car2_x, cam2_x;
    wire [9:0]  cam1_y, car1_y, car2_y, cam2_y;
    wire [9:0]  car1_heading, car2_heading;

    // Hardware frame counter
    wire [31:0] frame_counter_wire;

    axi_registers #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) u_regs (
        .S_AXI_ACLK    (S_AXI_ACLK),
        .S_AXI_ARESETN (S_AXI_ARESETN),
        .S_AXI_AWADDR  (S_AXI_AWADDR),
        .S_AXI_AWPROT  (S_AXI_AWPROT),
        .S_AXI_AWVALID (S_AXI_AWVALID),
        .S_AXI_AWREADY (S_AXI_AWREADY),
        .S_AXI_WDATA   (S_AXI_WDATA),
        .S_AXI_WSTRB   (S_AXI_WSTRB),
        .S_AXI_WVALID  (S_AXI_WVALID),
        .S_AXI_WREADY  (S_AXI_WREADY),
        .S_AXI_BRESP   (S_AXI_BRESP),
        .S_AXI_BVALID  (S_AXI_BVALID),
        .S_AXI_BREADY  (S_AXI_BREADY),
        .S_AXI_ARADDR  (S_AXI_ARADDR),
        .S_AXI_ARPROT  (S_AXI_ARPROT),
        .S_AXI_ARVALID (S_AXI_ARVALID),
        .S_AXI_ARREADY (S_AXI_ARREADY),
        .S_AXI_RDATA   (S_AXI_RDATA),
        .S_AXI_RRESP   (S_AXI_RRESP),
        .S_AXI_RVALID  (S_AXI_RVALID),
        .S_AXI_RREADY  (S_AXI_RREADY),
        .frame_count_in(frame_counter_wire),
        .cam1_x        (cam1_x),
        .cam1_y        (cam1_y),
        .car1_x        (car1_x),
        .car1_y        (car1_y),
        .car2_x        (car2_x),
        .car2_y        (car2_y),
        .car1_heading  (car1_heading),
        .car2_heading  (car2_heading),
        .cam2_x        (cam2_x),
        .cam2_y        (cam2_y)
    );

    // Clock generation
    wire clk_25, clk_125_int, mmcm_locked;

    clock_gen u_clkgen (
        .clk_125mhz_in (clk_125mhz),
        .reset          (1'b0),
        .clk_25mhz     (clk_25),
        .clk_125mhz    (clk_125_int),
        .locked         (mmcm_locked)
    );

    // Reset logic
    reg [7:0] reset_counter = 8'hFF;
    wire pixel_reset = ~mmcm_locked | (reset_counter != 0);

    always @(posedge clk_25) begin
        if (~mmcm_locked)
            reset_counter <= 8'hFF;
        else if (reset_counter != 0)
            reset_counter <= reset_counter - 1;
    end

    // VGA timing
    wire [9:0] h_count, v_count;
    wire       hsync, vsync, active;

    vga_timing u_timing (
        .clk_25mhz (clk_25),
        .reset      (pixel_reset),
        .h_count    (h_count),
        .v_count    (v_count),
        .hsync      (hsync),
        .vsync      (vsync),
        .active     (active)
    );

    // Frame counter (increments on vsync rising edge)
    reg [31:0] frame_counter;
    reg vsync_prev;
    always @(posedge clk_25) begin
        vsync_prev <= vsync;
        if (pixel_reset)
            frame_counter <= 32'd0;
        else if (vsync && !vsync_prev)
            frame_counter <= frame_counter + 1;
    end
    assign frame_counter_wire = frame_counter;

    // Synchronize AXI registers into pixel clock domain
    reg [10:0] cam1_x_sync, car1_x_sync, car2_x_sync, cam2_x_sync;
    reg [9:0]  cam1_y_sync, car1_y_sync, car2_y_sync, cam2_y_sync;
    reg [9:0]  car1_heading_sync, car2_heading_sync;

    always @(posedge clk_25) begin
        cam1_x_sync  <= cam1_x;
        cam1_y_sync  <= cam1_y;
        car1_x_sync  <= car1_x;
        car1_y_sync  <= car1_y;
        car2_x_sync  <= car2_x;
        car2_y_sync  <= car2_y;
        car1_heading_sync <= car1_heading;
        car2_heading_sync <= car2_heading;
        cam2_x_sync  <= cam2_x;
        cam2_y_sync  <= cam2_y;
    end

    // Split-screen: remap v_count to 0-239 for both halves
    wire top_half = (v_count < 10'd240);
    wire [9:0] local_v = top_half ? v_count : (v_count - 10'd240);

    // Camera mux
    wire [10:0] active_cam_x = top_half ? cam1_x_sync : cam2_x_sync;
    wire [9:0]  active_cam_y = top_half ? cam1_y_sync : cam2_y_sync;

    // Tile renderer - gets local_v (0-239), not raw v_count
    wire [15:0] tile_color;
    wire        tile_valid;

    tile_renderer u_tiles (
        .clk            (clk_25),
        .reset          (pixel_reset),
        .h_count        (h_count),
        .v_count        (local_v),
        .active         (active),
        .cam_x          (active_cam_x),
        .cam_y          (active_cam_y),
        .pixel_rgb565   (tile_color),
        .pixel_valid    (tile_valid)
    );

    // Pipeline delay (2 cycles to match tile pipeline)
    reg [9:0] h_d1, h_d2;
    reg [9:0] lv_d1, lv_d2;
    reg       top_half_d1, top_half_d2;
    always @(posedge clk_25) begin
        h_d1  <= h_count;   h_d2  <= h_d1;
        lv_d1 <= local_v;   lv_d2 <= lv_d1;
        top_half_d1 <= top_half;  top_half_d2 <= top_half_d1;
    end

    // Re-mux camera delayed to match sprite timing
    wire [10:0] cam_x_d2 = top_half_d2 ? cam1_x_sync : cam2_x_sync;
    wire [9:0]  cam_y_d2 = top_half_d2 ? cam1_y_sync : cam2_y_sync;

    // Sprite overlay - gets lv_d2 (0-239 remapped) and correctly delayed camera
    wire [15:0] sprite_color;
    wire        sprite_valid;

    sprite_overlay u_sprites (
        .clk            (clk_25),
        .reset          (pixel_reset),
        .tile_color     (tile_color),
        .tile_valid     (tile_valid),
        .h_count_d2     (h_d2),
        .v_count_d2     (lv_d2),
        .cam_x          (cam_x_d2),
        .cam_y          (cam_y_d2),
        .car1_x         (car1_x_sync),
        .car1_y         (car1_y_sync),
        .car2_x         (car2_x_sync),
        .car2_y         (car2_y_sync),
        .car1_heading   (car1_heading_sync),
        .car2_heading   (car2_heading_sync),
        .pixel_out      (sprite_color),
        .pixel_out_valid(sprite_valid)
    );

    // Divider line - uses raw v_count delayed, NOT local_v
    reg [9:0] v_raw_d1, v_raw_d2;
    always @(posedge clk_25) begin
        v_raw_d1 <= v_count;  v_raw_d2 <= v_raw_d1;
    end
    wire divider = (v_raw_d2 == 10'd239) || (v_raw_d2 == 10'd240);

    wire [15:0] final_color = divider ? 16'hFFFF : sprite_color;
    wire        final_valid = sprite_valid;



    // Sync signal pipeline delay (3 cycles: tile + sprite + composite)
    reg hsync_d1, hsync_d2, hsync_d3;
    reg vsync_d1, vsync_d2, vsync_d3;
    reg active_d1, active_d2, active_d3;
    always @(posedge clk_25) begin
        hsync_d1  <= hsync;   hsync_d2  <= hsync_d1;   hsync_d3  <= hsync_d2;
        vsync_d1  <= vsync;   vsync_d2  <= vsync_d1;   vsync_d3  <= vsync_d2;
        active_d1 <= active;  active_d2 <= active_d1;  active_d3 <= active_d2;
    end

    // RGB565 to RGB888
    wire [7:0] r8 = final_valid ? {final_color[15:11], final_color[15:13]} : 8'd0;
    wire [7:0] g8 = final_valid ? {final_color[10:5],  final_color[10:9]}  : 8'd0;
    wire [7:0] b8 = final_valid ? {final_color[4:0],   final_color[4:2]}   : 8'd0;

    // HDMI output
    hdmi_out u_hdmi (
        .clk_25mhz   (clk_25),
        .clk_125mhz  (clk_125_int),
        .reset        (pixel_reset),
        .red          (r8),
        .green        (g8),
        .blue         (b8),
        .hsync        (hsync_d3),
        .vsync        (vsync_d3),
        .active       (active_d3),
        .tmds_data_p  (tmds_data_p),
        .tmds_data_n  (tmds_data_n),
        .tmds_clk_p   (tmds_clk_p),
        .tmds_clk_n   (tmds_clk_n)
    );

endmodule

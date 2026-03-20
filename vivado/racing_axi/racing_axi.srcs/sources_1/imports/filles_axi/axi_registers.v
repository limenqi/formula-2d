// ============================================================================
// Module: axi_registers
// ============================================================================
// AXI4-Lite slave for split-screen racing renderer.
//
// REGISTER MAP (each register is 32 bits wide):
//   Offset 0x00: cam1_x       (bits [10:0])  camera 1 X position
//   Offset 0x04: cam1_y       (bits [9:0])   camera 1 Y position
//   Offset 0x08: car1_x       (bits [10:0])  player 1 X position
//   Offset 0x0C: car1_y       (bits [9:0])   player 1 Y position
//   Offset 0x10: car2_x       (bits [10:0])  player 2 X position
//   Offset 0x14: car2_y       (bits [9:0])   player 2 Y position
//   Offset 0x18: car1_heading (bits [9:0])   player 1 heading
//   Offset 0x1C: car2_heading (bits [9:0])   player 2 heading
//   Offset 0x20: cam2_x       (bits [10:0])  camera 2 X position
//   Offset 0x24: cam2_y       (bits [9:0])   camera 2 Y position
//   Offset 0x28: (reserved)
//   Offset 0x2C: frame_count  (bits [31:0])  read-only 60fps counter
// ============================================================================

module axi_registers #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 7    // 7 bits = 128 bytes = 32 registers max
)(
    // AXI4-Lite slave interface
    input  wire                                S_AXI_ACLK,
    input  wire                                S_AXI_ARESETN,

    // Write address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_AWADDR,
    input  wire [2:0]                          S_AXI_AWPROT,
    input  wire                                S_AXI_AWVALID,
    output wire                                S_AXI_AWREADY,

    // Write data channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   S_AXI_WSTRB,
    input  wire                                S_AXI_WVALID,
    output wire                                S_AXI_WREADY,

    // Write response channel
    output wire [1:0]                          S_AXI_BRESP,
    output wire                                S_AXI_BVALID,
    input  wire                                S_AXI_BREADY,

    // Read address channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_ARADDR,
    input  wire [2:0]                          S_AXI_ARPROT,
    input  wire                                S_AXI_ARVALID,
    output wire                                S_AXI_ARREADY,

    // Read data channel
    output wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_RDATA,
    output wire [1:0]                          S_AXI_RRESP,
    output wire                                S_AXI_RVALID,
    input  wire                                S_AXI_RREADY,

    // Hardware frame counter input (read-only register)
    input  wire [31:0] frame_count_in,

    // Register outputs to renderer
    output wire [10:0] cam1_x,
    output wire [9:0]  cam1_y,
    output wire [10:0] car1_x,
    output wire [9:0]  car1_y,
    output wire [10:0] car2_x,
    output wire [9:0]  car2_y,
    output wire [9:0]  car1_heading,
    output wire [9:0]  car2_heading,
    output wire [10:0] cam2_x,
    output wire [9:0]  cam2_y
);

    // Internal AXI signals
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg        axi_awready;
    reg        axi_wready;
    reg [1:0]  axi_bresp;
    reg        axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    reg        axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0]  axi_rresp;
    reg        axi_rvalid;

    // The 10 registers
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_cam1_x;        // 0x00  idx 0
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_cam1_y;        // 0x04  idx 1
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_car1_x;        // 0x08  idx 2
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_car1_y;        // 0x0C  idx 3
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_car2_x;        // 0x10  idx 4
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_car2_y;        // 0x14  idx 5
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_car1_heading;  // 0x18  idx 6
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_car2_heading;  // 0x1C  idx 7
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_cam2_x;        // 0x20  idx 8
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_cam2_y;        // 0x24  idx 9

    // Output assignments
    assign cam1_x       = reg_cam1_x[10:0];
    assign cam1_y       = reg_cam1_y[9:0];
    assign car1_x       = reg_car1_x[10:0];
    assign car1_y       = reg_car1_y[9:0];
    assign car2_x       = reg_car2_x[10:0];
    assign car2_y       = reg_car2_y[9:0];
    assign car1_heading = reg_car1_heading[9:0];
    assign car2_heading = reg_car2_heading[9:0];
    assign cam2_x       = reg_cam2_x[10:0];
    assign cam2_y       = reg_cam2_y[9:0];

    // Connect AXI outputs
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // Write address handshake
    always @(posedge S_AXI_ACLK) begin
        if (~S_AXI_ARESETN) begin
            axi_awready <= 1'b0;
            axi_awaddr  <= 0;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID) begin
                axi_awready <= 1'b1;
                axi_awaddr  <= S_AXI_AWADDR;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end

    // Write data handshake
    always @(posedge S_AXI_ACLK) begin
        if (~S_AXI_ARESETN)
            axi_wready <= 1'b0;
        else if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID)
            axi_wready <= 1'b1;
        else
            axi_wready <= 1'b0;
    end

    // Write to registers
    wire wr_en = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;
    wire [4:0] wr_addr = axi_awaddr[6:2];  // 5-bit register index (word-aligned)

    always @(posedge S_AXI_ACLK) begin
        if (~S_AXI_ARESETN) begin
            reg_cam1_x       <= 32'd200;
            reg_cam1_y       <= 32'd560;
            reg_car1_x       <= 32'd590;
            reg_car1_y       <= 32'd810;
            reg_car2_x       <= 32'd610;
            reg_car2_y       <= 32'd825;
            reg_car1_heading <= 32'd0;
            reg_car2_heading <= 32'd0;
            reg_cam2_x       <= 32'd200;
            reg_cam2_y       <= 32'd560;
        end else if (wr_en) begin
            case (wr_addr)
                5'd0:  reg_cam1_x       <= S_AXI_WDATA;
                5'd1:  reg_cam1_y       <= S_AXI_WDATA;
                5'd2:  reg_car1_x       <= S_AXI_WDATA;
                5'd3:  reg_car1_y       <= S_AXI_WDATA;
                5'd4:  reg_car2_x       <= S_AXI_WDATA;
                5'd5:  reg_car2_y       <= S_AXI_WDATA;
                5'd6:  reg_car1_heading <= S_AXI_WDATA;
                5'd7:  reg_car2_heading <= S_AXI_WDATA;
                5'd8:  reg_cam2_x       <= S_AXI_WDATA;
                5'd9:  reg_cam2_y       <= S_AXI_WDATA;
                default: ;
            endcase
        end
    end

    // Write response
    always @(posedge S_AXI_ACLK) begin
        if (~S_AXI_ARESETN) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end else begin
            if (wr_en && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b00;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // Read address handshake
    always @(posedge S_AXI_ACLK) begin
        if (~S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_araddr  <= 0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr  <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    // Read data
    always @(posedge S_AXI_ACLK) begin
        if (~S_AXI_ARESETN) begin
            axi_rvalid <= 1'b0;
            axi_rresp  <= 2'b00;
        end else begin
            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b00;
                case (axi_araddr[6:2])
                    5'd0:  axi_rdata <= reg_cam1_x;
                    5'd1:  axi_rdata <= reg_cam1_y;
                    5'd2:  axi_rdata <= reg_car1_x;
                    5'd3:  axi_rdata <= reg_car1_y;
                    5'd4:  axi_rdata <= reg_car2_x;
                    5'd5:  axi_rdata <= reg_car2_y;
                    5'd6:  axi_rdata <= reg_car1_heading;
                    5'd7:  axi_rdata <= reg_car2_heading;
                    5'd8:  axi_rdata <= reg_cam2_x;
                    5'd9:  axi_rdata <= reg_cam2_y;
                    5'd11: axi_rdata <= frame_count_in;  // read-only
                    default: axi_rdata <= 32'd0;
                endcase
            end else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

endmodule

// ============================================================================
// Module: vga_timing
// ============================================================================
// This module generates the timing signals for a 640x480 @ 60Hz display.
//
// HOW IT WORKS:
// Think of it like reading a book:
//   - h_count goes left to right (0 to 799) for each line
//   - When h_count reaches the end, it resets and v_count moves down one line
//   - v_count goes top to bottom (0 to 524) for each frame
//   - When v_count reaches the end, one full frame is done (happens 60x/sec)
//
// The first 640 of each line are the visible pixels.
// The first 480 lines are the visible lines.
// Everything else is "blanking" - invisible timing the monitor needs.
//
// TIMING DIAGRAM (horizontal):
//   |<--- 640 visible --->|<-16->|<-96->|<-48->|
//   |    active pixels    |front | sync | back |
//   |                     |porch |pulse |porch |
//   |<-------------- 800 total ------------->|
//
// TIMING DIAGRAM (vertical):
//   |<--- 480 visible --->|<-10->|<--2-->|<-33->|
//   |    active lines     |front | sync  | back |
//   |                     |porch | pulse |porch |
//   |<-------------- 525 total ------------->|
//
// OUTPUTS:
//   h_count, v_count  = current pixel position (for tile lookup)
//   hsync, vsync      = sync signals the monitor needs
//   active             = HIGH when we're in the visible area (640x480)
//                        When active=0, output black (don't draw anything)
// ============================================================================

module vga_timing (
    input  wire        clk_25mhz,   // 25.175 MHz pixel clock
    input  wire        reset,        // active-high reset
    
    output reg  [9:0]  h_count,     // horizontal pixel counter (0-799)
    output reg  [9:0]  v_count,     // vertical line counter (0-524)
    output wire        hsync,        // horizontal sync signal to monitor
    output wire        vsync,        // vertical sync signal to monitor
    output wire        active        // HIGH = visible pixel, LOW = blanking
);

    // ── Timing constants for 640x480 @ 60Hz ──
    // These numbers are from the VESA standard - don't change them!
    
    // Horizontal timing (in pixels)
    localparam H_ACTIVE  = 640;  // visible pixels per line
    localparam H_FRONT   = 16;   // front porch (gap before sync)
    localparam H_SYNC    = 96;   // sync pulse width
    localparam H_BACK    = 48;   // back porch (gap after sync)
    localparam H_TOTAL   = 800;  // total pixels per line (640+16+96+48)
    
    // Vertical timing (in lines)
    localparam V_ACTIVE  = 480;  // visible lines per frame
    localparam V_FRONT   = 10;   // front porch
    localparam V_SYNC    = 2;    // sync pulse width
    localparam V_BACK    = 33;   // back porch
    localparam V_TOTAL   = 525;  // total lines per frame (480+10+2+33)

    // ── Horizontal counter ──
    // Counts from 0 to 799, then wraps back to 0
    always @(posedge clk_25mhz) begin
        if (reset) begin
            h_count <= 10'd0;
        end else begin
            if (h_count == H_TOTAL - 1)
                h_count <= 10'd0;      // reached end of line, reset
            else
                h_count <= h_count + 1; // move to next pixel
        end
    end

    // ── Vertical counter ──
    // Increments by 1 each time we finish a horizontal line
    always @(posedge clk_25mhz) begin
        if (reset) begin
            v_count <= 10'd0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                // We just finished a line
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;      // finished frame, start over
                else
                    v_count <= v_count + 1; // move to next line
            end
        end
    end

    // ── Sync signals ──
    // hsync and vsync are active LOW (the monitor expects this for 640x480)
    // They go LOW during the sync pulse region
    assign hsync = ~((h_count >= H_ACTIVE + H_FRONT) && 
                     (h_count <  H_ACTIVE + H_FRONT + H_SYNC));
    
    assign vsync = ~((v_count >= V_ACTIVE + V_FRONT) && 
                     (v_count <  V_ACTIVE + V_FRONT + V_SYNC));

    // ── Active signal ──
    // HIGH only when we're in the visible 640x480 area
    assign active = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);

endmodule

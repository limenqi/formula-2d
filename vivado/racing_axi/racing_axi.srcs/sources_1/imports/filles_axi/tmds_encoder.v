// Converts an 8-bit color value into a 10-bit TMDS encoded value.
// HDMI/DVI requires this encoding for each of the 3 color channels.

// WHAT IS TMDS?
//   Our monitor doesn't receive raw RGB values. Instead, each 8-bit color
//   gets encoded into 10 bits using a special algorithm that minimizes
//   signal transitions (reduces interference on the cable).

//   During blanking (non-visible pixels), special control codes are sent
//   instead, which the monitor uses for synchronization

module tmds_encoder (
    input  wire       clk,       // pixel clock (25 MHz)
    input  wire       reset,
    input  wire [7:0] din,       // 8-bit color input
    input  wire       c0,        // control bit 0 (hsync for blue channel)
    input  wire       c1,        // control bit 1 (vsync for blue channel)
    input  wire       de,        // data enable (HIGH = active pixel)
    output reg  [9:0] dout       // 10-bit TMDS encoded output
);

    // Count number of 1s in the input
    wire [3:0] n_ones = din[0] + din[1] + din[2] + din[3] +
                        din[4] + din[5] + din[6] + din[7];

    // Step 1: Transition minimization
    wire use_xnor = (n_ones > 4) || (n_ones == 4 && din[0] == 0);
    
    wire [8:0] q_m;
    assign q_m[0] = din[0];
    assign q_m[1] = use_xnor ? ~(q_m[0] ^ din[1]) : (q_m[0] ^ din[1]);
    assign q_m[2] = use_xnor ? ~(q_m[1] ^ din[2]) : (q_m[1] ^ din[2]);
    assign q_m[3] = use_xnor ? ~(q_m[2] ^ din[3]) : (q_m[2] ^ din[3]);
    assign q_m[4] = use_xnor ? ~(q_m[3] ^ din[4]) : (q_m[3] ^ din[4]);
    assign q_m[5] = use_xnor ? ~(q_m[4] ^ din[5]) : (q_m[4] ^ din[5]);
    assign q_m[6] = use_xnor ? ~(q_m[5] ^ din[6]) : (q_m[5] ^ din[6]);
    assign q_m[7] = use_xnor ? ~(q_m[6] ^ din[7]) : (q_m[6] ^ din[7]);
    assign q_m[8] = use_xnor ? 1'b0 : 1'b1;

    // Count 1s and 0s in q_m[7:0]
    wire [3:0] n_ones_qm = q_m[0] + q_m[1] + q_m[2] + q_m[3] +
                            q_m[4] + q_m[5] + q_m[6] + q_m[7];
    wire [3:0] n_zeros_qm = 4'd8 - n_ones_qm;

    // Step 2: DC balancing
    reg signed [4:0] cnt;  // running disparity counter

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            dout <= 10'b0;
            cnt  <= 5'sd0;
        end else begin
            if (de) begin
                // Active pixel - encode data
                if (cnt == 0 || n_ones_qm == n_zeros_qm) begin
                    dout[9]   <= ~q_m[8];
                    dout[8]   <= q_m[8];
                    dout[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];
                    if (q_m[8] == 0)
                        cnt <= cnt + (n_zeros_qm - n_ones_qm);
                    else
                        cnt <= cnt + (n_ones_qm - n_zeros_qm);
                end else begin
                    if ((cnt > 0 && n_ones_qm > n_zeros_qm) ||
                        (cnt < 0 && n_zeros_qm > n_ones_qm)) begin
                        dout[9]   <= 1'b1;
                        dout[8]   <= q_m[8];
                        dout[7:0] <= ~q_m[7:0];
                        cnt <= cnt + {3'b0, q_m[8], 1'b0} + (n_zeros_qm - n_ones_qm);
                    end else begin
                        dout[9]   <= 1'b0;
                        dout[8]   <= q_m[8];
                        dout[7:0] <= q_m[7:0];
                        cnt <= cnt - {3'b0, ~q_m[8], 1'b0} + (n_ones_qm - n_zeros_qm);
                    end
                end
            end else begin
                // Blanking period - send control tokens
                cnt <= 5'sd0;
                case ({c1, c0})
                    2'b00: dout <= 10'b1101010100;
                    2'b01: dout <= 10'b0010101011;
                    2'b10: dout <= 10'b0101010100;
                    2'b11: dout <= 10'b1010101011;
                endcase
            end
        end
    end

endmodule

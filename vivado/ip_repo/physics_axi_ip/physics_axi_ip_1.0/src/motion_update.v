`timescale 1ns / 1ps

module motion_update (
    input  wire [23:0] cur_x,   
    input  wire [23:0] cur_y,
    input  wire [15:0] speed,
    input  wire signed [11:0] cos_val,  
    input  wire signed [11:0] sin_val,
    output reg  [23:0] x_try,
    output reg  [23:0] y_try
);

    reg signed [27:0] dx_full;  // raw multiplication results
    reg signed [27:0] dy_full;  
    reg signed [23:0] dx_step;  // scaled movement after shifting
    reg signed [23:0] dy_step;
    reg signed [24:0] x_sum;    
    reg signed [24:0] y_sum;

    always @(*) begin
        dx_full = $signed({1'b0, speed}) * cos_val; // cast speed to be signed positive (so signed multiplication works)
        dy_full = $signed({1'b0, speed}) * sin_val;

        // arithmetic shift (>>>) preserves the signed logic
        // multiplying speed (q8.8) by cos/sin_val (q1.10) creates a output of q?.18
        // the output position format only has 8 fractional bits 
        // so shift right by 10 bits
        dx_step = dx_full >>> 10;
        dy_step = dy_full >>> 10;

        x_sum = $signed({1'b0, cur_x}) + dx_step;
        y_sum = $signed({1'b0, cur_y}) + dy_step;

        if (x_sum < 0)
            x_try = 24'd0;
        else
            x_try = x_sum[23:0];

        if (y_sum < 0)
            y_try = 24'd0;
        else
            y_try = y_sum[23:0];
    end

endmodule

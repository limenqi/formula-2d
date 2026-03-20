`timescale 1ns / 1ps

module heading_update #(
    parameter integer HEADING_BITS = 10,
    parameter integer TURN_STEP = 10'd16    // max turn units per tick (out of 1024) = 16 (works out to 337 degrees / second)
) (
    input  wire [HEADING_BITS-1:0] cur_heading,
    input  wire [HEADING_BITS-1:0] target_heading,
    output reg  [HEADING_BITS-1:0] next_heading
);

    localparam integer HEADING_MAX  = 1 << HEADING_BITS;    // heading max = 1024 
    localparam integer HALF_TURN    = HEADING_MAX >> 1;     // half turn = 512
    localparam [HEADING_BITS-1:0] TURN_STEP_VALUE = TURN_STEP[HEADING_BITS-1:0];

    integer diff_signed;

    always @(*) begin
        diff_signed = $signed({1'b0, target_heading}) - $signed({1'b0, cur_heading});

        // compares the current current heading against target heading, determines whether clockwise or anti clockwise is shorter
        if (diff_signed > HALF_TURN)
            diff_signed = diff_signed - HEADING_MAX;
        else if (diff_signed < -HALF_TURN)
            diff_signed = diff_signed + HEADING_MAX;

        // update next heading by adding turn step value to the current heading until the current heading = next heading
        if (diff_signed > TURN_STEP)
            next_heading = cur_heading + TURN_STEP_VALUE;
        else if (diff_signed < -TURN_STEP)
            next_heading = cur_heading - TURN_STEP_VALUE;
        else
            next_heading = target_heading;
    end

endmodule

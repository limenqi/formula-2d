`timescale 1ns / 1ps

module speed_update #(
    parameter [15:0] ACCEL_STEP = 16'd24,
    parameter [15:0] DECEL_STEP = 16'd12,
    parameter [15:0] MAX_SPEED  = 16'd768
) (
    input  wire [15:0] cur_speed,
    input  wire        throttle,
    output reg  [15:0] next_speed
);

    reg [16:0] speed_ext;

    // if throttle applied, accelerate at max rate of accel_step until max speed is reached
    // else, decelerate at rate of decel_step until 0
    always @(*) begin
        if (throttle) begin
            speed_ext = {1'b0, cur_speed} + ACCEL_STEP;
            if (speed_ext[15:0] > MAX_SPEED || speed_ext[16])
                next_speed = MAX_SPEED;
            else
                next_speed = speed_ext[15:0];
        end else begin
            if (cur_speed > DECEL_STEP)
                next_speed = cur_speed - DECEL_STEP;
            else
                next_speed = 16'd0;
        end
    end

endmodule

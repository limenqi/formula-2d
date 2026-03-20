`timescale 1ns / 1ps

module physics_top (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire [23:0] cur_x,
    input  wire [23:0] cur_y,
    input  wire [9:0]  cur_heading,
    input  wire [15:0] cur_speed,
    input  wire [9:0]  target_heading,
    input  wire        throttle,
    output reg         busy,
    output reg         done,
    output reg  [23:0] next_x,
    output reg  [23:0] next_y,
    output reg  [9:0]  next_heading,
    output reg  [15:0] next_speed,
    output reg  [7:0]  status_flags
);

    wire [9:0] heading_calc;
    wire [15:0] speed_calc;
    wire signed [11:0] cos_val;
    wire signed [11:0] sin_val;
    wire [23:0] x_try;
    wire [23:0] y_try;
    wire [7:0] surface_meta;
    wire [23:0] resp_x;
    wire [23:0] resp_y;
    wire [15:0] resp_speed;
    wire [7:0] resp_flags;

    heading_update u_heading (
        .cur_heading(cur_heading),
        .target_heading(target_heading),
        .next_heading(heading_calc)
    );

    speed_update u_speed (
        .cur_speed(cur_speed),
        .throttle(throttle),
        .next_speed(speed_calc)
    );

    dir_lut u_lut (
        .heading(heading_calc),
        .cos_val(cos_val),
        .sin_val(sin_val)
    );

    motion_update u_motion (
        .cur_x(cur_x),
        .cur_y(cur_y),
        .speed(speed_calc),
        .cos_val(cos_val),
        .sin_val(sin_val),
        .x_try(x_try),
        .y_try(y_try)
    );

    track_lookup u_track (
        .x_pos(x_try),
        .y_pos(y_try),
        .surface_meta(surface_meta)
    );

    collision_response u_collision (
        .cur_x(cur_x),
        .cur_y(cur_y),
        .x_try(x_try),
        .y_try(y_try),
        .speed_try(speed_calc),
        .surface_meta(surface_meta),
        .next_x(resp_x),
        .next_y(resp_y),
        .next_speed(resp_speed),
        .status_flags(resp_flags)
    );

    always @(posedge clk) begin
        if (reset) begin
            busy <= 1'b0;
            done <= 1'b0;
            next_x <= 24'd0;
            next_y <= 24'd0;
            next_heading <= 10'd0;
            next_speed <= 16'd0;
            status_flags <= 8'd0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                busy <= 1'b1;
            end else if (busy) begin
                next_x <= resp_x;
                next_y <= resp_y;
                next_heading <= heading_calc;
                next_speed <= resp_speed;
                status_flags <= resp_flags;
                busy <= 1'b0;
                done <= 1'b1;
            end
        end
    end

endmodule

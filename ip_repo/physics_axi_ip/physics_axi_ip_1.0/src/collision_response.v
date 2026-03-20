`timescale 1ns / 1ps

module collision_response (
    input  wire [23:0] cur_x,
    input  wire [23:0] cur_y,
    input  wire [23:0] x_try,
    input  wire [23:0] y_try,
    input  wire [15:0] speed_try,
    input  wire [7:0]  surface_meta,
    output reg  [23:0] next_x,
    output reg  [23:0] next_y,
    output reg  [15:0] next_speed,
    output reg  [7:0]  status_flags
);

    wire [1:0] surface_type = surface_meta[1:0];
    wire wall_hit = (surface_type == 2'b10);
    wire grass_hit = (surface_type == 2'b01);
    wire checkpoint_hit = surface_meta[2];

    always @(*) begin
        status_flags = 8'd0;

        if (wall_hit) begin
            next_x = cur_x;
            next_y = cur_y;
            next_speed = speed_try >> 1;    // speed halved
            status_flags[0] = 1'b1; // wall collision flag
        end else begin
            next_x = x_try;
            next_y = y_try;
            next_speed = speed_try;

            if (grass_hit) begin
                next_speed = speed_try - (speed_try >> 2);  // speed is reduced by 25%
                status_flags[1] = 1'b1; // grass flag
            end

            if (checkpoint_hit)
                status_flags[2] = 1'b1; // checkpoint flag
        end
    end

endmodule

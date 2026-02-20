`timescale 1ns / 1ps

module priority_controller (
    input clk,
    input reset,
    input i_btn_m,
    input i_btn_r,
    input i_btn_l,
    input i_btn_u,
    input i_btn_d,
    output reg o_btn_m,
    output reg o_btn_r,
    output reg o_btn_l,
    output reg o_btn_u,
    output reg o_btn_d
);

    reg [4:0] btn_prev;
    wire [4:0] btn_edge;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            btn_prev <= 5'b0;
        end else begin
            btn_prev <= {i_btn_m, i_btn_r, i_btn_l, i_btn_u, i_btn_d};
        end
    end

    assign btn_edge = {i_btn_m, i_btn_r, i_btn_l, i_btn_u, i_btn_d} & ~btn_prev;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            o_btn_m <= 1'b0;
            o_btn_r <= 1'b0;
            o_btn_l <= 1'b0;
            o_btn_u <= 1'b0;
            o_btn_d <= 1'b0;
        end else begin
            o_btn_m <= 1'b0;
            o_btn_r <= 1'b0;
            o_btn_l <= 1'b0;
            o_btn_u <= 1'b0;
            o_btn_d <= 1'b0;

            if (btn_edge[4]) begin
                o_btn_m <= 1'b1;
            end else if (btn_edge[3]) begin
                o_btn_r <= 1'b1;
            end else if (btn_edge[2]) begin
                o_btn_l <= 1'b1;
            end else if (btn_edge[1]) begin
                o_btn_u <= 1'b1;
            end else if (btn_edge[0]) begin
                o_btn_d <= 1'b1;
            end
        end
    end

endmodule
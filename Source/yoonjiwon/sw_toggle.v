`timescale 1ns / 1ps

module sw_toggle (
    input      clk,
    input      reset,
    input      tick,   
    output reg state   
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= 1'b0;
        end else if (tick) begin
            state <= ~state;  
        end
    end
endmodule
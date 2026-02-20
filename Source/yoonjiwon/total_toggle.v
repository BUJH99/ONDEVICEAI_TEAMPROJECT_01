`timescale 1ns / 1ps


module total_toggle (

    input        clk,
    input        reset,
    input  [2:0] uart_sw,
    output       o_uart_0,
    output       o_uart_1,
    output       o_uart_2


);

    sw_toggle U_SW_0 (
        .clk  (clk),
        .reset(reset),
        .tick (uart_sw[0]),
        .state(o_uart_0)
    );

    sw_toggle U_SW_1 (
        .clk  (clk),
        .reset(reset),
        .tick (uart_sw[1]),
        .state(o_uart_1)
    );

    sw_toggle U_SW_2 (
        .clk  (clk),
        .reset(reset),
        .tick (uart_sw[2]),
        .state(o_uart_2)
    );

endmodule

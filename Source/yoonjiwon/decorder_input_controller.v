`timescale 1ns / 1ps



module decorder_input_controller (

    input clk,
    input reset,
    input [4:0] i_btn_fpga,
    input [2:0] i_sw_fpga,
    input [7:0] i_uart_data,
    input i_uart_done,
    output [7:0] select_data
);
    wire [7:0] w_decorder_data;

    ascii_decorder U_DECORDER (

        .clk(clk),
        .reset(reset),
        .uart_data(i_uart_data),
        .uart_done(i_uart_done),
        .uart_mode(w_decorder_data)

    );

    or_input_controller U_IN_CONTROLLER (

        .clk(clk),
        .reset(reset),
        .btn(i_btn_fpga),
        .sw(i_sw_fpga),
        .uart_data(w_decorder_data),
        .select_data(select_data)

    );

endmodule

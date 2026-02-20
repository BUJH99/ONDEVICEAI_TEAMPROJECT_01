`timescale 1ns / 1ps

module or_input_controller (
    input        clk,
    input        reset,
    input  [4:0] btn,
    input  [2:0] sw,
    input  [7:0] uart_data,
    output [7:0] select_data
);

    wire w_toggle_0, w_toggle_1, w_toggle_2;
    wire [7:0] w_select;

    total_toggle U_TOGGLE (
        .clk(clk),
        .reset(reset),
        .uart_sw(uart_data[7:5]),
        .o_uart_0(w_toggle_0),
        .o_uart_1(w_toggle_1),
        .o_uart_2(w_toggle_2)
    );

    or_gate U_RESET (
        .uart_mode  (uart_data[4]),
        .orig_mode  (btn[0]),
        .select_mode(w_select[4])
    );
    
    or_gate U_BTN_R (
        .uart_mode  (uart_data[0]),
        .orig_mode  (btn[1]),
        .select_mode(w_select[0])
    );

    or_gate U_BTN_L (
        .uart_mode  (uart_data[1]),
        .orig_mode  (btn[2]),
        .select_mode(w_select[1])
    );

    or_gate U_BTN_U (
        .uart_mode  (uart_data[2]),
        .orig_mode  (btn[3]),
        .select_mode(w_select[2])
    );

    or_gate U_BTN_D (
        .uart_mode  (uart_data[3]),
        .orig_mode  (btn[4]),
        .select_mode(w_select[3])
    );

    or_gate U_SW_0 (
        .uart_mode  (w_toggle_0),
        .orig_mode  (sw[0]),
        .select_mode(select_data[5])
    );

    or_gate U_SW_1 (
        .uart_mode  (w_toggle_1),
        .orig_mode  (sw[1]),
        .select_mode(select_data[6])
    );

    or_gate U_SW_2 (
        .uart_mode  (w_toggle_2),
        .orig_mode  (sw[2]),
        .select_mode(select_data[7])
    );

    priority_controller U_PRI_CON (
        .clk(clk),
        .reset(reset),
        .i_btn_m(w_select[4]),
        .i_btn_r(w_select[0]),
        .i_btn_l(w_select[1]),
        .i_btn_u(w_select[2]),
        .i_btn_d(w_select[3]),
        .o_btn_m(select_data[4]),
        .o_btn_r(select_data[0]),
        .o_btn_l(select_data[1]),
        .o_btn_u(select_data[2]),
        .o_btn_d(select_data[3])

    );
    

endmodule

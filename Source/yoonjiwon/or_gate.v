`timescale 1ns / 1ps

module or_gate (
    input  uart_mode,
    input  orig_mode,
    output select_mode

);

    assign select_mode = uart_mode | orig_mode;

endmodule

`timescale 1ns / 1ps
module ascii_decorder (

    input            clk,
    input            reset,
    input      [7:0] uart_data,
    input            uart_done,
    output reg [7:0] uart_mode

);
    always @(posedge clk or posedge reset) begin
        if (reset) begin

            uart_mode <= 8'b0;
        end else begin

            if (uart_done) begin
                case (uart_data)
                    8'h72:   uart_mode <= 8'h01;  // 'r'
                    8'h6c:   uart_mode <= 8'h02;  // 'l'clear
                    8'h75:   uart_mode <= 8'h04;  // 'u'
                    8'h64:   uart_mode <= 8'h08;  // 'd'
                    8'h63:   uart_mode <= 8'h10;  // 'm'center,reset
                    8'h30:   uart_mode <= 8'h20;  // '0'
                    8'h31:   uart_mode <= 8'h40;  // '1'
                    8'h32:   uart_mode <= 8'h80;  // '2'
                    default: uart_mode <= 8'b0;
                endcase
            end else begin
                uart_mode <= 8'b0;
            end
        end
    end


endmodule

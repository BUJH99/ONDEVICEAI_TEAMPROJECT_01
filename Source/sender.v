`timescale 1ns / 1ps


module sender (
    input         clk,
    input         rst,
    input  [ 1:0] i_c_mode,
    input         i_start,
    input  [31:0] i_dec_data,
    input         i_sender_ready,
    output [ 7:0] send_data,
    output        send_valid
);
    localparam IDLE = 0, SKIP_ZERO = 1, TIME = 2, SR04 = 3, DHT11 = 4, STOP = 5;
    localparam ASCII_0 = 8'h30, ASCII_LF = 8'h0a, 
            ASCII_PERSENT = 8'h25, ASCII_C = 8'h43, ASCII_DOT = 8'h2e , ASCII_COLON = 8'h3a, ASCII_M = 8'h6d, ASCII_TAB = 8'h09;

    reg [2:0] c_state, n_state;
    reg [3:0] send_cnt_reg, send_cnt_next;  //8 push
    reg [7:0] send_data_reg, send_data_next;
    reg [31:0] dec_data_reg, dec_data_next;
    reg send_push_reg, send_push_next;

    assign send_data  = send_data_reg;
    assign send_valid = send_push_reg;


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state       <= IDLE;
            dec_data_reg  <= 64'b0;
            send_cnt_reg  <= 0;
            send_push_reg <= 1'b0;
            send_data_reg <= 8'b0;
        end else begin
            c_state       <= n_state;
            dec_data_reg  <= dec_data_next;
            send_cnt_reg  <= send_cnt_next;
            send_push_reg <= send_push_next;
            send_data_reg <= send_data_next;
        end
    end

    always @(*) begin
        n_state        = c_state;
        dec_data_next  = dec_data_reg;
        send_cnt_next  = send_cnt_reg;
        send_push_next = send_push_reg;
        send_data_next = send_data_reg;
        case (c_state)
            IDLE: begin
                send_push_next = 1'b0;
                send_cnt_next  = 0;
                dec_data_next  = i_dec_data;
                send_data_next = 8'b0;
                if (i_sender_ready) begin
                    if (i_start) begin
                        n_state = SKIP_ZERO;
                    end
                end
            end
            SKIP_ZERO: begin
                if (dec_data_reg[31:28] == 4'b0) begin
                    dec_data_next = {dec_data_reg[27:0], 4'b0};
                    send_cnt_next = send_cnt_reg + 1;
                end else begin
                    if (i_c_mode == 3) begin
                        n_state = DHT11;
                    end else if (i_c_mode == 2) begin
                        n_state = SR04;
                    end else begin
                        n_state = TIME;
                    end
                end
            end
            //FOMET => hh:mm:ss:mm
            TIME: begin
                if (i_sender_ready) begin
                    if (send_cnt_reg == 11) begin
                        n_state = STOP;
                        send_push_next = 1'b0;
                    end else if ((send_cnt_reg == 2)||(send_cnt_reg == 5)||(send_cnt_reg == 8))begin
                        send_push_next = 1'b1;
                        send_data_next = ASCII_COLON;
                        send_cnt_next  = send_cnt_reg + 1;
                    end else begin
                        send_push_next = 1'b1;
                        send_data_next = {4'b0, dec_data_reg[31:28]} + ASCII_0;
                        dec_data_next  = {dec_data_reg[27:0], 4'b0};
                        send_cnt_next  = send_cnt_reg + 1;
                    end
                end else begin
                    send_push_next = 1'b0;
                end
            end
            //FOMET => 4.00m
            SR04: begin
                if (i_sender_ready) begin
                    //input M
                    if (send_cnt_reg == 9) begin
                        n_state = STOP;
                        send_data_next = ASCII_M;
                        send_push_next = 1'b1;
                    //input DOT
                    end else if (send_cnt_reg == 6) begin
                        send_push_next = 1'b1;
                        send_data_next = ASCII_DOT;
                        send_cnt_next  = send_cnt_reg + 1;
                    //input data
                    end else begin
                        send_push_next = 1'b1;
                        send_data_next = {4'b0, dec_data_reg[31:28]} + ASCII_0;
                        dec_data_next  = {dec_data_reg[27:0], 4'b0};
                        send_cnt_next  = send_cnt_reg + 1;
                    end
                end else begin
                    send_push_next = 1'b0;
                end
            end
            //FOMET => 40% [TAB input] 36.05C
            DHT11: begin
                if (i_sender_ready) begin
                    if (send_cnt_reg == 12) begin
                        n_state = STOP;
                        send_data_next = ASCII_C;
                        send_push_next = 1'b1;
                    //input DOT
                    end else if ((send_cnt_reg == 2) ||(send_cnt_reg == 9)) begin
                        send_push_next = 1'b1;
                        send_data_next = ASCII_DOT;
                        send_cnt_next  = send_cnt_reg + 1;
                    //input
                    end else if (send_cnt_reg == 5) begin
                        send_push_next = 1'b1;
                        send_data_next = ASCII_PERSENT;
                        send_cnt_next  = send_cnt_reg + 1;
                    //input TAB
                    end else if (send_cnt_reg == 6) begin
                        send_push_next = 1'b1;
                        send_data_next = ASCII_TAB;
                        send_cnt_next  = send_cnt_reg + 1;
                    //input data
                    end else begin
                        send_push_next = 1'b1;
                        send_data_next = {4'b0, dec_data_reg[31:28]} + ASCII_0;
                        dec_data_next  = {dec_data_reg[27:0], 4'b0};
                        send_cnt_next  = send_cnt_reg + 1;
                    end
                end else begin
                    send_push_next = 1'b0;
                end
            end
            STOP: begin
                if (i_sender_ready) begin
                    send_push_next = 1'b1;
                    send_data_next = ASCII_LF;
                    n_state = IDLE;
                end else begin
                    send_push_next = 1'b0;
                end
            end
        endcase
    end

endmodule


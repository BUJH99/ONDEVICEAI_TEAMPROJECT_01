`timescale 1ns / 1ps


module fnd_controller (
    input    clk,
    input    reset,
    input    sel_display,           //clock hour:min, sec:msec Mode
    input    mode,                  //blinking
    input    [31:0] fnd_in_data,
    output   [3:0] fnd_digit,
    output   [7:0] fnd_data,
    output   [31:0] fnd_to_sender   //to sender data
);
    wire [3:0] w_digit_msec_1, w_digit_msec_10;
    wire [3:0] w_digit_sec_1, w_digit_sec_10;
    wire [3:0] w_digit_min_1, w_digit_min_10;
    wire [3:0] w_digit_hour_1, w_digit_hour_10;
    wire [3:0] w_mux_hour_min_out, w_mux_sec_msec_out;
    wire [3:0] w_mux_2x1_out;
    wire [2:0] w_digit_sel;
    wire w_dot_onoff;
    wire w_1khz;
    wire [7:0] w_fnd_data;
    wire w_onoff;

    //hour
    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_HOUR_DS (
        .in_data (fnd_in_data[31:24]),
        .digit_1 (w_digit_hour_1),
        .digit_10(w_digit_hour_10)
    );

    //min
    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_MIN_DS (
        .in_data (fnd_in_data[23:16]),
        .digit_1 (w_digit_min_1),
        .digit_10(w_digit_min_10)
    );

    //sec
    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_SEC_DS (
        .in_data (fnd_in_data[15:8]),
        .digit_1 (w_digit_sec_1),
        .digit_10(w_digit_sec_10)
    );

    //msec
    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_MSEC_DS (
        .in_data (fnd_in_data[7:0]),
        .digit_1 (w_digit_msec_1),
        .digit_10(w_digit_msec_10)
    );

    dot_on_off_comp U_DOT_COMP (
        .msec_dot (fnd_in_data[7:0]),
        .dot_onoff(w_dot_onoff)
    );

    mux_8X1 U_MUX_HOUR_MIN (
        .digit_1(w_digit_min_1),
        .digit_10(w_digit_min_10),
        .digit_100(w_digit_hour_1),
        .digit_1000(w_digit_hour_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .sel(w_digit_sel),
        .mux_out(w_mux_hour_min_out)
    );

    mux_8X1 U_MUX_SEC_MSEC (
        .digit_1(w_digit_msec_1),
        .digit_10(w_digit_msec_10),
        .digit_100(w_digit_sec_1),
        .digit_1000(w_digit_sec_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .sel(w_digit_sel),
        .mux_out(w_mux_sec_msec_out)
    );


    mux_2x1 U_MUX_2x1 (
        .sel(sel_display),
        .i_sel0(w_mux_sec_msec_out),
        .i_sel1(w_mux_hour_min_out),
        .o_mux(w_mux_2x1_out)
    );


    counter_8 U_COUNTER_8 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );

    clk_div U_CLK_DIV (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );



    decoder_2X4 U_DECODER_2X4 (
        .digit_sel(w_digit_sel[1:0]),
        .fnd_digit(fnd_digit)

    );

    bcd U_BCD (
        .bcd(w_mux_2x1_out),
        .fnd_data(w_fnd_data)
    );

    mode_on_off U_ON_OFF (
        .clk(clk),
        .rst(rst),
        .mode(mode),
        .o_on_off(w_onoff)
    );

    mux_on_off U_M_OF (
        .fnd_data(w_fnd_data),
        .onoff(w_onoff),
        .data(fnd_data)

    );

    splitter_to_sender U_TO_SENDER(
    .clk(clk),
    .rst(rst),
    .h_10(w_digit_hour_10),
    .h_1(w_digit_hour_1),
    .m_10(w_digit_min_10),
    .m_1(w_digit_min_1),
    .s_10(w_digit_sec_10),
    .s_1(w_digit_sec_1),
    .ms_10(w_digit_msec_10),
    .ms_1(w_digit_msec_1),
    .to_sender(fnd_to_sender)
);


endmodule


module splitter_to_sender (
    input clk,
    input rst,
    input [3:0] h_10,
    input [3:0] h_1,
    input [3:0] m_10,
    input [3:0] m_1,
    input [3:0] s_10,
    input [3:0] s_1,
    input [3:0] ms_10,
    input [3:0] ms_1,
    output [31:0] to_sender
);

    reg [31:0] register;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
           register <= 0; 
        end else begin
            register <= {h_10, h_1, m_10, m_1, s_10, s_1, ms_10, ms_1};

        end
    end

    assign to_sender = register;

endmodule


module mode_on_off (
    input  clk,
    input  rst,
    input  mode,
    output o_on_off
);
    reg [26:0] cnt;

    assign o_on_off = (cnt < 50_000_000);

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            cnt <= 0;
        end else begin
            if (mode) begin
                if (cnt == 100_000_000 - 1) begin
                    cnt <= 0;
                end else cnt <= cnt + 1;
            end else begin
                cnt <= 0;
            end
        end
    end
endmodule

module mux_on_off (
    input [7:0] fnd_data,
    input onoff,
    output [7:0] data

);

    assign data = (onoff) ? fnd_data : 8'hff;

endmodule


module dot_on_off_comp (
    input [6:0] msec_dot,
    output dot_onoff
);
    assign dot_onoff = (msec_dot < 50);

endmodule




module mux_2x1 (
    input        sel,
    input  [3:0] i_sel0,
    input  [3:0] i_sel1,
    output [3:0] o_mux
);
    //sel 1: output i_sel1, 0: i_sel0
    assign o_mux = (sel) ? i_sel1 : i_sel0;

endmodule


module clk_div (
    input      clk,
    input      reset,
    output reg o_1khz
);

    reg [$clog2(100_000):0] counter_r;


    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;
            o_1khz    <= 1'b0;
        end else begin
            if (counter_r == 99999) begin
                counter_r <= 0;
                o_1khz    <= 1'b1;
            end else begin
                counter_r <= counter_r + 1;
                o_1khz    <= 1'b0;
            end
        end
    end
endmodule



module counter_8 (
    input clk,
    input reset,
    output [2:0] digit_sel
);

    reg [2:0] counter_r;

    assign digit_sel = counter_r;  //assign later than reg

    always @(posedge clk, posedge reset) begin
        if (reset == 1) begin
            //init counter_r
            counter_r <= 0;
        end else begin
            //to do
            counter_r <= counter_r + 1;
        end
    end

endmodule



//to select to fnd digit display
module decoder_2X4 (
    input [1:0] digit_sel,
    output reg [3:0] fnd_digit
);
    always @(digit_sel) begin
        case (digit_sel)
            2'b00: fnd_digit = 4'b1110;
            2'b01: fnd_digit = 4'b1101;
            2'b10: fnd_digit = 4'b1011;
            2'b11: fnd_digit = 4'b0111;
        endcase
    end
endmodule



module mux_8X1 (
    input [3:0] digit_1,
    input [3:0] digit_10,
    input [3:0] digit_100,
    input [3:0] digit_1000,
    input [3:0] digit_dot_1,
    input [3:0] digit_dot_10,
    input [3:0] digit_dot_100,
    input [3:0] digit_dot_1000,
    input [2:0] sel,
    output reg [3:0] mux_out
);

    always @(*) begin
        case (sel)
            3'b000: mux_out = digit_1;
            3'b001: mux_out = digit_10;
            3'b010: mux_out = digit_100;
            3'b011: mux_out = digit_1000;
            3'b100: mux_out = digit_dot_1;
            3'b101: mux_out = digit_dot_10;
            3'b110: mux_out = digit_dot_100;
            3'b111: mux_out = digit_dot_1000;
        endcase
    end

endmodule



module digit_splitter #(
    parameter BIT_WIDTH = 7
) (
    input [BIT_WIDTH-1:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10

);

    assign digit_1  = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;

endmodule



module bcd (
    input [3:0] bcd,
    output reg [7:0] fnd_data  //always output always Reg
);

    always @(bcd) begin
        case (bcd)
            4'd0: fnd_data = 8'hC0;
            4'd1: fnd_data = 8'hf9;
            4'd2: fnd_data = 8'ha4;
            4'd3: fnd_data = 8'hb0;
            4'd4: fnd_data = 8'h99;
            4'd5: fnd_data = 8'h92;
            4'd6: fnd_data = 8'h82;
            4'd7: fnd_data = 8'hf8;
            4'd8: fnd_data = 8'h80;
            4'd9: fnd_data = 8'h90;
            4'd10: fnd_data = 8'hff;
            4'd11: fnd_data = 8'hff;
            4'd12: fnd_data = 8'hff;
            4'd13: fnd_data = 8'hff;
            4'd14: fnd_data = 8'h7f;
            4'd15: fnd_data = 8'hff;
            default: fnd_data = 8'hFF;
        endcase
    end

endmodule

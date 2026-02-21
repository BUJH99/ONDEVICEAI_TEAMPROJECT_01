`timescale 1ns / 1ps

module top_module (
    input  clk,
    input  rst,
    output fnd_,

    input  RX,
    output TX
);
    //-------------------uart-----------------------------------
    uart_interface U_UART_INFC (
        .iClk   (clk),
        .iRst   (rst),
        .iUartRx(RX),
        .oUartTx(TX),

        .iSenderData (),
        .iSenderValid(),
        .oSenderReady(),

        .oDecoderData (),
        .oDecoderValid()
    );

    sender U_SENDER (
        .clk           (clk),
        .rst           (rst),
        .i_c_mode      (),
        .i_start       (),
        .i_dec_data    (),
        .i_sender_ready(),
        .send_data     (),
        .send_valid    ()
    );

    decorder_input_controller U_DECODER_INPUT_CTRL (
        .clk        (clk),
        .reset      (rst),
        .i_btn_fpga (),
        .i_sw_fpga  (),
        .i_uart_data(),
        .i_uart_done(),
        .select_data()
    );
    //-------------------------btn---------------------------------
    Debounce U_DB (
        .iClk     (clk),
        .iRst     (rst),
        .iBtnAsync(),
        .oBtnPulse()
    );

    //------------------------ctrl_unit-----------------------------
    CoreControlUnit U_CORE_CRTL (
        .iClk     (clk),
        .iRstn    (rst),
        .iTick1kHz(),
        .iMode    (),
        .iCmdValid(),
        .iCmdCode (),

        .iHcsrEcho  (),
        .oHcsrTrig  (),
        .ioDht11Data(),

        .oFndData  (),
        .oFullData (),
        .oBlinkMask(),
        .oDotMask  (),

        .oSenderMode (),
        .oSenderStart(),
        .oSenderData (),

        .oHcsrDistance(),
        .oHcsrValid(),
        .oDhtTemp(),
        .oDhtHumi(),
        .oDhtValid()
    );
    //---------------------------mux--------------------------------
    //---------------------------fnd--------------------------------
    fnd_controller U_FND_CTRL (
        .clk          (clk),
        .reset        (rst),
        .sel_display  (),     //clock hour:min, sec:msec Mode
        .mode         (),     //blinking
        .fnd_in_data  (),
        .fnd_digit    (),
        .fnd_data     (),
        .fnd_to_sender()      //to sender data
    );
endmodule

/*
[MODULE_INFO_START]
Name: uart_interface
Role: Integrates UART RX/TX paths for loopback, sender transmit, and decoder receive flows.
Summary:
  - LoopBack path: PC RX byte -> RX FIFO -> TX arbiter -> UART TX. -> PC
  - Sender TX path: sender byte -> TX FIFO -> TX arbiter -> UART TX -> PC
  - Decoder RX path: RX byte is forwarded to external decoder interface.
[MODULE_INFO_END]
*/

module uart_interface #(
    parameter integer P_CLK_HZ     = 100000000,
    parameter integer P_BAUD       = 9600,
    parameter integer P_FIFO_DEPTH = 16
)(
    input  wire       iClk,
    input  wire       iRst,
    input  wire       iUartRx,
    output wire       oUartTx,

    input  wire [7:0] iSenderData,
    input  wire       iSenderValid,
    output wire       oSenderReady,

    output wire [7:0] oDecoderData,
    output wire       oDecoderValid
);

    wire       wBaud2All_SampleTick;

    wire       wRx2All_Valid;
    wire [7:0] wRx2All_Data;

    wire [7:0] wRxFifo2Arb_Data;
    wire       wRxFifo2Arb_Empty;
    wire       wArb2RxFifo_Pop;

    wire [7:0] wTxFifo2Arb_Data;
    wire       wTxFifo2Arb_Empty;
    wire       wTxFifo2Arb_Full;
    wire       wArb2TxFifo_Pop;

    wire       wArb2Tx_TxStart;
    wire [7:0] wArb2Tx_TxData;
    wire       wTx2Arb_TxBusy;
    wire       wTx2Top_TxDone;

    assign oSenderReady  = ~wTxFifo2Arb_Full;
    assign oDecoderData  = wRx2All_Data;
    assign oDecoderValid = wRx2All_Valid;

    baud_rate_generator #(
        .P_CLK_HZ(P_CLK_HZ),
        .P_BAUD  (P_BAUD)
    ) uBaudRateGenerator (
        .iClk       (iClk),
        .iRst       (iRst),
        .oSampleTick(wBaud2All_SampleTick)
    );

    uart_rx uUartRx (
        .iClk       (iClk),
        .iRst       (iRst),
        .iSampleTick(wBaud2All_SampleTick),
        .iUartRx    (iUartRx),
        .oRxValid   (wRx2All_Valid),
        .oRxData    (wRx2All_Data)
    );

    rx_fifo #(
        .P_DEPTH(P_FIFO_DEPTH)
    ) uRxFifo (
        .iClk   (iClk),
        .iRst   (iRst),
        .iWrEn  (wRx2All_Valid),
        .iWrData(wRx2All_Data),
        .iRdEn  (wArb2RxFifo_Pop),
        .oRdData(wRxFifo2Arb_Data),
        .oEmpty (wRxFifo2Arb_Empty),
        .oFull  ()
    );

    tx_fifo #(
        .P_DEPTH(P_FIFO_DEPTH)
    ) uTxFifo (
        .iClk   (iClk),
        .iRst   (iRst),
        .iWrEn  (iSenderValid),
        .iWrData(iSenderData),
        .iRdEn  (wArb2TxFifo_Pop),
        .oRdData(wTxFifo2Arb_Data),
        .oEmpty (wTxFifo2Arb_Empty),
        .oFull  (wTxFifo2Arb_Full)
    );

    tx_arbiter uTxArbiter (
        .iTxBusy     (wTx2Arb_TxBusy),
        .iSenderValid(~wTxFifo2Arb_Empty),
        .iSenderData (wTxFifo2Arb_Data),
        .iEchoValid  (~wRxFifo2Arb_Empty),
        .iEchoData   (wRxFifo2Arb_Data),
        .oTxStart    (wArb2Tx_TxStart),
        .oTxData     (wArb2Tx_TxData),
        .oSenderPop  (wArb2TxFifo_Pop),
        .oEchoPop    (wArb2RxFifo_Pop)
    );

    uart_tx uUartTx (
        .iClk       (iClk),
        .iRst       (iRst),
        .iSampleTick(wBaud2All_SampleTick),
        .iTxStart   (wArb2Tx_TxStart),
        .iTxData    (wArb2Tx_TxData),
        .oUartTx    (oUartTx),
        .oTxBusy    (wTx2Arb_TxBusy),
        .oTxDone    (wTx2Top_TxDone)
    );

endmodule

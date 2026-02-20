/*
[MODULE_INFO_START]
Name: DebounceWrapper
Role: Multi-channel debounce wrapper for button inputs.
Summary:
  - Instantiates Debounce module for each button channel.
  - Default channel count is 5 for 5-button input.
[MODULE_INFO_END]
*/

module DebounceWrapper #(
    parameter integer P_NUM_BTN      = 5,
    parameter integer P_CLK_HZ       = 100000000,
    parameter integer P_DEBOUNCE_MS  = 20
)(
    input  wire [P_NUM_BTN-1:0] iBtnAsync,
    input  wire                 iClk,
    input  wire                 iRst,
    output wire [P_NUM_BTN-1:0] oBtnDebounced
);

    genvar idxBtn;
    generate
        for (idxBtn = 0; idxBtn < P_NUM_BTN; idxBtn = idxBtn + 1) begin: genDebounce
            Debounce #(
                .P_CLK_HZ     (P_CLK_HZ),
                .P_DEBOUNCE_MS(P_DEBOUNCE_MS)
            ) uDebounce (
                .iClk        (iClk),
                .iRst        (iRst),
                .iBtnAsync   (iBtnAsync[idxBtn]),
                .oBtnDebounced(oBtnDebounced[idxBtn])
            );
        end
    endgenerate

endmodule

/*
[MODULE_INFO_START]
Name: Debounce
Role: Single-channel debounce using synchronization and counter filtering.
Summary:
  - Synchronizes asynchronous button input with sync_2ff.
  - Applies CounterFilter to require stable level for debounce window.
  - Default debounce window is 20ms.
[MODULE_INFO_END]
*/

module Debounce #(
    parameter integer P_CLK_HZ      = 100000000,
    parameter integer P_DEBOUNCE_MS = 20
)(
    input  wire iClk,
    input  wire iRst,
    input  wire iBtnAsync,
    output wire oBtnDebounced
);

    localparam integer LP_COUNT_MAX = ((P_CLK_HZ / 1000) * P_DEBOUNCE_MS) - 1;

    wire sync2Filter_Sync;

    sync_2ff uSync2ff (
        .iAsync(iBtnAsync),
        .iClk  (iClk),
        .iRst  (iRst),
        .oSync (sync2Filter_Sync)
    );

    CounterFilter #(
        .MAX_COUNT(LP_COUNT_MAX)
    ) uCounterFilter (
        .iClk(iClk),
        .iRst(iRst),
        .iIn (sync2Filter_Sync),
        .oOut(oBtnDebounced)
    );

endmodule

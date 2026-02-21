/*
[MODULE_INFO_START]
Name: Hcsr04Core
Role: Drives HC-SR04 trigger pulse and measures echo width to estimate distance.
Summary:
  - Generates a 10us trigger pulse on start.
  - Waits for echo high with timeout protection.
  - Counts echo high duration and converts to cm with cycle-per-cm threshold.
  - Latches distance at DONE and pulses oValid for one cycle.
StateDescription:
  - IDLE: Wait for iStart.
  - TRIG_HIGH: Assert trigger for P_TRIG_US.
  - WAIT_ECHO_HIGH: Wait echo rising edge or timeout.
  - ECHO_MEASURE: Measure echo high width in cycles.
  - DONE: Output valid pulse and return to IDLE.
[MODULE_INFO_END]
*/

module Hcsr04Core #(
    parameter integer P_SYS_CLK_HZ      = 100_000_000,
    parameter integer P_TRIG_US         = 10,
    parameter integer P_WAIT_TIMEOUT_US = 1_000,
    parameter integer P_ECHO_TIMEOUT_US = 38_000
)(
    input  wire        iClk,
    input  wire        iRstn,
    input  wire        iStart,
    input  wire        iEcho,
    output reg         oTrig,
    output reg  [15:0] oDistance,
    output reg         oValid
);

    localparam integer LP_1_US                = P_SYS_CLK_HZ / 1_000_000;
    localparam integer LP_TRIG_CYCLES         = P_TRIG_US * LP_1_US;
    localparam integer LP_WAIT_TIMEOUT_CYCLES = P_WAIT_TIMEOUT_US * LP_1_US;
    localparam integer LP_ECHO_TIMEOUT_CYCLES = P_ECHO_TIMEOUT_US * LP_1_US;
    localparam integer LP_CYCLES_PER_CM       = 58 * LP_1_US;

    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] TRIG_HIGH      = 3'd1;
    localparam [2:0] WAIT_ECHO_HIGH = 3'd2;
    localparam [2:0] ECHO_MEASURE   = 3'd3;
    localparam [2:0] DONE           = 3'd4;

    reg [2:0]  state, state_d;
    reg [23:0] trigCnt, trigCnt_d;
    reg [23:0] waitCnt, waitCnt_d;
    reg [23:0] echoCnt, echoCnt_d;
    reg [23:0] cmCycleCnt, cmCycleCnt_d;
    reg [15:0] distCnt, distCnt_d;

    wire wEchoSync;

    sync_2ff uEchoSync2ff (
        .iAsync(iEcho),
        .iClk  (iClk),
        .iRst  (~iRstn),
        .oSync (wEchoSync)
    );

    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            state      <= IDLE;
            trigCnt    <= 24'd0;
            waitCnt    <= 24'd0;
            echoCnt    <= 24'd0;
            cmCycleCnt <= 24'd0;
            distCnt    <= 16'd0;
            oDistance  <= 16'd0;
        end else begin
            state      <= state_d;
            trigCnt    <= trigCnt_d;
            waitCnt    <= waitCnt_d;
            echoCnt    <= echoCnt_d;
            cmCycleCnt <= cmCycleCnt_d;
            distCnt    <= distCnt_d;

            if (state_d == DONE) begin
                oDistance <= distCnt_d;
            end
        end
    end

    always @(*) begin
        state_d      = state;
        trigCnt_d    = trigCnt;
        waitCnt_d    = waitCnt;
        echoCnt_d    = echoCnt;
        cmCycleCnt_d = cmCycleCnt;
        distCnt_d    = distCnt;

        case (state)
            IDLE: begin
                trigCnt_d    = 24'd0;
                waitCnt_d    = 24'd0;
                echoCnt_d    = 24'd0;
                cmCycleCnt_d = 24'd0;
                distCnt_d    = 16'd0;
                if (iStart) begin
                    state_d = TRIG_HIGH;
                end
            end

            TRIG_HIGH: begin
                if (trigCnt >= (LP_TRIG_CYCLES - 1)) begin
                    state_d   = WAIT_ECHO_HIGH;
                    trigCnt_d = 24'd0;
                    waitCnt_d = 24'd0;
                end else begin
                    trigCnt_d = trigCnt + 24'd1;
                end
            end

            WAIT_ECHO_HIGH: begin
                if (wEchoSync) begin
                    state_d      = ECHO_MEASURE;
                    waitCnt_d    = 24'd0;
                    echoCnt_d    = 24'd0;
                    cmCycleCnt_d = 24'd0;
                    distCnt_d    = 16'd0;
                end else if (waitCnt >= (LP_WAIT_TIMEOUT_CYCLES - 1)) begin
                    state_d   = DONE;
                    distCnt_d = 16'hFFFF;
                end else begin
                    waitCnt_d = waitCnt + 24'd1;
                end
            end

            ECHO_MEASURE: begin
                if (wEchoSync) begin
                    echoCnt_d = echoCnt + 24'd1;

                    if (cmCycleCnt >= (LP_CYCLES_PER_CM - 1)) begin
                        cmCycleCnt_d = 24'd0;
                        distCnt_d    = distCnt + 16'd1;
                    end else begin
                        cmCycleCnt_d = cmCycleCnt + 24'd1;
                    end

                    if (echoCnt >= (LP_ECHO_TIMEOUT_CYCLES - 1)) begin
                        state_d   = DONE;
                        distCnt_d = 16'hFFFF;
                    end
                end else begin
                    state_d = DONE;
                end
            end

            DONE: begin
                state_d = IDLE;
            end

            default: begin
                state_d = IDLE;
            end
        endcase
    end

    always @(*) begin
        oTrig  = 1'b0;
        oValid = 1'b0;

        case (state)
            TRIG_HIGH: begin
                oTrig = 1'b1;
            end

            DONE: begin
                oValid = 1'b1;
            end

            default: begin
                oTrig  = 1'b0;
                oValid = 1'b0;
            end
        endcase
    end

endmodule


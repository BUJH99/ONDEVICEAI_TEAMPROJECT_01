/*
[MODULE_INFO_START]
Name: Hcsr04Core
Role: Drives HC-SR04 trigger pulse and measures echo high width to compute distance.
Summary:
  - Generates a 10us trigger pulse when measurement start command arrives.
  - Waits for echo rising edge with timeout protection (timeout sets oDistance to FFFF).
  - Division-free distance calculation: 1cm 단위 카운터를 두어 나눗셈 회로 없이 연산
  - Latches evaluated distance at DONE state and asserts oValid for 1 clock.
StateDescription:
  - IDLE: Waits for iStart and clears internal counters.
  - TRIG_HIGH: Drives oTrig HIGH for 10us.
  - WAIT_ECHO_HIGH: Drives oTrig LOW and waits echo rising edge (timeout moves to DONE, returns FFFF).
  - ECHO_MEASURE: Counts echo high cycles, increments distance per 1cm cycles. Moves to DONE at edge or timeout.
  - DONE: Latches measured distance and asserts oValid for 1 clock, then returns to IDLE.
[MODULE_INFO_END]
*/
module Hcsr04Core #(
    parameter P_SYS_CLK_HZ         = 100_000_000,
    parameter P_TRIG_US            = 10,
    parameter P_WAIT_TIMEOUT_US    = 1_000,
    parameter P_ECHO_TIMEOUT_US    = 38_000
    input  wire        iClk,
    input  wire        iRstn,
    input  wire        iStart,
    input  wire        iEcho,
    output reg         oTrig,
    output reg  [15:0] oDistance,
    output reg         oValid
);

    // ----------------------------------------------------
    // 1) Parameters & State Encoding
    // ----------------------------------------------------
    // P_SYS_CLK_HZ must be >= 1_000_000 for 1us resolution.
    localparam LP_1_US                    = P_SYS_CLK_HZ / 1_000_000;
    localparam LP_TRIG_CYCLES             = P_TRIG_US * LP_1_US;
    localparam LP_WAIT_TIMEOUT_CYCLES     = P_WAIT_TIMEOUT_US * LP_1_US;
    localparam LP_ECHO_TIMEOUT_CYCLES     = P_ECHO_TIMEOUT_US * LP_1_US;
    localparam LP_CYCLES_PER_CM           = 58 * LP_1_US;

    localparam IDLE            = 3'd0;
    localparam TRIG_HIGH       = 3'd1;
    localparam WAIT_ECHO_HIGH  = 3'd2;
    localparam ECHO_MEASURE    = 3'd3;
    localparam DONE            = 3'd4;

    // ----------------------------------------------------
    // 2) Registers / Wires
    // ----------------------------------------------------
    reg [2:0]  state, state_d;
    reg [23:0] trigCnt, trigCnt_d;
    reg [23:0] waitCnt, waitCnt_d;
    
    // 전체 타임아웃 체크용 에코 누적 카운터 및 1cm 구간 판단용 카운터
    reg [23:0] echoCnt, echoCnt_d;
    reg [23:0] cmCycleCnt, cmCycleCnt_d;
    
    // 최종 도출될 거리값
    reg [15:0] distCnt, distCnt_d;

    wire       wEchoSync;

    sync_2ff uEchoSync2ff (
        .iAsync (iEcho),
        .iClk   (iClk),
        .iRst   (~iRstn),
        .oSync  (wEchoSync)
    );

    // ----------------------------------------------------
    // 3) Sequential Logic: state/register update + distance latch
    // ----------------------------------------------------
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

    // ----------------------------------------------------
    // 4. Combinational Logic (FSM & Datapath)
    // ----------------------------------------------------
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

                if (iStart == 1'b1)
                    state_d = TRIG_HIGH;
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
                if (wEchoSync == 1'b1) begin
                    state_d      = ECHO_MEASURE;
                    waitCnt_d    = 24'd0;
                    echoCnt_d    = 24'd0;
                    cmCycleCnt_d = 24'd0;
                    distCnt_d    = 16'd0;
                end else if (waitCnt >= (LP_WAIT_TIMEOUT_CYCLES - 1)) begin
                    // 에코 응답 대기 시간 초과
                    state_d   = DONE;
                    distCnt_d = 16'hFFFF; // 타임아웃 에러 플래그
                end else begin
                    waitCnt_d = waitCnt + 24'd1;
                end
            end

            ECHO_MEASURE: begin
                if (wEchoSync == 1'b1) begin
                    echoCnt_d = echoCnt + 24'd1;                 
                    // 나눗셈을 카운터로 대체: 1cm 진행 사이클 수에 도달 시 cm 증가
                    if (cmCycleCnt >= (LP_CYCLES_PER_CM - 1)) begin
                        cmCycleCnt_d = 24'd0;
                        distCnt_d    = distCnt + 16'd1;
                    end else begin
                        cmCycleCnt_d = cmCycleCnt + 24'd1;
                    end
                    if (echoCnt >= (LP_ECHO_TIMEOUT_CYCLES - 1)) begin
                        // 측정 중 타임아웃 한계 도달
                        state_d   = DONE;
                        distCnt_d = 16'hFFFF; // 타임아웃 에러 플래그
                    end
                end else begin
                    state_d = DONE; // 에코 정상 종료 시
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

    // ----------------------------------------------------
    // 5) Output Logic
    // ----------------------------------------------------
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

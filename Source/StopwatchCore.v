/*
[MODULE_INFO_START]
Name: StopwatchCore
Role: 스톱워치 모드의 구동 및 FSM-Counter 래퍼
Summary:
  - InputDistributor의 oCmdCode를 기반으로 스톱워치 런타임 제어/토글 동작 생성
  - Stopwatch Counter를 통해 10ms 단위 틱 카운터 구동
  - 현재 누적 시간과 설정된 자릿수 (깜빡임, 닷 마스크) 상태를 종합하여 출력
StateDescription:
[MODULE_INFO_END]
*/

module StopwatchCore (
    input  wire        iClk,
    input  wire        iRstn,

    // Command Interface (From InputControl / ControlUnit)
    input  wire        iTick1kHz,
    input  wire [1:0]  iMode,
    input  wire        iCmdValid,
    input  wire [4:0]  iCmdCode,

    // Outputs
    output wire [15:0] oFndData,   
    output wire [31:0] oFullData,  
    output wire [3:0]  oBlinkMask, 
    output wire [3:0]  oDotMask    
);

    // Command decoding Constants (matching InputDistributor)
    localparam [1:0] LP_MODE_STOPWATCH            = 2'd1;
    localparam [4:0] LP_CMD_MODE_LOCAL_RESET      = 5'd3;
    localparam [4:0] LP_CMD_STOP_FMT_TOGGLE       = 5'd7;
    localparam [4:0] LP_CMD_STOP_EDITMODE_TOGGLE  = 5'd8;
    localparam [4:0] LP_CMD_STOP_EDITDIGIT_NEXT   = 5'd9;

    // Command pulses
    wire wFormatToggle   = iCmdValid && (iCmdCode == LP_CMD_STOP_FMT_TOGGLE);
    wire wEditModeToggle = iCmdValid && (iCmdCode == LP_CMD_STOP_EDITMODE_TOGGLE);
    wire wEditUnitToggle = iCmdValid && (iCmdCode == LP_CMD_STOP_EDITDIGIT_NEXT);
    wire wResetTime      = iCmdValid && (iCmdCode == LP_CMD_MODE_LOCAL_RESET) && (iMode == LP_MODE_STOPWATCH);
    wire wInc            = iCmdValid && (iCmdCode == 5'd20) && (iMode == LP_MODE_STOPWATCH);
    wire wDec            = iCmdValid && (iCmdCode == 5'd21) && (iMode == LP_MODE_STOPWATCH);

    // Format Flag Register: HH:MM (0) <-> SS:ms (1) 토글 유지
    reg formatFlag;
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            formatFlag <= 1'b0;
        end else if (wFormatToggle) begin
            formatFlag <= ~formatFlag;
        end
    end

    // 중간 Dot 식별용도
    assign oDotMask = 4'b0100;

    // FSM Internal Flags
    wire wRun;
    wire wEditEn;
    wire wEditUnit;

    // FSM 인스턴스 (Stopwatch 동작, 일시정지, 단위 깜빡임)
    StopwatchFsm uStopwatchFsm (
        .iClk             (iClk),
        .iRstn            (iRstn),
        .iEditModeToggle  (wEditModeToggle),
        .iEditUnitToggle  (wEditUnitToggle),
        .oRun             (wRun),
        .oEditEn          (wEditEn),
        .oEditUnit        (wEditUnit),
        .oBlinkMask       (oBlinkMask)
    );

    // Counter 인스턴스 (실질적인 스톱워치 틱 누적)
    StopwatchCounter uStopwatchCounter (
        .iClk       (iClk),
        .iRstn      (iRstn),
        .iTick1kHz  (iTick1kHz),
        .iRun       (wRun),
        .iFormat    (formatFlag),
        .iEditEn    (wEditEn),
        .iEditUnit  (wEditUnit),
        .iInc       (wInc), // U 버튼 연동
        .iDec       (wDec), // D 버튼 연동
        .iResetTime (wResetTime),
        .oFndData   (oFndData),
        .oFullData  (oFullData)
    );

endmodule

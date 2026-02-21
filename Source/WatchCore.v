/*
[MODULE_INFO_START]
Name: WatchCore
Role: 시계(Watch) 모드의 구동 및 FSM-Counter 래퍼
Summary:
  - InputDistributor가 출력하는 CmdCode와 CmdValid를 해석하여 내부 제어 펄스 발생
  - Watch Counter와 Watch FSM을 연결하여 상태와 시간 연산 연동
  - 현재 시계 데이터(BCD 16비트) 및 컴포넌트 마스크(Blink, Dot) 출력
StateDescription:
[MODULE_INFO_END]
*/

module WatchCore (
    input  wire        iClk,
    input  wire        iRstn,

    // Command Interface (From InputControl / ControlUnit)
    input  wire        iTick1kHz,   // 1ms 글로벌 틱
    input  wire [1:0]  iMode,       // 현재 선택된 모드 (0: Watch, 1: Stopwatch ...)
    input  wire        iCmdValid,
    input  wire [4:0]  iCmdCode,

    // Outputs
    output wire [15:0] oFndData,   // FND 출력 BCD 데이터
    output wire [31:0] oFullData,  // UART 통신용 32-bit BCD 데이터
    output wire [3:0]  oBlinkMask, // 편집시 자릿수 깜빡임 마스크
    output wire [3:0]  oDotMask    // FND 콜론/대시 표기용
);

    // Command decoding Constants (matching InputDistributor)
    localparam [1:0] LP_MODE_WATCH                = 2'd0;
    localparam [4:0] LP_CMD_MODE_LOCAL_RESET      = 5'd3;
    localparam [4:0] LP_CMD_WATCH_FMT_TOGGLE      = 5'd4;
    localparam [4:0] LP_CMD_WATCH_EDITMODE_TOGGLE = 5'd5;
    localparam [4:0] LP_CMD_WATCH_EDITDIGIT_NEXT  = 5'd6;

    // Command pulses
    wire wFormatToggle   = iCmdValid && (iCmdCode == LP_CMD_WATCH_FMT_TOGGLE);
    wire wEditModeToggle = iCmdValid && (iCmdCode == LP_CMD_WATCH_EDITMODE_TOGGLE);
    wire wEditUnitToggle = iCmdValid && (iCmdCode == LP_CMD_WATCH_EDITDIGIT_NEXT);
    wire wResetTime      = iCmdValid && (iCmdCode == LP_CMD_MODE_LOCAL_RESET) && (iMode == LP_MODE_WATCH);
    wire wInc            = iCmdValid && (iCmdCode == 5'd20) && (iMode == LP_MODE_WATCH);
    wire wDec            = iCmdValid && (iCmdCode == 5'd21) && (iMode == LP_MODE_WATCH);

    // Format Flag Register: HH:MM (0) <-> SS:ms (1) 토글 유지
    reg formatFlag;
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            formatFlag <= 1'b0;
        end else if (wFormatToggle) begin
            formatFlag <= ~formatFlag;
        end
    end

    // 중간 Dot(단위 구분을 위한 표식) 항상 켜기
    assign oDotMask = 4'b0100;

    wire wEditEn;
    wire wEditUnit;

    // FSM 인스턴스화
    WatchFsm uWatchFsm (
        .iClk             (iClk),
        .iRstn            (iRstn),
        .iEditModeToggle  (wEditModeToggle),
        .iEditUnitToggle  (wEditUnitToggle),
        .oEditEn          (wEditEn),
        .oEditUnit        (wEditUnit),
        .oBlinkMask       (oBlinkMask)
    );

    // 카운터 인스턴스화
    WatchCounter uWatchCounter (
        .iClk       (iClk),
        .iRstn      (iRstn),
        .iTick1kHz  (iTick1kHz),
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

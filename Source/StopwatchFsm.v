/*
[MODULE_INFO_START]
Name: StopwatchFsm
Role: 스톱워치의 런(동작)과 편집(일시정지) 모드 상태 관리기 (2-State Moore)
Summary:
  - RUN과 EDIT의 기본 두 상태로만 유지되는 3-always 기반 Moore FSM
  - 카운팅 중이거나 멈춰있는 동작 모드(RUN)와 자리 단위 수정이 진행되는(EDIT) 모드로 양분
  - InputDistributor의 cmdCode 기반 Toggle 이벤트를 처리
StateDescription:
  - RUN: 스톱워치가 동작하는 기본 상태 (실제로 시간이 흐름)
  - EDIT: 카운트가 일시 정지되고 사용자 조작에 의해 왼쪽/오른쪽 자리를 선택하는 상태
[MODULE_INFO_END]
*/

module StopwatchFsm (
    input  wire        iClk,
    input  wire        iRstn,

    // Controls (From InputDistributor / ControlUnit)
    input  wire        iEditModeToggle, // LP_CMD_STOP_EDITMODE_TOGGLE
    input  wire        iEditUnitToggle, // LP_CMD_STOP_EDITDIGIT_NEXT
    
    // Outputs
    output reg         oRun,
    output reg         oEditEn,
    output reg         oEditUnit,
    output reg  [3:0]  oBlinkMask
);

    localparam RUN  = 1'b0;
    localparam EDIT = 1'b1;

    reg state, state_d;
    reg editUnit, editUnit_d; // 0: Left, 1: Right

    // 1) 상태 레지스터
    always @(posedge iClk or negedge iRstn) begin
        if (!iRstn) begin
            state    <= RUN;
            editUnit <= 1'b0;
        end else begin
            state    <= state_d;
            editUnit <= editUnit_d;
        end
    end

    // 2) 차기 상태 로직
    always @(*) begin
        state_d    = state;
        editUnit_d = editUnit;

        case (state)
            RUN: begin
                if (iEditModeToggle) begin
                    state_d    = EDIT;
                    editUnit_d = 1'b0; // 편집 진입 시 왼쪽 자리부터 시작
                end
            end
            EDIT: begin
                if (iEditModeToggle) begin
                    state_d = RUN;
                end else if (iEditUnitToggle) begin
                    editUnit_d = ~editUnit;
                end
            end
            default: begin
                state_d = RUN;
            end
        endcase
    end

    // 3) 출력 신호 연산 (Moore)
    always @(*) begin
        oRun       = 1'b0;
        oEditEn    = 1'b0;
        oEditUnit  = 1'b0;
        oBlinkMask = 4'b0000;

        case (state)
            RUN: begin
                oRun       = 1'b1; // 동작 모드에서는 카운터 시간 증분 정상 연결
                oEditEn    = 1'b0;
                oEditUnit  = 1'b0;
                oBlinkMask = 4'b0000;
            end
            EDIT: begin
                oRun       = 1'b0; // 편집 모드에 들어서면 카운트 무조건 일시 정지
                oEditEn    = 1'b1;
                oEditUnit  = editUnit;
                if (editUnit == 1'b0) begin
                    oBlinkMask = 4'b1100;
                end else begin
                    oBlinkMask = 4'b0011;
                end
            end
            default: begin
                oRun       = 1'b0;
                oEditEn    = 1'b0;
                oEditUnit  = 1'b0;
                oBlinkMask = 4'b0000;
            end
        endcase
    end
endmodule

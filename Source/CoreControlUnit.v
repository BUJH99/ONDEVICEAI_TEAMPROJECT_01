/*
[MODULE_INFO_START]
Name: CoreControlUnit
Role: Upper wrapper that integrates only core blocks.
Summary:
  - Wraps WatchCore, StopwatchCore, SensorControlUnit, Hcsr04Core, and Dht11Core.
  - Shares mode/command/tick inputs across cores.
  - Selects one active core output by iMode for display/sender handoff.
[MODULE_INFO_END]
*/

module CoreControlUnit #(
    parameter integer P_HCSR_CLK_HZ = 100_000_000,
    parameter integer P_DHT_CLK_HZ  = 100_000_000
)(
    input  wire        iClk,
    input  wire        iRstn,
    input  wire        iTick1kHz,
    input  wire [1:0]  iMode,
    input  wire        iCmdValid,
    input  wire [4:0]  iCmdCode,

    input  wire        iHcsrEcho,
    output wire        oHcsrTrig,
    inout  wire        ioDht11Data,

    output reg  [15:0] oFndData,
    output reg  [31:0] oFullData,
    output reg  [3:0]  oBlinkMask,
    output reg  [3:0]  oDotMask,

    output reg  [1:0]  oSenderMode,
    output reg         oSenderStart,
    output reg  [31:0] oSenderData,

    output wire [15:0] oHcsrDistance,
    output wire        oHcsrValid,
    output wire [15:0] oDhtTemp,
    output wire [15:0] oDhtHumi,
    output wire        oDhtValid
);

    localparam [1:0] LP_MODE_WATCH     = 2'd0;
    localparam [1:0] LP_MODE_STOPWATCH = 2'd1;
    localparam [1:0] LP_MODE_HCSR04    = 2'd2;
    localparam [1:0] LP_MODE_DHT11     = 2'd3;

    wire [15:0] wWatch2Top_FndData;
    wire [31:0] wWatch2Top_FullData;
    wire [3:0]  wWatch2Top_BlinkMask;
    wire [3:0]  wWatch2Top_DotMask;

    wire [15:0] wStop2Top_FndData;
    wire [31:0] wStop2Top_FullData;
    wire [3:0]  wStop2Top_BlinkMask;
    wire [3:0]  wStop2Top_DotMask;

    wire        wSensor2Hcsr_Start;
    wire        wSensor2Dht_Start;

    wire [15:0] wHcsr2Top_Distance;
    wire        wHcsr2Top_Valid;
    wire [15:0] wDht2Top_Temp;
    wire [15:0] wDht2Top_Humi;
    wire        wDht2Top_Valid;

    wire [15:0] wHcsr2Top_FndBcd;
    wire [31:0] wHcsr2Top_FullBcd;
    wire [15:0] wDht2Top_FndBcd;
    wire [31:0] wDht2Top_FullBcd;

    function [15:0] fnBin16ToBcd4;
        input [15:0] iValue;
        reg [15:0] wRemainder;
    begin
        wRemainder = iValue;
        fnBin16ToBcd4[15:12] = (wRemainder / 16'd1000) % 16'd10;
        fnBin16ToBcd4[11:8]  = (wRemainder / 16'd100)  % 16'd10;
        fnBin16ToBcd4[7:4]   = (wRemainder / 16'd10)   % 16'd10;
        fnBin16ToBcd4[3:0]   = wRemainder % 16'd10;
    end
    endfunction

    function [7:0] fnBin8ToBcd2;
        input [7:0] iValue;
        reg [7:0] wRemainder;
    begin
        wRemainder = iValue;
        fnBin8ToBcd2[7:4] = (wRemainder / 8'd10) % 8'd10;
        fnBin8ToBcd2[3:0] = wRemainder % 8'd10;
    end
    endfunction

    assign wHcsr2Top_FndBcd  = fnBin16ToBcd4(wHcsr2Top_Distance);
    assign wHcsr2Top_FullBcd = {16'h0000, wHcsr2Top_FndBcd};

    assign wDht2Top_FullBcd = {
        fnBin8ToBcd2(wDht2Top_Humi[15:8]),
        fnBin8ToBcd2(wDht2Top_Humi[7:0]),
        fnBin8ToBcd2(wDht2Top_Temp[15:8]),
        fnBin8ToBcd2(wDht2Top_Temp[7:0])
    };
    assign wDht2Top_FndBcd = {
        fnBin8ToBcd2(wDht2Top_Humi[15:8]),
        fnBin8ToBcd2(wDht2Top_Temp[15:8])
    };

    assign oHcsrDistance = wHcsr2Top_Distance;
    assign oHcsrValid    = wHcsr2Top_Valid;
    assign oDhtTemp      = wDht2Top_Temp;
    assign oDhtHumi      = wDht2Top_Humi;
    assign oDhtValid     = wDht2Top_Valid;

    WatchCore uWatchCore (
        .iClk      (iClk),
        .iRstn     (iRstn),
        .iTick1kHz (iTick1kHz),
        .iMode     (iMode),
        .iCmdValid (iCmdValid),
        .iCmdCode  (iCmdCode),
        .oFndData  (wWatch2Top_FndData),
        .oFullData (wWatch2Top_FullData),
        .oBlinkMask(wWatch2Top_BlinkMask),
        .oDotMask  (wWatch2Top_DotMask)
    );

    StopwatchCore uStopwatchCore (
        .iClk      (iClk),
        .iRstn     (iRstn),
        .iTick1kHz (iTick1kHz),
        .iMode     (iMode),
        .iCmdValid (iCmdValid),
        .iCmdCode  (iCmdCode),
        .oFndData  (wStop2Top_FndData),
        .oFullData (wStop2Top_FullData),
        .oBlinkMask(wStop2Top_BlinkMask),
        .oDotMask  (wStop2Top_DotMask)
    );

    SensorControlUnit uSensorControlUnit (
        .iClk      (iClk),
        .iRstn     (iRstn),
        .iTick1kHz (iTick1kHz),
        .iCmdValid (iCmdValid),
        .iCmdCode  (iCmdCode),
        .iMode     (iMode),
        .oHcsrStart(wSensor2Hcsr_Start),
        .oDht11Start(wSensor2Dht_Start)
    );

    Hcsr04Core #(
        .P_SYS_CLK_HZ(P_HCSR_CLK_HZ)
    ) uHcsr04Core (
        .iClk      (iClk),
        .iRstn     (iRstn),
        .iStart    (wSensor2Hcsr_Start),
        .iEcho     (iHcsrEcho),
        .oTrig     (oHcsrTrig),
        .oDistance (wHcsr2Top_Distance),
        .oValid    (wHcsr2Top_Valid)
    );

    Dht11Core #(
        .P_SYS_CLK_HZ(P_DHT_CLK_HZ)
    ) uDht11Core (
        .iClk   (iClk),
        .iRstn  (iRstn),
        .iStart (wSensor2Dht_Start),
        .ioData (ioDht11Data),
        .oTemp  (wDht2Top_Temp),
        .oHumi  (wDht2Top_Humi),
        .oValid (wDht2Top_Valid)
    );

    always @(*) begin
        oFndData     = 16'h0000;
        oFullData    = 32'h0000_0000;
        oBlinkMask   = 4'b0000;
        oDotMask     = 4'b0000;
        oSenderMode  = iMode;
        oSenderStart = 1'b0;
        oSenderData  = 32'h0000_0000;

        case (iMode)
            LP_MODE_WATCH: begin
                oFndData    = wWatch2Top_FndData;
                oFullData   = wWatch2Top_FullData;
                oBlinkMask  = wWatch2Top_BlinkMask;
                oDotMask    = wWatch2Top_DotMask;
                oSenderData = wWatch2Top_FullData;
            end

            LP_MODE_STOPWATCH: begin
                oFndData    = wStop2Top_FndData;
                oFullData   = wStop2Top_FullData;
                oBlinkMask  = wStop2Top_BlinkMask;
                oDotMask    = wStop2Top_DotMask;
                oSenderData = wStop2Top_FullData;
            end

            LP_MODE_HCSR04: begin
                oFndData     = wHcsr2Top_FndBcd;
                oFullData    = wHcsr2Top_FullBcd;
                oBlinkMask   = 4'b0000;
                oDotMask     = 4'b0100;
                oSenderStart = wHcsr2Top_Valid;
                oSenderData  = wHcsr2Top_FullBcd;
            end

            LP_MODE_DHT11: begin
                oFndData     = wDht2Top_FndBcd;
                oFullData    = wDht2Top_FullBcd;
                oBlinkMask   = 4'b0000;
                oDotMask     = 4'b0100;
                oSenderStart = wDht2Top_Valid;
                oSenderData  = wDht2Top_FullBcd;
            end

            default: begin
                oFndData     = 16'h0000;
                oFullData    = 32'h0000_0000;
                oBlinkMask   = 4'b0000;
                oDotMask     = 4'b0000;
                oSenderMode  = iMode;
                oSenderStart = 1'b0;
                oSenderData  = 32'h0000_0000;
            end
        endcase
    end

endmodule


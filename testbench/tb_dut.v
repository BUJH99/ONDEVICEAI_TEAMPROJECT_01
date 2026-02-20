`timescale 1ns / 1ps

module tb_dut ();
    //-------------------------sinario---------------------------
    //A. hardware
    //  1. stopwatch
    //      a. btn_R                                          run
    //      b. btn_D                                          run(up -> down)
    //      c. btn_U                                          run(down -> up)
    //      d. sw[0] == 1 + (bnt_R)*2 + (bnt_U)*2,(bnt_D)*5   time_set(Set digit + Set time number)
    //      e. sw[0] == 0 + btn_R                             run(for check running to setting time)
    //      f. btn_L                                          clear
    //  2. watch            
    //      a. nothing                                        delay(for check time up) 
    //      b. sw[0] == 1 + (bnt_R)*3 + (bnt_U)*3,(bnt_D)*4   time_set(Set digit + Set time number)
    //      c. sw[0] == 0                                     delay(for check time up)
    //      d. btn_L                                          clear
    //  3. sr04             
    //      a. btn_R                                          Run
    //      b. btn_U                                          Auto_Run 
    //  4. dht11         
    //      a.  btn_R                                         Run
    //      b.  sw[1] == 1 + sw[1] == 0                       check humi, temp + check sw[1]
    //      b.  btn_U                                         Auto_Run
    //B. uart
    //  1. stopwatch
    //      a. "2" + "r" + "2"                                mode_set_stopwatch                                  
    //      b. "R"                                            run
    //      c. "D"                                            run(up -> down)
    //      d. "U"                                            run(down -> up)
    //      e. "0" + "R"*2 + "U"*2 + "D" + "0"                time_set(Set digit + Set time number)
    //      g. "S"                                            check sender
    //      h. "L"                                            clear
    //----------------------------------------------------------
    //------------------------setting---------------------------
    parameter BTN_Dedounce = (100_000_000 / 1999999);
    parameter BAUD = 9600;
    parameter BAUD_REPIOD = (100_000_000 / BAUD) * 10;  //104_160
    parameter ASCII_0 = 8'h30, ASCII_1 = 8'h31, ASCII_2 = 8'h32, ASCII_S = 8'h73,
            ASCII_U = 8'h75, ASCII_L = 8'h6c, ASCII_M = 8'h6D, ASCII_R = 8'h72, ASCII_D = 8'h64;

    //input ports
    reg clk, rst;
    reg btn_u, btn_l, btn_r, btn_d;
    reg [2:0] sw;
    reg echo;
    reg rx;
    //output ports
    wire tx;
    wire [7:0] fnd_data;
    wire [3:0] fnd_digit;
    wire trigger;
    //inout ports
    wire dhtio;

    //other
    reg [7:0] rx_test_data;
    reg sensor_io_sel, dht11_sensor_io;
    reg [8:0] set_Distance;
    reg [39:0] dht11_test_data;
    integer i = 0;

    assign dhtio = (sensor_io_sel) ? 1'bz : dht11_sensor_io;

    //----------DUT-------------


    //--------------------------
    //--------------------------task----------------------------
    integer TIME_START = 0, TIME_REG = 0;
    integer SR04_Operation = 80_000;  //80us
    task sr04();
        begin
            TIME_START = 0;
            TIME_REG   = 0;
            repeat (10) @(posedge clk);
            //start
            @(posedge clk);
            btn_r = 1;
            repeat (BTN_Dedounce) @(posedge clk);
            btn_r = 0;

            //trigger check
            wait (trigger);
            TIME_START = $time;
            wait (!trigger);
            $display(
                "%t, \tTREAGER ==> start = %d, \tend = %d, \tlength = %d ns",
                $time, TIME_START, $time, ($time - TIME_START));
            TIME_START = 0;

            //SR04_Operation
            #(SR04_Operation);

            //senser output
            echo = 1;
            TIME_START = $time;
            #(set_Distance * 58 * 1000);
            echo = 0;
            TIME_REG = $time - TIME_START;
            #1;
        end
    endtask
    //--------------------------dht11----------------------------
    task test_dht11();
        begin
            //START + WAIT
            btn_r = 1;
            repeat (BTN_Dedounce) @(posedge clk);
            btn_r = 0;
            //19msec + 30usec
            #(1900 * 10 * 1000 + 30_000);

            sensor_io_sel   = 0;
            //SYNC_L
            dht11_sensor_io = 0;
            #(80_000);  //10us
            //SYNC_H
            dht11_sensor_io = 1;
            #(80_000);  //10us

            //DATA_C
            for (i = 39; i >= 0; i = i - 1) begin
                dht11_sensor_io = 0;
                #(50_000);
                if (dht11_test_data[i] == 0) begin
                    dht11_sensor_io = 1'b1;
                    #(28_000);
                end else begin
                    dht11_sensor_io = 1'b1;
                    #(70_000);
                end
            end
            //STOP
            dht11_sensor_io = 0;
            #(50_000);  //50us
            sensor_io_sel = 1;
        end
    endtask
    //-----------------------uart_rx---------------------------
    task uart_sender();
        begin
            rx = 0;
            #(BAUD_REPIOD);
            for (i = 0; i < 8; i = i + 1) begin
                rx = rx_test_data[i];
                #(BAUD_REPIOD);
            end
            //stop
            rx = 1'b1;
            #(BAUD_REPIOD);
        end
    endtask
    //----------------------------------------------------------

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;
        sw = 0;
        btn_u = 0;
        btn_l = 0;
        btn_r = 0;
        btn_d = 0;
        rx = 1;
        set_Distance = 0;
        dht11_test_data = 0;


        #50;
        rst = 0;
        repeat (50) @(posedge clk);
        //Hardware--------------------------------------------
        //----------------------stopwatch---------------------        
        sw[2] = 1;
        //test-run up count
        @(posedge clk);
        btn_r = 1;
        repeat (BTN_Dedounce) @(posedge clk);
        btn_r = 0;

        //-----------------------watch------------------------
        //mode_chage
        sw[2] = 0;
        btn_r = 1;
        repeat (BTN_Dedounce) @(posedge clk);
        sw[2] = 1;
        btn_r = 0;

        //test

        //-----------------------sr04-------------------------
        //mode_chage
        sw[2] = 0;
        btn_r = 1;
        repeat (BTN_Dedounce) @(posedge clk);
        sw[2] = 1;
        btn_r = 0;

        //test
        set_Distance = 240;
        sr04();
        //-----------------------dht11------------------------
        //mode_chage
        sw[2] = 0;
        btn_r = 1;
        repeat (BTN_Dedounce) @(posedge clk);
        sw[2] = 1;
        btn_r = 0;

        //test
        dht11_test_data = {
            8'd36, 8'd8, 8'd79, 8'd99, 8'd222
        };  //sum:222 hum:79.99 tem:36.8
        test_dht11();
        //uart-----------------------------------------------
        rx_test_data = ASCII_2;
        uart_sender();




        repeat (50) @(posedge clk);
        $stop;

    end
endmodule


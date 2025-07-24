`timescale 1ns/1ps

// Testbench for uart_lcd_tx
// Sends ASCII "$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47\r\n," over RX,
// monitors LCD and TX echo

`include "src/fpga/uart_top.v"
`include "src/fpga/baud_rate_generator.v"
`include "src/fpga/fifo.v"
`include "src/fpga/uart_receiver/uart_receiver.v"
`include "src/fpga/uart_transmitter/uart_transmitter.v"
`include "src/fpga/lcd/lcd1602.v"
`include "src/fpga/parser/nmea_parser.v"

module uart_top_tb;
    // Clock & reset
    reg clk_50MHz = 0;
    always #10 clk_50MHz = ~clk_50MHz;  // 50 MHz

    reg reset_n = 0;  // active-low reset
    initial begin
        reset_n = 0;
        #200;
        reset_n = 1;
    end

    // UART RX line (idle = 1)
    reg rx = 1'b1;

    // DUT signals
    wire tx;
    wire rs, rw, enable;
    wire [7:0] data_lcd;
    wire fifo_full, fifo_empty;

    // Instantiate DUT
    uart_top #(
        .DATA_BITS     (8),
        .STOP_BIT_TICK (16),
        .BR_LIMIT      (326),
        .BR_BITS       (9),
        .FIFO_EXP      (4)
    ) DUT (
        .clk_50MHz(clk_50MHz),
        .reset    (reset_n),
        .rx       (rx),
        .tx       (tx),
        .rs       (rs),
        .rw       (rw),
        .enable   (enable),
        .data_lcd (data_lcd),
        .fifo_full (fifo_full),
        .fifo_empty(fifo_empty)
    );

    // Baud period for 9600 baud: ~104166 ns
    localparam integer BAUD_PERIOD = 104166;

    // Task: send one byte via UART 8N1 LSB-first
    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            // Start bit
            rx = 1'b0;
            #(BAUD_PERIOD);
            // Data bits LSB first
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #(BAUD_PERIOD);
            end
            // Stop bit
            rx = 1'b1;
            #(BAUD_PERIOD);
        end
    endtask

    // Stimulus
    initial begin
        // Wait for reset deassertion
        @(posedge reset_n);
        // Give some margin
        #500_000;

        // Send "$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47\r\n"
        uart_send_string;

        // Wait for LCD update and TX echoes
        #200_000_000;

        $display("--- Simulation complete ---");
        $finish;
    end

    // Task to send the entire string byte by byte
    task uart_send_string;
        begin
            uart_send_byte("$");
            uart_send_byte("G");
            uart_send_byte("P");
            uart_send_byte("R");
            uart_send_byte("M");
            uart_send_byte("C");
            uart_send_byte(",");
            uart_send_byte("0");
            uart_send_byte("5");
            uart_send_byte("2");
            uart_send_byte("4");
            uart_send_byte("3");
            uart_send_byte("7");
            uart_send_byte(".");
            uart_send_byte("0");
            uart_send_byte("0");
            uart_send_byte(",");
            uart_send_byte("A");
            uart_send_byte(",");
            uart_send_byte("0");
            uart_send_byte("4");
            uart_send_byte("3");
            uart_send_byte("8");
            uart_send_byte(".");
            uart_send_byte("2");
            uart_send_byte("1");
            uart_send_byte("0");
            uart_send_byte("0");
            uart_send_byte("9");
            uart_send_byte(",");
            uart_send_byte("N");
            uart_send_byte(",");
            uart_send_byte("0");
            uart_send_byte("7");
            uart_send_byte("4");
            uart_send_byte("0");
            uart_send_byte("5");
            uart_send_byte(".");
            uart_send_byte("4");
            uart_send_byte("8");
            uart_send_byte("8");
            uart_send_byte("4");
            uart_send_byte("1");
            uart_send_byte(",");
            uart_send_byte("W");
            uart_send_byte(",");
            uart_send_byte("1");
            uart_send_byte(".");
            uart_send_byte("6");
            uart_send_byte("2");
            uart_send_byte("2");
            uart_send_byte(",");
            uart_send_byte(",");
            uart_send_byte("2");
            uart_send_byte("4");
            uart_send_byte("0");
            uart_send_byte("7");
            uart_send_byte("2");
            uart_send_byte("5");
            uart_send_byte(",");
            uart_send_byte(",");
            uart_send_byte(",");
            uart_send_byte("A");
            uart_send_byte("*");
            uart_send_byte("6");
            uart_send_byte("6");
            uart_send_byte("\r");
            uart_send_byte("\n");
        end
    endtask

    // VCD dump
    initial begin
        $dumpfile("uart_top_tb.vcd");
        $dumpvars(0, uart_top_tb);
    end

endmodule

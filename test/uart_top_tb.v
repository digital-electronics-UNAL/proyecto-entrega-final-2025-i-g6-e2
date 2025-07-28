`timescale 1ns/1ps

// Testbench for uart_top
// Sends a simulated NMEA string over UART RX
// Observes the TX line for echo

`include "src/fpga/uart_top.v"
`include "src/fpga/baud_rate_generator.v"
`include "src/fpga/fifo.v"
`include "src/fpga/uart_receiver/uart_receiver.v"
`include "src/fpga/uart_transmitter/uart_transmitter.v"

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
    wire fifo_full, fifo_empty;

    // Instantiate DUT
    uart_top #(
        .DATA_BITS     (8),
        .STOP_BIT_TICK (16),
        .BR_LIMIT      (326),
        .BR_BITS       (9),
        .FIFO_EXP      (4)
    ) DUT (
        .clk_50MHz   (clk_50MHz),
        .reset       (reset_n),
        .rx          (rx),
        .tx          (tx),
        .fifo_full   (fifo_full),
        .fifo_empty  (fifo_empty)
    );

    // Baud period for 9600 baud = 1 / 9600 ≈ 104166 ns
    localparam integer BAUD_PERIOD = 104166;

    // Task: send one byte via UART 8N1 LSB-first
    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            rx = 1'b0;  // start bit
            #(BAUD_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #(BAUD_PERIOD);
            end
            rx = 1'b1;  // stop bit
            #(BAUD_PERIOD);
        end
    endtask

    // Stimulus
    initial begin
        @(posedge reset_n);
        #500_000; // Espera a que el sistema se estabilice

        uart_send_string;

        #200_000_000;

        $display("--- Simulation complete ---");
        $finish;
    end

    // Task: send entire string
    task uart_send_string;
        reg [8*64-1:0] msg;
        integer i;
        begin
            msg = "$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47\r\n";
            for (i = 0; i < 64 && msg[8*63 - i*8 +: 8] != 8'd0; i = i + 1)
                uart_send_byte(msg[8*63 - i*8 +: 8]);
        end
    endtask

    // VCD dump
    initial begin
        $dumpfile("uart_top_tb.vcd");
        $dumpvars(0, uart_top_tb);
    end

endmodule

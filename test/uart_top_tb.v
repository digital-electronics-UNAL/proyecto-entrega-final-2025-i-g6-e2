`timescale 1ns/1ps
`include "src/fpga/uart_top.v"

module uart_rx_tb;

    /*-----  Señales de estímulo y monitoreo  -----*/
    reg  clk_50MHz_tb = 0;
    reg  reset_tb     = 1;
    reg  rx_tb        = 1;
    reg  read_uart_tb = 0;

    wire rx_full_tb, rx_empty_tb;
    wire [7:0] read_data_tb;

    uart_top #(
        .DATA_BITS    (8),
        .STOP_BIT_TICK(16),
        .BR_LIMIT     (326),   // 50 MHz / (9600*16) ≈ 326
        .BR_BITS      (9),
        .FIFO_EXP     (4)
    ) uut (
        .clk_50MHz (clk_50MHz_tb),
        .reset     (reset_tb),
        .rx        (rx_tb),
        .read_uart (read_uart_tb),
        .rx_full   (rx_full_tb),
        .rx_empty  (rx_empty_tb),
        .read_data (read_data_tb)
    );

    /*-----  Generador de clock de 50 MHz (20 ns)  -----*/
    always #10 clk_50MHz_tb = ~clk_50MHz_tb;

    /*-----  Parámetro de tiempo de bit a 9600 bps  -----*/
    localparam integer BIT_PERIOD = 104_167;  // ns

    /*-----  Tarea para enviar un byte UART (LSB first)  -----*/
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            rx_tb = 1'b0;            #(BIT_PERIOD);   // start bit
            for (i = 0; i < 8; i = i + 1) begin
                rx_tb = data[7-i];     #(BIT_PERIOD);   // bits 0…7
                $display("%d) data=%h bit %1b", i, data, data[7-i]);

            end
            rx_tb = 1'b1;            #(BIT_PERIOD);   // stop bit
        end
    endtask

    /*-----  Tarea para leer un byte de la FIFO  -----*/
    task fifo_read_pulse;
        begin
            @(posedge clk_50MHz_tb);   // alinea al reloj
            read_uart_tb = 1'b1;       
            @(posedge clk_50MHz_tb);
            read_uart_tb = 1'b0;
            @(posedge clk_50MHz_tb);   // FIFO actualiza read_data_tb
        end
    endtask

    /*-----  Secuencia de estímulos  -----*/
    initial begin
        /* Reset síncrono */
        #200       reset_tb = 0;
        #(5*BIT_PERIOD);

        // ——— Envío de las tres tramas sin leer ———
        send_uart_byte(8'h41);  // 'A'
        #(10*BIT_PERIOD);       // gap ≈1 ms
        send_uart_byte(8'h42);  // 'B'
        #(10*BIT_PERIOD);       
        send_uart_byte(8'h43);  // 'C'
        #(10*BIT_PERIOD);

        // ——— Ahora sí leemos 3 bytes de la FIFO ———
        fifo_read_pulse();      // leer 'A'
        fifo_read_pulse();      // leer 'B'
        fifo_read_pulse();      // leer 'C'

        $finish;
    end

    /*-----  Dump completo para GTKWave / VCD  -----*/
    initial begin
        $dumpfile("uart_rx_tb.vcd");
        $dumpvars(-1, uart_rx_tb);
    end

endmodule

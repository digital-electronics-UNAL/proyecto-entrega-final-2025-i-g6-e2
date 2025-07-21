`timescale 1ns/1ps
`include "src/fpga/uart_top.v"          // DUT
`include "src/fpga/baud_rate_generator.v"
`include "src/fpga/uart_receiver/uart_receiver.v"  // receptor-espía

module uart_top_loopback_tb;

    /*--------------------------------------------------------------
     * 1.  Señales de estímulo / monitor
     *------------------------------------------------------------*/
    reg  clk_50MHz_tb = 0;
    reg  reset_tb     = 0;          // 0 = reset interno activo
    reg  rx_tb        = 1;          // sensor → FPGA
    wire tx_tb;                     // FPGA  → ESP32 (salida)

    /*--------------------------------------------------------------
     * 2.  Instancia del diseño bajo prueba
     *------------------------------------------------------------*/
    uart_top #(
        .DATA_BITS    (8),
        .STOP_BIT_TICK(16),
        .BR_LIMIT     (326),        // 50 MHz / (9600×16)
        .BR_BITS      (9),
        .FIFO_EXP     (4)
    ) uut (
        .clk_50MHz (clk_50MHz_tb),
        .reset     (reset_tb),
        .rx        (rx_tb),
        .tx        (tx_tb),
        .read_uart (1'b0),          // no lectura manual
        .fifo_full (), .fifo_empty (),
        .fifo_data_out ()           // no se usa en esta prueba
    );

    /*--------------------------------------------------------------
     * 3.  Reloj de 50 MHz
     *------------------------------------------------------------*/
    always #10 clk_50MHz_tb = ~clk_50MHz_tb;

    /*--------------------------------------------------------------
     * 4.  Receptor “espía” para decodificar la línea TX
     *------------------------------------------------------------*/
    wire sample_tick_tb;
    baud_rate_generator #(
        .N(9), .M(326)
    ) BRG_MON (
        .clk_50MHz (clk_50MHz_tb),
        .reset     (reset_tb),
        .tick      (sample_tick_tb)
    );

    wire        spy_ready;
    wire [7:0]  spy_byte;

    uart_receiver #(
        .DATA_BITS(8), .STOP_BIT_TICK(16)
    ) RX_SPY (
        .clk_50MHz   (clk_50MHz_tb),
        .reset       (reset_tb),
        .rx          (tx_tb),           // escucha TX del DUT
        .sample_tick (sample_tick_tb),
        .data_ready  (spy_ready),
        .data_out    (spy_byte)
    );

    /*--------------------------------------------------------------
     * 5.  Tarea para enviar un byte UART  (MSB→LSB)
     *------------------------------------------------------------*/
    localparam integer BIT_PERIOD = 104_167;   // ns @9600 bps

    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            rx_tb = 1'b0;                #(BIT_PERIOD);            // start
            for (i = 0; i < 8; i = i + 1) begin
                rx_tb = data[7-i];       #(BIT_PERIOD);            // b7…b0
            end
            rx_tb = 1'b1;                #(BIT_PERIOD);            // stop
        end
    endtask

    /*--------------------------------------------------------------
     * 6.  Proceso de log del receptor-espía
     *------------------------------------------------------------*/
    integer n = 0;
    always @(posedge clk_50MHz_tb)
        if (spy_ready) begin
            $display("%0t ns  →  byte%0d = 0x%02h", $time, n, spy_byte);
            n = n + 1;
        end

    /*--------------------------------------------------------------
     * 7.  Secuencia de estímulos
     *------------------------------------------------------------*/
    initial begin
        // liberar reset tras 200 ns
        #200 reset_tb = 1;
        #(5*BIT_PERIOD);

        send_uart_byte(8'h41);  #(5*BIT_PERIOD);   // 'A'
        send_uart_byte(8'h42);  #(5*BIT_PERIOD);   // 'B'
        send_uart_byte(8'h43);                    // 'C'

        // Esperamos a que el espía reciba los 3 bytes
        wait (n == 3);
        #1_000;            // pequeño margen
        $finish;
    end

    /*--------------------------------------------------------------
     * 8.  Dump comprimido (FST)
     *------------------------------------------------------------*/
    initial begin
        $dumpfile("waves.fst");
        $dumpvars(0, uut);      // solo DUT
        $dumpvars(0, RX_SPY);   // y espía
    end
endmodule

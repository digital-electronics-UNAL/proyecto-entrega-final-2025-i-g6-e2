`include "src/fpga/uart_receiver_lcd.v"
`include "src/fpga/baud_rate_generator.v"
`include "src/fpga/fifo.v"
`include "src/fpga/uart_receiver/uart_receiver.v"
`include "src/fpga/uart_transmitter/uart_transmitter.v"
`include "src/fpga/lcd/lcd1602.v"
module uart_lcd_tb;
    // -----------------------------------------------------------------
    //  Clock & reset
    // -----------------------------------------------------------------
    reg clk_50MHz = 0;
    always #10 clk_50MHz = ~clk_50MHz;       // 20 ns → 50 MHz

    reg reset_n = 0;                         // activo‑bajo
    initial begin
        reset_n = 0;
        #200;                                // 200 ns en reset
        reset_n = 1;
    end

    // -----------------------------------------------------------------
    //  Señales de I/O
    // -----------------------------------------------------------------
    wire fifo_full, fifo_empty;
    wire [7:0] data_lcd;
    wire rs, rw, enable;

    // read_uart no se usa → atado a 0
    wire read_uart = 1'b0;

    // UART RX línea (idle = 1)
    reg rx = 1'b1;

    // Instancia del DUT
    uart_lcd DUT (
        .clk_50MHz(clk_50MHz), .reset(reset_n), .rx(rx), .read_uart(read_uart),
        .rs(rs), .rw(rw), .enable(enable),
        .fifo_full(fifo_full), .fifo_empty(fifo_empty), .data_lcd(data_lcd)
    );

    // -----------------------------------------------------------------
    //  Tarea: enviar un byte por UART (8N1 @9600 baud)
    // -----------------------------------------------------------------
    localparam integer BAUD_PERIOD = 104166;   // 1/9600 s = 104.166 µs

    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            // start bit (0)
            rx = 1'b0; #(BAUD_PERIOD);
            // 8 data bits, LSB first
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[7-i]; #(BAUD_PERIOD);
            end
            // stop bit (1)
            rx = 1'b1; #(BAUD_PERIOD);
        end
    endtask

    // -----------------------------------------------------------------
    //  Estímulo
    // -----------------------------------------------------------------
    initial begin
        // Espera a que termine el reset
        @(posedge reset_n);
        #500_000;   // margen antes de enviar (0.5 ms)

        // Enviamos 3 bytes ASCII: "1", "2", "3"
        uart_send_byte(8'h31);
        #500_000;
        uart_send_byte(8'h32);
        #500_000;
        uart_send_byte(8'h33);

        // Pausa para que la LCD procese
        #200_000_000;  // 200 ms

        $display("TEST finished - revisa data_lcd en el waveform");
        $finish;
    end

    // -----------------------------------------------------------------
    //  Dump VCD
    // -----------------------------------------------------------------
    initial begin
        $dumpfile("uart_lcd_tb.vcd");
        $dumpvars(0, uart_lcd_tb);  
    end
endmodule

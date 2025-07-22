// `include "src/fpga/baud_rate_generator.v"
// `include "src/fpga/fifo.v"
// `include "src/fpga/uart_receiver/uart_receiver.v"
// `include "src/fpga/uart_transmitter/uart_transmitter.v"

/*
 *  ────────────────────────────────────────────────────────────────
 *  uart_top
 *  • Receptor UART  → FIFO (buffer compartido) → Transmisor UART
 *  • El receptor escribe un byte cada vez que lo recibe
 *  • El transmisor lee el byte siguiente cuando está libre
 *  • También puedes leer la FIFO de forma externa con read_uart
 *  ────────────────────────────────────────────────────────────────
 */
module uart_top #(
    parameter DATA_BITS     = 8,
    parameter STOP_BIT_TICK = 16,  // no. pulsos de muestreo por bit
    parameter BR_LIMIT      = 326,
    parameter BR_BITS       = 9,   // 512 > 326
    parameter FIFO_EXP      = 4    // direcciones FIFO (cambiar si resultan muy pocas)
) (
    input  clk_50MHz,
    input  reset,
    input  rx,                     // entrada lectura de rx
    output tx,                     // salida a la ESP32
    input  read_uart,              // lectura manual del FIFO
    output fifo_full,
    output fifo_empty,
    output [DATA_BITS-1:0] fifo_data_out,  // byte disponible para test/lectura,
);

    /*──────────────────────────
     *  Señales internas
     *──────────────────────────*/
    wire tick;                          // pulso del baud generator (16× nominal)
    wire rx_done_tick;                  // receptor ha recibido un byte completo
    wire [DATA_BITS-1:0] rx_data_out;   // byte desde el receptor

    wire tx_busy, tx_done_tick;         // flags del transmisor
    /*──────────────────────────*/

    /* ─────  Baud-rate generator (común a RX y TX) ───── */
    baud_rate_generator #(
        .N(BR_BITS),
        .M(BR_LIMIT)
    ) BAUD_RATE_GENERATOR (
        .clk_50MHz (clk_50MHz),
        .reset     (~reset),            // reset activo-alto interno
        .tick      (tick)
    );
    /* ─────  UART Receiver ───── */
    uart_receiver #(
        .DATA_BITS     (DATA_BITS),
        .STOP_BIT_TICK (STOP_BIT_TICK)
    ) UART_RX (
        .clk_50MHz   (clk_50MHz),
        .reset       (~reset),
        .rx          (rx),
        .sample_tick (tick),
        .data_ready  (rx_done_tick),
        .data_out    (rx_data_out)
    );

    /* ─────  UART Transmitter ───── */
    uart_transmitter #(
        .DATA_BITS     (DATA_BITS),
        .STOP_BIT_TICK (STOP_BIT_TICK)
    ) UART_TX (
        .clk_50MHz   (clk_50MHz),
        .reset       (~reset),
        .sample_tick (tick),
        .tx_start    (~fifo_empty),     // arranca cuando hay dato
        .data_in     (fifo_data_out),
        .tx          (tx),
        .tx_busy     (tx_busy),
        .tx_done_tick(tx_done_tick)
    );

    /* ─────  FIFO compartida ───── */
    fifo #(
        .DATA_SIZE      (DATA_BITS),
        .ADDR_SPACE_EXP (FIFO_EXP)
    ) FIFO (
        .clk            (clk_50MHz),
        .reset          (~reset),
        .write_to_fifo  (rx_done_tick),            // receptor escribe
        .read_from_fifo (read_uart | tx_done_tick),// lector externo O TX
        .write_data_in  (rx_data_out),             // byte del receptor
        .read_data_out  (fifo_data_out),           // byte hacia TX o testbench
        .empty          (fifo_empty),
        .full           (fifo_full)
    );

endmodule

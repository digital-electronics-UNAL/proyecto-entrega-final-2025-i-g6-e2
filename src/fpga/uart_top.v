`include "src/fpga/baud_rate_generator.v"
`include "src/fpga/fifo.v"
`include "src/fpga/uart_receiver.v"

module uart_top #(parameter DATA_BITS = 8,
    STOP_BIT_TICK = 16, // no. pulsos de muestreo por bit
    BR_LIMIT = 326,
    BR_BITS = 9, // 512 > 326
    FIFO_EXP = 4 // direcciones FIFO (cambiar si resultan muy pocas)
) (
    input clk_50MHz,
    input reset,
    input rx, // entrada lectura de rx
    input read_uart, // lectura del FIFO
    output rx_full,
    output rx_empty,
    output [DATA_BITS - 1: 0] read_data
);

    wire tick; // para obtener del baud generator
    wire rx_done_tick; // marca cuando ha recibido un byte completo
    wire [DATA_BITS-1:0] rx_data_out; // al escribir en la FIFO rx

    baud_rate_generator
        #(
            .N(BR_BITS),
            .M(BR_LIMIT)
        )
        BAUD_RATE_GENERATOR
        (
            .clk_50MHz(clk_50MHz),
            .reset(reset),
            .tick(tick)
        );

    uart_receiver
        #(
            .DATA_BITS(DATA_BITS),
            .STOP_BIT_TICK(STOP_BIT_TICK)
        )
        UART_RX
        (
            .clk_50MHz(clk_50MHz),
            .reset(reset),
            .rx(rx),
            .sample_tick(tick),
            .data_ready(rx_done_tick),
            .data_out(rx_data_out)
        );

    fifo
        #(
            .DATA_SIZE(DATA_BITS),
            .ADDR_SPACE_EXP(FIFO_EXP)
        )
        FIFO
        (
            .clk(clk_50MHz),
            .reset(reset),
            .write_to_fifo(rx_done_tick), // cada que el receptor tenga un byte
            .read_from_fifo(read_uart), // señar externa para extraer
            .write_data_in(rx_data_out), // byte del receptor
            .read_data_out(read_data), // byte que sale de la FIFO
            .empty(rx_empty),
            .full(rx_full)
        );


endmodule
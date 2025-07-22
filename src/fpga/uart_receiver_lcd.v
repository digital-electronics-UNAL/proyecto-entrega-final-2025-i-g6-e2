// -----------------------------------------------------------------------------
// UART → FIFO → LCD1602 (versión sin puertos nuevos)
//   • El FIFO se vacía automáticamente (read = write retrasado 1 ciclo).
//   • No se toca el controlador LCD original; simplemente recibe «latitud».
//   • Se mantiene la interfaz externa original (read_uart sigue estando,
//     pero ya no es necesario conectarlo – puede dejarse sin uso).
// -----------------------------------------------------------------------------

module uart_lcd #(
    parameter DATA_BITS     = 8,
    parameter STOP_BIT_TICK = 16,   // nº pulsos de muestreo por bit
    parameter BR_LIMIT      = 326,
    parameter BR_BITS       = 9,    // 512 > 326
    parameter FIFO_EXP      = 4     // direcciones FIFO
) (
    input  clk_50MHz,
    input  reset,                // activo‑bajo, se conserva igual que el diseño original
    input  rx,                   // línea serie
    input  read_uart,            // ya no se usa, pero se conserva el puerto
    input  rs,
    input  rw,
    input  enable,
    output fifo_full,
    output fifo_empty,
    output [DATA_BITS-1:0] data_lcd
);
    wire tick;                          // 16× baud
    wire rx_done_tick;                  // byte recibido
    wire [DATA_BITS-1:0] rx_data_out;   // dato del receptor UART

    // ------- Baud‑rate generator -------
    baud_rate_generator #(
        .N(BR_BITS),
        .M(BR_LIMIT)
    ) BAUD_RATE_GENERATOR (
        .clk_50MHz (clk_50MHz),
        .reset     (~reset),            // diseño original: reset activo‑bajo
        .tick      (tick)
    );

    // ------------ UART Rx ---------------
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

    // ------------- FIFO -----------------
    wire                  fifo_rd_pulse;    // pulso de lectura interno
    wire [DATA_BITS-1:0]  fifo_data_out;

    fifo #(
        .DATA_SIZE      (DATA_BITS),
        .ADDR_SPACE_EXP (FIFO_EXP)
    ) FIFO (
        .clk            (clk_50MHz),
        .reset          (~reset),
        .write_to_fifo  (rx_done_tick),      // se escribe al recibir byte
        .read_from_fifo (fifo_rd_pulse),     // lectura automática
        .write_data_in  (rx_data_out),
        .read_data_out  (fifo_data_out),
        .empty          (fifo_empty),
        .full           (fifo_full)
    );

    //  Lee el FIFO exactamente un ciclo después de cada escritura
    //  (de ese modo nunca está vacío cuando se lee).
    reg rd_delay;
    always @(posedge clk_50MHz or negedge reset) begin
        if (!reset) begin
            rd_delay <= 1'b0;
        end else begin
            rd_delay <= rx_done_tick;     // retardo de 1 ciclo
        end
    end
    assign fifo_rd_pulse = rd_delay;      // pulso de lectura

    //  Registro que guarda el dato extraído del FIFO
    //  — estable en el dominio rápido y visible para la LCD
    reg [DATA_BITS-1:0] latitud_reg;
    always @(posedge clk_50MHz or negedge reset) begin
        if (!reset) begin
            latitud_reg <= {DATA_BITS{1'b0}};
        end else if (rd_delay) begin
            latitud_reg <= fifo_data_out;
        end
    end

    LCD1602_controller #(
        .NUM_COMMANDS      (4),
        .NUM_DATA_ALL      (32),
        .NUM_DATA_PERLINE  (16),
        .DATA_BITS         (8),
        .COUNT_MAX         (800000)
    ) lcd (
        .clk     (clk_50MHz),
        .latitud (latitud_reg),           // el dato capturado
        .reset   (reset),
        .ready_i (1'b1),
        .rs      (rs),
        .rw      (rw),
        .enable  (enable),
        .data    (data_lcd)
    );

endmodule

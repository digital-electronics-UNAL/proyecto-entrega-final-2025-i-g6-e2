// -----------------------------------------------------------------------------
// UART → FIFO → LCD1602 + UART TX (echo)
//   • Receptor UART → display LCD
//   • Receptor UART → FIFO → Transmisor UART (eco)
//   • Se muestra directamente 'latitud' en ASCII en la LCD
// -----------------------------------------------------------------------------

module uart_top #(
    parameter DATA_BITS     = 8,
    parameter STOP_BIT_TICK = 16,   // nº pulsos de muestreo por bit
    parameter BR_LIMIT      = 326,
    parameter BR_BITS       = 9,    // 512 > 326
    parameter FIFO_EXP      = 4     // direcciones FIFO
)(
    input  wire               clk_50MHz,
    input  wire               reset,    // activo-bajo
    input  wire               rx,       // línea serie entrante
    output wire               tx,       // línea serie saliente (eco)

    // LCD1602 interface
    output wire               rs,
    output wire               rw,
    output wire               enable,
    output wire [DATA_BITS-1:0] data_lcd,

    // FIFO status
    output wire               fifo_full,
    output wire               fifo_empty
);

    // ---------------------- señales internas ----------------------
    wire tick;                          // 16× baud
    wire rx_done_tick;                  // byte recibido
    wire [DATA_BITS-1:0] rx_data_out;   // dato del receptor UART

    wire [DATA_BITS-1:0] fifo_data_out; // dato extraído del FIFO
    wire tx_busy, tx_done_tick;

    // se usa para arrancar la lectura y transmisión: eco única vez
    wire tx_start = (~fifo_empty) && (~tx_busy);

    // -------------------- Baud-rate generator --------------------
    baud_rate_generator #(
        .N(BR_BITS),
        .M(BR_LIMIT)
    ) BAUD_RATE_GEN (
        .clk_50MHz(clk_50MHz),
        .reset    (~reset),    // reset interno activo-alto
        .tick     (tick)
    );

    // ---------------------- UART Receiver ------------------------
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

    // ------------------------- FIFO -------------------------------
    fifo #(
        .DATA_SIZE      (DATA_BITS),
        .ADDR_SPACE_EXP (FIFO_EXP)
    ) FIFO_INST (
        .clk            (clk_50MHz),
        .reset          (~reset),
        .write_to_fifo  (rx_done_tick),  // receptor escribe
        .read_from_fifo (tx_start),      // lectura en el inicio de TX (eco)
        .write_data_in  (rx_data_out),
        .read_data_out  (fifo_data_out),
        .empty          (fifo_empty),
        .full           (fifo_full)
    );

    // ---------------------- UART Transmitter ---------------------
    uart_transmitter #(
        .DATA_BITS     (DATA_BITS),
        .STOP_BIT_TICK (STOP_BIT_TICK)
    ) UART_TX (
        .clk_50MHz    (clk_50MHz),
        .reset        (~reset),
        .sample_tick  (tick),
        .tx_start     (tx_start),        // arranca eco una vez
        .data_in      (fifo_data_out),
        .tx           (tx),
        .tx_busy      (tx_busy),
        .tx_done_tick (tx_done_tick)
    );

    // ---------------------- LCD Display --------------------------
    // Latch directo del receptor para display (no usa FIFO)
    reg [DATA_BITS-1:0] latitud_reg;
    always @(posedge clk_50MHz or negedge reset) begin
        if (!reset)
            latitud_reg <= {DATA_BITS{1'b0}};
        else if (rx_done_tick)
            latitud_reg <= rx_data_out;
    end

    // Instanciación del controlador LCD
    LCD1602_controller #(
        .NUM_COMMANDS      (4),
        .NUM_DATA_ALL      (32),
        .NUM_DATA_PERLINE  (16),
        .DATA_BITS         (DATA_BITS),
        .COUNT_MAX         (800000)
    ) lcd_inst (
        .clk     (clk_50MHz),
        .latitud (latitud_reg),
        .reset   (reset),
        .ready_i (1'b1),
        .rs      (rs),
        .rw      (rw),
        .enable  (enable),
        .data    (data_lcd)
    );

endmodule

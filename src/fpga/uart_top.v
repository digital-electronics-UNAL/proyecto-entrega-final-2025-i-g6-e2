`timescale 1ns/1ps

module uart_top #(
    parameter DATA_BITS     = 8,
    parameter STOP_BIT_TICK = 16,   // muestras por bit (×16 oversampling)
    parameter BR_LIMIT      = 326,  // 50 MHz/(16·9600) ≈ 326
    parameter BR_BITS       = 9     // 2^9=512 > 326
)(
    input  wire                  clk_50MHz,
    input  wire                  reset,    // activo-bajo
    input  wire                  rx,       // UART Rx
    output wire                  tx,       // UART Tx (eco)

    // (Opcional) salidas fantasma para LCD1602
    output wire                  rs,
    output wire                  rw,
    output wire                  enable,
    output wire [DATA_BITS-1:0]  data_lcd
);

    // --------------------------------------------------------------
    // Señales internas
    // --------------------------------------------------------------
    wire                    tick;
    wire                    phase_reset;
    wire                    rx_done_tick;
    wire [DATA_BITS-1:0]    rx_data_out;
    wire                    tx_busy, tx_done_tick;

    // buffer “de un solo elemento”
    reg  [DATA_BITS-1:0]    pending_buffer;
    reg                     pending_flag;

    // buffer principal / start
    reg  [DATA_BITS-1:0]    tx_buffer;
    reg                     tx_start_d;

    // --------------------------------------------------------------
    // Baud-rate generator con phase_reset
    // --------------------------------------------------------------
    baud_rate_generator #(
        .N(BR_BITS),
        .M(BR_LIMIT)
    ) BAUD_GEN (
        .clk_50MHz   (clk_50MHz),
        .reset       (~reset),
        .phase_reset (phase_reset),
        .tick        (tick)
    );

    // --------------------------------------------------------------
    // UART Receiver
    // --------------------------------------------------------------
    uart_receiver #(
        .DATA_BITS     (DATA_BITS),
        .STOP_BIT_TICK (STOP_BIT_TICK)
    ) UART_RX (
        .clk_50MHz    (clk_50MHz),
        .reset        (~reset),
        .rx           (rx),
        .sample_tick  (tick),
        .data_ready   (rx_done_tick),
        .data_out     (rx_data_out),
        .phase_reset  (phase_reset)
    );

    // --------------------------------------------------------------
    // Lógica de eco con buffer único
    // --------------------------------------------------------------
    //   - Si llega rx_done_tick y TX está libre → arranca TX inmediato
    //   - Si llega rx_done_tick y TX está ocupado → guarda en pending_buffer
    //   - Cuando tx_done_tick → si hay pending_flag, arranca esa transmisión
    // --------------------------------------------------------------
    always @(posedge clk_50MHz or negedge reset) begin
        if (!reset) begin
            pending_flag  <= 1'b0;
            pending_buffer<= {DATA_BITS{1'b0}};
            tx_buffer     <= {DATA_BITS{1'b0}};
            tx_start_d    <= 1'b0;
        end else begin
            // por defecto solo el pulso de start
            tx_start_d <= 1'b0;

            // 1) Si recibo un byte
            if (rx_done_tick) begin
                if (!tx_busy) begin
                    // TX libre → inicio trama inmediatamente
                    tx_buffer  <= rx_data_out;
                    tx_start_d <= 1'b1;
                end else begin
                    // TX ocupado → lo guardo para después
                    pending_buffer <= rx_data_out;
                    pending_flag   <= 1'b1;
                end
            end
            // 2) Si acaba la transmisión y tengo pendiente
            else if (tx_done_tick && pending_flag) begin
                tx_buffer    <= pending_buffer;
                tx_start_d   <= 1'b1;
                pending_flag <= 1'b0;
            end
        end
    end

    // --------------------------------------------------------------
    // UART Transmitter (eco)
    // --------------------------------------------------------------
    uart_transmitter #(
        .DATA_BITS     (DATA_BITS),
        .STOP_BIT_TICK (STOP_BIT_TICK)
    ) UART_TX (
        .clk_50MHz    (clk_50MHz),
        .reset        (~reset),
        .sample_tick  (tick),
        .tx_start     (tx_start_d),
        .data_in      (tx_buffer),
        .tx           (tx),
        .tx_busy      (tx_busy),
        .tx_done_tick (tx_done_tick)
    );

    // --------------------------------------------------------------
    // Salidas fantasma LCD/Parser (inutilizadas aquí)
    // --------------------------------------------------------------
    assign rs       = 1'b0;
    assign rw       = 1'b0;
    assign enable   = 1'b0;
    assign data_lcd = {DATA_BITS{1'b0}};

endmodule

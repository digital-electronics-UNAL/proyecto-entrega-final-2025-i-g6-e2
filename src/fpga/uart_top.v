`timescale 1ns/1ps

module uart_top #(
    parameter DATA_BITS     = 8,
    parameter STOP_BIT_TICK = 16,   // muestras por bit (×16 oversampling)
    parameter BR_LIMIT      = 326,  // 50 MHz/(16·9600) ≈ 326
    parameter BR_BITS       = 9,    // 2^9=512 > 326
    parameter FIFO_DEPTH    = 16    // profundidad de FIFO
)(
    input  wire                  clk_50MHz,
    input  wire                  reset,       // activo-bajo
    input  wire                  rx,          // UART Rx
    output wire                  tx,          // UART Tx (eco)

    // LCD1602 interface (fantasma)
    output wire                  rs,
    output wire                  rw,
    output wire                  enable,
    output wire [DATA_BITS-1:0]  data_lcd,

    // FIFO flags
    output wire                  fifo_full,
    output wire                  fifo_empty,

    // debug: salida directa de la FIFO
    output wire [DATA_BITS-1:0]  lat_deg_out
);

    // ------------------------------------------------------------------------
    // Internas
    // ------------------------------------------------------------------------
    wire                    tick;
    wire                    phase_reset;
    wire                    rx_done_tick;
    wire [DATA_BITS-1:0]    rx_data_out, fifo_data_out;
    wire                    tx_busy, tx_done_tick;

    reg                     fifo_rd_en;
    reg  [DATA_BITS-1:0]    tx_buffer;
    reg                     tx_start;
    reg  [1:0]              tx_state;
    reg                     skip_first;

    localparam IDLE  = 2'd0,
               RD    = 2'd1,
               START = 2'd2,
               WAIT  = 2'd3;

    // ------------------------------------------------------------------------
    // Baud-rate generator con phase_reset
    // ------------------------------------------------------------------------
    baud_rate_generator #(
        .N(BR_BITS),
        .M(BR_LIMIT)
    ) BAUD_GEN (
        .clk_50MHz   (clk_50MHz),
        .reset       (~reset),
        .phase_reset (phase_reset),
        .tick        (tick)
    );

    // ------------------------------------------------------------------------
    // UART Receiver
    // ------------------------------------------------------------------------
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

    // ------------------------------------------------------------------------
    // FIFO síncrona
    // ------------------------------------------------------------------------
    sync_fifo #(
        .DWIDTH       (DATA_BITS),
        .DEPTH        (FIFO_DEPTH)
    ) FIFO_INST (
        .clk          (clk_50MHz),
        .rstn         (reset),
        .wr_en        (rx_done_tick),
        .rd_en        (fifo_rd_en),
        .din          (rx_data_out),
        .dout         (fifo_data_out),
        .full         (fifo_full),
        .empty        (fifo_empty)
    );

    // ------------------------------------------------------------------------
    // FSM para eco y skip_first
    // ------------------------------------------------------------------------
    always @(posedge clk_50MHz or negedge reset) begin
        if (!reset) begin
            tx_state   <= IDLE;
            fifo_rd_en <= 1'b0;
            tx_start   <= 1'b0;
            tx_buffer  <= {DATA_BITS{1'b0}};
            skip_first <= 1'b1;
        end else begin
            // por defecto
            fifo_rd_en <= 1'b0;
            tx_start   <= 1'b0;

            case (tx_state)
                IDLE: begin
                    if (~fifo_empty && ~tx_busy) begin
                        fifo_rd_en <= 1'b1;
                        tx_state   <= RD;
                    end
                end

                RD: begin
                    if (skip_first) begin
                        // descartamos primer byte
                        skip_first <= 1'b0;
                        tx_state   <= IDLE;
                    end else begin
                        tx_buffer <= fifo_data_out;
                        tx_state  <= START;
                    end
                end

                START: begin
                    tx_start <= 1'b1;
                    tx_state <= WAIT;
                end

                WAIT: begin
                    // cuando termine la trama...
                    if (tx_done_tick) begin
                        // si ya no hay más datos, preparamos a descartar el next first
                        if (fifo_empty)
                            skip_first <= 1'b1;
                        tx_state <= IDLE;
                    end
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // UART Transmitter (eco)
    // ------------------------------------------------------------------------
    uart_transmitter #(
        .DATA_BITS     (DATA_BITS),
        .STOP_BIT_TICK (STOP_BIT_TICK)
    ) UART_TX (
        .clk_50MHz    (clk_50MHz),
        .reset        (~reset),
        .sample_tick  (tick),
        .tx_start     (tx_start),
        .data_in      (tx_buffer),
        .tx           (tx),
        .tx_busy      (tx_busy),
        .tx_done_tick (tx_done_tick)
    );

    // ------------------------------------------------------------------------
    // Señales fantasma LCD/Parser
    // ------------------------------------------------------------------------
    assign rs       = 1'b0;
    assign rw       = 1'b0;
    assign enable   = 1'b0;
    assign data_lcd = {DATA_BITS{1'b0}};

    // ------------------------------------------------------------------------
    // Debug
    // ------------------------------------------------------------------------
    assign lat_deg_out = fifo_data_out;

endmodule

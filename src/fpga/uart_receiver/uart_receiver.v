`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// uart_receiver.v
//  • 8N1, 16× oversampling
//  • Sincroniza rx, detecta start-bit inmediatamente al flanco
//  • Genera phase_reset y entra a START sin esperar sample_tick
//  • Muestreo de cada bit siempre EXACTAMENTE en tick == STOP_BIT_TICK/2-1
// -----------------------------------------------------------------------------
module uart_receiver #(
    parameter DATA_BITS     = 8,
    parameter STOP_BIT_TICK = 16     // oversampling ×16
)(
    input  wire                 clk_50MHz,
    input  wire                 reset,        // activo-alto
    input  wire                 rx,           // línea serie (asincrónica)
    input  wire                 sample_tick,  // de baud_gen.tick
    output reg                  data_ready,   // 1 ciclo cuando byte completo
    output wire [DATA_BITS-1:0] data_out,     // byte armado
    output reg                  phase_reset   // 1 ciclo al detectar start-bit
);

  // ─── 1) Sincroniza rx para evitar metastabilidad ─────────────────────────
  reg rx_sync0, rx_sync1, rx_prev;
  always @(posedge clk_50MHz) begin
    if (reset) begin
      rx_sync0 <= 1'b1;
      rx_sync1 <= 1'b1;
      rx_prev  <= 1'b1;
    end else begin
      rx_sync0 <= rx;
      rx_sync1 <= rx_sync0;
      rx_prev  <= rx_sync1;
    end
  end

  // ─── 2) Estados de la FSM ───────────────────────────────────────────────
  localparam [1:0]
    IDLE  = 2'b00,
    START = 2'b01,
    DATA  = 2'b10,
    STOP  = 2'b11;

  reg [1:0]                state, next_state;
  reg [3:0]                tick_cnt, next_tick;
  reg [3:0]                bit_cnt,  next_bit;
  reg [DATA_BITS-1:0]      data_reg, next_data;

  // ─── 3) Registro secuencial con phase_reset generado al flanco ──────────
  always @(posedge clk_50MHz) begin
    if (reset) begin
      state       <= IDLE;
      tick_cnt    <= 0;
      bit_cnt     <= 0;
      data_reg    <= {DATA_BITS{1'b0}};
      phase_reset <= 1'b0;
    end else begin
      // default: clear phase_reset
      phase_reset <= 1'b0;

      // detectar flanco de start asíncrono, entrar a START y resetear fase
      if (state == IDLE && rx_prev && !rx_sync1) begin
        state       <= START;
        tick_cnt    <= 0;
        phase_reset <= 1'b1;    // al detectar flanco bajada de RX
      end else begin
        state    <= next_state;
        tick_cnt <= next_tick;
      end

      bit_cnt  <= next_bit;
      data_reg <= next_data;
    end
  end

  // ─── 4) FSM combinacional para muestreo ─────────────────────────────────
  always @* begin
    // por defecto mantenemos todo
    next_state = state;
    next_tick  = tick_cnt;
    next_bit   = bit_cnt;
    next_data  = data_reg;
    data_ready = 1'b0;

    case (state)
      // ──────────────────────────────────────────────────────────── IDLE
      IDLE: begin
        // nada aquí, el flanco de RX hace la transición
      end

      // ───────────────────────────────────────────────────── START bit
      START: begin
        if (sample_tick) begin
          if (tick_cnt == (STOP_BIT_TICK/2 - 1)) begin
            // confirmamos que sigue bajo
            if (!rx_sync1) begin
              next_state = DATA;
              next_tick  = 0;
              next_bit   = 0;
              next_data  = {DATA_BITS{1'b0}};
            end else begin
              next_state = IDLE; // falsa detección
            end
          end else begin
            next_tick = tick_cnt + 1;
          end
        end
      end

      // ────────────────────────────────────────────────────── DATA bits
      DATA: begin
        if (sample_tick) begin
          // muestreamos siempre en tick STOP_BIT_TICK/2-1
          if (tick_cnt == (STOP_BIT_TICK/2 - 1)) begin
            next_data = { rx_sync1, data_reg[DATA_BITS-1:1] };
          end
          // fin de ventana del bit?
          if (tick_cnt == STOP_BIT_TICK-1) begin
            next_tick = 0;
            if (bit_cnt == DATA_BITS-1)
              next_state = STOP;
            else
              next_bit = bit_cnt + 1;
          end else begin
            next_tick = tick_cnt + 1;
          end
        end
      end

      // ────────────────────────────────────────────────────── STOP bit
      STOP: begin
        if (sample_tick) begin
          if (tick_cnt == STOP_BIT_TICK-1) begin
            data_ready = 1'b1;
            next_state = IDLE;
            next_tick  = 0;
          end else begin
            next_tick = tick_cnt + 1;
          end
        end
      end
    endcase
  end

  // ─── 5) Salida del byte armado ───────────────────────────────────────────
  assign data_out = data_reg;

endmodule

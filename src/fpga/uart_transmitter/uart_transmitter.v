/*
 *  ────────────────────────────────────────────────────────────────
 *  UART Transmitter 8 N 1 con sobre-muestreo ×16
 *  • tx_start carga ‘data_in’ en el shift‐register
 *  • Emite 1 start, DATA_BITS datos (LSB first) y 1 stop
 *  • tx_busy alto mientras transmite, tx_done_tick un pulso al acabar
 *  ────────────────────────────────────────────────────────────────
 */
module uart_transmitter
  #(
    parameter DATA_BITS     = 8,
    parameter STOP_BIT_TICK = 16    // tics de muestreo por bit
  )
  (
    input  wire                   clk_50MHz,
    input  wire                   reset,       // activo-alto
    input  wire                   sample_tick, // f_baud×16
    input  wire                   tx_start,    // pulso de inicio
    input  wire [DATA_BITS-1:0]   data_in,     // byte a transmitir
    output wire                   tx,          // línea serial
    output wire                   tx_busy,
    output wire                   tx_done_tick
  );

  // ─── Estados FSM ──────────────────────────────
  localparam [1:0]
    S_IDLE  = 2'b00,
    S_START = 2'b01,
    S_DATA  = 2'b10,
    S_STOP  = 2'b11;

  // ─── Registros de estado y conteo ─────────────
  reg [1:0]                state,       next_state;
  reg [3:0]                tick_cnt,    next_tick;
  reg [3:0]                bit_cnt,     next_bit;
  reg [DATA_BITS-1:0]      shreg,       next_shreg;

  // ─── Señales de salida registradas ───────────
  reg                      tx_r,        next_tx;
  reg                      busy_r,      next_busy;
  reg                      done_r,      next_done;

  // ─── Salidas combinacionales ──────────────────
  assign tx          = tx_r;
  assign tx_busy     = busy_r;
  assign tx_done_tick= done_r;

  // ─── Flip‐flops síncronos ─────────────────────
  always @(posedge clk_50MHz or posedge reset) begin
    if (reset) begin
      state    <= S_IDLE;
      tick_cnt <= 0;
      bit_cnt  <= 0;
      shreg    <= {DATA_BITS{1'b1}};  // línea idle = 1
      tx_r     <= 1'b1;
      busy_r   <= 1'b0;
      done_r   <= 1'b0;
    end else begin
      state    <= next_state;
      tick_cnt <= next_tick;
      bit_cnt  <= next_bit;
      shreg    <= next_shreg;
      tx_r     <= next_tx;
      busy_r   <= next_busy;
      done_r   <= next_done;
    end
  end

  // ─── Lógica combinacional de la FSM ──────────
  always @* begin
    // valores por defecto
    next_state = state;
    next_tick  = tick_cnt;
    next_bit   = bit_cnt;
    next_shreg = shreg;
    next_tx    = tx_r;
    next_busy  = busy_r;
    next_done  = 1'b0;              // pulso de un tic

    case (state)
      S_IDLE: begin
        next_tx   = 1'b1;
        next_busy = 1'b0;
        if (tx_start) begin
          next_state  = S_START;
          next_shreg  = data_in;     // cargar byte
          next_tick   = 0;
          next_busy   = 1'b1;
        end
      end

      S_START: begin
        next_tx   = 1'b0;            // start bit
        next_busy = 1'b1;
        if (sample_tick) begin
          if (tick_cnt == STOP_BIT_TICK-1) begin
            next_state = S_DATA;
            next_tick  = 0;
            next_bit   = 0;
          end else
            next_tick = tick_cnt + 1;
        end
      end

      S_DATA: begin
        next_tx   = shreg[0];        // LSB first
        next_busy = 1'b1;
        if (sample_tick) begin
          if (tick_cnt == STOP_BIT_TICK-1) begin
            next_tick   = 0;
            next_shreg  = {1'b1, shreg[DATA_BITS-1:1]}; // shift right
            if (bit_cnt == DATA_BITS-1)
              next_state = S_STOP;
            else
              next_bit = bit_cnt + 1;
          end else
            next_tick = tick_cnt + 1;
        end
      end

      S_STOP: begin
        next_tx   = 1'b1;            // stop bit
        next_busy = 1'b1;
        if (sample_tick) begin
          if (tick_cnt == STOP_BIT_TICK-1) begin
            next_state = S_IDLE;
            next_tick  = 0;
            next_done  = 1'b1;      // pulso de fin de trama
          end else
            next_tick = tick_cnt + 1;
        end
      end
    endcase
  end

endmodule

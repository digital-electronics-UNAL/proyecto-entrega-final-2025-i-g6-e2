module uart_transmitter
  #(
    parameter DATA_BITS = 8,
    parameter STOP_BIT_TICK = 16   // =16 → 1 bit de parada
  )
  (
    input  clk_50MHz,
    input  reset,
    input  sample_tick,
    input  tx_start,               // pulso ‘1’ para iniciar envío
    input  [DATA_BITS-1:0] data_in,
    output reg tx = 1'b1,   // línea serial
    output reg tx_busy = 1'b0,
    output reg tx_done_tick = 1'b0    // pulso ‘1’ al terminar
  );

  // ----- Estados ------------------------------------------------
  localparam [1:0]
    idle  = 2'b00,
    start = 2'b01,
    data  = 2'b10,
    stop  = 2'b11;

  reg [1:0] state, next_state;
  reg [3:0] tick_reg, tick_next;
  reg [3:0] nbits_reg, nbits_next;
  reg [DATA_BITS-1:0] shreg, shreg_next;

  // ----- FFs síncronos -----------------------------------------
  always @(posedge clk_50MHz or posedge reset) begin
    if (reset) begin
      state <= idle;
      tick_reg <= 0;
      nbits_reg <= 0;
      shreg <= 0;
      tx <= 1'b1;
      tx_busy <= 1'b0;
    end else begin
      state <= next_state;
      tick_reg <= tick_next;
      nbits_reg <= nbits_next;
      shreg <= shreg_next;
    end
  end

  // ----- Lógica de control -------------------------------------
  always @* begin
    // valores por defecto
    next_state = state;
    tick_next = tick_reg;
    nbits_next = nbits_reg;
    shreg_next = shreg;
    tx_done_tick = 1'b0;

    case (state)
      // ---------------- IDLE  ----------------
      idle: begin
        tx = 1'b1;
        tx_busy = 1'b0;
        if (tx_start) begin
          next_state = start;
          shreg_next = data_in; // **
          tick_next  = 0;
          tx_busy    = 1'b1;
        end
      end

      // ---------------- START ----------------
      start: begin
        tx      = 1'b0;         // bit de inicio
        tx_busy = 1'b1;
        if (sample_tick) begin
          if (tick_reg == STOP_BIT_TICK-1) begin
            tick_next  = 0;
            nbits_next = 0;
            next_state = data;
          end else begin
            tick_next = tick_reg + 1;
          end
        end
      end

      // ---------------- DATA -----------------
      data: begin
        tx      = shreg[0];     // LSB first
        tx_busy = 1'b1;
        if (sample_tick) begin
          if (tick_reg == STOP_BIT_TICK-1) begin
            tick_next  = 0;
            shreg_next = {1'b1, shreg[DATA_BITS-1:1]}; // shift right
            if (nbits_reg == DATA_BITS-1)
              next_state = stop;
            else
              nbits_next = nbits_reg + 1;
          end else
            tick_next = tick_reg + 1;
        end
      end

      // ---------------- STOP -----------------
      stop: begin
        tx      = 1'b1;
        tx_busy = 1'b1;
        if (sample_tick) begin
          if (tick_reg == STOP_BIT_TICK-1) begin
            next_state   = idle;
            tick_next    = 0;
            tx_done_tick = 1'b1;
          end else
            tick_next = tick_reg + 1;
        end
      end
    endcase
  end
endmodule

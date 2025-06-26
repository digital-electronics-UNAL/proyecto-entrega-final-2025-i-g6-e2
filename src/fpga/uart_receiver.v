module uart_receiver
  #(
    parameter DATA_BITS   = 8,
    parameter STOP_BIT_TICK = 16
  )
  (
    input  clk_50MHz,
    input  reset,
    input  rx,
    input  sample_tick,
    output reg data_ready,
    output [DATA_BITS-1:0] data_out
  );

  localparam [1:0]
    idle  = 2'b00,
    start = 2'b01,
    data  = 2'b10,
    stop  = 2'b11;

  reg [1:0] state,   next_state;
  reg [3:0] tick_reg,  tick_next;
  reg [2:0] nbits_reg, nbits_next;
  reg [DATA_BITS-1:0] data_reg, data_next;

  always @(posedge clk_50MHz or posedge reset) begin
    if (reset) begin
      state     <= idle;
      tick_reg  <= 0;
      nbits_reg <= 0;
      data_reg  <= 0;
    end else begin
      state     <= next_state;
      tick_reg  <= tick_next;
      nbits_reg <= nbits_next;
      data_reg  <= data_next;
    end
  end

  always @* begin
    next_state = state;
    data_ready = 1'b0;
    tick_next  = tick_reg;
    nbits_next = nbits_reg;
    data_next  = data_reg;

    case (state)
      idle:
        if (~rx) begin
          next_state = start;
          tick_next  = 0;
        end

      start:
        if (sample_tick) begin
          if (tick_reg == (STOP_BIT_TICK/2 - 1)) begin
            next_state = data;
            tick_next  = 0;
            nbits_next = 0;
            data_next = 0;
          end else begin
            tick_next = tick_reg + 1;
          end
        end

      data:
        if (sample_tick) begin
          // Capturamos el bit en el LSB, desplazando todo a la izquierda
          if (tick_reg == (STOP_BIT_TICK/2 - 1)) begin
            data_next = { data_reg[DATA_BITS-2:0], rx };
          end

          // Avanzamos el conteo de ticks y de bits
          if (tick_reg == STOP_BIT_TICK-1) begin
            tick_next = 0;
            if (nbits_reg == (DATA_BITS-1))
              next_state = stop;
            else
              nbits_next = nbits_reg + 1;
          end else begin
            tick_next = tick_reg + 1;
          end
        end

      stop:
        if (sample_tick) begin
          if (tick_reg == STOP_BIT_TICK-1) begin
            data_ready = 1'b1;
            next_state = idle;
            tick_next  = 0;
          end else begin
            tick_next = tick_reg + 1;
          end
        end
    endcase
  end

  assign data_out = data_reg;
endmodule

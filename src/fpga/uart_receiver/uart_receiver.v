// -----------------------------------------------------------------------------
// UART receiver, 8 N 1, 16× oversampling
//   • Muestra cada bit en su centro (tick 8 de 16)
//   • Reconstruye el byte LSB-first
// -----------------------------------------------------------------------------
module uart_receiver #(
    parameter DATA_BITS     = 8,
    parameter STOP_BIT_TICK = 16        // ticks por bit (16 → oversampling ×16)
)(
    input  wire               clk_50MHz,
    input  wire               reset,        // activo-alto
    input  wire               rx,           // línea serie
    input  wire               sample_tick,  // pulso a 16× baud
    output reg                data_ready,   // 1 ciclo cuando data_out es válido
    output wire [DATA_BITS-1:0] data_out
);

    // ------------------- estados -------------------
    localparam [1:0]
        idle  = 2'b00,
        start = 2'b01,
        data  = 2'b10,
        stop  = 2'b11;

    reg [1:0] state,   next_state;
    reg [3:0] tick_reg,  tick_next;
    reg [3:0]  nbits_reg, nbits_next;
    reg [DATA_BITS-1:0] data_reg, data_next;

    // --------------- secuencial --------------------
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

    // ---------------- combinacional ----------------
    always @* begin
        // valores por defecto
        next_state = state;
        data_ready = 1'b0;
        tick_next  = tick_reg;
        nbits_next = nbits_reg;
        data_next  = data_reg;

        case (state)
            // ------------------------------------------------ idle
            idle: begin
                if (~rx) begin            // flanco descendente = start-bit
                    next_state = start;
                    tick_next  = 0;
                end
            end

            // --------------------------------------------- start-bit
            // contamos 1,0 bit + 0,5 bit → 16 ticks → centra el muestreo
            start: begin
                if (sample_tick) begin
                    if (tick_reg == (STOP_BIT_TICK - 1)) begin
                        next_state = data;
                        tick_next  = 0;
                        nbits_next = 0;
                        data_next  = 0;
                    end else
                        tick_next = tick_reg + 1;
                end
            end

            // --------------------------------------------- data bits
            data: begin
                if (sample_tick) begin
                    // Muestra en el centro del bit (tick 8)
                    if (tick_reg == (STOP_BIT_TICK/2 - 1)) begin
                        // LSB-first ⇒ desplazamos a la derecha
                        data_next = { data_reg[DATA_BITS-2:0], rx };
                    end

                    if (tick_reg == STOP_BIT_TICK-1) begin
                        tick_next = 0;
                        if (nbits_reg == DATA_BITS-1)     // 0-7 → 8 bits
                            next_state = stop;
                        else
                            nbits_next = nbits_reg + 1;
                    end else
                        tick_next = tick_reg + 1;
                end
            end

            // ----------------------------------------------- stop-bit
            stop: begin
                if (sample_tick) begin
                    if (tick_reg == STOP_BIT_TICK-1) begin
                        data_ready = 1'b1; // byte completo
                        next_state = idle;
                        tick_next  = 0;
                    end else
                        tick_next = tick_reg + 1;
                end
            end
        endcase
    end

    // ------------------------------------------------ salidas
    assign data_out = data_reg;

endmodule

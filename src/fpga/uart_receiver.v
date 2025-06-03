`timescale 1ps/1ps

module uart_receiver
    #(
        parameter DATA_BITS = 8,
        STOP_BIT_TICK = 16 //  número de ticks (oversampling) correspondientes a 1 bit de parada
    )
    (
        input clk_50MHz, // reloj Cyclone IV
        input reset,
        input rx, // señal serial de entrada
        input sample_tick, // pulso de muestreo del generador de baudios para muestrear rx
        output reg data_ready // señal cuando el byte/palabra se completa (para el FIFO)
        output [DATA_BITS-1:0] data_out // data para la FIFO
    )

    // FSM para UART
    localparam [1:0]    idle = 2'b00, // constante inmutable
                        start = 2'b01,
                        data = 2'b10,
                        stop = 2'b11;
    
    reg [1:0] state, next_state; // estado actual de la FSM
    reg [3:0] tick_reg, tick_next; // contador de muestras dentro de cada bit
    reg [2:0] nbits_reg, nbits_next; // cuantos bits de datos se han leído
    reg [7:0] data_reg, data_next; // aqui se van dejando los bits recibidos

    // Actualización de los registros
    always @(posedge clk_50MHz, posedge reset)
        if (reset) begin
            state <= idle;
            tick_reg <= 0;
            nbits_reg <= 0;
            data_reg <= 0;
        end
        else begin
            state <= next_state;
            tick_reg <= tick_next;
            nbits_reg <= nbits_next;
            data_reg <= data_next;
        end

    // Lógica de FSM
    always @* begin
        next_state = state; // si no cambia se mantiene en el mismo estado
        data_ready = 1'b0; // solo 1 si la palabra termina
        tick_next = tick_reg; // mantener igual
        nbits_next = nbits_reg;
        data_next = data_reg; // se dejan igual

        case (state)
            idle:
                if (~rx) begin // se activa señal, llega start bit
                    next_state = start;
                    tick_next = 0;
                end
            start: // verificar centro del bit
                if (sample_tick)
                    if (tick_reg == 7) begin // TOOD mover si hay más ruido
                        next_state = data;
                        tick_next = 0;
                        nbits_next = 0;
                    end
                    else
                        tick_next = tick_reg + 1;
            data:
                if (sample_tick) begin
                    // En el “punto medio” (tick_reg == 7), se captura el valor
                    if (tick_reg == 7) begin
                        data_next = { rx, data_reg[7:1] };
                    end

                    // Al final del bit (tick_reg == 15), se reinicia y avanza bit count
                    if (tick_reg == 15) begin
                        tick_next = 0;
                        if (nbits_reg == (DATA_BITS - 1))
                            next_state = stop; // en el último bit se pasa a stop
                        else
                            nbits_next = nbits_reg + 1;
                    end
                    else
                        tick_next = tick_reg + 1;
                end
        endcase
    end

    // output
    assign data_out = data_reg

endmodule
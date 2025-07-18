`timescale 1ns / 1ps

module tb_fifo;

    // Parámetros
    parameter DATA_SIZE = 8;
    parameter ADDR_SPACE_EXP = 4;

    // Señales
    reg clk;
    reg reset;
    reg write_to_fifo;
    reg read_from_fifo;
    reg [DATA_SIZE-1:0] write_data_in;
    wire [DATA_SIZE-1:0] read_data_out;
    wire empty;
    wire full;

    // Instanciar la FIFO
    fifo #(DATA_SIZE, ADDR_SPACE_EXP) uut (
        .clk(clk),
        .reset(reset),
        .write_to_fifo(write_to_fifo),
        .read_from_fifo(read_from_fifo),
        .write_data_in(write_data_in),
        .read_data_out(read_data_out),
        .empty(empty),
        .full(full)
    );

    // Generador de reloj
    always #5 clk = ~clk; // cada 5 ns cambia el estado → periodo de 10 ns

    // Proceso de prueba
    initial begin
        // Inicialización
        clk = 0;
        reset = 1;
        write_to_fifo = 0;
        read_from_fifo = 0;
        write_data_in = 0;

        #20; // esperar 20 ns
        reset = 0;

        // Escribir 5 datos
        repeat (5) begin
            @(posedge clk);
            write_data_in = $random;
            write_to_fifo = 1;
        end

        @(posedge clk);
        write_to_fifo = 0;

        #10;

        // Leer 5 datos
        repeat (5) begin
            @(posedge clk);
            read_from_fifo = 1;
        end

        @(posedge clk);
        read_from_fifo = 0;

        #20;
        $finish;
    end

endmodule

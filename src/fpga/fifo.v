
module fifo
    #(
        parameter DATA_SIZE = 8, // no. bits
        ADDR_SPACE_EXP = 7 // 2^7 = 16 address
    )
    (
        input clk, // reloj FPGA 
        input reset, // boton reset
        input write_to_fifo, // signal start writing to FIFO
        input read_from_fifo, // signal start reading from FIFO
        input [DATA_SIZE-1:0] write_data_in, // data byte into FIFO
        output [DATA_SIZE-1:0] read_data_out, // data byte out of FIFO
        output empty,
        output full
);
    
    reg [DATA_SIZE-1:0] memory [2**ADDR_SPACE_EXP-1:0]; // reg [WIDTH-1:0] nombre_memoria [DEPTH-1:0];
    reg [ADDR_SPACE_EXP-1:0] current_write_addr, current_write_addr_buff, next_write_addr;
    reg [ADDR_SPACE_EXP-1:0] current_read_addr, current_read_addr_buff, next_read_addr;
    reg fifo_full, fifo_empty, full_buff, empty_buff;
    wire write_enabled;

    always @(*)
        if(write_enabled) // se omite begin/end
            memory[current_write_addr] <= write_data_in;

    // lectura de memoria
    assign read_data_out = memory[current_read_addr];
    
    // solo permitir escribir cuando no esté lleno
    assign write_enabled = write_to_fifo & ~fifo_full;
    
    // CONTROL DE LA FIFO
    always @(posedge clk or posedge reset)
        if(reset) begin
            current_write_addr <= 0;
            current_read_addr <= 0;
            fifo_full <= 1'b0;
            fifo_empty <= 1'b1;
        end
        else begin
            current_write_addr <= current_write_addr_buff;
            current_read_addr <= current_read_addr_buff;
            fifo_full <= full_buff;
            fifo_empty <= empty_buff;
        end

    always @* begin
        // asignar siguiente puntero
        next_write_addr = current_write_addr + 1;
        next_read_addr = current_read_addr + 1;

        current_write_addr_buff = current_write_addr;
        current_read_addr_buff = current_read_addr;
        full_buff = fifo_full;
        empty_buff = fifo_empty;

        // selector
        case({write_to_fifo, read_from_fifo})
            2'b01: // botón de lectura presionado
                if(~fifo_empty) begin
                    current_read_addr_buff = next_read_addr;
                    full_buff = 1'b0;
                    if(next_read_addr == current_write_addr)
						empty_buff = 1'b1;
                end
    
            2'b10: // botón de escritura presionado
                if(~fifo_full) begin
                    current_write_addr_buff = next_write_addr;
                    empty_buff = 1'b0;
                    if(next_write_addr == current_read_addr)
                        full_buff = 1'b1;
                end
            // next: la posición que tomaría el puntero si se hace una operación de lectura o escritura.
            2'b11: begin
                current_write_addr_buff = next_write_addr;
                current_read_addr_buff = next_read_addr;
            end

        endcase
    end

    assign full = fifo_full;
    assign empty = fifo_empty;

endmodule

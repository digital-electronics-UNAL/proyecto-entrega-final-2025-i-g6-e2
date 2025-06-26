// M = 50000000 / (16 * 9600 baud) = 325.52 = 326

module baud_rate_generator
    #(
        parameter N = 9, // bits para contador (hasta 512 > 326)
        M = 326
    )
    (
        input clk_50MHz, // reloj cyclone IV
        input reset,
        output tick
);

    reg [N-1:0] counter;
    wire [N-1:0] next; // siguiente valor de counter

    always @(posedge clk_50MHz, posedge reset)
        if(reset)
            counter <= 0;
        else
            counter <= next;

    assign next = (counter == (M-1)) ? 0 : counter + 1;
    
    assign tick = (counter == (M-1)) ? 1'b1 : 1'b0; // salida 1 cuando llega al final de 1 ciclo

endmodule
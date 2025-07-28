// -----------------------------------------------------------------------------
// baud_rate_generator.v
//  • Genera “tick” cada M ciclos de clk_50MHz
//  • Si phase_reset=1 en un flanco de reloj, reinicia el conteo a 0
// -----------------------------------------------------------------------------
module baud_rate_generator #(
    parameter N = 9,    // ancho de counter: 2^9=512 > M
    parameter M = 326   // nº de ciclos de 50 MHz por tick (≈104 µs)
)(
    input  wire        clk_50MHz,   // reloj de sistema
    input  wire        reset,       // resetsync (act-alto)
    input  wire        phase_reset, // resetea fase de muestreo
    output wire        tick         // pulso cada M clocks
);

    reg [N-1:0] counter;

    always @(posedge clk_50MHz) begin
        if (reset || phase_reset) begin
            counter <= 0;
        end else if (counter == M-1) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end

    assign tick = (counter == M-1);

endmodule

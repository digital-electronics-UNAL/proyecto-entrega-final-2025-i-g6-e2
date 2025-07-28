// ────────────────────────────────────────────────────────────────
// sync_fifo.v  — FIFO síncrona de profundidad 2^N, 8-bits de dato
//   • Profundidad = DEPTH (debe ser potencia de 2)
//   • Un bit extra en los punteros para full/empty
// ────────────────────────────────────────────────────────────────
module sync_fifo #(
  parameter DEPTH  = 16,   // ¡Tiene que ser potencia de 2!
  parameter DWIDTH = 8
)(
  input  wire             rstn,   // reset activo‐bajo
  input  wire             clk,
  input  wire             wr_en,  // escribir (si full=0)
  input  wire             rd_en,  // leer    (si empty=0)
  input  wire [DWIDTH-1:0] din,
  output reg  [DWIDTH-1:0] dout,
  output wire             full,
  output wire             empty
);

  // número de bits para indexar DEPTH
  localparam ADDR_W = $clog2(DEPTH);

  // memoria interna
  reg [DWIDTH-1:0] mem [0:DEPTH-1];

  // punteros con bit extra (ADDR_W:0)
  reg [ADDR_W:0] wptr, rptr;

  // puntero “siguiente” para full/empty
  wire [ADDR_W:0] wptr_n = wptr + (wr_en & ~full);
  wire [ADDR_W:0] rptr_n = rptr + (rd_en & ~empty);

  // full cuando los ADDR_W bajos coinciden pero el bit MSB difiere
  assign full  = (wptr_n[ADDR_W-1:0] == rptr[ADDR_W-1:0]) &&
                 (wptr_n[ADDR_W]     != rptr[ADDR_W]);

  // empty cuando ambos punteros son idénticos
  assign empty = (wptr == rptr);

  // escritura
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      wptr <= 0;
    end else if (wr_en & ~full) begin
      mem[wptr[ADDR_W-1:0]] <= din;
      wptr <= wptr + 1;
    end
  end

  // lectura y actualización de dout
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      rptr <= 0;
      dout <= {DWIDTH{1'b0}};
    end else if (rd_en & ~empty) begin
      dout <= mem[rptr[ADDR_W-1:0]];
      rptr <= rptr + 1;
    end
  end

endmodule

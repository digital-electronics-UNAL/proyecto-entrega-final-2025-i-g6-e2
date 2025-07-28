module LCD1602_controller #(parameter NUM_COMMANDS = 4, 
                                      NUM_DATA_ALL = 32,  
                                      NUM_DATA_PERLINE = 16,
                                      DATA_BITS = 8,
                                      COUNT_MAX = 800000)( //tamaño del contador
    input clk,
    input [7:0] latitud,            
    input reset,          
    input ready_i,
    output reg rs,        
    output reg rw,
    output enable,    
    output reg [DATA_BITS-1:0] data // salida de tamaño 8 bits
);

// Definir los estados de la FSM
localparam IDLE = 3'b000; //arranca en idle, el estado se encarga de leer la memoria de 4 filas que se lleno y las manda por data
localparam CONFIG_CMD1 = 3'b001; // se encarga de recorrer } memoria y sacarlos por data (cgram ayuda a leer caracteres especiales), se queda 4 ciclos de relog
localparam WR_STATIC_TEXT_1L = 3'b010; //1L primera linea, se queda 16 ciclos de relog
localparam CONFIG_CMD2 = 3'b011; // se queda 1 ciclo de relog
localparam WR_STATIC_TEXT_2L = 3'b100; //16 ciclos de relog y se devuelve 
localparam DYNAMIC_TEXT = 3'b101;

reg [2:0] fsm_state;
reg [2:0] next_state;
reg clk_16ms;

// Comandos de configuración
localparam CLEAR_DISPLAY = 8'h01;
localparam SHIFT_CURSOR_RIGHT = 8'h06; // escriba hacia la derecha
localparam DISPON_CURSOROFF = 8'h0C;
localparam DISPON_CURSORBLINK = 8'h0E; // solo uno de estos dos para probar el parapadeo, se puede borrar
localparam LINES2_MATRIX5x8_MODE8bit = 8'h38; // tamaño de la lcd
localparam START_2LINE = 8'hC0;// arranque en la segunda linea , toca mandarlo en un punto especifico de la simulacion

// Definir un contador para el divisor de frecuencia
reg [$clog2(COUNT_MAX)-1:0] clk_counter; //garantizar que el contador llegue al maximo
// Definir un contador para controlar el envío de comandos
reg [$clog2(NUM_COMMANDS):0] command_counter; 
// Definir un contador para controlar el envío de datos
reg [$clog2(NUM_DATA_PERLINE):0] data_counter;

// Banco de registros // esta es la base de la memoria
reg [DATA_BITS-1:0] static_data_mem [0: NUM_DATA_ALL-1];  
reg [DATA_BITS-1:0] config_mem [0:NUM_COMMANDS-1]; 

reg [1:0] flag_substate;

initial begin
    fsm_state <= IDLE;
    command_counter <= 'b0;
    data_counter <= 'b0;
    rs <= 1'b0;
    rw <= 1'b0;
    data <= 8'b0;
    clk_16ms <= 1'b0;
    clk_counter <= 'b0;                             // este txt se pasa a askki para poner un texto especifico, se puede usar un convertidor en linea para facilitar
    $readmemh("/home/sergio/Documents/esp-lora32-fpga-cyclone-IV/src/fpga/lcd/data.txt", static_data_mem);  // esto hace que el archivo txt llene la memoria con un numero de valores ¿aski? en hexadecimal, y depsues se va a la siguiente fila
	config_mem[0] <= LINES2_MATRIX5x8_MODE8bit; // esto sirve para guardar las configuraciones, llenar la memoria
	config_mem[1] <= SHIFT_CURSOR_RIGHT; 
	config_mem[2] <= DISPON_CURSOROFF;
	config_mem[3] <= CLEAR_DISPLAY;
    flag_substate <= 2'b00;
end

always @(posedge clk) begin
    if (clk_counter == COUNT_MAX-1) begin
        clk_16ms <= ~clk_16ms;
        clk_counter <= 'b0;
    end else begin
        clk_counter <= clk_counter + 1;
    end
end


always @(posedge clk_16ms)begin // si no se oprime reste de devuelve
    if(reset == 0)begin// logica negada con el 0
        fsm_state <= IDLE;// un registro
    end else begin
        fsm_state <= next_state;//otro registro, asigna el valor de next state
    end
end

always @(*) begin  // logica combinacional, es un case o multiplekor
    case(fsm_state) // seleccionador 
        IDLE: begin // se asigna a fuerza IDLE, y asigna un valor a next state
            next_state <= (ready_i)? CONFIG_CMD1 : IDLE; // una condicion o multiplexor, si esta en 1 salta a cmd1 (ready==1) sino se queda en 0 y asigna a idle, a menos que complte los 16 no salta a lo siguiente
        end
        CONFIG_CMD1: begin  // config pregunta un contador de numero de comandos, cuando llegue a 4 (command counter==4)ya s emandaron todos los comandos, sino es igual a 4 se queda en esta parte sino salta a la siguiente
            next_state <= (command_counter == NUM_COMMANDS)? WR_STATIC_TEXT_1L : CONFIG_CMD1;
        end
        WR_STATIC_TEXT_1L:begin // (hace lo mismo que el de arriba pero pa otro contador) 
			next_state <= (data_counter == NUM_DATA_PERLINE)? CONFIG_CMD2 : WR_STATIC_TEXT_1L;
        end
        CONFIG_CMD2: begin 
            next_state <= WR_STATIC_TEXT_2L;//(este codigo no tiene ninguna pregunta) por lo que la transicion e sdirecta
        end
		WR_STATIC_TEXT_2L: begin
			next_state <= (data_counter == NUM_DATA_PERLINE)? DYNAMIC_TEXT : WR_STATIC_TEXT_2L; // logica de estado futuro
		end
        default: next_state = DYNAMIC_TEXT;
    endcase
end

always @(posedge clk_16ms) begin // este bloque define cuando se salta a idle config cmd1 o wr static o lo siguiente, es secuncial tambien
    if (reset == 0) begin // volver a condiciones iniciales
        command_counter <= 'b0;
        data_counter <= 'b0;
		  data <= 'b0;
        $readmemh("/home/sergio/Documents/esp-lora32-fpga-cyclone-IV/src/fpga/lcd/data.txt", static_data_mem);
        flag_substate <= 2'b00;
    end else begin
        case (next_state)
            IDLE: begin 
                command_counter <= 'b0;  // garantizar que idle limpie los datos para el reset
                data_counter <= 'b0; // tiene que volver y saltar de una sin esperar los 16 ciclos de relog
                rs <= 1'b0; //fija en 0
                data  <= 'b0; //fija en 0
            end
            CONFIG_CMD1: begin
			    rs <= 1'b0; 	// se puede borrar xq ya estaba en 0
                command_counter <= command_counter + 1; //contador de 1 a 4 
				data <= config_mem[command_counter]; // salida de la lcd, la memoria arranca 
            end
            WR_STATIC_TEXT_1L: begin
                data_counter <= data_counter + 1;
                rs <= 1'b1; // la lcd ya sabe lo que tiene que mostrar, x eso se qued aen uno
				data <= static_data_mem[data_counter];
            end
            CONFIG_CMD2: begin
                data_counter <= 'b0; // resetaera el data counter (en 0) xq el contador ya estaba en 16
				rs <= 1'b0; 
				data <= START_2LINE;
            end
			WR_STATIC_TEXT_2L: begin //hace lo mismo que el de arriba, pero se hizo para colocar un offset para que se envie de 17 a 32
                data_counter <= data_counter + 1;
                rs <= 1'b1; 
				data <= static_data_mem[NUM_DATA_PERLINE + data_counter];
                flag_substate <= 2'b00;
            end
            DYNAMIC_TEXT: begin
                case(flag_substate)
                    2'b00: begin
                        rs <= 1'b0;
                        data <= 8'h80 + 8'h04;    // Posición: 1ª línea, columna 5
                        flag_substate <= 2'b01;
                    end
                    2'b01: begin
                        rs <= 1'b1;
                        data <= (latitud - latitud%100)/100 + 8'h30;   // Centenas → ASCII
                        flag_substate <= 2'b10;
                    end
                    2'b10: begin
                        rs <= 1'b1;
                        data <= (latitud%100 - latitud%10)/10 + 8'h30;  // Decenas → ASCII
                        flag_substate <= 2'b11;
                    end
                    2'b11: begin
                        rs <= 1'b1;
                        data <= (latitud%10) + 8'h30;   // Unidades → ASCII
                        flag_substate <= 2'b00;
                    end
                endcase
            end
        endcase
    end
end

assign enable = clk_16ms; // lo que sale al pin enable

endmodule
module nmea_parser (
    input wire clk,
    input wire rst,
    input wire [7:0] rx_data,
    input wire rx_valid,

    output reg [7:0] lat_deg,
    output reg [7:0] lat_min,
    output reg [7:0] lon_deg,
    output reg [7:0] lon_min,
    output [4:0] state_o,
    output reg valid_fix
);

    localparam IDLE      = 5'b00000;//0
    localparam DETECT_G  = 5'b00001;//1
    localparam DETECT_P  = 5'b00010;//2
    localparam DETECT_R  = 5'b00011;//3
    localparam DETECT_M  = 5'b00100;//4
    localparam DETECT_C  = 5'b00101;//5
    localparam SKIP      = 5'b00110;//6
    localparam SKIP1     = 5'b00111;//7
    localparam SKIPA     = 5'b01000;//8
    localparam READ_LAT  = 5'b01001;//9
    localparam SKIP_NS   = 5'b01010;//10 
    localparam READ_LON  = 5'b01011;//11
    localparam SKIP_EW   = 5'b01100;//12
    localparam WAIT_CR   = 5'b01101;//13
    localparam WAIT_LF   = 5'b01110;//14
    localparam DONE      = 5'b01111;//15  

    //reg [4:0] state, 
	 reg [4:0] next_state, state;
    reg [14:0] idx;
    reg [7:0] lat_idx;
    reg [7:0] lon_idx;

    reg [7:0] lat_1;

    reg [7:0] lat_str [0:15];
    reg [7:0] lon_str [0:15];

    initial begin
        lat_deg = 'd0;
        lat_min = 'd0;
        lon_deg = 'd0;
        lon_min = 'd0;
        state = IDLE;
        idx = 'd0;
        lat_idx = 'd0;
        lon_idx = 'd0;
        valid_fix = 1'b0;
    end

    always @(posedge clk)begin 
        if(rst == 0)begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin  
        next_state = state;
        case(state)
            IDLE: next_state = (rx_data == 8'h24 && rx_valid)? DETECT_G : IDLE;
            DETECT_G:  next_state = (rx_data == 8'h47 && rx_valid) ? DETECT_P : DETECT_G;
            DETECT_P:  next_state = (rx_data == 8'h50 && rx_valid) ? DETECT_R : DETECT_P;
            DETECT_R: next_state = (rx_data == 8'h52 && rx_valid) ? DETECT_M : DETECT_R;
            DETECT_M: next_state = (rx_data == 8'h4D && rx_valid) ? DETECT_C : DETECT_M;
            DETECT_C:  next_state = (rx_data == 8'h43 && rx_valid) ? SKIP : DETECT_C;
            SKIP: next_state = (rx_data == 8'h2C && rx_valid)? SKIP1 : SKIP;
            SKIP1: next_state = (rx_data == 8'h2C && rx_valid)? SKIPA : SKIP1;
            SKIPA: next_state = (rx_data == 8'h2C && rx_valid)? READ_LAT : SKIPA;
            READ_LAT: next_state = (rx_data == 8'h2C && rx_valid)? SKIP_NS : READ_LAT;
            SKIP_NS: next_state = (rx_data == 8'h2C && rx_valid)? READ_LON : SKIP_NS;
            READ_LON: next_state = (rx_data == 8'h2C && rx_valid)? SKIP_EW : READ_LON;
            SKIP_EW: next_state = (rx_data == 8'h2C && rx_valid)? DONE : SKIP_EW;
            WAIT_CR: next_state = (rx_data == "\r" && rx_valid) ? DONE : WAIT_CR;  // '\r'
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (!rst) begin
            idx <= 0;
            lat_idx <= 0;
            lon_idx <= 0;
            valid_fix <= 0;
            lat_deg <= 'd0;
            lat_min <= 'd0;
            lon_deg <= 'd0;
            lon_min <= 'd0;
        end else begin
            case (state)
                SKIP1: begin
                    lat_idx <= 0;
                end
                READ_LAT: begin
                    if (rx_data != "," && rx_valid) begin
                        lat_str[lat_idx] <= rx_data;
                        lat_idx <= lat_idx + 1;
                    end
                    lat_deg <= ((lat_str[1] - 8'h30) * 10 + (lat_str[2]- 8'h30));
                    lat_min <= (((lat_str[2]- 8'h30) * 10 + (lat_str[3]- 8'h30)) * 100 +
                                ((lat_str[5] - 8'h30) * 10 + (lat_str[6]- 8'h30))); 
                end
                SKIP_NS: begin
                    lon_idx <= 0;
                end
                READ_LON: begin
                    if (rx_data != "," && rx_valid) begin
                        lon_str[lon_idx] <= rx_data;
                        lon_idx <= lon_idx + 1;
                    end 
                end
                DONE: begin
                    // ---------------- LATITUDE ----------------
                    //lat_0 = lat_str[1];
                    lat_1 = lat_str[2];
                    lat_deg <= ((lat_str[1] - 8'h30) * 10 + (lat_str[2]- 8'h30));
                    lat_min <= (((lat_str[2]- 8'h30) * 10 + (lat_str[3]- 8'h30)) * 100 +
                                ((lat_str[5] - 8'h30) * 10 + (lat_str[6]- 8'h30)));

                    // ---------------- LONGITUDE ----------------
                    
                    lon_deg <= (lon_str[0]- 8'h30) * 100 + (lon_str[1]- 8'h30) * 10 + (lon_str[2]- 8'h30);
                    lon_min <= (((lon_str[3] - 8'h30) * 10 + (lon_str[4] - 8'h30)) * 100 +
                                ((lon_str[6] - 8'h30) * 10 + (lon_str[7] - 8'h30)));

                    valid_fix <= 1;
                end
            endcase
        end
    end
	 
	 assign state_o = state;
endmodule

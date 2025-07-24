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

    localparam IDLE      = 5'b00000;
    localparam DETECT_G  = 5'b00001;
    localparam DETECT_P  = 5'b00010;
    localparam DETECT_G2 = 5'b00011;
    localparam DETECT_G3 = 5'b00100;
    localparam DETECT_A  = 5'b00101;
    localparam SKIP      = 5'b00110;
    localparam SKIP1     = 5'b00111;
    localparam SKIPA     = 5'b01000;
    localparam READ_LAT  = 5'b01001;
    localparam SKIP_NS   = 5'b01010; 
    localparam READ_LON  = 5'b01011;
    localparam SKIP_EW   = 5'b01111;
    localparam DONE      = 5'b10000;  

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
        case(state)
            IDLE: next_state <= (rx_data == "$" && rx_valid)? DETECT_G : IDLE;
            DETECT_G:  next_state <= (rx_data == "G" && rx_valid) ? DETECT_P : DETECT_G;
            DETECT_P:  next_state <= (rx_data == "P" && rx_valid) ? DETECT_G2 : DETECT_P;
            DETECT_G2: next_state <= (rx_data == "R" && rx_valid) ? DETECT_G3 : DETECT_G2;
            DETECT_G3: next_state <= (rx_data == "M" && rx_valid) ? DETECT_A : DETECT_G3;
            DETECT_A:  next_state <= (rx_data == "C" && rx_valid) ? SKIP : DETECT_A;
            SKIP: next_state <= (rx_data == "," && rx_valid)? SKIP1 : SKIP;
            SKIP1: next_state <= (rx_data == "," && rx_valid)? SKIPA : SKIP1;
            SKIPA: next_state <= (rx_data == "," && rx_valid)? READ_LAT : SKIPA;
            READ_LAT: next_state <= (rx_data == "," && rx_valid)? SKIP_NS : READ_LAT;
            SKIP_NS: next_state <= (rx_data == "," && rx_valid)? DONE : SKIP_NS;
            READ_LON: next_state <= (rx_data == "," && rx_valid)? DONE : READ_LON;
            SKIP_EW: next_state <= (rx_data == "," && rx_valid)? DONE : SKIP_EW;
            DONE: next_state <= IDLE;
            default: state <= IDLE;
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
                    if (rx_data == ",") begin
                        lat_idx <= 0;
                    end
                end
                READ_LAT: begin
                    if (rx_data != ",") begin
                        lat_str[lat_idx] <= rx_data;
                        if (rx_valid) begin
                            lat_idx <= lat_idx + 1;
                        end
                    end else begin
                        idx <= 0;
                    end
                end
                SKIP_NS: begin
                    if (rx_data == ",") begin
                        lon_idx <= 0;
                    end
                end
                READ_LON: begin
                    if (rx_data != ",") begin
                        lon_str[lon_idx] <= rx_data;
                        if (rx_valid) begin
                            lon_idx <= lon_idx + 1;
                        end
                    end else begin
                        idx <= 0;
                    end
                end
                DONE: begin
                    // ---------------- LATITUDE ----------------
                    //lat_0 = lat_str[1];
                    lat_1 = lat_str[2];
                    lat_deg <= ((lat_str[1] - "0") * 10 + (lat_str[2]- "0"));
                    lat_min <= (((lat_str[2]- "0") * 10 + (lat_str[3]- "0")) * 100 +
                                ((lat_str[5] - "0") * 10 + (lat_str[6]- "0")));

                    // ---------------- LONGITUDE ----------------
                    
                    lon_deg <= (lon_str[0]- "0") * 100 + (lon_str[1]- "0") * 10 + (lon_str[2]- "0");
                    lon_min <= (((lon_str[3] - "0") * 10 + (lon_str[4] - "0")) * 100 +
                                ((lon_str[6] - "0") * 10 + (lon_str[7] - "0")));

                    valid_fix <= 1;
                end
            endcase
        end
    end
	 
	 assign state_o = state;
endmodule
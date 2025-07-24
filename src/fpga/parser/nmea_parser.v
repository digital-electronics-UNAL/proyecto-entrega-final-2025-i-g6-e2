module nmea_parser (
    input wire clk,
    input wire rst,
    input wire [7:0] rx_data,
    input wire rx_valid,

    output reg [7:0] lat_deg,
    output reg [7:0] lat_min,
    output reg [7:0] lon_deg,
    output reg [7:0] lon_min,
    output reg valid_fix
);

    localparam IDLE      = 4'b0000;
    localparam DETECT_G  = 4'b0001;
    localparam DETECT_P  = 4'b0010;
    localparam DETECT_G2 = 4'b0011;
    localparam DETECT_G3 = 4'b0100;
    localparam DETECT_A  = 4'b0101;
    localparam SKIP      = 4'b0110;
    localparam READ_LAT  = 4'b0111;
    localparam SKIP_NS   = 4'b1000; 
    localparam READ_LON  = 4'b1001;
    localparam SKIP_EW   = 4'b1010;
    localparam DONE      = 4'b1011;

    reg [3:0] state, next_state;
    reg [7:0] idx;
    reg [7:0] lat_idx;
    reg [7:0] lon_idx;

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
            IDLE: if (rx_data == 8'h24) next_state <= DETECT_G;
            DETECT_G:  next_state <= (rx_data == 8'h47) ? DETECT_P : DETECT_G;
            DETECT_P:  next_state <= (rx_data == 8'h50) ? DETECT_G2 : DETECT_P;
            DETECT_G2: next_state <= (rx_data == 8'h47) ? DETECT_G3 : DETECT_G2;
            DETECT_G3: next_state <= (rx_data == 8'h47) ? DETECT_A : DETECT_G3;
            DETECT_A:  next_state <= (rx_data == 8'h41) ? SKIP : DETECT_A;
            SKIP: next_state <= (idx == 2)? READ_LAT : SKIP;
            READ_LAT: next_state <= (rx_data == 8'h2C)? SKIP_NS : READ_LAT;
            SKIP_NS: next_state <= (rx_data == 8'h2C)? READ_LON : SKIP_NS;
            READ_LON: next_state <= (rx_data == 8'h2C)? SKIP_EW : READ_LON;
            SKIP_EW: next_state <= (rx_data == 8'h2C)? DONE : SKIP_EW;
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
        end else if (rx_valid) begin
            case (state)
                SKIP: begin
                    if (rx_data == 8'h2C) idx = idx + 1;
                    if (idx == 2) begin
                        lat_idx <= 0;
                    end
                end
                READ_LAT: begin
                    if (rx_data != 8'h2C) begin
                        lat_str[lat_idx] <= rx_data;
                        lat_idx <= lat_idx + 1;
                    end else begin
                        idx <= 0;
                    end
                end
                SKIP_NS: begin
                    if (rx_data == 8'h2C) begin
                        lon_idx <= 0;
                    end
                end
                READ_LON: begin
                    if (rx_data != 8'h2C) begin
                        lon_str[lon_idx] <= rx_data;
                        lon_idx <= lon_idx + 1;
                    end else begin
                        idx <= 0;
                    end
                end
                DONE: begin
                    // ---------------- LATITUDE ----------------
                    lat_deg <= lat_str[0] * 10 + lat_str[1];
                    lat_min <= ((lat_str[2] * 10 + lat_str[3]) * 100 +
                                (lat_str[5] * 10 + lat_str[6]));

                    // ---------------- LONGITUDE ----------------
                    
                    lon_deg <= lon_str[0] * 100 +
                                lon_str[1] * 10 +
                                lon_str[2];
                    lon_min <= ((lon_str[3] * 10 + lon_str[4]) * 100 +
                                (lon_str[6] * 10 + lon_str[7]));

                    valid_fix <= 1;
                end
            endcase
        end
    end
endmodule
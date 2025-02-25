//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2024/9
//		Version		: v1.0
//   	File Name   : MDC.v
//   	Module Name : MDC
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "HAMMING_IP.v"
//synopsys translate_on

module MDC(
    // Input signals
    clk,
	rst_n,
	in_valid,
    in_data, 
	in_mode,
    // Output signals
    out_valid, 
	out_data
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk, rst_n, in_valid;
input [8:0] in_mode;
input [14:0] in_data;

output reg out_valid;
output reg [206:0] out_data;

// ===============================================================
// Parameter Declaration
// ===============================================================
parameter IDLE = 2'b00,
          DECODE = 2'b01,
          OUT = 2'b11;
// ===============================================================
// REG Declaration
// ===============================================================

reg [1:0] c_state, n_state;

reg signed [10:0] grid [15:0];
reg signed [10:0] grid_c [15:0];

wire [14:0] in_code_15 ;
wire [8:0] in_code_9;
reg signed [10:0] decoded_in_data;
reg [4:0] decoded_inst, mode_type;

reg signed [22:0] mul_1_in1, mul_1_in2, mul_2_in1, mul_2_in2, mul_3_in1, mul_3_in2;
reg signed [33:0] mul_1_out, mul_2_out; 
reg signed [33:0] mul_1_out_c, mul_2_out_c, mul_3_out_c;

reg signed [33:0] sub_1_in1, sub_1_in2;
reg signed [33:0] sub_1_out, sub_1_out_c;

reg signed [45:0] sub_2_in1, sub_2_in2;
reg signed [45:0] sub_2_out, sub_2_out_c;

reg signed [33:0] add_1_in1, add_1_in2;
reg signed [33:0] add_1_out, add_1_out_c;
reg signed [45:0] add_2_in1, add_2_in2;
reg signed [45:0] add_2_out, add_2_out_c;

reg signed [33:0] mul_4_in1, mul_4_in2;
reg signed [45:0] mul_4_out;
reg signed [45:0] mul_4_out_c;

reg signed [206:0] ans_out_44;
reg signed [206:0] ans_out_c_44;

reg signed [10:0] in1_reg, in2_reg, in3_reg, in0_reg;
reg signed [10:0] in1_1_reg, in2_1_reg, in3_1_reg, in0_1_reg;
reg signed [22:0] det22_reg,det22_1_reg;
reg signed [22:0] det22_temp[5:0];
reg signed [22:0] det22_temp_c[5:0];

reg [4:0] cnt ,nxt_cnt;

integer i;
// ===============================================================
// Design
// ===============================================================
HAMMING_IP #(.IP_BIT(11)) I_HAMMING_IP_15(.IN_code(in_code_15), .OUT_code(decoded_in_data)); // 9 bit signed output 
HAMMING_IP #(.IP_BIT(5)) I_HAMMING_IP_9(.IN_code(in_code_9), .OUT_code(decoded_inst));  // 5 bit instruction
assign in_code_15 = in_data;
assign in_code_9 = in_mode;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mode_type <= 0;
    end else if (cnt == 0 && in_valid) begin
        mode_type <= decoded_inst;
    end 
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        c_state <= IDLE;
    end else begin
        c_state <= n_state;
    end
end

always @(*) begin
    case (c_state)
        IDLE: begin
            if (in_valid) begin
                n_state = DECODE;
            end else n_state = IDLE;
        end 
        DECODE: begin
            if (cnt == 16) begin
                n_state = OUT;
            end else n_state = DECODE;
        end
        OUT : begin
            n_state = IDLE;
        end
        default: n_state = c_state;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt <= 0;
    end else cnt <= nxt_cnt; 
end

always @(*) begin
    if (cnt == 16) begin
        nxt_cnt = 0;
    end else if (n_state == DECODE) begin
        nxt_cnt = cnt + 1;
    end else begin
        nxt_cnt = cnt;
    end
end

always @(posedge clk ) begin
    for (i = 0 ; i < 16 ; i = i+1) begin
        grid[i] <= grid_c[i];
    end
end

always @(*) begin
    for (i = 0 ; i < 16 ; i=i+1 ) begin
        grid_c[i] = grid[i];
    end

    if (c_state == IDLE || c_state == DECODE) begin
        for (i = 0 ; i < 16 ; i = i+1) begin
            grid_c[cnt] = decoded_in_data;
        end
    end 
end

always @(posedge clk) begin
    ans_out_44 <= ans_out_c_44;
end

det22 d1(.in0(in0_reg), .in1(in1_reg), .in2(in2_reg), .in3(in3_reg), .det22_out(det22_reg));
det22 d2(.in0(in0_1_reg), .in1(in1_1_reg), .in2(in2_1_reg), .in3(in3_1_reg), .det22_out(det22_1_reg));


always @(posedge clk) begin
    for (i = 0 ; i < 6 ; i=i+1 ) begin
        det22_temp[i] <= det22_temp_c[i];
    end
end

always @(*) begin
    in0_reg = 0;  in1_reg= 0;
    in2_reg = 0;  in3_reg= 0;
    in0_1_reg = 0;  in1_1_reg= 0;
    in2_1_reg = 0;  in3_1_reg= 0;

    if (mode_type == 5'b00100) begin
        case (cnt)
            6 : begin
                in0_reg = grid[0];  in1_reg= grid[1];
                in2_reg = grid[4];  in3_reg= grid[5];
            end 
            7: begin
                in0_reg = grid[1];  in1_reg= grid[2];
                in2_reg = grid[5];  in3_reg= grid[6];
            end
            8: begin
                in0_reg = grid[2];  in1_reg= grid[3];
                in2_reg = grid[6];  in3_reg= grid[7];
            end

            10: begin
                in0_reg = grid[4];  in1_reg= grid[5];
                in2_reg = grid[8];  in3_reg= grid[9];
            end

            11: begin
                in0_reg = grid[5];  in1_reg= grid[6];
                in2_reg = grid[9];  in3_reg= grid[10];
            end 
            12: begin
                in0_reg = grid[6];  in1_reg= grid[7];
                in2_reg = grid[10]; in3_reg= grid[11];
            end

            14: begin
                in0_reg = grid[8];  in1_reg= grid[9];
                in2_reg = grid[12]; in3_reg= grid[13];
            end
            15: begin
                in0_reg = grid[9];  in1_reg= grid[10];
                in2_reg = grid[13]; in3_reg= grid[14];
            end
            16: begin
                in0_reg = grid[10]; in1_reg= grid[11];
                in2_reg = grid[14]; in3_reg= grid[15];
            end
        endcase     
    end
    else if (mode_type == 5'b00110)begin
        case (cnt)
            6 : begin
                in0_reg = grid[0];  in1_reg= grid[1];
                in2_reg = grid[4];  in3_reg= grid[5];
            end 
            7: begin
                in0_reg = grid[0];  in1_reg= grid[2];
                in2_reg = grid[4];  in3_reg= grid[6];
 
                in0_1_reg = grid[1];  in1_1_reg= grid[2];
                in2_1_reg = grid[5];  in3_1_reg= grid[6];
            end
            8: begin
                in0_reg = grid[2];  in1_reg= grid[3];
                in2_reg = grid[6];  in3_reg= grid[7];
                
                in0_1_reg = grid[1];  in1_1_reg= grid[3];
                in2_1_reg = grid[5];  in3_1_reg= grid[7];
            end
            12 : begin
                in0_reg = grid[4];  in1_reg= grid[5];
                in2_reg = grid[8];  in3_reg= grid[9];
            end 
            13: begin
                in0_reg = grid[4];  in1_reg= grid[6];
                in2_reg = grid[8];  in3_reg= grid[10];
                
                in0_1_reg = grid[5];  in1_1_reg= grid[6];
                in2_1_reg = grid[9];  in3_1_reg= grid[10];
            end
            14: begin
                in0_reg = grid[6];  in1_reg= grid[7];
                in2_reg = grid[10];  in3_reg= grid[11];
                
                in0_1_reg = grid[5];  in1_1_reg= grid[7];
                in2_1_reg = grid[9];  in3_1_reg= grid[11];
            end
        endcase   
    end
    else if (mode_type == 5'b10110)begin
        case (cnt)
            6 : begin
                in0_reg = grid[0];  in1_reg= grid[1];
                in2_reg = grid[4];  in3_reg= grid[5];
            end 
            7: begin
                in0_reg = grid[0];  in1_reg= grid[2];
                in2_reg = grid[4];  in3_reg= grid[6];
                
                in0_1_reg = grid[1];  in1_1_reg= grid[2];
                in2_1_reg = grid[5];  in3_1_reg= grid[6];
            end
            8: begin
                in0_reg = grid[0];  in1_reg= grid[3];
                in2_reg = grid[4];  in3_reg= grid[7];
                
                in0_1_reg = grid[1];  in1_1_reg= grid[3];
                in2_1_reg = grid[5];  in3_1_reg= grid[7];
            end

            9 : begin
                in0_1_reg = grid[2];  in1_1_reg= grid[3];
                in2_1_reg = grid[6];  in3_1_reg= grid[7];
            end 
        endcase   
    end
end

always @(*) begin
    for (i = 0 ; i < 6 ; i=i+1 ) begin
        det22_temp_c[i] = det22_temp[i];
    end

    if (mode_type == 5'b00110)begin
        case (cnt)
            6 : begin
                det22_temp_c[0] = det22_reg;
            end 
            7: begin
                det22_temp_c[1] = det22_reg;
                det22_temp_c[2] = det22_1_reg;
            end
            8: begin
                det22_temp_c[3] = det22_reg;
                det22_temp_c[4] = det22_1_reg;
            end
            12 : begin
                det22_temp_c[0] = det22_reg;
            end 
            13: begin
                det22_temp_c[1] = det22_reg;
                det22_temp_c[2] = det22_1_reg; 
            end
            14: begin
                det22_temp_c[3] = det22_reg;
                det22_temp_c[4] = det22_1_reg;
            end
        endcase   
    end
    else if (mode_type == 5'b10110)begin
        case (cnt)
            6 : begin
                det22_temp_c[0] = det22_reg;
            end 
            7: begin
                det22_temp_c[1] = det22_reg;
                det22_temp_c[2] = det22_1_reg;
            end
            8: begin
                det22_temp_c[3] = det22_reg;
                det22_temp_c[4] = det22_1_reg;
            end
            9 : begin
                det22_temp_c[5] = det22_1_reg;
            end 
        endcase   
    end
end

always @(*) begin
    ans_out_c_44 = ans_out_44;
    if (mode_type == 5'b00100) begin
        case (cnt)
            6 : begin
                ans_out_c_44[206:184] = det22_reg;
            end 
            7: begin
                ans_out_c_44[183:161] = det22_reg;
            end
            8: begin
                ans_out_c_44[160:138] = det22_reg;
            end

            10: begin
                ans_out_c_44[137:115] = det22_reg;
            end

            11: begin
                ans_out_c_44[114:92] = det22_reg;
            end 
            12: begin
                ans_out_c_44[91:69] = det22_reg;
            end

            14: begin
                ans_out_c_44[68:46] = det22_reg;
            end
            15: begin
                ans_out_c_44[45:23] = det22_reg;
            end
            16: begin
                ans_out_c_44[22:0] = det22_reg;
            end
        endcase     
    end
    else if (mode_type == 5'b00110)begin
        case (cnt)
            11: ans_out_c_44[203:153] = add_1_out_c;
            12 :ans_out_c_44[152:102]= add_1_out_c;
            15: ans_out_c_44[101:51]= add_1_out_c;
            16: ans_out_c_44[50:0]= add_1_out_c;
        endcase   
    end
    else if (mode_type == 5'b10110)begin
        case (cnt)
            16: begin
                ans_out_c_44 =add_2_out_c ; 
            end
        endcase   
    end
end


// mul
always @(*) begin
    mul_1_out_c = mul_1_in1 * mul_1_in2;
    mul_2_out_c = mul_2_in1 * mul_2_in2;
    mul_3_out_c = mul_3_in1 * mul_3_in2;
    mul_4_out_c = mul_4_in1 * mul_4_in2;

end
always @(posedge clk) begin
    mul_1_out <= mul_1_out_c;
    mul_2_out <= mul_2_out_c;
    mul_4_out <= mul_4_out_c;
end

always @(*) begin
    mul_1_in1 = 0; mul_1_in2 = 0;
    mul_2_in1 = 0; mul_2_in2 = 0;
    mul_3_in1 = 0; mul_3_in2 = 0;
    mul_4_in1 = 0; mul_4_in2 = 0;
    if (mode_type == 5'b00110)begin
        case (cnt)
            9 : begin
                mul_1_in1 = grid[8]; mul_1_in2 = det22_temp[2];
            end 
            10: begin
                mul_1_in1 = grid[9]; mul_1_in2 = det22_temp[1]; 
                mul_2_in1 = grid[9]; mul_2_in2 = det22_temp[3];
            end
            11: begin
                mul_1_in1 = grid[10]; mul_1_in2 = det22_temp[0]; 
                mul_2_in1 = grid[10]; mul_2_in2 = det22_temp[4];
            end
            12 : begin
                mul_1_in1 = grid[11]; mul_1_in2 = det22_temp[2]; 
            end 

            13 : begin
                mul_1_in1 = grid[12]; mul_1_in2 = det22_temp_c[2];
            end 
            14: begin
                mul_1_in1 = grid[13]; mul_1_in2 = det22_temp[1]; 
                mul_2_in1 = grid[13]; mul_2_in2 = det22_temp_c[3];
            end
            15: begin
                mul_1_in1 = grid[14]; mul_1_in2 = det22_temp[0]; 
                mul_2_in1 = grid[14]; mul_2_in2 = det22_temp[4];
            end
            16 : begin
                mul_1_in1 = grid[15]; mul_1_in2 = det22_temp[2]; 
            end 
        endcase   
    end
    else if (mode_type == 5'b10110) begin
        case (cnt)
            10: begin
                mul_1_in1 = grid[9]; mul_1_in2 = det22_temp[5]; 
            end
            11: begin
                mul_1_in1 = grid[8]; mul_1_in2 = det22_temp[5]; 
                mul_2_in1 = grid[10]; mul_2_in2 = det22_temp[4];
            end
            12 : begin
                mul_1_in1 = grid[8]; mul_1_in2 = det22_temp[4]; 
                mul_2_in1 = grid[10]; mul_2_in2 = det22_temp[3];
                mul_3_in1 = grid[11]; mul_3_in2 = det22_temp[2];
            end 
            13 : begin
                mul_1_in1 = grid[8]; mul_1_in2 = det22_temp[2];
                mul_2_in1 = grid[9]; mul_2_in2 = det22_temp[3];
                mul_3_in1 = grid[11]; mul_3_in2 = det22_temp[1];

                mul_4_in1 = grid[12]; mul_4_in2 = add_1_out;
            end 
            14: begin
                mul_2_in1 = grid[9]; mul_2_in2 = det22_temp[1];
                mul_3_in1 = grid[11]; mul_3_in2 = det22_temp[0];

                mul_4_in1 = grid[13]; mul_4_in2 = add_1_out;
            end
            15: begin
                mul_3_in1 = grid[10]; mul_3_in2 = det22_temp[0];

                mul_4_in1 = grid[14]; mul_4_in2 = add_1_out;
            end
            16: begin
                mul_4_in1 = grid[15]; mul_4_in2 = add_1_out;
            end
        endcase   
    end
end

//sub
always @(*) begin
    sub_1_out_c = sub_1_in1 - sub_1_in2;
    sub_2_out_c = sub_2_in1 - sub_2_in2;
end
always @(posedge clk) begin
    sub_1_out <= sub_1_out_c;
    sub_2_out <= sub_2_out_c;
end

always @(*) begin
    sub_1_in1 = mul_1_out ; sub_1_in2 = mul_2_out_c;
    sub_2_in1 = 0; sub_2_in2 = 0;
    if (mode_type == 5'b00110)begin
        case (cnt)
            10 : begin
                sub_1_in1 = mul_1_out ; sub_1_in2 = mul_1_out_c;
            end 
            11: begin
                sub_1_in1 = mul_2_out ; sub_1_in2 = mul_2_out_c;
            end

            14: begin
                sub_1_in1 = mul_1_out ; sub_1_in2 = mul_1_out_c;
            end

            15 : begin
                sub_1_in1 = mul_2_out ; sub_1_in2 = mul_2_out_c; 
            end 
        endcase   
    end
    else if (mode_type == 5'b10110)begin
        case (cnt)
            14: begin
                //sub_1_in1 = mul_1_out ; sub_1_in2 = mul_2_out_c;
                sub_2_in2 = mul_4_out ; sub_2_in1 = mul_4_out_c;
            end
            15: begin
               // sub_1_in1 = mul_1_out ; sub_1_in2 = mul_2_out_c;
                sub_2_in1 = sub_2_out ; sub_2_in2 = mul_4_out_c;
            end
        endcase   
    end
end

always @(*) begin
    add_1_out_c = add_1_in1 + add_1_in2;
    add_2_out_c = add_2_in1 + add_2_in2;
end

always @(posedge clk) begin
    add_1_out <= add_1_out_c;
    add_2_out <= add_2_out_c;
end


always @(*) begin
    add_1_in1 =  sub_1_out  ;  add_1_in2 =  mul_1_out_c; 
    add_2_in1 = 0 ; add_2_in2 = 0;
    if (mode_type == 5'b10110) begin
        case (cnt)
            12: begin
                add_1_in1 = sub_1_out ; 
                add_1_in2 = mul_3_out_c; 
            end 
            13: begin
                add_1_in1 = sub_1_out; 
                add_1_in2 = mul_3_out_c; 
            end 
            14: begin
                add_1_in1 = sub_1_out; 
                add_1_in2 = mul_3_out_c; 
            end 
            15: begin
                add_1_in1 = sub_1_out; 
                add_1_in2 = mul_3_out_c; 
            end 
            16: begin
                add_2_in1 = sub_2_out; 
                add_2_in2 = mul_4_out_c; 
            end 
        endcase       
    end 
end
// ===============================================================
// Output
// ===============================================================

always @(*) begin
    out_valid = 0;
    if (c_state == OUT) begin
        out_valid = 1;
    end else out_valid = 0;
end
always @(*) begin
    out_data = 0;
    if (c_state == OUT) begin
        if (mode_type == 5'b00100) begin
            out_data = ans_out_44;
        end
        else if (mode_type == 5'b00110) begin
            out_data = {3'b000,  ans_out_44[203:0]};
        end
        else out_data = ans_out_44;
    end else out_data = 0;
end
endmodule


module det22(in0,in1,in2,in3,det22_out);
    input signed [10:0] in0,in1,in2,in3;
    output reg signed [22:0] det22_out;

    always @(*) begin
        det22_out = in0*in3 - in1*in2;
    end
endmodule

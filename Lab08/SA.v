/**************************************************************************/
// Copyright (c) 2024, OASIS Lab
// MODULE: SA
// FILE NAME: SA.v
// VERSRION: 1.0
// DATE: Nov 06, 2024
// AUTHOR: Yen-Ning Tung, NYCU AIG
// CODE TYPE: RTL or Behavioral Level (Verilog)
// DESCRIPTION: 2024 Fall IC Lab / Exersise Lab08 / SA
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/

// synopsys translate_off
`ifdef RTL
	`include "GATED_OR.v"
`else
	`include "Netlist/GATED_OR_SYN.v"
`endif
// synopsys translate_on


module SA(
    //Input signals
    clk,
    rst_n,
    cg_en,
    in_valid,
    T,
    in_data,
    w_Q,
    w_K,
    w_V,

    //Output signals
    out_valid,
    out_data
    );

input clk;
input rst_n;
input in_valid;
input cg_en;
input [3:0] T;
input signed [7:0] in_data;
input signed [7:0] w_Q;
input signed [7:0] w_K;
input signed [7:0] w_V;

output reg out_valid;
output reg signed [63:0] out_data;

//==============================================//
//       parameter & integer declaration        //
//==============================================//

parameter IDLE = 0,
		  PROCESS_Q = 1,
          PROCESS_K = 2,
		  PROCESS_V = 3,
		  PROCESS_L = 4,
		  PROCESS_P = 5,
          OUT = 6;

integer i,j;
genvar k;
//==============================================//
//           reg & wire declaration             //
//==============================================//
reg [2:0] c_state, n_state;

reg signed [7:0] data[0:7][0:7];
reg signed [7:0] data_c[0:7][0:7];

reg signed [7:0] w_k [0:7][0:7];
reg signed [7:0] w_q [0:7][0:7];
// reg signed [7:0] w_v [0:7][0:7];


reg signed [7:0] w_k_c [0:7][0:7];
reg signed [7:0] w_q_c [0:7][0:7];
// reg signed [7:0] w_v_c [0:7][0:7];

reg signed [18:0] K [0:7][0:7];
reg signed [18:0] Q [0:7][0:7];
reg signed [18:0] V [0:7][0:7];
reg signed [39:0] A [0:7][0:7];
reg signed [18:0] K_c [0:7][0:7];
reg signed [18:0] Q_c [0:7][0:7];
reg signed [18:0] V_c [0:7][0:7];
reg signed [39:0] A_c [0:7][0:7];

reg signed [7:0] mul_in1 [0:7];
reg signed [7:0] mul_in2 [0:7];
reg signed [15:0] mul_out [0:7];
reg signed [18:0] sum_out ;

reg signed [7:0] mul_0_in1 [0:7];
reg signed [7:0] mul_0_in2 [0:7];
reg signed [15:0] mul_0_out [0:7];
reg signed [18:0] sum_0_out ;


reg signed [39:0] mul_2_in1 [0:7];
reg signed [18:0] mul_2_in2 [0:7];
reg signed [63:0] mul_2_out [0:7];
reg signed [63:0] sum_2_out ;

reg signed [39:0] mul_3_in1 [0:7];
reg signed [18:0] mul_3_in2 [0:7];
reg signed [63:0] mul_3_out [0:7];
reg signed [63:0] sum_3_out ;

reg signed [63:0] ans ;
reg signed [63:0] ans1 ;
reg [3:0] T_len ;
reg [2:0] x_idx, nxt_x_idx;
reg [2:0] y_idx, nxt_y_idx;
reg [2:0] x_idx1, nxt_x_idx1;
reg [2:0] y_idx1, nxt_y_idx1;
reg [10:0] cnt, nxt_cnt;
//==============================================//
//                 GATED_OR                     //
//==============================================//

reg input_sleep_k;
reg gated_clk_k[0:7];


always@(*)begin
	input_sleep_k = !( c_state == PROCESS_V)  && cg_en ;
end


generate
    for(k=0; k<8; k=k+1)begin: Gate_or_K
        GATED_OR GATED_K(.CLOCK(clk),.SLEEP_CTRL(input_sleep_k),.RST_N(rst_n),.CLOCK_GATED(gated_clk_k[k]));
    end
endgenerate


reg input_sleep_Q ;
reg gated_clk_Q[0:7];


always@(*)begin
	input_sleep_Q= !( c_state == PROCESS_K)  && cg_en ;
end

generate
    for(k=0; k<8; k=k+1)begin: Gate_or_Q
        GATED_OR GATED_Q(.CLOCK(clk),.SLEEP_CTRL(input_sleep_Q),.RST_N(rst_n),.CLOCK_GATED(gated_clk_Q[k]));
    end
endgenerate


reg input_sleep_V ;
reg gated_clk_V[0:7];


always@(*)begin
	input_sleep_V = !( c_state == PROCESS_L)  && cg_en ;
end

generate
    for(k=0; k<8; k=k+1)begin: Gate_or_V
        GATED_OR GATED_V(.CLOCK(clk),.SLEEP_CTRL(input_sleep_V),.RST_N(rst_n),.CLOCK_GATED(gated_clk_V[k]));
    end
endgenerate

reg input_sleep_qK;
reg gated_clk_qK[0:7];


always@(*)begin
	input_sleep_qK= !( c_state == PROCESS_K)  && cg_en ;
end

generate
    for(k=0; k<8; k=k+1)begin: Gate_or_qK
        GATED_OR GATED_qK(.CLOCK(clk),.SLEEP_CTRL(input_sleep_qK),.RST_N(rst_n),.CLOCK_GATED(gated_clk_qK[k]));
    end
endgenerate


//==============================================//
//                  design                      //
//==============================================//

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        c_state <= 0;
    end else c_state <= n_state;
end

always @(*) begin
    n_state = c_state;
    case (c_state)
        IDLE: begin
            if (in_valid) begin
                n_state = PROCESS_Q;
            end
        end 
		PROCESS_Q: begin
            if (x_idx == 7 && y_idx == 7) begin
                n_state = PROCESS_K;
            end
        end
		PROCESS_K: begin
            if (x_idx == 7 && y_idx == 7) begin
                n_state = PROCESS_V;
            end
        end
		PROCESS_V: begin
            if (x_idx == 7 && y_idx == 7) begin
                n_state = PROCESS_L;
            end
        end
		PROCESS_L: begin
            if (x_idx == 6 && y_idx == (T_len-1)) begin
                n_state = PROCESS_P;
            end
        end
		PROCESS_P: begin
            if (x_idx == 7 && y_idx == (T_len-1)) begin
                n_state = IDLE;
            end
        end
    endcase
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_idx <= 0;
    end else x_idx <= nxt_x_idx;
end

always @(*) begin
	if (c_state == PROCESS_L) begin
        nxt_x_idx = x_idx + 2;
    end 
	else if (x_idx == 7) begin
		nxt_x_idx = 0;
	end
	else if (n_state != IDLE) begin
        nxt_x_idx = x_idx + 1;
    end 
	else if (c_state == IDLE) begin
		nxt_x_idx = 0;
	end
	else nxt_x_idx = x_idx;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        y_idx <= 0;
    end else y_idx <= nxt_y_idx;
end

always @(*) begin
	if ((c_state == PROCESS_L) &&  y_idx == (T_len-1) && x_idx == 6) begin
        nxt_y_idx = 0;
    end 
	else if ((c_state == PROCESS_L) && x_idx == 6) begin
        nxt_y_idx = y_idx + 1;
    end 
	else if (c_state == IDLE) begin
		nxt_y_idx = 0;
	end
	else if (y_idx == 7 && x_idx == 7) begin
		nxt_y_idx = 0;
	end
    else if ( x_idx == 7) begin
        nxt_y_idx = y_idx + 1;
    end 
	else nxt_y_idx = y_idx;
end




always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		T_len <= 1;
	end
	else if (c_state == IDLE && n_state == PROCESS_Q) begin
		T_len <= T;
	end
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		for (i = 0; i < 8; i = i + 1) begin
			for (j = 0; j < 8; j = j + 1) begin
				data[j][i] <= 0;
			end
		end
	end
	else if (n_state == IDLE) begin
		for (i = 0; i < 8; i = i + 1) begin
			for (j = 0; j < 8; j = j + 1) begin
				data[j][i] <= 0;
			end
		end		
	end
	else begin
		for (i = 0; i < 8; i = i + 1) begin
			for (j = 0; j < 8; j = j + 1) begin
				data[j][i] <= data_c[j][i];
			end
		end		
	end 
end


generate
    for(k=0; k<8; k=k+1) begin: Gate_or_qK_1
		always @(posedge gated_clk_qK[k] or negedge rst_n) begin
			if (!rst_n) begin
				for (j = 0; j < 8; j = j + 1) begin
					w_k[j][k] <= 0;
				end
			end
			else begin
				for (j = 0; j < 8; j = j + 1) begin
					w_k[j][k] <= w_k_c[j][k];
				end	
			end 
		end
	end
endgenerate


always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		for (i = 0; i < 8; i = i + 1) begin
			for (j = 0; j < 8; j = j + 1) begin
				w_q[j][i] <= 0;
			end
		end
	end
	else begin
		for (i = 0; i < 8; i = i + 1) begin
			for (j = 0; j < 8; j = j + 1) begin
				w_q[j][i] <= w_q_c[j][i];
			end
		end		
	end 
end


always @(*) begin
	for (i = 0 ; i < 8; i=i+1 ) begin
		for (j = 0 ; j < 8; j=j+1 ) begin
			data_c[j][i] = data[j][i];
		end
	end

	if ((c_state == PROCESS_Q || n_state == PROCESS_Q) && y_idx < T_len) begin
		data_c[y_idx][x_idx] = in_data;
	end
end

always @(*) begin
	for (i = 0 ; i < 8; i=i+1 ) begin
		for (j = 0 ; j < 8; j=j+1 ) begin
			w_k_c[j][i] = w_k[j][i];
		end
	end
	if (c_state == PROCESS_K) begin
		w_k_c[y_idx][x_idx] = w_K;
	end
end

always @(*) begin
	for (i = 0 ; i < 8; i=i+1 ) begin
		for (j = 0 ; j < 8; j=j+1 ) begin
			w_q_c[j][i] = w_q[j][i];
		end
	end
	if (c_state == PROCESS_Q || n_state == PROCESS_Q) begin
		w_q_c[y_idx][x_idx] = w_Q;
	end
	else if (c_state == PROCESS_V) begin
		w_q_c[y_idx][x_idx] = w_V;
	end
end

//================================================================
// Matrix multiplication
//================================================================
generate
    for(k=0; k<8; k=k+1)begin: Gate_or_K_1
        always @(posedge gated_clk_k[k] or negedge rst_n ) begin
            if (  !rst_n) begin
				for (i = 0 ; i <8 ; i=i+1 ) begin
					K[i][k] <= 0;
				end
            end
            else begin
				for (i = 0 ; i <8 ; i=i+1 ) begin
					K[i][k]<= K_c[i][k];
				end
            end 
        end

    end
endgenerate

generate
    for(k=0; k<8; k=k+1)begin: Gate_or_Q_1
        always @(posedge gated_clk_Q[k] or negedge rst_n ) begin
            if (  !rst_n) begin
				for (i = 0 ; i <8 ; i=i+1 ) begin
					Q[i][k] <= 0;
				end
            end
            else begin
				for (i = 0 ; i <8 ; i=i+1 ) begin
					Q[i][k]<= Q_c[i][k];
				end
            end 
        end

    end
endgenerate

generate
    for(k=0; k<8; k=k+1)begin: Gate_or_V_1
        always @(posedge gated_clk_V[k] or negedge rst_n ) begin

            if (  !rst_n) begin
				for (i = 0 ; i <8 ; i=i+1 ) begin
					V[i][k] <= 0;
				end
            end
            else begin
				for (i = 0 ; i <8 ; i=i+1 ) begin
					V[i][k]<= V_c[i][k];
				end
            end 
        end

    end
endgenerate

generate
    for(k=0; k<8; k=k+1)begin: Gate_or_A_1
        always @(posedge clk or negedge rst_n ) begin

            if ( !rst_n) begin
				for (i = 0 ; i <8 ; i=i+1 ) begin
					A[i][k] <= 0;
				end
            end
            else begin
				for (i = 0 ; i <8 ; i=i+1 ) begin
					A[i][k]<= A_c[i][k];
				end
            end 
        end

    end
endgenerate



always @(*) begin
	for (i = 0 ; i < 8; i=i+1 ) begin
		for (j = 0 ; j < 8; j=j+1 ) begin
			K_c[j][i] = K[j][i];
		end
	end
	if (c_state == PROCESS_V ) begin
		K_c[y_idx][x_idx] = sum_out;
	end
end

always @(*) begin
	for (i = 0 ; i < 8; i=i+1 ) begin
		for (j = 0 ; j < 8; j=j+1 ) begin
			Q_c[j][i] = Q[j][i];
		end
	end
	if (c_state == PROCESS_K ) begin
		Q_c[y_idx][x_idx] = sum_out;
	end
end


always @(*) begin
	for (i = 0 ; i < 8; i=i+1 ) begin
		for (j = 0 ; j < 8; j=j+1 ) begin
			V_c[j][i] = V[j][i];
		end
	end
	if (c_state == PROCESS_L ) begin
		V_c[y_idx][x_idx] = sum_out;
		V_c[y_idx][x_idx+1] = sum_0_out;
	end
end

always @(*) begin
	for (i = 0 ; i < 8; i=i+1 ) begin
		for (j = 0 ; j < 8; j=j+1 ) begin
			A_c[j][i] = A[j][i];
		end
	end
	if (c_state == PROCESS_L ) begin
		A_c[y_idx][x_idx] = (ans[40] ) ? 0 : ans / 3;
		A_c[y_idx][x_idx+1] = (ans1[40] ) ? 0 : ans1 / 3;
	end
end

always @(*) begin
	for ( i = 0 ; i < 8; i=i+1 )begin
		mul_in1[i] = 0;
		mul_in2[i] = 0;
	end	
	if (c_state == PROCESS_K) begin
			for ( i = 0 ; i < 8; i=i+1 )begin
				mul_in1[i] = data[y_idx][i];
				mul_in2[i] = w_q[i][x_idx];
			end			
	end
	else if (c_state == PROCESS_V) begin
		for ( i = 0 ; i < 8; i=i+1 )begin
			mul_in1[i] = data[y_idx][i];
			mul_in2[i] = w_k[i][x_idx];
		end				
	end
	else if (c_state == PROCESS_L) begin
		for ( i = 0 ; i < 8; i=i+1 )begin
			mul_in1[i] = data[y_idx][i];
			mul_in2[i] = w_q[i][x_idx];
		end				
	end
end


always @(*) begin
	for ( i = 0 ; i < 8; i=i+1) begin
		mul_out[i] = mul_in1[i] * mul_in2[i] ;
	end
end
always @(*) begin
	sum_out = (mul_out[0] + mul_out[1] + mul_out[2] + mul_out[3]) + (mul_out[4] + mul_out[5] + mul_out[6] + mul_out[7]);
end


always @(*) begin
	for ( i = 0 ; i < 8; i=i+1 )begin
		mul_0_in1[i] = 0;
		mul_0_in2[i] = 0;
	end	
	if (c_state == PROCESS_L) begin
		for ( i = 0 ; i < 8; i=i+1 )begin
			mul_0_in1[i] = data[y_idx][i];
			mul_0_in2[i] = w_q[i][x_idx+1];
		end				
	end
end

always @(*) begin
	for ( i = 0 ; i < 8; i=i+1) begin
		mul_0_out[i] = mul_0_in1[i] * mul_0_in2[i] ;
	end
end
always @(*) begin
	sum_0_out = (mul_0_out[0] + mul_0_out[1] + mul_0_out[2] + mul_0_out[3]) + (mul_0_out[4] + mul_0_out[5] + mul_0_out[6] + mul_0_out[7]);
end


always @(*) begin
	sum_2_out = (mul_2_out[0] + mul_2_out[1] + mul_2_out[2] + mul_2_out[3]) +  (mul_2_out[4] + mul_2_out[5] + mul_2_out[6] + mul_2_out[7]);
end
always @(*) begin
	for ( i = 0 ; i < 8; i=i+1) begin
		mul_2_out[i] = mul_2_in1[i] * mul_2_in2[i] ;
	end
end

always @(*) begin
	for ( i = 0 ; i < 8; i=i+1 )begin
		mul_2_in1[i] = 0;
		mul_2_in2[i] = 0;
	end			
	if (c_state == PROCESS_L) begin
		for ( i = 0 ; i < 8; i=i+1 )begin
			mul_2_in1[i] = Q[y_idx][i];
			mul_2_in2[i] = K[x_idx][i];
		end			
	end
	else if (c_state == PROCESS_P) begin
		for ( i = 0 ; i < 8; i=i+1 )begin
			mul_2_in1[i] = A[y_idx][i];
			mul_2_in2[i] = V[i][x_idx];
		end			
	end
end


always @(*) begin
	for ( i = 0 ; i < 8; i=i+1) begin
		mul_3_out[i] = mul_3_in1[i] * mul_3_in2[i] ;
	end
end

always @(*) begin
	for ( i = 0 ; i < 8; i=i+1 )begin
		mul_3_in1[i] = 0;
		mul_3_in2[i] = 0;
	end			
	if (c_state == PROCESS_L) begin
		for ( i = 0 ; i < 8; i=i+1 )begin
			mul_3_in1[i] = Q[y_idx][i];
			mul_3_in2[i] = K[x_idx+1][i];
		end			
	end
end

always @(*) begin
	sum_3_out = (mul_3_out[0] + mul_3_out[1] + mul_3_out[2] + mul_3_out[3]) +  (mul_3_out[4] + mul_3_out[5] + mul_3_out[6] + mul_3_out[7]);
end

always @(*) begin
	ans = 0;ans1 = 0;
	if (c_state == PROCESS_L) begin
		ans = sum_2_out;
		ans1 = sum_3_out;
	end
	else ans = 0;
end

//================================================================
// OUTPUT
//================================================================
always @(*) begin
	out_data = 0;
	if (c_state == PROCESS_P) begin
		out_data = sum_2_out;
	end else out_data = 0;
end

always @(*) begin
	out_valid = 0;
	if (c_state == PROCESS_P) begin
		out_valid = 1;
	end else out_valid = 0;
end
endmodule
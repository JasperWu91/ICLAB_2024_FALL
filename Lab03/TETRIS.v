/**************************************************************************/
// Copyright (c) 2024, OASIS Lab
// MODULE: TETRIS
// FILE NAME: TETRIS.v
// VERSRION: 1.0
// DATE: August 15, 2024
// AUTHOR: Yu-Hsuan Hsu, NYCU IEE
// DESCRIPTION: ICLAB2024FALL / LAB3 / TETRIS
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/
module TETRIS (
	//INPUT
	rst_n,
	clk,
	in_valid,
	tetrominoes,
	position,
	//OUTPUT
	tetris_valid,
	score_valid,
	fail,
	score,
	tetris
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input				rst_n, clk, in_valid;
input		[2:0]	tetrominoes;
input		[2:0]	position;
output reg			tetris_valid, score_valid, fail;
output reg	[3:0]	score;
output reg 	[71:0]	tetris;


//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
parameter IDLE = 2'b01, // wait and fill data
		  BUSY = 2'b10, // process data
		  OUT  = 2'b11;// output stage

integer f_i, i, g_i;
//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------
reg [1:0] c_state, n_state;
reg [3:0] peak  [5:0]; // record the height of each column
reg [3:0] peak_s  [5:0]; // record the height of each column
reg [5:0] grid [13:0] ; // 14 rows * 6 columns
reg [5:0] grid_s [13:0] ; // 14 rows * 6 columns
reg [2:0] tetrominoes_type;
reg [2:0] pos_x;
reg [2:0] x_pos[0:3];
reg [3:0] y_pos[0:3];
reg [3:0] score_temp;
reg [3:0] cnt, cnt_next; 
reg [3:0] p1, p2, p3, p4; // input of find pos_y
reg fail_flag;
wire finish_check_line;
wire sfinish_check_line;
wire over_flag;

wire [3:0] pos_y_7;

wire [3:0] pos_y_6;
wire [3:0] pos_y_5;
wire [3:0] pos_y_4;
wire [3:0] pos_y_3;
wire [3:0] pos_y_2;
wire [3:0] pos_y_1;
wire [3:0] pos_y_0;

wire [3:0] pos_y;


// connecting lines
wire  c_line_0, c_line_1, c_line_2, c_line_3, c_line_4, c_line_5, c_line_6, c_line_7, c_line_8, c_line_9, c_line_10, c_line_11;
wire  s_line_0, s_line_1, s_line_2, s_line_3, s_line_4, s_line_5, s_line_6, s_line_7, s_line_8, s_line_9, s_line_10, s_line_11;

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		c_state <= IDLE;
	end
	else c_state <= n_state;
end

always @(*) begin
	case (c_state)
		IDLE: begin
			if (in_valid) begin
				if (!finish_check_line) begin
					n_state = OUT ;
				end else n_state = BUSY; 
			end else n_state =  IDLE ;
		end
		BUSY: begin
			if (!finish_check_line) begin
				n_state = OUT ;
			end else n_state = BUSY; 
		end
		OUT: begin
            n_state = IDLE;
        end
		default: n_state = c_state;
	endcase
end

assign over_flag = (cnt == 0);
assign tetrominoes_type = tetrominoes;
assign pos_x = position;
FindPeak FP (.grid(grid_s[11:0]), .peak(peak));

sort find_pos_y(p1, p2, p3, p4, pos_y);


always @(*) begin    
	p1 = 4'b0000;
    p2 = 4'b0000;
    p3 = 4'b0000;
    p4 = 4'b0000;

    if (in_valid) begin
        case (tetrominoes_type)
            3'd0: begin 
                p1 = peak_s[pos_x];
                p2 = peak_s[pos_x + 1];
            end

            3'd1: begin 
                p1 = peak_s[pos_x];
            end

            3'd2: begin 
                p1 = peak_s[pos_x];
                p2 = peak_s[pos_x + 1];
                p3 = peak_s[pos_x + 2];
                p4 = peak_s[pos_x + 3];
            end

            3'd3: begin 
                p1 = peak_s[pos_x];
                p2 = peak_s[pos_x + 1] + 2;
            end

            3'd4: begin 
                p1 = peak_s[pos_x] + 1;
                p2 = peak_s[pos_x + 1];
                p3 = peak_s[pos_x + 2];
            end

            3'd5: begin 
                p1 = peak_s[pos_x];
                p2 = peak_s[pos_x + 1];
            end

            3'd6: begin 
                p1 = peak_s[pos_x] + 1;
                p2 = peak_s[pos_x + 1] + 2;
            end

            3'd7: begin 
                p1 = peak_s[pos_x] + 1;
                p2 = peak_s[pos_x + 1] + 1;
                p3 = peak_s[pos_x + 2];
            end

            default: begin
                p1 = 4'b0000;
                p2 = 4'b0000;
                p3 = 4'b0000;
                p4 = 4'b0000;
            end
        endcase
    end
end


always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		for ( i = 0 ; i < 14 ; i = i + 1 ) begin
			grid_s[i] <= 0;
		end	
	end
	else begin
		for ( i = 0 ; i < 14 ; i = i + 1 ) begin
			grid_s[i] <= grid[i];
		end	
	end
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		for ( i = 0 ; i < 6 ; i = i + 1 ) begin
			peak_s[i] <= 0;
		end	
	end
	else if (c_state == OUT &&  ((over_flag ) || (fail_flag) )  ) begin
			for ( i = 0 ; i < 6 ; i = i + 1 ) begin
				peak_s[i] <= 0;
			end	
	end
	else begin
		for ( i = 0 ; i < 6 ; i = i + 1 ) begin
			peak_s[i] <= peak[i];
		end	
	end
end

always @(*) begin
	for ( i = 0 ; i < 14 ; i = i + 1 ) begin
		grid[i] = grid_s[i];
	end	
	if (in_valid && (c_state == IDLE)) begin
		case (tetrominoes_type)
			0: begin
				grid[pos_y][pos_x] = 1;
				grid[pos_y + 1][pos_x] = 1;
				grid[pos_y][pos_x + 1] = 1;
				grid[pos_y + 1][pos_x + 1] = 1;
			end 

			1: begin
				grid[pos_y][pos_x] = 1;
				grid[pos_y + 1][pos_x] = 1;
				grid[pos_y + 2][pos_x] = 1;
				grid[pos_y + 3][pos_x] = 1;
			end 

			2: begin
				grid[pos_y][pos_x] = 1;
				grid[pos_y][pos_x + 1] = 1;
				grid[pos_y][pos_x + 2] = 1;
				grid[pos_y][pos_x + 3] = 1;
			end 

			3: begin
				grid[pos_y][pos_x] = 1;
				grid[pos_y][pos_x + 1] = 1;
				grid[pos_y -1][pos_x + 1] = 1;
				grid[pos_y -2][pos_x + 1] = 1;
			end 

			4: begin
				grid[pos_y - 1][pos_x] = 1;
				grid[pos_y][pos_x] = 1;
				grid[pos_y][pos_x + 1] = 1;
				grid[pos_y][pos_x + 2] = 1;
			end 

			5: begin
				grid[pos_y][pos_x] = 1;
				grid[pos_y][pos_x + 1] = 1;
				grid[pos_y + 1][pos_x] = 1;
				grid[pos_y + 2][pos_x] = 1;
			end 

			6: begin
				grid[pos_y - 1][pos_x] = 1;
				grid[pos_y - 1][pos_x + 1] = 1;
				grid[pos_y - 2][pos_x + 1] = 1;
				grid[pos_y][pos_x] = 1;
			end 

			7: begin
				grid[pos_y - 1][pos_x] = 1;
				grid[pos_y - 1][pos_x + 1] = 1;
				grid[pos_y][pos_x + 1] = 1;
				grid[pos_y][pos_x + 2] = 1;
			end 
		endcase
	end

	else if (c_state == BUSY) begin
		if(s_line_11) begin
			for (g_i = 11; g_i < 14; g_i = g_i + 1) begin
				if ((g_i + 1) < 14) begin
					grid[g_i] = grid_s[g_i + 1];						
				end
				else grid[g_i] = 0;

			end
		end
		else if(s_line_10) begin
	
			for (g_i = 10; g_i < 14; g_i = g_i + 1) begin
				if ((g_i + 1) < 14) begin
					grid[g_i] = grid_s[g_i + 1];						
				end
				else grid[g_i] = 0;
			end
		end
		else if(s_line_9) begin
			
			for (g_i = 9; g_i < 14; g_i = g_i + 1) begin
				if ((g_i + 1) < 14) begin
					grid[g_i] = grid_s[g_i + 1];						
				end
				else grid[g_i] = 0;
			end
		end
		else if(s_line_8) begin
		
			for (g_i = 8; g_i < 14; g_i = g_i + 1) begin
				if ((g_i + 1) < 14) begin
					grid[g_i] = grid_s[g_i + 1];						
				end
				else grid[g_i] = 0;
			end
		end
		else if(s_line_7) begin
			for (g_i = 7; g_i < 14; g_i = g_i + 1) begin
				if ((g_i + 1) < 14) begin
					grid[g_i] = grid_s[g_i + 1];						
				end
				else grid[g_i] = 0;
			end
		end
		else if(s_line_6) begin
			for (g_i = 6; g_i < 14; g_i = g_i + 1) begin
				if ((g_i + 1) < 14) begin
					grid[g_i] = grid_s[g_i + 1];						
				end
				else grid[g_i] = 0;
			end
		end
		else if(s_line_5) begin
			for (g_i = 5; g_i < 14; g_i = g_i + 1) begin
				if ((g_i + 1) < 14) begin
					grid[g_i] = grid_s[g_i + 1];						
				end
				else grid[g_i] = 0;
			end
		end
		else if(s_line_4) begin
			for (g_i = 4; g_i < 14; g_i = g_i + 1) begin
				if ((g_i + 1) < 14) begin
					grid[g_i] = grid_s[g_i + 1];						
				end
				else grid[g_i] = 0;
			end
		end
		else if(s_line_3) begin
			for (g_i = 3; g_i < 14; g_i = g_i + 1) begin
				if ((g_i + 1) < 14) begin
					grid[g_i] = grid_s[g_i + 1];						
				end
				else grid[g_i] = 0;
			end
		end

		else if(s_line_2) begin
			for (g_i = 2; g_i < 14; g_i = g_i + 1) begin
				if ((g_i + 1) < 14) begin
					grid[g_i] = grid_s[g_i + 1];						
				end
				else grid[g_i] = 0;
			end
		end

		else if(s_line_1) begin
			for (g_i = 1; g_i < 14; g_i = g_i + 1) begin
				if ((g_i + 1) < 14) begin
					grid[g_i] = grid_s[g_i + 1];						
				end
				else grid[g_i] = 0;
			end
		end
		else if(s_line_0) begin
			for (g_i = 0; g_i < 14; g_i = g_i + 1) begin
				if ((g_i + 1) < 14) begin
					grid[g_i] = grid_s[g_i + 1];						
				end
				else grid[g_i] = 0;
			end

		end
	end

	else if (c_state == OUT &&  ((over_flag) || (fail_flag) )  ) begin
			for ( i = 0 ; i < 14 ; i = i + 1 ) begin
				grid[i] = 0;
			end	
	end
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		score_temp <= 0;
	end
	else if(finish_check_line && n_state == BUSY) begin
			score_temp <= score_temp + 1; 
		end
	else if (c_state == OUT &&  ((over_flag ) || (fail_flag) )  ) begin
		score_temp <= 0;
	end
end


assign c_line_0  = &grid[0];  
assign c_line_1  = &grid[1];  
assign c_line_2  = &grid[2];  
assign c_line_3  = &grid[3];  
assign c_line_4  = &grid[4];  
assign c_line_5  = &grid[5];  
assign c_line_6  = &grid[6];  
assign c_line_7  = &grid[7];  
assign c_line_8  = &grid[8];  
assign c_line_9  = &grid[9];  
assign c_line_10 = &grid[10]; 
assign c_line_11 = &grid[11];  


assign s_line_0  = &grid_s[0];   
assign s_line_1  = &grid_s[1];  
assign s_line_2  = &grid_s[2];  
assign s_line_3  = &grid_s[3];  
assign s_line_4  = &grid_s[4];  
assign s_line_5  = &grid_s[5];  
assign s_line_6  = &grid_s[6];  
assign s_line_7  = &grid_s[7];  
assign s_line_8  = &grid_s[8];  
assign s_line_9  = &grid_s[9];  
assign s_line_10 = &grid_s[10]; 
assign s_line_11 = &grid_s[11];  


assign finish_check_line =  c_line_0 || c_line_1 || c_line_2 || c_line_3 || c_line_4 
	|| c_line_5 || c_line_6 || c_line_7 || c_line_8 || c_line_9 || c_line_10 || c_line_11;

assign sfinish_check_line =  s_line_0 || s_line_1 || s_line_2 || s_line_3 || s_line_4 
	|| s_line_5 || s_line_6 || s_line_7 || s_line_8 || s_line_9 || s_line_10 || s_line_11;


always @(*) begin
	if (!rst_n) begin
		fail_flag = 0;
	end
	else if ((c_state == BUSY || c_state == OUT )) begin
		fail_flag = |grid_s[12];		
	end else fail_flag = 0;
end


always @(*) begin
    if (!rst_n) begin
       	score = 1'b0;
    end 
    else if(score_valid) score = score_temp;
    else score = 1'b0;
end


always @(*) begin
    if (!rst_n) begin
       	tetris = 0;
    end 
	else if(tetris_valid ) begin
		tetris = { grid_s[11],grid_s[10],grid_s[9],grid_s[8],grid_s[7],grid_s[6],grid_s[5],grid_s[4],grid_s[3],grid_s[2],grid_s[1],grid_s[0]};
	end
    else tetris = 0;
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt <= 0;
    end else begin
        cnt <= cnt_next; 
    end
end

always @(*) begin
    cnt_next = cnt; 
    if (n_state == OUT) begin
        cnt_next = cnt + 1; 
    end else if (c_state == OUT && (over_flag|| fail_flag)) begin
        cnt_next = 0; 
    end
end

always @(*) begin
    if (!rst_n) begin
       	fail = 1'b0;
    end 
    else if(fail_flag && score_valid) fail = 1'b1;
    else fail = 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
       	score_valid <= 1'b0;
    end 
    else if(n_state == OUT ) score_valid <= 1'b1;
    else score_valid <= 1'b0;
end

always @(*) begin
    if (!rst_n) begin
       	tetris_valid <= 1'b0;
    end 
    else if(score_valid &&  ((over_flag) || (fail_flag) )) tetris_valid <= 1'b1;
    else tetris_valid <= 1'b0;
end
endmodule

module cmp(in1, in2, out1 , out2);
	input  [3:0] in1 ;
	input  [3:0] in2 ;
	output [3:0] out1 ;
	output [3:0] out2 ;

	assign out1 = (in1 > in2)? in1 : in2;
	assign out2 = (in1 > in2)? in2 : in1;
endmodule

module sort(in0, in1, in2 , in3 ,out);
    input [3:0] in0, in1, in2 , in3 ;
    output [3:0] out ;

    wire[3:0] a[0:3], b[0:3], c[0:1];

    cmp c0(.in1(in0), .in2(in2), .out1(a[0]), .out2(a[2]) );
    cmp c1(.in1(in1), .in2(in3), .out1(a[1]), .out2(a[3]) );
    cmp c2(.in1(a[0]), .in2(a[1]), .out1(b[0]), .out2(b[1]) );
    cmp c3(.in1(a[2]), .in2(a[3]), .out1(b[2]), .out2(b[3]) );
    cmp c4(.in1(b[1]), .in2(b[2]), .out1(c[0]), .out2(c[1]) );
    assign out = b[0];
endmodule


module FindPeak ( grid, peak);
	//input  clk;      // Clock input
	input  [5:0] grid [11:0];      // Input grid array
	output reg [3:0] peak[5:0] ;  // Output peak array for each column
	
	always @(*) begin
		if (grid[11][0]) begin
			peak[0] = 12;
		end else if (grid[10][0]) begin
			peak[0] = 11;
		end else if (grid[9][0]) begin
			peak[0] = 10;
		end else if (grid[8][0]) begin
			peak[0] = 9;
		end else if (grid[7][0]) begin
			peak[0] = 8;
		end else if (grid[6][0]) begin
			peak[0] = 7;
		end else if (grid[5][0]) begin
			peak[0] = 6;
		end else if (grid[4][0]) begin
			peak[0] = 5;
		end else if (grid[3][0]) begin
			peak[0] = 4;
		end else if (grid[2][0]) begin
			peak[0] = 3;
		end else if (grid[1][0]) begin
			peak[0] = 2;
		end else if (grid[0][0]) begin
			peak[0] = 1;
		end else begin
			peak[0] = 0;
		end
	end
	
	always @(*) begin
		if (grid[11][1]) begin
			peak[1] = 12;
		end else if (grid[10][1]) begin
			peak[1] = 11;
		end else if (grid[9][1]) begin
			peak[1] = 10;
		end else if (grid[8][1]) begin
			peak[1] = 9;
		end else if (grid[7][1]) begin
			peak[1] = 8;
		end else if (grid[6][1]) begin
			peak[1] = 7;
		end else if (grid[5][1]) begin
			peak[1] = 6;
		end else if (grid[4][1]) begin
			peak[1] = 5;
		end else if (grid[3][1]) begin
			peak[1] = 4;
		end else if (grid[2][1]) begin
			peak[1] = 3;
		end else if (grid[1][1]) begin
			peak[1] = 2;
		end else if (grid[0][1]) begin
			peak[1] = 1;
		end else begin
			peak[1] = 0;
		end
	end
	
	always @(*) begin
		if (grid[11][2]) begin
			peak[2] = 12;
		end else if (grid[10][2]) begin
			peak[2] = 11;
		end else if (grid[9][2]) begin
			peak[2] = 10;
		end else if (grid[8][2]) begin
			peak[2] = 9;
		end else if (grid[7][2]) begin
			peak[2] = 8;
		end else if (grid[6][2]) begin
			peak[2] = 7;
		end else if (grid[5][2]) begin
			peak[2] = 6;
		end else if (grid[4][2]) begin
			peak[2] = 5;
		end else if (grid[3][2]) begin
			peak[2] = 4;
		end else if (grid[2][2]) begin
			peak[2] = 3;
		end else if (grid[1][2]) begin
			peak[2] = 2;
		end else if (grid[0][2]) begin
			peak[2] = 1;
		end else begin
			peak[2] = 0;
		end
	end

	always @(*) begin
		if (grid[11][3]) begin
			peak[3] = 12;
		end else if (grid[10][3]) begin
			peak[3] = 11;
		end else if (grid[9][3]) begin
			peak[3] = 10;
		end else if (grid[8][3]) begin
			peak[3] = 9;
		end else if (grid[7][3]) begin
			peak[3] = 8;
		end else if (grid[6][3]) begin
			peak[3] = 7;
		end else if (grid[5][3]) begin
			peak[3] = 6;
		end else if (grid[4][3]) begin
			peak[3] = 5;
		end else if (grid[3][3]) begin
			peak[3] = 4;
		end else if (grid[2][3]) begin
			peak[3] = 3;
		end else if (grid[1][3]) begin
			peak[3] = 2;
		end else if (grid[0][3]) begin
			peak[3] = 1;
		end else begin
			peak[3] = 0;
		end
	end


	always @(*) begin
		if (grid[11][4]) begin
			peak[4] = 12;
		end else if (grid[10][4]) begin
			peak[4] = 11;
		end else if (grid[9][4]) begin
			peak[4] = 10;
		end else if (grid[8][4]) begin
			peak[4] = 9;
		end else if (grid[7][4]) begin
			peak[4] = 8;
		end else if (grid[6][4]) begin
			peak[4] = 7;
		end else if (grid[5][4]) begin
			peak[4] = 6;
		end else if (grid[4][4]) begin
			peak[4] = 5;
		end else if (grid[3][4]) begin
			peak[4] = 4;
		end else if (grid[2][4]) begin
			peak[4] = 3;
		end else if (grid[1][4]) begin
			peak[4] = 2;
		end else if (grid[0][4]) begin
			peak[4] = 1;
		end else begin
			peak[4] = 0;
		end
	end

	always @(*) begin
		if (grid[11][5]) begin
			peak[5] = 12;
		end else if (grid[10][5]) begin
			peak[5] = 11;
		end else if (grid[9][5]) begin
			peak[5] = 10;
		end else if (grid[8][5]) begin
			peak[5] = 9;
		end else if (grid[7][5]) begin
			peak[5] = 8;
		end else if (grid[6][5]) begin
			peak[5] = 7;
		end else if (grid[5][5]) begin
			peak[5] = 6;
		end else if (grid[4][5]) begin
			peak[5] = 5;
		end else if (grid[3][5]) begin
			peak[5] = 4;
		end else if (grid[2][5]) begin
			peak[5] = 3;
		end else if (grid[1][5]) begin
			peak[5] = 2;
		end else if (grid[0][5]) begin
			peak[5] = 1;
		end else begin
			peak[5] = 0;
		end
	end
endmodule



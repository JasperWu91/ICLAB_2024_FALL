module CLK_1_MODULE (
    clk,
    rst_n,
    in_valid,
	in_row,
    in_kernel,
    out_idle,
    handshake_sready,
    handshake_din,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

	fifo_empty,
    fifo_rdata,
    fifo_rinc,
    out_valid,
    out_data,

    flag_clk1_to_fifo,
    flag_fifo_to_clk1
);
input clk;
input rst_n;
input in_valid;
input [17:0] in_row;
input [11:0] in_kernel;
input out_idle;
output reg handshake_sready;
output reg [29:0] handshake_din;
// You can use the the custom flag ports for your design
input  flag_handshake_to_clk1;
output flag_clk1_to_handshake;

input fifo_empty;
input [7:0] fifo_rdata;
output reg fifo_rinc;
output reg out_valid;
output reg [7:0] out_data;
// You can use the the custom flag ports for your design
output flag_clk1_to_fifo;
input flag_fifo_to_clk1;


//================================================================
// FSM
//================================================================
reg [29:0] handshake_data_buffer[5:0];
reg [29:0] handshake_data_buffer_c[5:0];
reg [2:0] cnt, nxt_cnt;
reg [2:0] b_cnt, nxt_b_cnt;
reg [2:0] e_cnt, nxt_e_cnt;
reg [5:0] c_cnt, nxt_c_cnt;
reg [7:0] o_cnt, nxt_o_cnt;


integer i;
parameter IDLE = 0,
          TRANS = 1,
          OUT = 2;
reg [1:0] c_state, n_state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        c_state <= IDLE;
    end else c_state <= n_state; 
end
always @(*) begin
    n_state = c_state;
    case (c_state)
        IDLE : if (in_valid) begin
            n_state = TRANS;
        end 
        TRANS : if (!fifo_empty &&  c_cnt > 2 ) begin
            n_state = OUT;
        end
        OUT : if (o_cnt == 151) begin
            n_state = IDLE;
        end
        default:  n_state = c_state;
    endcase
end

//================================================================
// Design
//================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt <= 0;
    end else cnt <= nxt_cnt;
end

always @(*) begin
    if (c_state == OUT && n_state == IDLE) begin
        nxt_cnt = 0;
    end
    else if (n_state == TRANS) begin
        nxt_cnt = cnt + 1;
    end else nxt_cnt = cnt;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        b_cnt <= 0;
    end else b_cnt <= nxt_b_cnt;
end

always @(*) begin
    if (c_state == IDLE) begin
        nxt_b_cnt = 0;
    end
    else if (handshake_sready) begin
        nxt_b_cnt = b_cnt + 1;
    end else nxt_b_cnt = b_cnt;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        c_cnt <= 0;
    end else c_cnt <= nxt_c_cnt;
end

always @(*) begin
    if (c_state == IDLE) begin
        nxt_c_cnt = 0;
    end
    else if (c_state == TRANS) begin
        nxt_c_cnt = c_cnt + 1;
    end else nxt_c_cnt = c_cnt;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        e_cnt <= 0;
    end else e_cnt <= nxt_e_cnt;
end

always @(*) begin
    if (c_state == IDLE) begin
        nxt_e_cnt = 0;
    end
    else if (c_state == TRANS && !fifo_empty) begin
        nxt_e_cnt = e_cnt + 1;
    end else nxt_e_cnt = e_cnt;
end

always @(*) begin
    handshake_sready = 0;
    if( c_state == TRANS && out_idle) begin
        handshake_sready = 1;
    end
    else if( c_state == TRANS && !out_idle) begin
        handshake_sready = 0;
    end
    else handshake_sready =handshake_sready;
end



always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for ( i = 0 ; i < 6 ; i = i + 1 ) begin
            handshake_data_buffer[i] <= 0;
        end
    end 
    else begin
        for ( i = 0 ; i < 6 ; i = i + 1 ) begin
            handshake_data_buffer[i] <=handshake_data_buffer_c[i];
        end
    end
end

always @(*) begin
    for ( i = 0 ; i < 6 ; i = i + 1 ) begin
        handshake_data_buffer_c[i] =handshake_data_buffer[i];
    end

    if (in_valid) begin
        handshake_data_buffer_c[cnt] = {in_row,in_kernel};
    end
end

always @(*) begin
    handshake_din = 0;
    if (!rst_n) begin
        handshake_din = 0;
    end else if(handshake_sready)begin
        handshake_din = handshake_data_buffer[b_cnt];
    end
end


reg fifo_empty_d, fifo_empty_d2;
reg fifo_rinc_d, fifo_rinc_d2;

always @(*) begin
    if ((c_state == OUT  ) &&  !fifo_empty && o_cnt < 150) begin
        fifo_rinc = 1;
    end
    else  if ((c_state == OUT  ) && o_cnt == 0 && (!fifo_empty )) begin
        fifo_rinc = 1;
    end
    else if (c_state == IDLE && (!fifo_empty )) begin
        fifo_rinc = 1;
    end
    else begin
        fifo_rinc = 0;        
    end
end

always @(posedge clk ) begin
    fifo_rinc_d <= fifo_rinc;
    fifo_rinc_d2 <= fifo_rinc_d;
end

always @(posedge clk ) begin
    fifo_empty_d <= fifo_empty;
    fifo_empty_d2 <= fifo_empty_d;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_cnt <= 0;
    end else o_cnt <= nxt_o_cnt;
end

always @(*) begin
    if (c_state == IDLE) begin
        nxt_o_cnt = 0;
    end
    else if (c_state == OUT   && o_cnt == 150) begin
        nxt_o_cnt = o_cnt + 1;
    end
    else if (c_state == OUT   && (fifo_rinc)) begin
        nxt_o_cnt = o_cnt + 1;
    end else nxt_o_cnt = o_cnt;
end

always @(*) begin
    if (!rst_n) begin
        out_valid = 0;
    end 
    else if (c_state == IDLE) begin
        out_valid = 0;
    end 
    
    // else if (c_state == OUT && !fifo_empty && fifo_empty_d2  && o_cnt > 1) begin
    //     out_valid = 0;
    // end
    // else if (c_state == OUT && fifo_empty  && !fifo_empty_d  && o_cnt > 1 ) begin
    //     out_valid = 1;
    // end
    else if (c_state == OUT && fifo_rinc_d2  ) begin
        out_valid = 1;
    end

    else begin
        out_valid = 0;   
    end
end

always @(*) begin
    if (!rst_n) begin
        out_data = 0;
    end 
    else if (c_state == IDLE) begin
        out_data = 0;
    end 
    // else if (c_state == OUT && !fifo_empty && fifo_empty_d2 && o_cnt > 1  ) begin
    //     out_data = 0;
    // end    
    // else if (c_state == OUT && fifo_empty  && !fifo_empty_d && o_cnt > 1 ) begin
    //     out_data = fifo_rdata;
    // end
    else if (c_state == OUT && fifo_rinc_d2  ) begin
        out_data = fifo_rdata;
    end

    else begin
        out_data = 0;        
    end
end



endmodule

module CLK_2_MODULE (
    clk,
    rst_n,
    in_valid,
    fifo_full,
    in_data,
    out_valid,
    out_data,
    busy,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo
);

input clk;
input rst_n;
input in_valid;
input fifo_full;
input [29:0] in_data;
output reg out_valid;
output reg [7:0] out_data;
output reg busy;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk2;
output flag_clk2_to_handshake;

input  flag_fifo_to_clk2;
output flag_clk2_to_fifo;

//================================================================
// REG
//================================================================
reg [2:0] matrix_buffer [0:5][0:5];
reg [2:0] matrix_buffer_c[0:5][0:5];

reg [2:0] kernel_buffer [0:5][0:3];
reg [2:0] kernel_buffer_c[0:5][0:3];

reg [7:0] f_buffer [0:150];
reg [7:0] f_buffer_c [0:150];

reg [2:0] c_state, n_state;
reg in_valid_reg;

reg [9:0] cnt, nxt_cnt;
reg [2:0] k_cnt;
reg [2:0] d_cnt, nxt_d_cnt;
reg [2:0] x_idx, nxt_x_idx;
reg [2:0] y_idx, nxt_y_idx;
reg [7:0] o_cnt, nxt_o_cnt;

reg [2:0] in [3:0];
reg [2:0] w [3:0];
reg [5:0] out [3:0];
reg [5:0] out_n [3:0];
reg [7:0] conv_out;

//================================================================
// FSM
//================================================================
integer i,j;
parameter WAIT_DATA = 0,
          GET_DATA = 1,
          CONV = 2,
          OUT = 3,
          REST = 4;


always @(posedge clk ) begin
    in_valid_reg <= in_valid;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        c_state <= WAIT_DATA;
    end else c_state <= n_state; 
end
always @(*) begin
    n_state = c_state;
    case (c_state)
        WAIT_DATA : if (in_valid) begin
            n_state = GET_DATA;
        end 
        GET_DATA : if (d_cnt == 5) begin
            n_state = CONV;
        end 
        CONV : if (x_idx == 4 && y_idx == 4) begin
            n_state = OUT;
        end
        OUT: if (o_cnt == 149) begin
            n_state = REST;
        end
        REST: begin
            if (o_cnt == 150) begin
            n_state = WAIT_DATA;     
            end
           
        end
        default:  n_state = c_state;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        d_cnt <= 0;
    end else d_cnt <= nxt_d_cnt; 
end

always @(*) begin
    if (c_state == GET_DATA && (in_valid_reg == 0) && (in_valid != in_valid_reg)) begin
        nxt_d_cnt = d_cnt + 1;
    end 
    else if (c_state == WAIT_DATA) begin
        nxt_d_cnt = 0;
    end
    else nxt_d_cnt = d_cnt; 
end


// Buffer logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for ( i = 0 ; i < 6 ; i = i + 1 ) begin
            for ( j = 0 ; j < 6 ; j = j + 1) begin
                matrix_buffer[i][j] <= 0;
            end
        end
    end
    else begin
        for ( i = 0 ; i < 6 ; i = i + 1 ) begin
            for ( j = 0 ; j < 6 ; j = j + 1) begin
                matrix_buffer[i][j] <= matrix_buffer_c[i][j];
            end
        end
    end
end

always @(*) begin
    for ( i = 0 ; i < 6 ; i = i + 1 ) begin
        for ( j = 0 ; j < 6 ; j = j + 1) begin
            matrix_buffer_c[i][j] = matrix_buffer[i][j];
        end
    end
    if (in_valid && c_state != CONV && c_state != OUT) begin
        case (nxt_d_cnt)
            0: begin
                matrix_buffer_c[0][5] = in_data[29:27];
                matrix_buffer_c[0][4] = in_data[26:24];
                matrix_buffer_c[0][3] = in_data[23:21];
                matrix_buffer_c[0][2] = in_data[20:18];
                matrix_buffer_c[0][1] = in_data[17:15];
                matrix_buffer_c[0][0] = in_data[14:12];                
            end 
            1: begin
                matrix_buffer_c[1][5] = in_data[29:27];
                matrix_buffer_c[1][4] = in_data[26:24];
                matrix_buffer_c[1][3] = in_data[23:21];
                matrix_buffer_c[1][2] = in_data[20:18];
                matrix_buffer_c[1][1] = in_data[17:15];
                matrix_buffer_c[1][0] = in_data[14:12];                     
            end 
            2: begin
                matrix_buffer_c[2][5] = in_data[29:27];
                matrix_buffer_c[2][4] = in_data[26:24];
                matrix_buffer_c[2][3] = in_data[23:21];
                matrix_buffer_c[2][2] = in_data[20:18];
                matrix_buffer_c[2][1] = in_data[17:15];
                matrix_buffer_c[2][0] = in_data[14:12];                 
            end 
            3: begin
                matrix_buffer_c[3][5] = in_data[29:27];
                matrix_buffer_c[3][4] = in_data[26:24];
                matrix_buffer_c[3][3] = in_data[23:21];
                matrix_buffer_c[3][2] = in_data[20:18];
                matrix_buffer_c[3][1] = in_data[17:15];
                matrix_buffer_c[3][0] = in_data[14:12];                
            end 
            4: begin
                matrix_buffer_c[4][5] = in_data[29:27];
                matrix_buffer_c[4][4] = in_data[26:24];
                matrix_buffer_c[4][3] = in_data[23:21];
                matrix_buffer_c[4][2] = in_data[20:18];
                matrix_buffer_c[4][1] = in_data[17:15];
                matrix_buffer_c[4][0] = in_data[14:12];                 
            end 
            5: begin
                matrix_buffer_c[5][5] = in_data[29:27];
                matrix_buffer_c[5][4] = in_data[26:24];
                matrix_buffer_c[5][3] = in_data[23:21];
                matrix_buffer_c[5][2] = in_data[20:18];
                matrix_buffer_c[5][1] = in_data[17:15];
                matrix_buffer_c[5][0] = in_data[14:12];                 
            end 

        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for ( i = 0 ; i < 6 ; i = i + 1 ) begin
            for ( j = 0 ; j < 4 ; j = j + 1) begin
                kernel_buffer[i][j] <= 0;
            end
        end
    end 
    
    else begin
        for ( i = 0 ; i < 6 ; i = i + 1 ) begin
            for ( j = 0 ; j < 4 ; j = j + 1) begin
                kernel_buffer[i][j] <= kernel_buffer_c[i][j];
            end
        end
    end
end
always @(*) begin
    for ( i = 0 ; i < 6 ; i = i + 1 ) begin
        for ( j = 0 ; j < 4 ; j = j + 1) begin
            kernel_buffer_c[i][j] = kernel_buffer[i][j];
        end
    end

    if (in_valid && c_state != CONV && c_state != OUT) begin
        case (nxt_d_cnt)
            0 : begin
                kernel_buffer_c[0][3] = in_data[11:9];
                kernel_buffer_c[0][2] = in_data[8:6];
                kernel_buffer_c[0][1] = in_data[5:3];
                kernel_buffer_c[0][0] = in_data[2:0];                
            end        
            1 : begin
                kernel_buffer_c[1][3] = in_data[11:9];
                kernel_buffer_c[1][2] = in_data[8:6];
                kernel_buffer_c[1][1] = in_data[5:3];
                kernel_buffer_c[1][0] = in_data[2:0];                   
            end        
            2 : begin
                kernel_buffer_c[2][3] = in_data[11:9];
                kernel_buffer_c[2][2] = in_data[8:6];
                kernel_buffer_c[2][1] = in_data[5:3];
                kernel_buffer_c[2][0] = in_data[2:0];               
            end        
            3 : begin
                kernel_buffer_c[3][3] = in_data[11:9];
                kernel_buffer_c[3][2] = in_data[8:6];
                kernel_buffer_c[3][1] = in_data[5:3];
                kernel_buffer_c[3][0] = in_data[2:0];                 
            end        
            4 : begin
                kernel_buffer_c[4][3] = in_data[11:9];
                kernel_buffer_c[4][2] = in_data[8:6];
                kernel_buffer_c[4][1] = in_data[5:3];
                kernel_buffer_c[4][0] = in_data[2:0];               
            end 
            5 : begin
                kernel_buffer_c[5][3] = in_data[11:9];
                kernel_buffer_c[5][2] = in_data[8:6];
                kernel_buffer_c[5][1] = in_data[5:3];
                kernel_buffer_c[5][0] = in_data[2:0];                
            end               
        endcase
    end
end

//================================================================
// CONV
//================================================================



always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_idx <= 0;
    end 
    else x_idx <= nxt_x_idx; 
end

always @(*) begin
    if(x_idx == 4)begin
        nxt_x_idx = 0;
    end
    else if(c_state == WAIT_DATA)begin
        nxt_x_idx = 0;
    end
    else if (c_state == CONV || c_state == OUT) begin
        nxt_x_idx = x_idx + 1;
    end 
    else nxt_x_idx = x_idx; 
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        y_idx <= 0;
    end 
    else y_idx <= nxt_y_idx; 
end

always @(*) begin
    if(x_idx == 4 && y_idx == 4)begin
        nxt_y_idx = 0;
    end
    else if(x_idx == 4)begin
        nxt_y_idx = y_idx + 1;
    end
    else if(c_state == WAIT_DATA)begin
        nxt_y_idx = 0;
    end
    else nxt_y_idx = y_idx; 
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        k_cnt <= 0;
    end
    else if (c_state == WAIT_DATA) begin
        k_cnt <= 0;
    end
    else if (x_idx == 4 && y_idx == 4) begin
        k_cnt <= k_cnt+1;
    end
end

always @(*) begin
    in[0] = matrix_buffer[ y_idx ][ x_idx ];     
    in[1] = matrix_buffer[ y_idx ][ x_idx+1 ];  
    in[2] = matrix_buffer[ y_idx+1 ][ x_idx ];
    in[3] = matrix_buffer[ y_idx+1 ][ x_idx+1 ];  
end

always @(*) begin
	w[0] = kernel_buffer[k_cnt][0];   w[1] = kernel_buffer[k_cnt][1];  
    w[2] = kernel_buffer[k_cnt][2];   w[3] = kernel_buffer[k_cnt][3];  
end

always @(*) begin
    for ( i  =  0 ; i < 4 ; i = i+1 ) begin
        out_n[i] = in[i] * w[i];
    end  
end

// always @(posedge clk) begin
//     for (i = 0 ; i < 4; i=i+1) begin
//         out[i] <= out_n[i];
//     end         
// end

always @(*) begin
    conv_out = out_n[0] + out_n[1] + out_n[2] + out_n[3];
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt <= 0;
    end else cnt <= nxt_cnt; 
end

always @(*) begin
    if (c_state == CONV || c_state == OUT) begin
        nxt_cnt = cnt + 1;
    end 
    
    else if (c_state == WAIT_DATA) begin
        nxt_cnt = 0;
    end
    else nxt_cnt = cnt; 
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for ( j = 0 ; j < 150 ; j = j + 1) begin
            f_buffer[j] <= 0;
        end
    end 
    else if (c_state == CONV || c_state == OUT && cnt <150) begin
        f_buffer[cnt] <= conv_out;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        o_cnt <= 0;
    end 
    else o_cnt <= nxt_o_cnt; 
end
reg  fifo_full_d1;
always @(posedge clk) begin
    fifo_full_d1 <= fifo_full;
end

always @(*) begin
    if (out_valid && !fifo_full) begin
        nxt_o_cnt = o_cnt + 1;
    end 
    else  if (out_valid && fifo_full && !fifo_full_d1) begin
        nxt_o_cnt = o_cnt + 1;
    end 
    else if (o_cnt == 150 ) begin
        nxt_o_cnt = 0;
    end
    else if (c_state == WAIT_DATA ) begin
        nxt_o_cnt = 0;
    end
    else nxt_o_cnt = o_cnt; 
end

//================================================================
// Output
//================================================================

always @(*) begin
    out_data= 0;
    if (out_valid ) begin
        out_data = f_buffer[o_cnt];
    end 
end

always @(*) begin
    out_valid = 0;
    if (!rst_n) begin
        out_valid = 0;
    end
    else if ((c_state == OUT || c_state == REST) && !fifo_full && o_cnt < 150) begin
        out_valid = 1;
    end
    else out_valid = 0;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        busy <= 0;
    end else busy <= 0;
end

endmodule
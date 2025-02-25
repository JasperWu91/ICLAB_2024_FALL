module ISP(
    // Input Signals
    input clk,
    input rst_n,
    input in_valid,
    input [3:0] in_pic_no,
    input [1:0] in_mode,
    input [1:0] in_ratio_mode,

    // Output Signals
    output reg out_valid,
    output reg[7:0] out_data,
    
    // DRAM Signals
    // axi write address channel
    // src master
    output [3:0]  awid_s_inf, //4'd0
    output reg [31:0] awaddr_s_inf,
    output [2:0]  awsize_s_inf, //3'b100
    output [1:0]  awburst_s_inf,// 2'b01
    output [7:0]  awlen_s_inf, // burst length : 
    output  reg      awvalid_s_inf,
    // src slave
    input         awready_s_inf,
    // -----------------------------
  
    // axi write data channel 
    // src master
    output reg [127:0] wdata_s_inf,
    output         wlast_s_inf,
    output reg        wvalid_s_inf,
    // src slave
    input          wready_s_inf,
  
    // axi write response channel 
    // src slave
    input [3:0]    bid_s_inf,//4'd0
    input [1:0]    bresp_s_inf,
    input          bvalid_s_inf,
    // src master 
    output         bready_s_inf,
    // -----------------------------
  
    // axi read address channel 
    // src master
    output [3:0]   arid_s_inf,
    output reg [31:0]  araddr_s_inf, 
    output [7:0]   arlen_s_inf,
    output [2:0]   arsize_s_inf, //3'b100
    output [1:0]   arburst_s_inf, // 2'b01
    output  reg       arvalid_s_inf,
    // src slave
    input          arready_s_inf,
    // -----------------------------
  
    // axi read data channel 
    // slave
    input [3:0]    rid_s_inf,
    input [127:0]  rdata_s_inf,
    input [1:0]    rresp_s_inf,
    input          rlast_s_inf,
    input          rvalid_s_inf,
    // master
    output         rready_s_inf // 1 master ready
    
);


//========================================
// REG & WIRE
//========================================
reg [3:0] c_state, n_state;
reg [3:0] pic_no_reg;
reg [1:0] ratio_mode_reg;
reg[2:0] rest_cnt,rest_cnt_n;
reg [8:0] dram_data_cnt, dram_data_cnt_1;
reg [8:0 ]dram_w_data_cnt, dram_w_data_cnt_1,dram_w_data_cnt_2,dram_w_data_cnt_3;
reg [1:0] dram_type_cnt, dram_type_cnt_1;

reg [7:0] img_buffer [0:5][0:5];
reg [7:0] img_buffer_c [0:5][0:5];
reg [1:0] mode_reg;

reg [8:0] add_in_1 [0:5];
reg [8:0] add_in_2 [0:5];
reg [8:0] add_out [0:5];
reg [8:0] add_out_c [0:5];


reg [10:0] img_temp_0 [0:1];
reg [10:0] img_temp_1 [0:3];
reg [10:0] img_temp_2 [0:5];

reg [10:0] img_temp_a0 [0:1];
reg [10:0] img_temp_a1 [0:3];
reg [11:0] img_temp_a2 [0:5];


reg [10:0] acc_in_1 [0:5];
reg [10:0] acc_in_2 [0:5];
reg [13:0] acc_out [0:5];

reg [13:0] contrast_acc [0:2];
reg [13:0] contrast [0:2];
reg [13:0] contrast_acc_c [0:2];
reg [13:0] contrast_c [0:2];

reg [7:0] dram_data_buffer[0:15];
reg [7:0] dram_data_buffer_c[0:15];
reg [8:0] w_data_expose_b[0:15];
reg [7:0] w_data_expose_r[0:15];
reg [7:0] w_data_expose[0:15];
reg [127:0] w_data_in_0;
reg [127:0] w_data_in_1;
reg [127:0] w_data_in_2;
reg [8:0] add_e_in_1 [0:7];
reg [8:0] add_e_in_2 [0:7];
reg [8:0] add_e_out [0:7];

reg [7:0] s_addr, s_addr_temp;
reg [7:0] s_addr_delay_1, s_addr_delay_2;
reg [127:0] d_data_in;
reg [127:0] s_data_out;
reg [127:0] s_data_out_w;
reg [7:0] s_data_out_check [0:15];

reg [7:0] focus_table [0:15];
reg focus_flag [0:15];
reg [7:0] avg_table [0:15];
reg avg_flag [0:15];
reg [7:0] zero_table [0:15];
reg zero_flag [0:15];
reg [7:0] focus_result;
reg s_web;
reg find_ans;
reg find_avg;
reg find_zero;
reg zero_detect;

reg [7:0] max_one, min_one;
reg [7:0] max_one_reg, min_one_reg;
reg [9:0] max_sum, min_sum;
reg [9:0] max_sum_c, min_sum_c;
reg [9:0] max_result, min_result;
reg [9:0] avg_result_c, avg_result;
reg [7:0] avg_in [0:15];
reg cmp_start_flag,cmp_start_flag_reg;

//========================================
// PARAMETER
//========================================

parameter  IDLE     = 0,
           FIND     = 1,
           GET_DATA = 2,
           OUT_F    = 3,
           REST     = 4,
           OUT_D    = 5,
           OUT_E    = 6,
           OUT      = 7,
           OUT_AVG  = 8,
           REST_AVG = 9,
           OUT_A  = 10;
integer i ,j;
//========================================
// DESIGN
//========================================

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        c_state <= IDLE;
    end else c_state <= n_state;
end

always @(*) begin
    n_state = c_state;
    case (c_state)
        IDLE : begin
            if (in_valid) begin
                n_state = FIND;
            end
        end 
        FIND : begin
            if (find_ans) begin
                n_state = OUT_D;
            end 
            else if (find_zero) begin
                n_state = OUT_E;
            end
            else if (find_avg) begin
                n_state = OUT_A;
            end
            else n_state = GET_DATA;
        end
        GET_DATA : begin
            // if(dram_data_cnt_1 == 63 && dram_type_cnt_1 == 2 && (mode_reg==1)) begin
            //     n_state = REST;
            // end
            // else if (dram_data_cnt_1 == 63 && dram_type_cnt_1 == 2 && (mode_reg==2)) begin
            //     n_state = REST_AVG;
            // end
            // else if (dram_data_cnt_1 == 63 && dram_type_cnt_1 == 2) begin
            //     n_state = OUT_F;
            // end
            if(dram_data_cnt_1 == 63 && dram_type_cnt_1 == 2) begin
                n_state = REST;
            end
        end   
        OUT_F: begin
            n_state = IDLE;
        end  
        REST: begin
            // n_state = OUT;
            if (rest_cnt == 6) begin
                if (mode_reg==1) begin
                    n_state = OUT;
                end
                else if (mode_reg==2) begin
                     n_state = OUT_AVG;
                end
                else n_state = OUT_F;
            end
        end 
        REST_AVG: begin
            n_state = OUT_AVG;
        end 
        OUT: begin
            n_state = IDLE;
        end  
        OUT_D: begin
            n_state = IDLE;
        end  
        OUT_A: begin
            n_state = IDLE;
        end  
        OUT_AVG: begin
            n_state = IDLE;
        end  
        OUT_E: begin
            n_state = IDLE;
        end        
        default:  n_state = c_state;
    endcase
end

always @(posedge clk ) begin
    if (in_valid) begin
        pic_no_reg <= in_pic_no;
    end
end
always @(posedge clk ) begin
    if (in_valid) begin
        ratio_mode_reg <= in_ratio_mode;
    end
end
always @(posedge clk ) begin
    if (in_valid) begin
        mode_reg <= in_mode;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dram_data_cnt <= 0;
    end 
    else if (dram_data_cnt == 63) begin
        dram_data_cnt <= 0;
    end 
    else if (rvalid_s_inf) begin
        dram_data_cnt <= dram_data_cnt + 1;
    end 
    else if (c_state != GET_DATA) begin
        dram_data_cnt <= 0;
    end
end

always @(posedge clk ) begin
    dram_data_cnt_1 <= dram_data_cnt;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dram_type_cnt <= 0;
    end else if (dram_data_cnt == 63 || dram_data_cnt == 127) begin
        dram_type_cnt <= dram_type_cnt + 1;
    end else if (c_state != GET_DATA) begin
        dram_type_cnt <= 0;
    end
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rest_cnt <= 0;
    end
    else begin
        rest_cnt <= rest_cnt_n;
    end
end

always @(*) begin
    rest_cnt_n = rest_cnt;
    if (c_state == REST) begin
        rest_cnt_n = rest_cnt + 1 ;
    end else if (c_state !=REST ) begin
        rest_cnt_n = 0;
    end
end

always @(posedge clk ) begin
    dram_type_cnt_1 <= dram_type_cnt;
end

wire [6:0] img_idx ;
assign img_idx  = dram_data_cnt_1 >> 1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for ( i = 0 ; i < 16 ; i = i+1 ) begin
            dram_data_buffer[i] <= 0;
        end
    end
    else if (c_state == GET_DATA) begin
        for ( i = 0 ; i < 16 ; i = i+1 ) begin
            dram_data_buffer[i] <= dram_data_buffer_c[i];
        end
    end

end

always @(*) begin
    for ( i = 0 ; i < 16 ; i = i+1 ) begin
        dram_data_buffer_c[i] = 0;
    end
    if (c_state == GET_DATA) begin
        dram_data_buffer_c[15] = rdata_s_inf[127:120];
        dram_data_buffer_c[14] = rdata_s_inf[119:112];
        dram_data_buffer_c[13] = rdata_s_inf[111:104];
        dram_data_buffer_c[12] = rdata_s_inf[103:96];
        dram_data_buffer_c[11] = rdata_s_inf[95:88];
        dram_data_buffer_c[10] = rdata_s_inf[87:80];
        dram_data_buffer_c[9]  = rdata_s_inf[79:72];
        dram_data_buffer_c[8]  = rdata_s_inf[71:64];
        dram_data_buffer_c[7]  = rdata_s_inf[63:56];
        dram_data_buffer_c[6]  = rdata_s_inf[55:48];
        dram_data_buffer_c[5]  = rdata_s_inf[47:40];
        dram_data_buffer_c[4]  = rdata_s_inf[39:32];
        dram_data_buffer_c[3]  = rdata_s_inf[31:24];
        dram_data_buffer_c[2]  = rdata_s_inf[23:16];
        dram_data_buffer_c[1]  = rdata_s_inf[15:8];
        dram_data_buffer_c[0]  = rdata_s_inf[7:0];
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0 ; i < 6 ; i = i+1) begin
            for (j = 0 ; j < 6  ;j = j+1) begin
                img_buffer[j][i] <= 0;
            end
        end         
    end
    else begin
        for (i = 0 ; i < 6 ; i = i+1) begin
            for (j = 0 ; j < 6  ;j = j+1) begin
                img_buffer[j][i] <= img_buffer_c[j][i];
            end
        end 
    end
end

always @(*) begin
    for (i = 0 ; i < 6 ; i = i+1) begin
        for (j = 0 ; j < 6  ;j = j+1) begin
            img_buffer_c[j][i] = img_buffer[j][i];
        end
    end

    if (img_idx > 12 && img_idx < 19 && c_state == GET_DATA) begin
        if (!dram_data_cnt_1[0]) begin
            img_buffer_c[img_idx- 13][2] = add_out[2] ; 
            img_buffer_c[img_idx- 13][1] = add_out[1] ;
            img_buffer_c[img_idx- 13][0] = add_out[0] ;
        end
        else begin
            img_buffer_c[img_idx- 13][5] = add_out[5] ;
            img_buffer_c[img_idx- 13][4] = add_out[4] ;
            img_buffer_c[img_idx- 13][3] = add_out[3] ; 
        end
    end
    else if (c_state == IDLE) begin
        for (i = 0 ; i < 6 ; i = i+1) begin
            for (j = 0 ; j < 6  ;j = j+1) begin
                img_buffer_c[j][i] = 0;
            end
        end
    end
end

wire [1:0] img_w;
assign img_w = (dram_type_cnt_1 == 0 || dram_type_cnt_1 == 2) ? 2 : 1;

always @(*) begin
    for ( i = 0 ; i < 6 ; i = i + 1 ) begin
        add_out[i] = add_in_1[i] + add_in_2[i] ;
    end
end

always @(*) begin
    for ( i = 0 ; i < 6 ; i = i + 1 ) begin
        add_in_1[i] = 0; add_in_2[i] = 0;
    end    
    if (dram_data_cnt_1 > 37 && dram_type_cnt_1 == 2) begin
        case (dram_data_cnt_1)
            38:begin
                add_in_1[0] = ~img_buffer[0][0] + 1'b1; add_in_2[0] = img_buffer[1][0];
                add_in_1[1] = ~img_buffer[0][1] + 1'b1; add_in_2[1] = img_buffer[1][1];
                add_in_1[2] = ~img_buffer[0][2] + 1'b1; add_in_2[2] = img_buffer[1][2];
                add_in_1[3] = ~img_buffer[0][3] + 1'b1; add_in_2[3] = img_buffer[1][3];
                add_in_1[4] = ~img_buffer[0][4] + 1'b1; add_in_2[4] = img_buffer[1][4];
                add_in_1[5] = ~img_buffer[0][5] + 1'b1; add_in_2[5] = img_buffer[1][5];
            end

            39:begin
                add_in_1[0] = ~img_buffer[1][0] + 1'b1; add_in_2[0] = img_buffer[2][0];
                add_in_1[1] = ~img_buffer[1][1] + 1'b1; add_in_2[1] = img_buffer[2][1];
                add_in_1[2] = ~img_buffer[1][2] + 1'b1; add_in_2[2] = img_buffer[2][2];
                add_in_1[3] = ~img_buffer[1][3] + 1'b1; add_in_2[3] = img_buffer[2][3];
                add_in_1[4] = ~img_buffer[1][4] + 1'b1; add_in_2[4] = img_buffer[2][4];
                add_in_1[5] = ~img_buffer[1][5] + 1'b1; add_in_2[5] = img_buffer[2][5];
            end

            40:begin
                add_in_1[0] = ~img_buffer[2][0] + 1'b1; add_in_2[0] = img_buffer[3][0];
                add_in_1[1] = ~img_buffer[2][1] + 1'b1; add_in_2[1] = img_buffer[3][1];
                add_in_1[2] = ~img_buffer[2][2] + 1'b1; add_in_2[2] = img_buffer[3][2];
                add_in_1[3] = ~img_buffer[2][3] + 1'b1; add_in_2[3] = img_buffer[3][3];
                add_in_1[4] = ~img_buffer[2][4] + 1'b1; add_in_2[4] = img_buffer[3][4];
                add_in_1[5] = ~img_buffer[2][5] + 1'b1; add_in_2[5] = img_buffer[3][5];
            end

            41:begin
                add_in_1[0] = ~img_buffer[3][0] + 1'b1; add_in_2[0] = img_buffer[4][0];
                add_in_1[1] = ~img_buffer[3][1] + 1'b1; add_in_2[1] = img_buffer[4][1];
                add_in_1[2] = ~img_buffer[3][2] + 1'b1; add_in_2[2] = img_buffer[4][2];
                add_in_1[3] = ~img_buffer[3][3] + 1'b1; add_in_2[3] = img_buffer[4][3];
                add_in_1[4] = ~img_buffer[3][4] + 1'b1; add_in_2[4] = img_buffer[4][4];
                add_in_1[5] = ~img_buffer[3][5] + 1'b1; add_in_2[5] = img_buffer[4][5];
            end

            42:begin
                add_in_1[0] = ~img_buffer[4][0] + 1'b1; add_in_2[0] = img_buffer[5][0];
                add_in_1[1] = ~img_buffer[4][1] + 1'b1; add_in_2[1] = img_buffer[5][1];
                add_in_1[2] = ~img_buffer[4][2] + 1'b1; add_in_2[2] = img_buffer[5][2];
                add_in_1[3] = ~img_buffer[4][3] + 1'b1; add_in_2[3] = img_buffer[5][3];
                add_in_1[4] = ~img_buffer[4][4] + 1'b1; add_in_2[4] = img_buffer[5][4];
                add_in_1[5] = ~img_buffer[4][5] + 1'b1; add_in_2[5] = img_buffer[5][5];
            end
            43:begin
                add_in_1[0] = ~img_buffer[0][0]+ 1'b1; add_in_2[0] = img_buffer[0][1];
                add_in_1[1] = ~img_buffer[1][0]+ 1'b1; add_in_2[1] = img_buffer[1][1];
                add_in_1[2] = ~img_buffer[2][0]+ 1'b1; add_in_2[2] = img_buffer[2][1];
                add_in_1[3] = ~img_buffer[3][0]+ 1'b1; add_in_2[3] = img_buffer[3][1];
                add_in_1[4] = ~img_buffer[4][0]+ 1'b1; add_in_2[4] = img_buffer[4][1];
                add_in_1[5] = ~img_buffer[5][0]+ 1'b1; add_in_2[5] = img_buffer[5][1];
            end

            44:begin
                add_in_1[0] = ~img_buffer[0][1]+ 1'b1; add_in_2[0] = img_buffer[0][2];
                add_in_1[1] = ~img_buffer[1][1]+ 1'b1; add_in_2[1] = img_buffer[1][2];
                add_in_1[2] = ~img_buffer[2][1]+ 1'b1; add_in_2[2] = img_buffer[2][2];
                add_in_1[3] = ~img_buffer[3][1]+ 1'b1; add_in_2[3] = img_buffer[3][2];
                add_in_1[4] = ~img_buffer[4][1]+ 1'b1; add_in_2[4] = img_buffer[4][2];
                add_in_1[5] = ~img_buffer[5][1]+ 1'b1; add_in_2[5] = img_buffer[5][2];
            end

            45:begin
                add_in_1[0] = ~img_buffer[0][2]+ 1'b1; add_in_2[0] = img_buffer[0][3];
                add_in_1[1] = ~img_buffer[1][2]+ 1'b1; add_in_2[1] = img_buffer[1][3];
                add_in_1[2] = ~img_buffer[2][2]+ 1'b1; add_in_2[2] = img_buffer[2][3];
                add_in_1[3] = ~img_buffer[3][2]+ 1'b1; add_in_2[3] = img_buffer[3][3];
                add_in_1[4] = ~img_buffer[4][2]+ 1'b1; add_in_2[4] = img_buffer[4][3];
                add_in_1[5] = ~img_buffer[5][2]+ 1'b1; add_in_2[5] = img_buffer[5][3];
            end

            46:begin
                add_in_1[0] = ~img_buffer[0][3]+ 1'b1; add_in_2[0] = img_buffer[0][4];
                add_in_1[1] = ~img_buffer[1][3]+ 1'b1; add_in_2[1] = img_buffer[1][4];
                add_in_1[2] = ~img_buffer[2][3]+ 1'b1; add_in_2[2] = img_buffer[2][4];
                add_in_1[3] = ~img_buffer[3][3]+ 1'b1; add_in_2[3] = img_buffer[3][4];
                add_in_1[4] = ~img_buffer[4][3]+ 1'b1; add_in_2[4] = img_buffer[4][4];
                add_in_1[5] = ~img_buffer[5][3]+ 1'b1; add_in_2[5] = img_buffer[5][4];
            end

            47:begin
                add_in_1[0] = ~img_buffer[0][4]+ 1'b1; add_in_2[0] = img_buffer[0][5];
                add_in_1[1] = ~img_buffer[1][4]+ 1'b1; add_in_2[1] = img_buffer[1][5];
                add_in_1[2] = ~img_buffer[2][4]+ 1'b1; add_in_2[2] = img_buffer[2][5];
                add_in_1[3] = ~img_buffer[3][4]+ 1'b1; add_in_2[3] = img_buffer[3][5];
                add_in_1[4] = ~img_buffer[4][4]+ 1'b1; add_in_2[4] = img_buffer[4][5];
                add_in_1[5] = ~img_buffer[5][4]+ 1'b1; add_in_2[5] = img_buffer[5][5];
            end
        endcase        
    end
    else begin
        case (dram_data_cnt_1)
            26, 28, 30, 32, 34, 36:begin
                add_in_1[0] = img_buffer[img_idx- 13][0]; add_in_2[0] = w_data_expose_r[13]; 
                add_in_1[1] = img_buffer[img_idx- 13][1]; add_in_2[1] = w_data_expose_r[14]; 
                add_in_1[2] = img_buffer[img_idx- 13][2]; add_in_2[2] = w_data_expose_r[15]; 
            end 
            27, 29, 31, 33, 35, 37:begin
                add_in_1[3] = img_buffer[img_idx- 13][3]; add_in_2[3] = w_data_expose_r[0];
                add_in_1[4] = img_buffer[img_idx- 13][4]; add_in_2[4] = w_data_expose_r[1]; 
                add_in_1[5] = img_buffer[img_idx- 13][5]; add_in_2[5] = w_data_expose_r[2];
            end
        endcase
    end
end

reg [8:0] add_temp[0:5];
reg [8:0] add_temp_c[0:5];

always @(*) begin
    for (i = 0; i < 6; i = i + 1) begin
        add_temp_c[i] = 0;
    end 
    if (dram_data_cnt_1 > 37 && dram_type_cnt_1 == 2) begin
        for (i = 0; i < 6; i = i + 1) begin
            add_temp_c[i] = (add_out[i][8]) ? (~add_out[i] + 1'b1) : add_out[i];
        end       
    end 
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 6; i = i + 1) begin
            add_temp[i] <= 0;
        end         
    end
    else  begin
        for (i = 0; i < 6; i = i + 1) begin
             add_temp[i] <= add_temp_c[i];
        end       
    end 
end



always @(*) begin
    contrast_acc_c[0] = 0 ;
    if (dram_data_cnt_1 > 38 && dram_type_cnt_1 == 2) begin
        contrast_acc_c[0] = (add_temp[0] + add_temp[1] + add_temp[2] + add_temp[3] + add_temp[4] + add_temp[5] ) ;        
    end
end

always @(*) begin
    contrast_acc_c[1] = 0 ;
    if (((dram_data_cnt_1 < 43 && dram_data_cnt_1 > 39) || (dram_data_cnt_1 < 48 && dram_data_cnt_1 > 44) )&& dram_type_cnt_1 == 2) begin
        contrast_acc_c[1] = ( add_temp[1] + add_temp[2] + add_temp[3] + add_temp[4]  ) ;        
    end
end

always @(*) begin
    contrast_acc_c[2] = 0 ;
    if (((dram_data_cnt_1 == 41) || (dram_data_cnt_1 == 46) )&& dram_type_cnt_1 == 2) begin
        contrast_acc_c[2] = (  add_temp[2] + add_temp[3]) ;        
    end
end


always @(posedge clk) begin
    contrast_acc[2] <= contrast_acc_c[2] ;
    contrast_acc[1] <= contrast_acc_c[1] ;
    contrast_acc[0] <= contrast_acc_c[0] ;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        contrast[0] <= 0;
    end
    else if (c_state == IDLE) begin
        contrast[0] <= 0;
    end
    else if (dram_data_cnt_1 > 39 &&  dram_data_cnt_1 < 50  &&dram_type_cnt_1 == 2) begin
        contrast[0] <= contrast[0] + contrast_acc[0] ;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        contrast[1] <= 0;
    end
    else if (c_state == IDLE) begin
        contrast[1] <= 0;
    end
    else if (((dram_data_cnt_1 < 44 && dram_data_cnt_1 > 40) || (dram_data_cnt_1 < 49 && dram_data_cnt_1 > 45) )&& dram_type_cnt_1 == 2) begin
        contrast[1] <= contrast[1] + contrast_acc[1] ;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        contrast[2] <= 0;
    end
    else if (c_state == IDLE) begin
        contrast[2] <= 0;
    end
    else if (((dram_data_cnt_1 == 42) || (dram_data_cnt_1 == 47) )&& dram_type_cnt_1 == 2) begin
        contrast[2] <= contrast[2] + contrast_acc[2] ;
    end
end

reg [8:0] d_contrast[0:2];
reg [8:0] temp_max;
always @(posedge clk) begin
    d_contrast[0] <= (contrast[0] >> 2) / 9;
    d_contrast[1] <= contrast[1] >> 4;
    d_contrast[2] <= contrast[2] >> 2;
end

//========================================
// AUTO EXPOSURE
//========================================

reg [1:0] e_ratio;

always @(*) begin
    e_ratio = 0;
    case (ratio_mode_reg)
        0:  e_ratio = 2;
        1:  e_ratio = 1;
        2:  e_ratio = 0;
    endcase
end

always @(*) begin
    if (mode_reg == 1) begin
        for (i = 0 ; i < 16 ; i = i+1  ) begin
            w_data_expose_b[i] = (ratio_mode_reg == 3) ? dram_data_buffer[i] << 1 : dram_data_buffer[i] >> e_ratio;
        end        
    end
    else begin
        for (i = 0 ; i < 16 ; i = i+1  ) begin
            w_data_expose_b[i] = dram_data_buffer[i] ;
        end 
    end
end

always @(*) begin
    for (i = 0 ; i < 16 ; i = i+1  ) begin
        w_data_expose[i] = (!w_data_expose_b[i][8]) ? w_data_expose_b[i] : 255;
    end
end

reg [10:0] add_e_out_2 [0:3];
reg [8:0] add_e_in_2_1 [0:3];
reg [8:0] add_e_in_2_2 [0:3];
reg [8:0] add_e_in_2_1_n [0:3];
reg [8:0] add_e_in_2_2_n [0:3];

reg [12:0] add_e_out_3,  add_e_out_3_n;
reg [23:0] exposed_results;
reg [23:0] exposed_results_n;

always @(*) begin
    case (dram_type_cnt_1)
         0 : begin
            for ( i = 0 ; i < 16 ; i = i + 1 ) begin
                w_data_expose_r[i] = w_data_expose[i] >> 2 ;
            end
         end
         1 : begin
            for ( i = 0 ; i < 16 ; i = i + 1 ) begin
                w_data_expose_r[i] = w_data_expose[i] >> 1 ;
            end         
         end
         2: begin
            for ( i = 0 ; i < 16 ; i = i + 1 ) begin
                w_data_expose_r[i] = w_data_expose[i] >> 2 ;
            end           
         end
        default:  begin
            for ( i = 0 ; i < 16 ; i = i + 1 ) begin
                w_data_expose_r[i] = w_data_expose[i] >> 1 ;
            end 
        end
    endcase
end

always @(*) begin
    for ( i = 0 ; i < 8 ; i = i + 1 ) begin
        add_e_out[i] = add_e_in_1[i] + add_e_in_2[i] ;
    end
end

always @(*) begin
    add_e_in_1[0] = w_data_expose_r[0] ; add_e_in_2[0] = w_data_expose_r[8] ; 
    add_e_in_1[1] = w_data_expose_r[1] ; add_e_in_2[1] = w_data_expose_r[9] ; 
    add_e_in_1[2] = w_data_expose_r[2] ; add_e_in_2[2] = w_data_expose_r[10] ; 
    add_e_in_1[3] = w_data_expose_r[3] ; add_e_in_2[3] = w_data_expose_r[11] ; 
    add_e_in_1[4] = w_data_expose_r[4] ; add_e_in_2[4] = w_data_expose_r[12] ;
    add_e_in_1[5] = w_data_expose_r[5] ; add_e_in_2[5] = w_data_expose_r[13] ;
    add_e_in_1[6] = w_data_expose_r[6] ; add_e_in_2[6] = w_data_expose_r[14] ;
    add_e_in_1[7] = w_data_expose_r[7] ; add_e_in_2[7] = w_data_expose_r[15] ;
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for ( i = 0 ; i < 4 ; i = i + 1 ) begin
            add_e_in_2_1[i] <= 0;
            add_e_in_2_2[i] <= 0;
        end           
    end
    else begin
        add_e_in_2_1[0] <= add_e_out[0];  add_e_in_2_2[0] <= add_e_out[4];
        add_e_in_2_1[1] <= add_e_out[1];  add_e_in_2_2[1] <= add_e_out[5];
        add_e_in_2_1[2] <= add_e_out[2];  add_e_in_2_2[2] <= add_e_out[6];
        add_e_in_2_1[3] <= add_e_out[3];  add_e_in_2_2[3] <= add_e_out[7];
    end
end

always @(*) begin
    for ( i = 0 ; i < 4 ; i = i + 1 ) begin
        add_e_out_2[i] = add_e_in_2_1[i] + add_e_in_2_2[i] ;
    end   
end

always @(*) begin
    add_e_out_3 = add_e_out_2[0] + add_e_out_2[1]  + add_e_out_2[2] + add_e_out_2[3];
end



always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        exposed_results <= 0;           
    end
    else if(c_state == IDLE )begin
        exposed_results <=  0;
    end
    else if((c_state == GET_DATA || c_state == REST) && (mode_reg == 1) &&(dram_data_cnt > 0 || dram_type_cnt > 0) )begin
        exposed_results <=  exposed_results  + add_e_out_3;
    end
end

always @(*) begin
    exposed_results_n = exposed_results >> 10;
end

always @(*) begin
    focus_result = 0;
    if (dram_data_cnt_1 == 51 && dram_type_cnt_1 == 2 ) begin
        if (d_contrast[2] >= d_contrast[1] && d_contrast[2] >= d_contrast[0]) begin
            focus_result = 0; 
        end else if (d_contrast[1] >= d_contrast[2] && d_contrast[1] >= d_contrast[0]) begin
            focus_result = 1;  
        end else begin
            focus_result = 2;
        end
    end    
end

always @(*) begin
    find_ans = 0;
    if (c_state == FIND && (mode_reg == 0)) begin
        find_ans = focus_flag[pic_no_reg];
    end
end
// TP BE DEBUG
always @(*) begin
    find_zero = 0;
    if (c_state == FIND && (mode_reg == 1)) begin
        find_zero = zero_flag[pic_no_reg];
    end
end

always @(*) begin
    find_avg = 0;
    if (c_state == FIND && (mode_reg == 2)) begin
        find_avg = avg_flag[pic_no_reg];
    end
end

wire w_data_expose_r_or;

always @(posedge clk) begin
    if (c_state == IDLE) begin
        zero_detect <= 1;
    end
    else if(c_state == GET_DATA && (mode_reg == 1)) begin
        if (w_data_expose_r_or) begin
            zero_detect <= 0;
        end
    end
    else begin
        zero_detect <= zero_detect;
    end
end


assign w_data_expose_r_or = w_data_expose[0] || w_data_expose[1] || w_data_expose[2] || 
                            w_data_expose[3] || w_data_expose[4] || w_data_expose[5] || 
                            w_data_expose[6] || w_data_expose[7] || w_data_expose[8] || 
                            w_data_expose[9] || w_data_expose[10] || w_data_expose[11] || 
                            w_data_expose[12] || w_data_expose[13] || w_data_expose[14] || 
                            w_data_expose[15];


always @(posedge clk or negedge rst_n) begin
     if (!rst_n) begin
        for (i = 0 ; i < 16 ; i=i+1 ) begin
            focus_table[i] <= 0;
        end      
    end
    else if(dram_data_cnt_1 == 51 && dram_type_cnt_1 == 2 )begin
        focus_table[pic_no_reg] <= focus_result;
    end   
end

reg avg_table_flag;


always @(posedge clk or negedge rst_n) begin
     if (!rst_n) begin
        for (i = 0 ; i < 16 ; i=i+1 ) begin
            zero_flag[i] <= 0;
        end      
    end
    else if(c_state == OUT )begin
        if (zero_detect) begin
            zero_flag[pic_no_reg]<= 1;
        end
    end   
end


always @(posedge clk or negedge rst_n) begin
     if (!rst_n) begin
        for (i = 0 ; i < 16 ; i=i+1 ) begin
            focus_flag[i] <= 0;
        end      
    end
    else if(c_state == OUT || c_state == OUT_F || c_state == OUT_AVG)begin
        focus_flag[pic_no_reg] <= 1;
    end   
end

//========================================
// Average of Min and Max 
//========================================


always @(*) begin
    avg_in[0] = w_data_expose[0] ; avg_in[8] = w_data_expose[8] ; 
    avg_in[1] = w_data_expose[1] ; avg_in[9] = w_data_expose[9] ; 
    avg_in[2] = w_data_expose[2] ; avg_in[10] = w_data_expose[10] ; 
    avg_in[3] = w_data_expose[3] ; avg_in[11] = w_data_expose[11] ; 
    avg_in[4] = w_data_expose[4] ; avg_in[12] = w_data_expose[12] ;
    avg_in[5] = w_data_expose[5] ; avg_in[13] = w_data_expose[13] ;
    avg_in[6] = w_data_expose[6] ; avg_in[14] = w_data_expose[14] ;
    avg_in[7] = w_data_expose[7] ; avg_in[15] = w_data_expose[15] ;
end
// TO BE DEBUG
find_MAX_MIN module_avg (
    .clk(clk),
    .in0(avg_in[0]), 
    .in1(avg_in[1]), 
    .in2(avg_in[2]), 
    .in3(avg_in[3]), 
    .in4(avg_in[4]), 
    .in5(avg_in[5]), 
    .in6(avg_in[6]), 
    .in7(avg_in[7]), 
    .in8(avg_in[8]), 
    .in9(avg_in[9]), 
    .in10(avg_in[10]), 
    .in11(avg_in[11]), 
    .in12(avg_in[12]), 
    .in13(avg_in[13]), 
    .in14(avg_in[14]), 
    .in15(avg_in[15]), 
    .max_one(max_one), 
    .min_one(min_one)
);

reg [7:0] max_one_result, min_one_result;
reg [7:0] cmp_cnt,cmp_cnt_n;
reg cmp_start_flag_1,cmp_start_flag_2;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cmp_cnt <= 0;
    end else cmp_cnt <= cmp_cnt_n;
end
always @(*) begin
    cmp_cnt_n = cmp_cnt;
    if (cmp_cnt == 63) begin
        cmp_cnt_n = 0;
    end
    else if (cmp_start_flag_2) begin
        cmp_cnt_n = cmp_cnt + 1;
    end else cmp_cnt_n = cmp_cnt;
end

always @(*) begin
    if (cmp_start_flag_2 && (cmp_cnt == 0)) begin
        max_one_result = max_one ;
    end
    else max_one_result = (max_one > max_one_reg)? max_one: max_one_reg;
end
always @(*) begin
    if (cmp_start_flag_2 && (cmp_cnt == 0)) begin
        min_one_result = min_one ;
    end
    else min_one_result = (min_one < min_one_reg)? min_one: min_one_reg;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        max_one_reg <= 0;
        min_one_reg <= 255;
    end
    else if (c_state == IDLE) begin
        max_one_reg <= 0;
        min_one_reg <= 255;
    end   
    else if(cmp_start_flag_2)begin
        max_one_reg <= max_one_result;
        min_one_reg <= min_one_result;
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cmp_start_flag_1 <= 0 ;
        cmp_start_flag_2 <= 0;
    end
    else begin
        cmp_start_flag_1 <=  cmp_start_flag_reg ;
        cmp_start_flag_2 <= cmp_start_flag_1; 
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cmp_start_flag_reg <= 0;
    end
    else cmp_start_flag_reg <= cmp_start_flag;
end
always @(*) begin
    cmp_start_flag = cmp_start_flag_reg;
    if (c_state == GET_DATA && (dram_data_cnt> 0))begin
        cmp_start_flag = 1;
    end
    else if (c_state != GET_DATA ) begin
        cmp_start_flag = 0;
    end
    else begin
        cmp_start_flag = cmp_start_flag_reg;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        max_sum <= 0;
        min_sum <= 0;
    end
    else if (c_state == IDLE) begin
        max_sum <= 0;
        min_sum <= 0;
    end
    else begin
        max_sum <= max_sum_c;
        min_sum <= min_sum_c;
    end
end

reg add_reg,add_reg_1;
always @(posedge clk) begin
    if (cmp_start_flag_2 && (cmp_cnt == 63)) begin
        add_reg <= 1;
    end else add_reg <= 0;
end


always @(*) begin
    max_sum_c = max_sum;
    min_sum_c = min_sum;

    if (add_reg) begin
        // max_sum_c = max_sum + max_one_result; 
        // min_sum_c = min_sum + min_one_result; 
        max_sum_c = max_sum + max_one_reg;
        min_sum_c = min_sum + min_one_reg;  // for min_sum
    end
    else if (c_state == IDLE) begin
        max_sum_c = 0; 
        min_sum_c = 0;         
    end
end
always @(*) begin
    max_result = max_sum / 3;
    min_result = min_sum / 3;
end

always @(*) begin
    avg_result_c = (max_result + min_result) ; 
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        avg_result <= 0;
    end
    else begin
        avg_result <= avg_result_c;
    end
end

always @(posedge clk) begin
    if((dram_data_cnt_1 == 0 && dram_type_cnt_1 == 3) )begin
        avg_table_flag <= 1;
    end
    else avg_table_flag <= 0;      
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0 ; i < 16 ; i=i+1 ) begin
            avg_table[i] <= 0;
        end      
    end
    else if(rest_cnt == 5)begin
        avg_table[pic_no_reg] <= (avg_result >> 1);
    end   
end
always @(posedge clk or negedge rst_n) begin
     if (!rst_n) begin
        for (i = 0 ; i < 16 ; i=i+1 ) begin
            avg_flag[i] <= 0;
        end      
    end
    else if(c_state == OUT_AVG || c_state == OUT || c_state == OUT_F)begin
            avg_flag[pic_no_reg]<= 1;
    end   
end

//========================================
// Output 
//========================================
always @(*) begin
    out_valid = 0;
    if (c_state == OUT_F || c_state == OUT || c_state == OUT_D || c_state == OUT_E || c_state == OUT_AVG|| c_state == OUT_A) begin
        out_valid = 1;
    end 
end


// always @(*) begin
//     out_data = 0;
//     if (c_state == OUT_F || c_state == OUT_D) begin
//         out_data = focus_table[pic_no_reg];
//     end
//     else if (c_state == OUT_A) begin
//        out_data = avg_table[pic_no_reg];
//     end
//     else if (c_state == OUT) begin
//        out_data = exposed_results_n;
//     end
//     else if (c_state == OUT_E) begin
//        out_data = 0;
//     end
//     else if (c_state == OUT_AVG) begin
//         out_data = avg_table[pic_no_reg];
//     end
// end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
         out_data <= 0;
    end
    else if (n_state == OUT_F || n_state == OUT_D) begin
        out_data <= focus_table[pic_no_reg];
    end
    else if (n_state == OUT_A) begin
       out_data <= avg_table[pic_no_reg];
    end
    else if (n_state == OUT) begin
       out_data <= exposed_results_n;
    end
    else if (n_state == OUT_E) begin
       out_data <= 0;
    end
    else if (n_state == OUT_AVG) begin
        out_data <= avg_table[pic_no_reg];
    end
end

//========================================
// DRAM CONTROl
//========================================


//========================================
// DRAM WRITE CONTROl
//========================================
assign awid_s_inf = (!rst_n) ? 4'd0 : 4'd0;
// awaddr_s_inf 
assign awsize_s_inf = (!rst_n) ? 3'd0 : 3'b100;
assign awburst_s_inf = (!rst_n) ? 2'b00 : 2'b01;
assign awlen_s_inf = (!rst_n) ? 0 : 8'd191;
//assign awvalid_s_inf = (!rst_n) ? 0:0;
// wdata_s_inf,
// wlast_s_inf,
// wvalid_s_inf,



// WRITE ADDR
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        awaddr_s_inf  <= 0;
    end
    else if (c_state == FIND && n_state == GET_DATA && (mode_reg == 1) ) begin
        awaddr_s_inf  <= 32'h10000 + 3072*pic_no_reg;
    end
    else awaddr_s_inf  <=  awaddr_s_inf;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        awvalid_s_inf <= 0;
    end
    else if (awready_s_inf) awvalid_s_inf <= 0 ;
    else if (c_state == FIND && n_state == GET_DATA && (mode_reg == 1) ) begin
        awvalid_s_inf <= 1; 
    end
	else awvalid_s_inf <= awvalid_s_inf ;
end

// WRITE DATA
assign wlast_s_inf = (dram_w_data_cnt_3 == 192) ? 1 : 0;


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wvalid_s_inf <= 0;
    end
    else if (awready_s_inf) wvalid_s_inf <= 0;
    else if (rvalid_s_inf) wvalid_s_inf <= 1 ;
    else if (dram_w_data_cnt_3 == 192) wvalid_s_inf <= 0 ;
	else wvalid_s_inf <= wvalid_s_inf;
end

always @(*) begin
    wdata_s_inf = w_data_in_2 ;
end

always @(posedge clk) begin
    w_data_in_0 <= d_data_in ;
    w_data_in_1 <= w_data_in_0 ;
    w_data_in_2 <= w_data_in_1 ;
end

assign bready_s_inf = 1;

//========================================
// DRAM READ CONTROl
//========================================
assign arid_s_inf   = (!rst_n) ? 4'd0 : 4'd0;
// [31:0]  araddr_s_inf, 
assign arlen_s_inf  = (!rst_n) ? 0 : 8'd191;
assign arsize_s_inf = (!rst_n) ? 3'd0 : 3'b100;
assign arburst_s_inf = (!rst_n) ? 2'b00 : 2'b01; // 2'b01
// arvalid_s_inf,

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        araddr_s_inf <= 0;
    end
    else if (c_state == FIND && n_state == GET_DATA  ) begin
        araddr_s_inf <= 32'h10000 + 3072*pic_no_reg;
    end
    else araddr_s_inf <= araddr_s_inf;
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        arvalid_s_inf <= 0;
    end
    else if (c_state == FIND && n_state == GET_DATA ) begin
        arvalid_s_inf <= 1;
    end
    else if (arready_s_inf) arvalid_s_inf <= 0 ;
	else arvalid_s_inf <= arvalid_s_inf ;
end
assign rready_s_inf = 1;


//==========================================//
//            DRAM WRITE BACK               //
//==========================================//

always @(*) begin
    d_data_in = {w_data_expose[15], w_data_expose[14], w_data_expose[13], w_data_expose[12],
                 w_data_expose[11], w_data_expose[10], w_data_expose[9],  w_data_expose[8],
                 w_data_expose[7],  w_data_expose[6],  w_data_expose[5],  w_data_expose[4],
                 w_data_expose[3],  w_data_expose[2],  w_data_expose[1],  w_data_expose[0]};
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
       dram_w_data_cnt <= 0;
    end 
    else if (rvalid_s_inf) begin
       dram_w_data_cnt <=dram_w_data_cnt + 1;
    end 
    else if (c_state != GET_DATA && c_state != REST) begin
       dram_w_data_cnt <= 0;
    end
end

always @(posedge clk ) begin

   dram_w_data_cnt_1 <=dram_w_data_cnt;
   dram_w_data_cnt_2 <=dram_w_data_cnt_1;
   dram_w_data_cnt_3 <=dram_w_data_cnt_2;

end
endmodule


module find_MAX_MIN(clk,in0, in1,in2, in3, in4, in5, in6, in7, in8, in9, in10, in11 ,in12 , in13, in14, in15, max_one, min_one);

    input  [7:0] in0, in1,in2, in3, in4, in5, in6, in7, in8, in9, in10, in11 ,in12 , in13, in14, in15;
    input clk;
    output reg [7:0] max_one, min_one;

    reg [7:0] temp_max[7:0];
    reg [7:0] temp_max_1[3:0];
    reg [7:0] temp_max_2[1:0];

    
    reg [7:0] temp_min[7:0];
    reg [7:0] temp_min_1[3:0];
    reg [7:0] temp_min_2[1:0];

    cmp c0_0(.in0(in0), .in1(in8),   .bigger(temp_max[0]), .smaller(temp_min[0]));
    cmp c0_1(.in0(in1), .in1(in9),   .bigger(temp_max[1]), .smaller(temp_min[1]));
    cmp c0_2(.in0(in2), .in1(in10),  .bigger(temp_max[2]), .smaller(temp_min[2]));
    cmp c0_3(.in0(in3), .in1(in11),  .bigger(temp_max[3]), .smaller(temp_min[3]));
    cmp c0_4(.in0(in4), .in1(in12),  .bigger(temp_max[4]), .smaller(temp_min[4]));
    cmp c0_5(.in0(in5), .in1(in13),  .bigger(temp_max[5]), .smaller(temp_min[5]));
    cmp c0_6(.in0(in6), .in1(in14),  .bigger(temp_max[6]), .smaller(temp_min[6]));
    cmp c0_7(.in0(in7), .in1(in15),  .bigger(temp_max[7]), .smaller(temp_min[7]));

    // always @(*) begin
    //     temp_max_1[0] = (temp_max[0] > temp_max[4]) ? temp_max[0] : temp_max[4];
    //     temp_max_1[1] = (temp_max[1] > temp_max[5]) ? temp_max[1] : temp_max[5];
    //     temp_max_1[2] = (temp_max[2] > temp_max[6]) ? temp_max[2] : temp_max[6];
    //     temp_max_1[3] = (temp_max[3] > temp_max[7]) ? temp_max[3] : temp_max[7];

    //     temp_min_1[0] = (temp_min[0] > temp_min[4]) ? temp_min[4] : temp_min[0];
    //     temp_min_1[1] = (temp_min[1] > temp_min[5]) ? temp_min[5] : temp_min[1];
    //     temp_min_1[2] = (temp_min[2] > temp_min[6]) ? temp_min[6] : temp_min[2];
    //     temp_min_1[3] = (temp_min[3] > temp_min[7]) ? temp_min[7] : temp_min[3];

    //     temp_max_2[0] = (temp_max_1[0] > temp_max_1[2]) ? temp_max_1[0] : temp_max_1[2];
    //     temp_max_2[1] = (temp_max_1[1] > temp_max_1[3]) ? temp_max_1[1] : temp_max_1[3];      

    //     temp_min_2[0] = (temp_min_1[0] > temp_min_1[2]) ? temp_min_1[2] : temp_min_1[0];
    //     temp_min_2[1] = (temp_min_1[1] > temp_min_1[3]) ? temp_min_1[3] : temp_min_1[1];  

    //     max_one = (temp_max_2[0] > temp_max_2[1]) ? temp_max_2[0] : temp_max_2[1];
    //     min_one = (temp_min_2[0] > temp_min_2[1]) ? temp_min_2[1] : temp_min_2[0];
    // end
    always @(*) begin
        // temp_max_1[0] = (temp_max[0] > temp_max[4]) ? temp_max[0] : temp_max[4];
        // temp_max_1[1] = (temp_max[1] > temp_max[5]) ? temp_max[1] : temp_max[5];
        // temp_max_1[2] = (temp_max[2] > temp_max[6]) ? temp_max[2] : temp_max[6];
        // temp_max_1[3] = (temp_max[3] > temp_max[7]) ? temp_max[3] : temp_max[7];

        // temp_min_1[0] = (temp_min[0] > temp_min[4]) ? temp_min[4] : temp_min[0];
        // temp_min_1[1] = (temp_min[1] > temp_min[5]) ? temp_min[5] : temp_min[1];
        // temp_min_1[2] = (temp_min[2] > temp_min[6]) ? temp_min[6] : temp_min[2];
        // temp_min_1[3] = (temp_min[3] > temp_min[7]) ? temp_min[7] : temp_min[3];

       
    end    
    always @(posedge clk) begin
        temp_max_1[0] <= (temp_max[0] > temp_max[4]) ? temp_max[0] : temp_max[4];
        temp_max_1[1] <= (temp_max[1] > temp_max[5]) ? temp_max[1] : temp_max[5];
        temp_max_1[2] <= (temp_max[2] > temp_max[6]) ? temp_max[2] : temp_max[6];
        temp_max_1[3] <= (temp_max[3] > temp_max[7]) ? temp_max[3] : temp_max[7];

        temp_min_1[0] <= (temp_min[0] > temp_min[4]) ? temp_min[4] : temp_min[0];
        temp_min_1[1] <= (temp_min[1] > temp_min[5]) ? temp_min[5] : temp_min[1];
        temp_min_1[2] <= (temp_min[2] > temp_min[6]) ? temp_min[6] : temp_min[2];
        temp_min_1[3] <= (temp_min[3] > temp_min[7]) ? temp_min[7] : temp_min[3];
        temp_max_2[0] <= (temp_max_1[0] > temp_max_1[2]) ? temp_max_1[0] : temp_max_1[2];
        temp_max_2[1] <= (temp_max_1[1] > temp_max_1[3]) ? temp_max_1[1] : temp_max_1[3];      

        temp_min_2[0] <= (temp_min_1[0] > temp_min_1[2]) ? temp_min_1[2] : temp_min_1[0];
        temp_min_2[1] <= (temp_min_1[1] > temp_min_1[3]) ? temp_min_1[3] : temp_min_1[1];        

        max_one <= (temp_max_2[0] > temp_max_2[1]) ? temp_max_2[0] : temp_max_2[1];
        min_one <= (temp_min_2[0] > temp_min_2[1]) ? temp_min_2[1] : temp_min_2[0];  
    end


endmodule

module cmp(in0, in1, bigger, smaller);
    input  [7:0] in0, in1;
    output reg [7:0] bigger, smaller;

    always @(*) begin
        bigger = (in0 > in1) ? in0 : in1;
        smaller = (in0 > in1) ? in1 : in0;
    end
endmodule

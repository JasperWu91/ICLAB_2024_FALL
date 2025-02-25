module TMIP(
    // input signals
    clk,
    rst_n,
    in_valid, 
    in_valid2,
    
    image,
    template,
    image_size,
	action,
	
    // output signals
    out_valid,
    out_value
    );

input            clk, rst_n;
input            in_valid, in_valid2;

input      [7:0] image;
input      [7:0] template;
input      [1:0] image_size;
input      [2:0] action;

output reg       out_valid;
output reg       out_value;

//==================================================================
// parameter & integer
//==================================================================
parameter IDLE = 4'd0,
          WRITE_IMG = 4'd1,
          FETCH = 4'd2, // fetch data
          ACTION = 4'd3,
          MAXPOOL = 4'd4,
          IMG_FILTER = 4'd5,
          CONV = 4'd6,
          REST = 4'd7,
          REST_M = 4'd10,// skip state
          FLIP = 4'd8,
          NEGATIVE = 4'd9;

parameter IMG_max_offset = 0;
parameter IMG_avg_offset = 256;
parameter IMG_weight_offset = 512;

integer i,j;
//==================================================================
// reg & wire
//==================================================================

reg [4:0] c_state, n_state;
reg [1:0] img_size, nxt_img_size;
reg [2:0] actions [7:0];
reg [2:0] actions_c [7:0];
reg [7:0] template_reg [8:0], nxt_template_reg[8:0];
reg [7:0] img_R, img_G, img_B, img_R_c, img_G_c, img_B_c, img_gray, img_gray_c;
reg [9:0] cnt, nxt_cnt;
reg [6:0] act_cnt, nxt_act_cnt;
reg [6:0] conv_cnt, nxt_conv_cnt;
reg [1:0] img_cnt, nxt_img_cnt;
reg [9:0] img_idx_cnt, nxt_img_idx_cnt; 
reg img_filled;
reg [7:0] img_gray_avg, img_gray_max, img_gray_weight; 
reg [10:0] addr_img_write_end;

reg [9:0] addr_img;
reg [7:0] data_out_img, data_out_img_c;
reg [7:0] data_in_img;
reg web_img;
reg [1:0] gray_type_c,gray_type;

reg [7:0] img_reg [15:0][15:0];
reg [7:0] img_reg_c [15:0][15:0];

wire [8:0] img_length;// total length ofimage
wire [5:0] img_size_; //length of the image
reg [5:0] img_size_temp; //length if the image
reg [9:0] sum_c, sum_reg,sum_divided, sum_w_c, sum_w_reg;
reg [7:0] temp_max_c, temp_max;

reg [4:0] x_cnt, x_cnt_c, y_cnt ,y_cnt_c;
reg [4:0] x_idx, x_idx_c, y_idx ,y_idx_c;
reg [4:0] cx_idx, cx_idx_c, cy_idx ,cy_idx_c;
reg [7:0] m_in0, m_in1, m_in2, m_in3, m_out, m_min_out;
reg maxpool_complete;

reg [4:0] x_idx_1, x_idx_2, y_idx_1 ,y_idx_2;
reg [7:0] in00,in01,in02,in10,in11,in12,in20,in21,in22,in30,in31,in32;
reg [7:0] median_result, median_result_2;
reg [7:0] buffer_img_reg_1 [15:0];
reg [7:0] buffer_img_reg_2 [15:0];
reg [7:0] buffer_img_reg_3 [15:0];

reg output_flag;
reg [19:0] output_reg;
reg [7:0] outvalid_cnt, nxt_outvalid_cnt;
//reg flip_or_not;
reg neg_or_not;
wire [5:0] img_size_minus_one;
reg [5:0] cx_left, cy_up, cx_right, cy_down;
//==================================================================
// design
//==================================================================

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
                n_state = WRITE_IMG;
            end else if (in_valid2) begin
                n_state = FETCH;
            end
            else n_state = IDLE;
        end 
        // calculate the gray scale and store the data in the sram
        WRITE_IMG: begin
            if (addr_img == (addr_img_write_end + IMG_weight_offset  ) && in_valid2) begin
                n_state = FETCH;
            end else if (addr_img == (addr_img_write_end + IMG_weight_offset ) ) begin
                n_state = IDLE;
            end else n_state = WRITE_IMG;
        end
        // FETCH img data
        FETCH : begin
            if (img_filled) begin
                n_state = ACTION;
            end else n_state = FETCH;           
        end
        // fetch  transition between task
        ACTION: begin
            case (actions[0])
                3: begin
                    if(img_size_temp == 4)begin
                        n_state = REST_M;
                    end else n_state = MAXPOOL;
                end
                4: n_state = NEGATIVE;
                5: n_state = FLIP;
                6: n_state = IMG_FILTER;
                7: n_state = CONV;
                default: n_state = ACTION;
            endcase
        end
        NEGATIVE: begin
            n_state = ACTION;
        end
        MAXPOOL: begin
            if (maxpool_complete) begin
                n_state = ACTION;
            end else n_state = MAXPOOL;
        end
        FLIP: begin
            n_state = ACTION;
        end
        IMG_FILTER: begin
            if (x_idx_2 == (img_size_temp - 2) && y_idx_2 == (img_size_temp - 1)) begin
                n_state = REST;
            end
            else n_state = IMG_FILTER;
        end
        REST_M: begin
            n_state = ACTION;
        end
        REST: begin
            n_state = ACTION;
        end
        CONV: begin
            if (out_valid == 1 && output_flag == 0) begin
                n_state = IDLE;
            end
            else n_state = CONV;
        end
        default: n_state = c_state; 
    endcase
end



always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        neg_or_not <= 0;
    end else if (c_state == NEGATIVE) begin
        neg_or_not <= ~neg_or_not;
    end else if (c_state == FETCH) begin
        neg_or_not <= 0;
    end 
    else neg_or_not <= neg_or_not;
end



// global cnt
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt <= 0;
    end else cnt <= nxt_cnt;
end

always @(*) begin
    if (!in_valid && cnt == 0) begin
        nxt_cnt = 0;
    end else if (cnt == 1000) begin
        nxt_cnt = 0;
    end
    else nxt_cnt = cnt + 1;
end
//=================================================//
//         write Img and template to SRAM 
//=================================================//

// image size , 0: 4x4 , 1: 8x8 , 2:16 x 16 
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        img_size<= 0;
    end else img_size <=  nxt_img_size;
end

always @(*) begin
    if (c_state == IDLE && n_state == WRITE_IMG ) begin
        nxt_img_size = image_size;
    end else nxt_img_size = img_size;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0 ; i < 9 ; i = i + 1 ) begin
            template_reg[i] <= 0;
        end
    end else begin
        for (i = 0 ; i < 9 ; i = i + 1 ) begin
            template_reg[i] <= nxt_template_reg[i];
        end
    end
end

// TO BE CHECKED
always @(*) begin
    for (i = 0 ; i < 9 ; i = i + 1 ) begin
        nxt_template_reg[i] = template_reg[i];
    end

    if (in_valid) begin
        nxt_template_reg[cnt] = template;
    end
end



// img cnt
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        img_cnt <= 0;
    end else img_cnt <= nxt_img_cnt;
end


always @(*) begin
    if (!in_valid && c_state != WRITE_IMG) begin
        nxt_img_cnt = 0;
    end else if (img_cnt == 2 ) begin
        nxt_img_cnt = 0;
    end
    else nxt_img_cnt = img_cnt + 1;
end
// to calculalte the addr of img
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        img_idx_cnt <= 0;
    end else img_idx_cnt <= nxt_img_idx_cnt ;
end

always @(*) begin
    if (nxt_img_cnt == 0 && img_cnt == 2 && cnt >2) begin
        nxt_img_idx_cnt = img_idx_cnt + 1  ;
    end
    else if (c_state == IDLE) begin
        nxt_img_idx_cnt = 0 ;
    end
    else  nxt_img_idx_cnt = img_idx_cnt ;
end

//img store
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        img_R = 0;
        img_G = 0;
        img_B = 0;
    end else begin
        img_R = img_R_c;
        img_G = img_G_c;
        img_B = img_B_c;
    end
end

always @(*) begin
        img_R_c = 0;
        img_G_c = 0;
        img_B_c = 0;
    if (in_valid && img_cnt == 0 ) begin
        img_R_c = image;
    end else if (in_valid && img_cnt == 1) begin
        img_G_c = image;
    end else if (in_valid && img_cnt == 2) begin
        img_B_c = image;
    end
     else begin
        img_R_c = img_R;
        img_G_c = img_G;
        img_B_c = img_B;
    end
end

//Gray scale processing

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        temp_max <= 0;
    end else begin
        temp_max <= temp_max_c;
    end
end

//Maximum scale processing
always @(*) begin
    img_gray_c = 0;
    if (img_cnt == 1) begin
        temp_max_c = (img_R > img_G_c) ? img_R : img_G_c;
    end else if (img_cnt == 2) begin
        temp_max_c = (temp_max > img_B_c) ? temp_max : img_B_c;
        img_gray_c = temp_max_c;
    end else begin
        temp_max_c = temp_max;
        img_gray_c = img_gray_max;
    end
end

// average
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum_reg <= 0;
        sum_w_reg <= 0;
    end else  begin
        sum_reg <= sum_c;
        sum_w_reg <= sum_w_c;
    end
end
// average
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        img_gray_avg <= 0;
        img_gray_weight <= 0;
        img_gray_max <= 0;
    end
    else  if (img_cnt == 0) begin
        img_gray_avg <= sum_divided;
    end 
    else  if (img_cnt == 2) begin
        img_gray_weight <= sum_w_c;
        img_gray_max <= img_gray_c;
    end
    else begin
        img_gray_avg <= img_gray_avg;
        img_gray_weight <= img_gray_weight;
        img_gray_max <= img_gray_max;
    end
end
// average sum
always @(*) begin
     sum_divided = 0;
    if (img_cnt == 0) begin
        sum_c = img_R_c;
        sum_divided = sum_reg / 3;
    end else if (img_cnt == 1) begin
        sum_c =  sum_reg + img_G_c;
    end else if (img_cnt == 2) begin
        sum_c =  (sum_reg + img_B_c);
    end else  begin
        sum_c =  sum_reg;
    end
end
// weight sum
always @(*) begin
    if (img_cnt == 0) begin
        sum_w_c = (img_R_c >> 2);
    end else if (img_cnt == 1) begin
        sum_w_c =  sum_w_reg + (img_G_c >> 1);
    end else if (img_cnt == 2) begin
        sum_w_c =  sum_w_reg + (img_B_c >> 2);
    end else  begin
        sum_w_c =  sum_w_reg;
    end
end

// action cnt
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        act_cnt <= 0;
    end else act_cnt <= nxt_act_cnt;
end

always @(*) begin
    if (!in_valid2 && act_cnt == 0) begin
        nxt_act_cnt = 0;
    end else if (act_cnt == 8) begin
        nxt_act_cnt = 0;
    end
    else nxt_act_cnt = act_cnt + 1;
end

always @(posedge clk) begin
    gray_type <= gray_type_c;
end

always @(*) begin
    if (in_valid2 && act_cnt == 0) begin
        gray_type_c = action;
    end else gray_type_c = gray_type;
end

reg [8:0] img_fill_cnt, img_fill_cnt_c;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        img_fill_cnt <= 0;
    end
    else img_fill_cnt <= img_fill_cnt_c;
end
 
always @(*) begin
    if (c_state != FETCH) begin
        img_fill_cnt_c = 0;
    end else if (c_state == FETCH && gray_type == 0 || gray_type == 1 || gray_type == 2) begin
        img_fill_cnt_c = img_fill_cnt + 1;
    end else img_fill_cnt_c = img_fill_cnt;
end
wire [3:0]img_si_;
assign img_length = (img_size == 2) ? 256 : ((img_size == 1) ? 64 : 16);
assign img_size_ = (img_size == 2) ? 16 : ((img_size == 1) ? 8 : 4);
assign img_si_ = (img_size == 2) ? 4 : ((img_size == 1) ? 3 : 2);
assign img_filled = (img_fill_cnt == (img_length + 1))? 1 : 0;

always @(posedge clk) begin
    if (c_state == FETCH) begin
        img_size_temp <= img_size_;
    end else if (c_state == MAXPOOL && n_state == ACTION) begin
        img_size_temp <= img_size_temp >> 1;
    end 
    else img_size_temp <= img_size_temp;
end

always @(posedge clk or negedge rst_n ) begin
    if (!rst_n) begin
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                img_reg[j][i]  <= 0;
            end
        end
    end else begin
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                img_reg[j][i]  <= img_reg_c[j][i];
            end
        end
    end
end

//TODO: fill the wrong place
always @(*) begin
    for (i = 0; i < 16; i = i + 1) begin
        for (j = 0; j < 16; j = j + 1) begin
            img_reg_c[j][i] = img_reg[j][i];
        end
    end

    case (c_state)
        FETCH : begin
            img_reg_c[(img_fill_cnt -2) >> img_si_][(img_fill_cnt -2) % img_size_] = data_out_img;
        end
        FLIP : begin
            if (img_size_temp == 4) begin
                for (j = 0; j < 4; j = j + 1) begin
                    img_reg_c[j][0] =  img_reg[j][3]; 
                    img_reg_c[j][1] =  img_reg[j][2];
                    img_reg_c[j][2] =  img_reg[j][1];
                    img_reg_c[j][3] =  img_reg[j][0];
                end
            end                   
            else if (img_size_temp == 8) begin
                for (j = 0; j < 8; j = j + 1) begin
                    img_reg_c[j][0] =  img_reg[j][7]; 
                    img_reg_c[j][1] =  img_reg[j][6];
                    img_reg_c[j][2] =  img_reg[j][5];
                    img_reg_c[j][3] =  img_reg[j][4];
                    img_reg_c[j][4] =  img_reg[j][3];
                    img_reg_c[j][5] =  img_reg[j][2];
                    img_reg_c[j][6] =  img_reg[j][1];
                    img_reg_c[j][7] =  img_reg[j][0];
                end
            end
            else if (img_size_temp == 16) begin
                for (j = 0; j < 16; j = j + 1) begin
                    img_reg_c[j][0]  =  img_reg[j][15]; 
                    img_reg_c[j][1]  =  img_reg[j][14];
                    img_reg_c[j][2]  =  img_reg[j][13];
                    img_reg_c[j][3]  =  img_reg[j][12];
                    img_reg_c[j][4]  =  img_reg[j][11];
                    img_reg_c[j][5]  =  img_reg[j][10];
                    img_reg_c[j][6]  =  img_reg[j][9];
                    img_reg_c[j][7]  =  img_reg[j][8];
                    img_reg_c[j][8]  =  img_reg[j][7]; 
                    img_reg_c[j][9]  =  img_reg[j][6];
                    img_reg_c[j][10] =  img_reg[j][5];
                    img_reg_c[j][11] =  img_reg[j][4];
                    img_reg_c[j][12] =  img_reg[j][3];
                    img_reg_c[j][13] =  img_reg[j][2];
                    img_reg_c[j][14] =  img_reg[j][1];
                    img_reg_c[j][15] =  img_reg[j][0];
                end                  
            end
        end
        MAXPOOL:begin
            img_reg_c[y_cnt][x_cnt] =(neg_or_not) ? m_min_out : m_out;
        end
        REST:begin
            for (j = 0; j < 16; j = j + 1) begin
                if (img_size_temp == 16) begin
                    img_reg_c[3][j] =img_reg[0][j];
                    img_reg_c[4][j] =img_reg[1][j];
                    img_reg_c[5][j] =img_reg[2][j];
                    img_reg_c[6][j] =img_reg[3][j];
                    img_reg_c[7][j] =img_reg[4][j];
                    img_reg_c[8][j] =img_reg[5][j];
                    img_reg_c[9][j] =img_reg[6][j];
                    img_reg_c[10][j] =img_reg[7][j];
                    img_reg_c[11][j] =img_reg[8][j];
                    img_reg_c[12][j] =img_reg[9][j];
                    img_reg_c[13][j] =img_reg[10][j];
                    img_reg_c[14][j] =img_reg[11][j];
                    img_reg_c[15][j] =img_reg[12][j];

                    img_reg_c[0][j] =buffer_img_reg_1[j];
                    img_reg_c[1][j] =buffer_img_reg_2[j];
                    img_reg_c[2][j] =buffer_img_reg_3[j]; 
                end
                else if (img_size_temp == 8) begin
                    img_reg_c[3][j] =img_reg[0][j];
                    img_reg_c[4][j] =img_reg[1][j];
                    img_reg_c[5][j] =img_reg[2][j];
                    img_reg_c[6][j] =img_reg[3][j];
                    img_reg_c[7][j] =img_reg[4][j];

                    img_reg_c[0][j] =buffer_img_reg_1[j];
                    img_reg_c[1][j] =buffer_img_reg_2[j];
                    img_reg_c[2][j] =buffer_img_reg_3[j]; 
                end
                else if (img_size_temp == 4) begin
                    img_reg_c[3][j] = img_reg[0][j];
                    img_reg_c[0][j] = buffer_img_reg_1[j];
                    img_reg_c[1][j] = buffer_img_reg_2[j];
                    img_reg_c[2][j] = buffer_img_reg_3[j]; 
                end
            end
        end
        IMG_FILTER:begin
            if ( y_idx_2 > 2  ) begin
                img_reg_c[y_idx_2 -3][x_idx_2 ] = median_result;
                img_reg_c[y_idx_2 -3][x_idx_2 + 1 ] = median_result_2;
            end          
        end
        default: begin
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    img_reg_c[j][i] = img_reg[j][i];
                end
            end
        end
    endcase
end


// reset action reg
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0 ; i < 8 ; i = i + 1 ) begin
            actions[i] <= 0;
        end
    end else begin
        for (i = 0 ; i < 8 ; i = i + 1 ) begin
            actions[i] <= actions_c[i]; 
        end
    end
end

always @(*) begin
    for (i = 0 ; i < 8 ; i = i + 1 ) begin
        actions_c[i] = actions[i]; 
    end
    if (c_state == FETCH && act_cnt < 8 && act_cnt != 0) begin
        actions_c[act_cnt] = action;    
    end 
    else if((c_state != ACTION && n_state == ACTION  || n_state == CONV) )begin
        for (i = 1 ; i <8 ; i = i + 1 ) begin
            actions_c[i-1] = actions[i]; 
        end
    end
    else begin
        for (i = 0 ; i < 8 ; i = i + 1 ) begin
            actions_c[i] = actions[i]; 
        end
    end
end

//=================================================//
//       Max pooling 
//=================================================//

maxpool_4 m4(.in0(m_in0), .in1(m_in1), .in2(m_in2), .in3( m_in3), .max_out(m_out), .min_out(m_min_out));

assign maxpool_complete = (((x_cnt << 1) > (img_size_temp - 4) )&& (((y_cnt+1) << 1) == img_size_temp ) ) ? 1 : 0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_cnt <= 0;
    end 
    else x_cnt <= x_cnt_c;
end

always @(*) begin
     if (c_state != MAXPOOL ) begin
        x_cnt_c = 0;
    end else if ((x_cnt << 1) > (img_size_temp - 4)) begin
        x_cnt_c = 0;
    end else if (c_state == MAXPOOL) begin
        x_cnt_c = x_cnt + 1;
    end 
    else x_cnt_c = x_cnt;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        y_cnt <= 0;
    end 
    else y_cnt <= y_cnt_c;
end

always @(*) begin
    if (c_state != MAXPOOL ) begin
        y_cnt_c = 0;
    end else if ((x_cnt << 1) > (img_size_temp - 4)) begin
        y_cnt_c = y_cnt + 1;
    end
    else y_cnt_c = y_cnt;
end


always @(*) begin
    if (c_state == MAXPOOL && (x_cnt < img_size_temp)) begin
        m_in0 = img_reg[(y_cnt << 1)][(x_cnt << 1)];
        m_in1 = img_reg[(y_cnt << 1)][(x_cnt << 1)+1];
        m_in2 = img_reg[(y_cnt << 1)+1][(x_cnt << 1)];
        m_in3 = img_reg[(y_cnt << 1)+1][(x_cnt << 1)+1];
    end else begin
        m_in0 = 0;
        m_in1 = 0;
        m_in2 = 0;
        m_in3 = 0;
    end
end
//=================================================//
//      Image Filter
//=================================================//


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_idx <= 0;
    end 
    else x_idx <= x_idx_c;
end


always @(posedge clk ) begin
    if (c_state == ACTION) begin
        y_idx_1 <= 0;
    end
    else if (c_state == IMG_FILTER) begin
         y_idx_1 <= y_idx;
    end
   
end
always @(posedge clk ) begin
    if (c_state == ACTION) begin
        y_idx_2 <= 0;
    end
    else if (c_state == IMG_FILTER) begin
         y_idx_2 <= y_idx_1;
    end
     //y_idx_2 <= y_idx_1;
end

always @(posedge clk ) begin
    if (c_state == ACTION) begin
        x_idx_1 <= 0;
    end
    else if (c_state == IMG_FILTER) begin
        x_idx_1 <= x_idx;
    end
end
always @(posedge clk ) begin
    if (c_state == ACTION) begin
        x_idx_2 <= 0;
    end
    else if (c_state == IMG_FILTER) begin
        x_idx_2 <= x_idx_1;
    end
end


// TODO : change the state from action to IMG_FILTER 
always @(*) begin
     if (c_state != IMG_FILTER & n_state == IMG_FILTER ) begin
        x_idx_c = 0;
    end else if (x_idx == (img_size_temp - 2)) begin
        x_idx_c = 0;
    end else if (c_state == IMG_FILTER) begin
        x_idx_c = x_idx + 2;
    end 
    else x_idx_c = x_idx;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        y_idx <= 0;
    end 
    else y_idx <= y_idx_c;
end

always @(*) begin
    if (c_state != IMG_FILTER & n_state == IMG_FILTER ) begin
        y_idx_c = 0;
     end else if (x_idx == (img_size_temp - 2)) begin
        y_idx_c = y_idx + 1;
    end
    else y_idx_c = y_idx;
end

img_filter f1(.clk(clk), .in11(in00) , .in12(in01), .in13(in02), .in21(in10),
         .in22(in11), .in23(in12), .in31(in20), .in32(in21), .in33(in22),
         .in41(in30), .in42(in31), .in43(in32), .median(median_result),.median2(median_result_2));
//module img_filter(clk,in11, in12, in13, in21, in22, in23, in31, in32, in33, in41, in42, in43, median, median2);
always @(posedge clk) begin
    if (y_idx_2 == 0  && n_state == IMG_FILTER) begin
        for (i = 0; i < 16; i = i + 1) begin
            if (x_idx_2 == i) begin
               buffer_img_reg_1[i] <= median_result; 
               buffer_img_reg_1[i+1] <= median_result_2; 
            end 
        end
    end    
    else if (y_idx_2 == 1 && n_state == IMG_FILTER) begin
        for (i = 0; i < 16; i = i + 1) begin
            if (x_idx_2 == i) begin
               buffer_img_reg_2[i] <= median_result; 
               buffer_img_reg_2[i+1] <= median_result_2; 
            end 
        end
    end
    else if (y_idx_2 == 2 && n_state == IMG_FILTER) begin
        for (i = 0; i < 16; i = i + 1) begin
            if (x_idx_2 == i) begin
               buffer_img_reg_3[i] <= median_result; 
               buffer_img_reg_3[i+1] <= median_result_2; 
            end 
        end
    end
    else if(c_state == FETCH) begin
        for (i = 0; i < 16; i = i + 1) begin
            buffer_img_reg_1[i] <= 0; 
            buffer_img_reg_2[i] <= 0; 
            buffer_img_reg_3[i] <= 0; 
        end
    end
    else begin
        for (i = 0; i < 16; i = i + 1) begin
            buffer_img_reg_1[i] <= buffer_img_reg_1[i]; 
            buffer_img_reg_2[i] <= buffer_img_reg_2[i]; 
            buffer_img_reg_3[i] <= buffer_img_reg_3[i]; 
        end
    end
end
// input of image filter
reg [5:0] x_left, y_up, x_right, y_down;
reg [5:0] x_left1, y_up1, x_right1, y_down1;

assign x_left = (x_idx == 0) ? x_idx : (x_idx - 1);
assign x_right = (x_idx == img_size_minus_one) ? x_idx : (x_idx + 1);
assign y_up = (y_idx == 0) ? y_idx : (y_idx - 1);
assign y_down = (y_idx == img_size_minus_one) ? y_idx : (y_idx + 1);

assign x_left1 = (x_idx);
assign x_right1 = ((x_idx +1) == img_size_minus_one) ? x_idx +1 : (x_idx + 2);
// assign y_up1 = (y_idx == 0) ? y_idx : (y_idx - 1);
// assign y_down1 = (y_idx == img_size_minus_one) ? y_idx : (y_idx + 1);

always @(*) begin
    if (c_state == IMG_FILTER) begin
        // Assign values based on the determined boundaries
        in00 = img_reg[y_up][x_left];
        in10 = img_reg[y_up][x_idx];
        in20 = img_reg[y_up][x_right];
        in30 = img_reg[y_up][x_right1];

        in01 = img_reg[y_idx][x_left];
        in11 = img_reg[y_idx][x_idx];
        in21 = img_reg[y_idx][x_right];
        in31 = img_reg[y_idx][x_right1];

        in02 = img_reg[y_down][x_left];
        in12 = img_reg[y_down][x_idx];
        in22 = img_reg[y_down][x_right];
        in32 = img_reg[y_down][x_right1];


        
    end else begin
        in00 = 0 ; in01 = 0; in02 = 0;
        in10 = 0 ; in11 = 0; in12 = 0;
        in20 = 0 ; in21 = 0; in22 = 0;  
        in30 = 0 ; in31 = 0; in32 = 0;     
    end
end

//=================================================//
//       Convolurion 
//=================================================//
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        conv_cnt <= 0;
    end else conv_cnt <= nxt_conv_cnt;
end

always @(*) begin
    if ( n_state != CONV) begin
        nxt_conv_cnt = 0;
    end
    else if ( outvalid_cnt > 7 && outvalid_cnt < 19) begin
        nxt_conv_cnt = 0;
    end
    else if ( c_state == CONV && conv_cnt == 8) begin
        nxt_conv_cnt = 0;
    end
    else if (c_state == CONV ) begin
        nxt_conv_cnt = conv_cnt + 1;
    end else nxt_conv_cnt = conv_cnt;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cx_idx <= 0;
    end else if (cx_idx_c == (img_size_temp )) begin
        cx_idx <= 0;
    end
    else cx_idx <= cx_idx_c;
end

// TODO : change the state from action to IMG_FILTER 
always @(*) begin
     if (c_state != CONV & n_state == CONV ) begin
        cx_idx_c = 0;
    end  else if (c_state == CONV && conv_cnt == 8) begin
        cx_idx_c = cx_idx + 1;
    end 
    else cx_idx_c = cx_idx;
end


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cy_idx <= 0;
    end 
    else cy_idx <= cy_idx_c;
end

always @(*) begin
    if ((cx_idx == (img_size_temp -1 )) && (conv_cnt == 8)) begin
        cy_idx_c = cy_idx + 1;
    end else if ((c_state != CONV)) begin
        cy_idx_c = 0;
    end
    else cy_idx_c = cy_idx;
end
reg [7:0] img00,img01,img02,img10,img11,img12,img20,img21,img22;
reg [7:0] PE_w; 
reg [7:0] PE_img; 
reg [19:0] PE_p_sum_in; 
wire [19:0] PE_p_sum_out; 

//PE unit

PE u_PE_1(.clk(clk), .weight(PE_w), .img(PE_img), .partial_sum_input(PE_p_sum_in), .partial_sum_output(PE_p_sum_out));

// PE input
always @(*) begin
    if (c_state == CONV) begin
        case (conv_cnt)
            0: begin
                PE_img = ( neg_or_not) ? (~img00) : img00;
                PE_p_sum_in = 0;
                PE_w = template_reg[0];
            end 
            1: begin
                PE_img = (neg_or_not) ? (~img01) : img01;
                PE_p_sum_in = PE_p_sum_out;
                PE_w = template_reg[1];
            end
            2: begin
                PE_img = (neg_or_not) ? (~img02) : img02;
                PE_p_sum_in = PE_p_sum_out;
                PE_w = template_reg[2];
            end
            3: begin
                PE_img = (neg_or_not) ? (~img10) : img10;
                PE_p_sum_in = PE_p_sum_out;
                PE_w = template_reg[3];               
            end
            4: begin
                PE_img = (neg_or_not) ? (~img11) : img11;
                PE_p_sum_in = PE_p_sum_out;
                PE_w = template_reg[4]; 
            end
            5: begin
                PE_img = (neg_or_not) ? (~img12) : img12;
                PE_p_sum_in = PE_p_sum_out;
                PE_w = template_reg[5]; 
            end
            6: begin
                PE_img = (neg_or_not) ? (~img20) : img20;
                PE_p_sum_in = PE_p_sum_out;
                PE_w = template_reg[6];  
            end
            7: begin
                PE_img = (neg_or_not) ? (~img21) : img21;
                PE_p_sum_in = PE_p_sum_out;
                PE_w = template_reg[7]; 
            end
            8: begin
                PE_img = (neg_or_not) ? (~img22) : img22;
                PE_p_sum_in = PE_p_sum_out;
                PE_w = template_reg[8];            
            end
            default:  begin
                PE_img = img11;
                PE_p_sum_in = PE_p_sum_out;
                PE_w = template_reg[1];
            end
        endcase
    end else begin
        PE_img =0;
        PE_p_sum_in = 0;
        PE_w = 0;
    end
end

assign img_size_minus_one = img_size_temp - 1;

// img select
assign cx_left = (cx_idx == 0) ? cx_idx : (cx_idx - 1);
assign cx_right = (cx_idx == img_size_minus_one) ? cx_idx : (cx_idx + 1);
assign cy_up = (cy_idx == 0) ? cy_idx : (cy_idx - 1);
assign cy_down = (cy_idx == img_size_minus_one) ? cy_idx : (cy_idx + 1);

always @(*) begin
    if (c_state == CONV) begin
        // Assign values based on the determined boundaries
        img00 = (cy_idx == 0 || cx_idx == 0) ? ((neg_or_not) ? 255 : 0) : img_reg[cy_up][cx_left];
        img01 = (cy_idx == 0) ? ((neg_or_not) ? 255 : 0) : img_reg[cy_up][cx_idx];
        img02 = (cy_idx == 0 || cx_idx == img_size_minus_one) ? ((neg_or_not) ? 255 : 0) : img_reg[cy_up][cx_right];

        img10 = (cx_idx == 0) ? ((neg_or_not) ? 255 : 0) : img_reg[cy_idx][cx_left];
        img11 = img_reg[cy_idx][cx_idx];
        img12 = (cx_idx == img_size_minus_one) ? ((neg_or_not) ? 255 : 0) : img_reg[cy_idx][cx_right];

        img20 = (cy_idx == img_size_minus_one || cx_idx == 0) ? ((neg_or_not) ? 255 : 0) : img_reg[cy_down][cx_left];
        img21 = (cy_idx == img_size_minus_one) ? ((neg_or_not) ? 255 : 0) : img_reg[cy_down][cx_idx];
        img22 = (cy_idx == img_size_minus_one || cx_idx == img_size_minus_one) ? ((neg_or_not) ? 255 : 0) : img_reg[cy_down][cx_right];
    end else begin
        img00 = 0 ; img01 = 0; img02 = 0;
        img10 = 0 ; img11 = 0; img12 = 0;
        img20 = 0 ; img21 = 0; img22 = 0;     
    end
end

//=================================================//
//       Image SRAM control 
//=================================================//

//addr_img == (addr_img_write_end + IMG_weight_offset)

always @(*) begin
     addr_img = 0;
    if (!rst_n) begin
        addr_img = 0;
    end else if (c_state == WRITE_IMG ) begin
        if (img_cnt == 0 ) begin
            addr_img = img_idx_cnt + IMG_max_offset;
        end else if (img_cnt == 1)begin
            addr_img = img_idx_cnt + IMG_avg_offset;
        end else if (img_cnt == 2)begin
            addr_img = img_idx_cnt + IMG_weight_offset;
        end
        //addr_img <= addr_img + 1;
    end else if (c_state == FETCH ) begin
        case (gray_type)
            0 : begin
              addr_img = img_fill_cnt + IMG_max_offset;
            end
            1 : begin
              addr_img = img_fill_cnt + IMG_avg_offset;
            end
            2 : begin
              addr_img = img_fill_cnt + IMG_weight_offset;
            end 
            default: addr_img = 0;
        endcase
    end
    else addr_img = 0;
end

always @(*) begin
    data_in_img = 0;
    if (!rst_n) begin
        data_in_img = 0;
    end else if (c_state == WRITE_IMG ) begin
        if (img_cnt == 0 ) begin
            data_in_img = img_gray_max;
        end else if (img_cnt == 1)begin
            data_in_img = img_gray_avg;
        end else if (img_cnt == 2)begin
            data_in_img = img_gray_weight;
        end
    end else data_in_img = 0;
end

// set the img address
always @(posedge clk) begin
    if (img_size == 0) begin
        addr_img_write_end <= 15;// 4X4 words
    end else if (img_size == 1) begin
        addr_img_write_end <= 63;// 8X8 words
    end else if (img_size == 2) begin
        addr_img_write_end <= 255;// 16X16 words
    end else addr_img_write_end <= addr_img_write_end ;
end
//=================================================//
//       WRITE ENABLE of image SRAM 
//=================================================//
always @(posedge clk) begin
    data_out_img <= data_out_img_c;
end

always @(*) begin
    if (c_state == WRITE_IMG && cnt > 2 ) begin
        web_img = 0; // enable write image
    end else begin
        web_img = 1; // disable write image
    end
end
// MEMORY MODULE
sram_1024x8_inst mem_0(.A(addr_img), .DO(data_out_img_c), .DI(data_in_img), .CK(clk), .WEB(web_img), .CS(1'b1), .OE(1'b1));

reg [9:0] output_cnt, nxt_output_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        output_cnt <= 0;
    end else output_cnt <= nxt_output_cnt;
end

always @(*) begin
    if (conv_cnt == 8) begin
        nxt_output_cnt = output_cnt + 1;
    end  else if (c_state != CONV) begin
        nxt_output_cnt = 0;
    end else nxt_output_cnt = output_cnt;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        outvalid_cnt <= 0;
    end 
    else if (nxt_outvalid_cnt == 20) begin
        outvalid_cnt <= 0;
    end
    else outvalid_cnt <= nxt_outvalid_cnt;
end

always @(*) begin
    if (out_valid) begin
        nxt_outvalid_cnt = outvalid_cnt + 1;
    end else nxt_outvalid_cnt = outvalid_cnt;
end
reg [19:0] output_temp_reg;

always @(posedge clk) begin
    if ( out_valid && conv_cnt == 0 && outvalid_cnt == 8 ) begin
       output_temp_reg <= PE_p_sum_out;
    end else begin
       output_temp_reg <=  output_temp_reg;
    end
end

always @(posedge clk) begin
    if (conv_cnt == 0 && output_cnt == 1) begin
        output_reg <= PE_p_sum_out;
    end else if ( outvalid_cnt == 19 && output_flag) begin
        output_reg <= output_temp_reg;
    end else begin
        for (i = 1; i < 20 ; i = i + 1 ) begin
            output_reg[i] <= output_reg[i-1];
        end
    end
end

reg [8:0] img_area;

always @(*) begin
    img_area = 0;
    case (img_size_temp)
        4:  img_area = 16;
        8:  img_area = 64;
        16: img_area = 256;
        default: img_area = 0;
    endcase
end

always @(*) begin
    if (c_state == CONV && output_cnt > 0) begin
        if (!(output_cnt > (img_area) && outvalid_cnt == 19)) begin
            output_flag = 1;
        end else begin
            output_flag = 0;
        end
    end else begin
        output_flag = 0;
    end
end


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <= 1'b0;
    end 
    else if (output_flag) begin
        out_valid <= 1'b1;
    end 
    else begin
        out_valid <= 1'b0;
    end
end
always @(*) begin
    if(!rst_n) begin
        out_value = 0;
    end 
    else if (out_valid) begin
        out_value = output_reg[19];
    end 
    else begin
        out_value = 0;
    end
end
endmodule


//==========================================//
//             Memory Module                //
//==========================================//

module sram_1024x8_inst (A, DO, DI, CK, WEB, CS, OE);
input [9:0] A;
input [7:0] DI;
output [7:0] DO;

input CK;
input CS, OE;
input WEB;

// sram module
    SRAM_1024X8 MEM0(
        .A0(A[0]),.A1(A[1]),.A2(A[2]),.A3(A[3]),.A4(A[4]),.A5(A[5]),.A6(A[6]),
        .A7(A[7]),.A8(A[8]), .A9(A[9]), .DO0(DO[0]), .DO1(DO[1]) , .DO2(DO[2]), .DO3(DO[3]), .DO4(DO[4]),
        .DO5(DO[5]),.DO6(DO[6]), .DO7(DO[7]), .DI0(DI[0]), .DI1(DI[1]),.DI2(DI[2]), .DI3(DI[3]), .DI4(DI[4]), .DI5(DI[5]), .DI6(DI[6]), .DI7(DI[7]),
        .CK(CK),.WEB(WEB),.OE(OE), .CS(CS));
endmodule


//==========================================//
//          Image Filter Module             //
//==========================================//

module img_filter(clk,in11, in12, in13, in21, in22, in23, in31, in32, in33, in41, in42, in43, median, median2);

    input [7:0] in11, in12, in13;
    input [7:0] in21, in22, in23;
    input [7:0] in31, in32, in33;
    input [7:0] in41, in42, in43;
    input clk;
    output reg [7:0] median, median2;

    reg [7:0] max1, mid1 , min1;
    reg [7:0] max2, mid2 , min2;
    reg [7:0] max3, mid3 , min3;
    reg [7:0] max4, mid4 , min4;
    reg [7:0] max_min_val, mid_mid_val, min_max_val;
    reg [7:0] max_min_val_2, mid_mid_val_2, min_max_val_2;
    reg [7:0] temp;
    wire [7:0] a[2:0], b[2:0], c[2:0];


    reg [7:0] max1_, mid1_ , min1_;
    reg [7:0] max2_, mid2_ , min2_;
    reg [7:0] max3_, mid3_ , min3_;
    reg [7:0] max4_, mid4_ , min4_;
    reg [7:0] max_min_val_, mid_mid_val_, min_max_val_;
    reg [7:0] max_min_val_2_, mid_mid_val_2_, min_max_val_2_;


    cmp c0_1(.in0(in11), .in1(in12), .in2(in13), .minVal(min1), .maxVal(max1), .midVal(mid1));
    cmp c0_2(.in0(in21), .in1(in22), .in2(in23), .minVal(min2), .maxVal(max2), .midVal(mid2));
    cmp c0_3(.in0(in31), .in1(in32), .in2(in33), .minVal(min3), .maxVal(max3), .midVal(mid3));
    cmp c0_4(.in0(in41), .in1(in42), .in2(in43), .minVal(min4), .maxVal(max4), .midVal(mid4));

    cmp c1_1(.in0(max1_), .in1(max2_), .in2(max3_), .minVal(max_min_val), .maxVal(a[0]), .midVal(a[1]));
    cmp c1_2(.in0(min1_), .in1(min2_), .in2(min3_), .minVal(b[0]), .maxVal(min_max_val), .midVal(b[1]));
    cmp c1_3(.in0(mid1_), .in1(mid2_), .in2(mid3_), .minVal(c[0]), .maxVal(c[1]), .midVal(mid_mid_val));

    cmp c2_1(.in0(max4_), .in1(max2_), .in2(max3_), .minVal(max_min_val_2), .maxVal(), .midVal());
    cmp c2_2(.in0(min4_), .in1(min2_), .in2(min3_), .minVal(), .maxVal(min_max_val_2), .midVal());
    cmp c2_3(.in0(mid4_), .in1(mid2_), .in2(mid3_), .minVal(), .maxVal(), .midVal(mid_mid_val_2));

    

    cmp c4_1(.in0(max_min_val_), .in1(min_max_val_), .in2(mid_mid_val_), .minVal(a[2]), .maxVal(b[2]), .midVal(median));

    cmp c4_2(.in0(max_min_val_2_), .in1(min_max_val_2_), .in2(mid_mid_val_2_), .minVal(), .maxVal(), .midVal(median2));

    always @(posedge clk) begin
        max1_ <= max1;
        mid1_ <= mid1;
        min1_ <= min1;
        

        max2_ <= max2;
        mid2_ <= mid2;
        min2_ <= min2;

        min3_ <= min3;
        mid3_ <= mid3;
        max3_ <= max3;

        min4_ <= min4;
        mid4_ <= mid4;
        max4_ <= max4;

        max_min_val_ <= max_min_val;
        mid_mid_val_ <= mid_mid_val;
        min_max_val_ <= min_max_val;

        max_min_val_2_ <= max_min_val_2;
        mid_mid_val_2_ <= mid_mid_val_2;
        min_max_val_2_ <= min_max_val_2;


    end

endmodule



module cmp(in0, in1, in2, minVal, maxVal, midVal);

    input  [7:0] in0, in1, in2;
    output reg [7:0] minVal, maxVal, midVal;
    reg [7:0] b[2:0], s[2:0];

    always @(*) begin
        b[0] = (in0 > in1) ? in0 : in1;
        s[0] = (in0 > in1) ? in1 : in0;

        b[1] = (b[0] > in2) ? b[0] : in2;
        s[1] = (b[0] > in2) ? in2 : b[0];

        b[2] = (s[1] > s[0]) ? s[1] : s[0];
        s[2] = (s[1] > s[0]) ? s[0] : s[1];

        maxVal = b[1];
        midVal = b[2];
        minVal = s[2];
    end

endmodule

module maxpool_4 ( 
    input [7:0] in0, 
    input [7:0] in1, 
    input [7:0] in2, 
    input [7:0] in3, 
    output reg [7:0] max_out,
    output reg [7:0] min_out
);

    reg [7:0] max_temp_0, max_temp_1, min_temp_0, min_temp_1;

    always @(*) begin
        max_temp_0 = (in0 > in1) ? in0 : in1;
        min_temp_0 = (in0 > in1) ? in1 : in0;

        max_temp_1 = (in2 > in3) ? in2 : in3;
        min_temp_1 = (in2 > in3) ? in3 : in2;

        max_out = (max_temp_0 > max_temp_1) ? max_temp_0 : max_temp_1;
        min_out = (min_temp_0 > min_temp_1) ? min_temp_1 : min_temp_0;
    end

endmodule


module PE(
    clk,
    weight,
    img, 
    partial_sum_input,
    partial_sum_output
);

input clk;
input [7:0] weight;
input [7:0] img;
input [19:0] partial_sum_input;
output reg [19:0] partial_sum_output;

reg [19:0] n_psum_out;
reg [19:0] tmp;

always @(*) begin
    tmp = weight * img;
    n_psum_out = partial_sum_input + tmp;
end

always @(posedge clk) begin
    partial_sum_output <= n_psum_out;
end

endmodule


module Ramen(
    // Input Registers
    input clk, 
    input rst_n, 
    input in_valid,
    input selling,
    input portion, 
    input [1:0] ramen_type,

    // Output Signals
    output reg out_valid_order,
    output reg success,

    output reg out_valid_tot,
    output reg [27:0] sold_num,
    output reg [14:0] total_gain
);


//==============================================//
//             Parameter and Integer            //
//==============================================//

// ramen_type
parameter TONKOTSU = 0;
parameter TONKOTSU_SOY = 1;
parameter MISO = 2;
parameter MISO_SOY = 3;

// initial ingredient
parameter NOODLE_INIT = 12000;
parameter BROTH_INIT = 41000;
parameter TONKOTSU_SOUP_INIT =  9000;
parameter MISO_INIT = 1000;
parameter SOY_SAUSE_INIT = 1500;


//state 
parameter IDLE =  0,
          GET_ORDER = 1 ,
          CHECK = 2 ,
          RESPONSE = 3,
          OUT = 4;

//==============================================//
//                 reg declaration              //
//==============================================// 


reg [3:0] c_state, n_state ;

reg signed [18:0] noodle_remain, broth_remain, t_soup_remain, miso_remain ,soy_reamin  ;
reg signed [18:0] noodle_remain_c, broth_remain_c, t_soup_remain_c, miso_remain_c ,soy_reamin_c  ;
reg signed [18:0] noodle_remain_c_f, broth_remain_c_f, t_soup_remain_c_f, miso_remain_c_f ,soy_reamin_c_f  ;

reg [14:0] total_gain_reg;
reg portion_type_reg ; // 1'b0 samll , 1'b1:big
reg [1:0] ramen_type_reg ; // 1'b0 samll , 1'b1:big

reg [1:0] order_cnt, nxt_order_cnt;

reg [18:0] p_cnt, nxt_p_cnt;

reg check_result,check_result_reg;

reg [7:0] type_T_cnt, type_TS_cnt, type_MISO_cnt, type_MISO_SOY_cnt;

//==============================================//
//                    Design                    //
//==============================================//

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
                n_state = GET_ORDER;
            end
            else n_state = c_state;
		end
		GET_ORDER: begin
            if (order_cnt == 1 ) begin
                n_state = CHECK;
            end
            else n_state = c_state;
		end
        CHECK: begin
            n_state = RESPONSE;
            // if (check_result) begin
                
            // end
            // else n_state = c_state;
        end
		RESPONSE: begin
            if (!selling) begin
                n_state = OUT;
            end
            else n_state = IDLE;
        end
        OUT : begin
            n_state = IDLE;
        end
		default: n_state = c_state;
	endcase
end
//cnt for order 
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        order_cnt <= 0;
    end else order_cnt <= nxt_order_cnt;
end

always @(*) begin
    if (c_state== IDLE) begin
        nxt_order_cnt = 0;
    end else if (c_state == GET_ORDER) begin
        nxt_order_cnt = order_cnt + 1;
    end
    else nxt_order_cnt = order_cnt;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        p_cnt <= 0;
    end else p_cnt <= nxt_p_cnt;
end

always @(*) begin
    if (c_state == GET_ORDER &&n_state == CHECK  ) begin
        nxt_p_cnt = p_cnt + 1;
    end
    else nxt_p_cnt = p_cnt;
end

always @(posedge clk) begin
    if (nxt_order_cnt == 0 && n_state == GET_ORDER) begin
        ramen_type_reg = ramen_type;
    end else ramen_type_reg = ramen_type_reg;
end

always @(posedge clk) begin
    if (nxt_order_cnt == 1 && c_state == GET_ORDER) begin
        portion_type_reg = portion;
    end else portion_type_reg = portion_type_reg;
end




// remain 

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        noodle_remain <= NOODLE_INIT;
    end else if (c_state == OUT) noodle_remain <= NOODLE_INIT;
    else noodle_remain <=  noodle_remain_c;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        broth_remain <= BROTH_INIT;
    end else if (c_state == OUT) broth_remain <= BROTH_INIT;
    else broth_remain <=  broth_remain_c;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        t_soup_remain <= TONKOTSU_SOUP_INIT;
    end  else if (c_state == OUT) t_soup_remain <= TONKOTSU_SOUP_INIT;
    else t_soup_remain <=  t_soup_remain_c;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        soy_reamin <= SOY_SAUSE_INIT;
    end  else if (c_state == OUT) soy_reamin <= SOY_SAUSE_INIT;
    else soy_reamin <=  soy_reamin_c;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        miso_remain <= MISO_INIT;
    end  else if (c_state == OUT)  miso_remain <= MISO_INIT;
    else miso_remain <=  miso_remain_c;
end


always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		type_T_cnt <= 0;
        type_TS_cnt <= 0;
        type_MISO_cnt <= 0;
        type_MISO_SOY_cnt <= 0;
	end
    else if(c_state == OUT)begin
        type_T_cnt <= 0;
        type_TS_cnt <= 0;
        type_MISO_cnt <= 0;
        type_MISO_SOY_cnt <= 0;
    end
    else if (c_state == RESPONSE) begin
        if (check_result_reg) begin
            case (ramen_type_reg)
                0: type_T_cnt <= type_T_cnt +1;
                1: type_TS_cnt <= type_TS_cnt +1 ;
                2: type_MISO_cnt <= type_MISO_cnt + 1;
                3:  type_MISO_SOY_cnt <= type_MISO_SOY_cnt + 1;
            endcase
        end
    end
	else begin
        type_T_cnt <= type_T_cnt;
        type_TS_cnt <= type_TS_cnt;
        type_MISO_cnt <= type_MISO_cnt;
        type_MISO_SOY_cnt <= type_MISO_SOY_cnt;
    end
end

always @(*) begin
    noodle_remain_c = noodle_remain;
    broth_remain_c = broth_remain;
    t_soup_remain_c = t_soup_remain;
    soy_reamin_c = soy_reamin;
    miso_remain_c = miso_remain;

    if (c_state == RESPONSE && portion_type_reg == 0 && check_result_reg == 1) begin
        case (ramen_type_reg)
            0 : begin
                broth_remain_c = broth_remain - 300;
                t_soup_remain_c = t_soup_remain - 150;
                noodle_remain_c = noodle_remain - 100;
            end 
            1 : begin
                broth_remain_c = broth_remain - 300;
                t_soup_remain_c = t_soup_remain -100;      
                soy_reamin_c = soy_reamin -30;  
                noodle_remain_c = noodle_remain - 100;   
            end 
            2 : begin
                broth_remain_c = broth_remain - 400;    
                miso_remain_c = miso_remain - 30;   
                noodle_remain_c = noodle_remain - 100;     
            end 
            3 : begin
                broth_remain_c = broth_remain - 300;
                t_soup_remain_c = t_soup_remain - 70;      
                soy_reamin_c = soy_reamin -15; 
                miso_remain_c = miso_remain - 15;
                noodle_remain_c = noodle_remain - 100;
            end 
        endcase 
    end
    else if(c_state == RESPONSE && portion_type_reg == 1 && check_result_reg == 1)begin
        case (ramen_type_reg)
            0 : begin
                broth_remain_c = broth_remain - 500;
                t_soup_remain_c = t_soup_remain - 200;
                noodle_remain_c = noodle_remain - 150;
            end 
            1 : begin
                broth_remain_c = broth_remain - 500;
                t_soup_remain_c = t_soup_remain -150;      
                soy_reamin_c = soy_reamin -50;  
                noodle_remain_c = noodle_remain - 150;   
            end 
            2 : begin
                broth_remain_c = broth_remain - 650;    
                miso_remain_c = miso_remain - 50;   
                noodle_remain_c = noodle_remain - 150;     
            end 
            3 : begin
                broth_remain_c = broth_remain - 500;
                t_soup_remain_c = t_soup_remain - 100;      
                soy_reamin_c = soy_reamin -25; 
                miso_remain_c = miso_remain - 25;
                noodle_remain_c = noodle_remain - 150;
            end 
        endcase 
        
    end
end

always @(*) begin
    noodle_remain_c_f = noodle_remain;
    broth_remain_c_f = broth_remain;
    t_soup_remain_c_f = t_soup_remain;
    soy_reamin_c_f = soy_reamin;
    miso_remain_c_f = miso_remain;

    if (c_state == CHECK && portion_type_reg == 0) begin
        case (ramen_type_reg)
            0 : begin
                broth_remain_c_f = broth_remain - 300;
                t_soup_remain_c_f = t_soup_remain - 150;
                noodle_remain_c_f = noodle_remain - 100;
            end 
            1 : begin
                broth_remain_c_f = broth_remain - 300;
                t_soup_remain_c_f = t_soup_remain -100;      
                soy_reamin_c_f = soy_reamin -30;  
                noodle_remain_c_f = noodle_remain - 100;   
            end 
            2 : begin
                broth_remain_c_f = broth_remain - 400;    
                miso_remain_c_f = miso_remain - 30;   
                noodle_remain_c_f = noodle_remain - 100;     
            end 
            3 : begin
                broth_remain_c_f = broth_remain - 300;
                t_soup_remain_c_f = t_soup_remain - 70;      
                soy_reamin_c_f = soy_reamin -15; 
                miso_remain_c_f = miso_remain - 15;
                noodle_remain_c_f = noodle_remain - 100;
            end 
        endcase 
    end
    else if(c_state == CHECK && portion_type_reg == 1)begin
        case (ramen_type_reg)
            0 : begin
                broth_remain_c_f = broth_remain - 500;
                t_soup_remain_c_f = t_soup_remain - 200;
                noodle_remain_c_f = noodle_remain - 150;
            end 
            1 : begin
                broth_remain_c_f = broth_remain - 500;
                t_soup_remain_c_f = t_soup_remain -150;      
                soy_reamin_c_f = soy_reamin -50;  
                noodle_remain_c_f = noodle_remain - 150;   
            end 
            2 : begin
                broth_remain_c_f = broth_remain - 650;    
                miso_remain_c_f = miso_remain - 50;   
                noodle_remain_c_f = noodle_remain - 150;     
            end 
            3 : begin
                broth_remain_c_f = broth_remain - 500;
                t_soup_remain_c_f = t_soup_remain - 100;      
                soy_reamin_c_f = soy_reamin -25; 
                miso_remain_c_f = miso_remain - 25;
                noodle_remain_c_f = noodle_remain - 150;
            end 
        endcase 
        
    end
end


always @(posedge clk) begin
    if (n_state == GET_ORDER) begin
        check_result_reg = 0;
    end else if ( c_state == CHECK ) check_result_reg  = check_result;
    else check_result_reg  = check_result_reg;
end
// check_result
always @(*) begin
    check_result = 0;
    if (c_state == CHECK) begin
        case (ramen_type_reg)
            0 : begin
                if (broth_remain_c_f < 0 || t_soup_remain_c_f < 0 ||  noodle_remain_c_f< 0) begin
                    check_result = 0;
                end else check_result = 1;
            end 
            1 : begin
                if (broth_remain_c_f < 0 || t_soup_remain_c_f < 0 ||  noodle_remain_c_f< 0 || soy_reamin_c_f < 0) begin
                    check_result = 0;
                end else check_result = 1;
            end 
            2 : begin
                if (broth_remain_c_f < 0 || miso_remain_c_f < 0 ||  noodle_remain_c_f <0) begin
                    check_result = 0;
                end else check_result = 1;  
            end 
            3 : begin
                if (broth_remain_c_f < 0 || t_soup_remain_c_f < 0 ||  noodle_remain_c_f < 0 || soy_reamin_c_f < 0 || miso_remain_c_f < 0  ) begin
                    check_result = 0;
                end else check_result = 1;
            end 
        endcase 
    end
end


always @(*) begin
    success = 0;
    if (c_state == RESPONSE ) begin
        success = (check_result_reg) ? 1: 0;
    end
end

always @(*) begin
    out_valid_order = 0;
    if (c_state == RESPONSE) begin
        out_valid_order = 1;
    end
end




// output logic

always @(*) begin
    if (c_state == OUT) begin
        sold_num[27:21] = type_T_cnt;
        sold_num[20:14] = type_TS_cnt;
        sold_num[13:7] = type_MISO_cnt;
        sold_num[6:0] = type_MISO_SOY_cnt;
    end
    else sold_num = 0;
end

always @(*) begin
    if (c_state == OUT) begin
        total_gain = sold_num[27:21]* 200 + sold_num[20:14]* 250 + sold_num[13:7] * 200 + sold_num[6:0] * 250;
    end
    else total_gain = 0;
end

always @(*) begin
    if (c_state == OUT) begin
        out_valid_tot = 1;
    end
    else out_valid_tot = 0;
end

endmodule



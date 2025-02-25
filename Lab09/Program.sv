module Program(input clk, INF.Program_inf inf);
import usertype::*;

typedef enum logic[3:0] {
    IDLE         = 4'd0,
    GET_ACTION   = 4'd1,
    FETCH_DATA   = 4'd2,
    UPDATE       = 4'd3,
    CHECK_DATE   = 4'd4,
    CALC         = 4'd5,
    CHECK_RESULT = 4'd6,
    WRITEBACK    = 4'd7,
    OUT_VIOLATE  = 4'd8,
    OUT          = 4'd9
} state_type;

//================================================================
// DEFINE TYPE ANDd LOGIC
//================================================================

state_type c_state, n_state;
Date date_early;
Action action_reg;
Date date_reg;
Order_Info order_reg;
Data_No data_no_reg;

logic if_date_valid, if_date_valid_c;
logic if_risk_warning, if_risk_warning_c;
logic if_data_warning, if_data_warning_c;

logic [2:0] idx_cnt, idx_cnt_c;
logic [2:0] c_cnt, c_cnt_c;
logic dram_data_receive;

// FOR TI
Index cmp_0_in[0:1], cmp_1_in[0:1];
Index cmp_0_out[0:1], cmp_1_out[0:1];
// FOR G
Index cmp_2_in[0:1], cmp_3_in[0:1];
Index cmp_2_out[0:1], cmp_3_out[0:1];
// FOR I & G
Index add_0_in[0:1], add_1_in[0:1];
logic [12:0]  add_0_out, add_1_out;
// FOR DE
Index add_2_in[0:1], add_3_in[0:1];
logic [12:0] add_2_out, add_3_out;

Index sub_0_in[0:1];
logic [12:0] sub_0_out;

Index index_I[0:3];
Index index_I_W[0:3];
logic signed [13:0] index_I_VAR[0:3];
Index index_TI [0:3];
Index index_G [0:3];
Index index_R;
Index index_temp_max, index_temp_max_c;
Index index_temp_min, index_temp_min_c;
// Index index_G_temp_max, index_G_temp_max_c;
// Index index_G_temp_min, index_G_temp_min_c;
Index index_G_temp_min1, index_G_temp_min1_c;
Index index_MAX_I;
Index index_MIN_I;
Index index_MAX_G;
Index index_MIN_G;
Index R_result[0:7];

logic [13:0] index_I_updated[0:3];
logic [13:0] index_I_updated_c[0:3];

//================================================================
// DESIGN
//================================================================

always_ff @( posedge clk or negedge inf.rst_n ) begin : FSM_C
    if (!inf.rst_n) begin
        c_state <= IDLE;
    end else c_state <= n_state;
end

always_comb begin : FSM_N
    n_state = c_state;
    case (c_state)
        IDLE : begin
            if (inf.sel_action_valid) begin
                n_state = GET_ACTION;
            end
        end 
        GET_ACTION : begin
            if (inf.data_no_valid) begin
                n_state = FETCH_DATA;
            end            
        end

        FETCH_DATA : begin
            if (inf.R_VALID) begin
                if (action_reg == Update) begin
                    n_state = CALC;
                end
                else n_state = CHECK_DATE;
            end
        end

        CHECK_DATE: begin
            if (if_date_valid_c) begin
                if (action_reg == Index_Check) begin
                    n_state = CALC;
                end
                else n_state = OUT;
            end
            else if((idx_cnt == 4 && action_reg == Index_Check) || action_reg == Check_Valid_Date)begin
               n_state = OUT_VIOLATE; 
            end
        end
        CALC: begin
            if (action_reg == Index_Check) begin
                if (c_cnt == 7) begin
                    n_state = CHECK_RESULT;
                end
            end
            else if (action_reg == Update) begin
                 if (c_cnt == 4) begin
                    n_state = CHECK_RESULT;
                end               
            end
        end
        CHECK_RESULT : begin
            if (action_reg == Update) begin
                n_state = WRITEBACK; 
            end
            else if (action_reg == Index_Check && if_risk_warning_c) begin
                n_state = OUT_VIOLATE;
            end
            else n_state = OUT; 
        end
        WRITEBACK : begin
            if (inf.B_VALID && if_data_warning) begin
                n_state = OUT_VIOLATE; 
            end 
            else if(inf.B_VALID)  n_state = OUT; 
        end
        OUT_VIOLATE: begin
            n_state = IDLE;
        end
        OUT: begin
            n_state = IDLE;
        end
    endcase
end

// store reg
always_ff @( posedge clk or negedge inf.rst_n ) begin :act_store
    if (!inf.rst_n) begin
        action_reg <= Index_Check;
    end
    else if (inf.sel_action_valid) begin
        action_reg <= inf.D.d_act[0];
    end
    else action_reg <= action_reg;
end


always_ff @( posedge clk or negedge inf.rst_n ) begin :mode_store
    if (!inf.rst_n) begin
        order_reg.Formula_Type_O <= Formula_A;
        order_reg.Mode_O <= Insensitive;
    end
    else if (c_state == IDLE) begin
         order_reg.Formula_Type_O <= 0;
    end
    else if (inf.formula_valid) begin
         order_reg.Formula_Type_O <= inf.D.d_formula[0];
    end
    else if (inf.mode_valid) begin
         order_reg.Mode_O <= inf.D.d_mode[0];
    end
    else begin
        order_reg.Formula_Type_O <= order_reg.Formula_Type_O;
         order_reg.Mode_O <=  order_reg.Mode_O ;
    end
end


always_ff @( posedge clk or negedge inf.rst_n ) begin :date_store
    if (!inf.rst_n) begin
        date_reg.M <= 0;
        date_reg.D <= 0;
    end
    else if (inf.date_valid) begin
        date_reg <= inf.D.d_date[0];
    end
    else begin
        date_reg.M <= date_reg.M;
        date_reg.D <= date_reg.D;
    end
end

always_ff @( posedge clk or negedge inf.rst_n ) begin :data_store
    if (!inf.rst_n) begin
        data_no_reg <= 0;
    end
    else if (inf.data_no_valid) begin
        data_no_reg <= inf.D.d_data_no[0];
    end
    else data_no_reg <= data_no_reg;
end

// TODAY INDEX 
always_ff @( posedge clk or negedge inf.rst_n ) begin :index_store
    integer i;
    if (!inf.rst_n) begin
        for (i = 0; i < 4; i++)begin
            index_TI[i] <= 0;
        end
    end
    else if (inf.index_valid) begin
        index_TI[idx_cnt] <= inf.D.d_index[0];
    end
    else begin
        for (i = 0; i < 4; i=i+1)begin
            index_TI[i] <= index_TI[i];
        end
    end
end
// TODAY INDEX  COUNTER
always_ff @( posedge clk or negedge inf.rst_n ) begin : idx_cnt_logic
    if (!inf.rst_n) begin
        idx_cnt <= 0;
    end 
    else idx_cnt <= idx_cnt_c;
end

always_comb begin : idx_cnt_c_logic
    idx_cnt_c = idx_cnt;
    if (inf.index_valid) begin
        idx_cnt_c = idx_cnt + 1;
    end
    else if (c_state == IDLE) idx_cnt_c = 0;
    else idx_cnt_c = idx_cnt;
end

always_ff @( posedge clk or negedge inf.rst_n ) begin : c_cnt_logic
    if (!inf.rst_n) begin
        c_cnt <= 0;
    end 
    else c_cnt <= c_cnt_c;
end

always_comb begin : c_cnt_c_logic
    c_cnt_c = c_cnt;
    if (c_state == IDLE) c_cnt_c = 0;
    else if (idx_cnt == 4 && dram_data_receive && c_cnt < 7) begin
        c_cnt_c = c_cnt + 1;
    end
    else c_cnt_c = c_cnt;
end

//================================================================
// DRAM signal handling
//================================================================

always_ff @( posedge clk or negedge inf.rst_n ) begin : if_dram_data
    if (!inf.rst_n) begin
        dram_data_receive <= 0;
    end
    else if(inf.R_VALID && inf.R_READY)begin
        dram_data_receive <= 1;
    end
    else if (c_state == IDLE) begin
        dram_data_receive <= 0;
    end else dram_data_receive <= dram_data_receive;
end

always_ff @( posedge clk or negedge inf.rst_n ) begin : dram_data_buffer
    if (!inf.rst_n) begin
        date_early.M <= 0;
        date_early.D <= 0;
        index_I[0] <= 0;
        index_I[1] <= 0;
        index_I[2] <= 0;
        index_I[3] <= 0;       
    end
    else if (inf.R_VALID) begin
        index_I[0]   <=   inf.R_DATA[63:52];
        index_I[1]   <=   inf.R_DATA[51:40];
        date_early.M <=   inf.R_DATA[39:32];
        index_I[2]   <=   inf.R_DATA[31:20];
        index_I[3]   <=   inf.R_DATA[19:8];    
        date_early.D <=   inf.R_DATA[7:0];
    end
    else begin
        if ((order_reg.Formula_Type_O == Formula_F || order_reg.Formula_Type_O == Formula_G || order_reg.Formula_Type_O == Formula_H) && action_reg == Index_Check ) begin
                   case (c_cnt)
            1 : begin
                index_I[0] <= sub_0_out;
            end 
            2 : begin
                index_I[1] <= sub_0_out;
            end
            3 : begin
                index_I[2] <= sub_0_out;
            end
            4 : begin
                index_I[3] <= sub_0_out;
            end
        endcase  
        end      
    end
end

// always_ff @( posedge clk ) begin : idx_G_reg
//     case (c_cnt)
//         1 : begin
//            index_G[0] <= sub_0_out;
//         end 
//         2 : begin
//            index_G[1] <= sub_0_out;
//         end
//         3 : begin
//            index_G[2] <= sub_0_out;
//         end
//         4 : begin
//            index_G[3] <= sub_0_out;
//         end
//     endcase
// end

//================================================================
// CHECK DATE
//================================================================

always_ff @( posedge clk or negedge inf.rst_n) begin : check_date
    if (!inf.rst_n) begin
        if_date_valid <= 1;
    end
    else if_date_valid <=  if_date_valid_c;
end

always_comb begin : check_data_c
    if_date_valid_c = if_date_valid;
    if (c_state == IDLE) begin
            if_date_valid_c = 1;
    end
    else if (c_state == CHECK_DATE)  begin
        if(date_reg.M > date_early.M)begin
            if_date_valid_c = 1;
        end
        else if (date_reg.M == date_early.M && date_reg.D >= date_early.D) begin
            if_date_valid_c = 1;
        end
        else if_date_valid_c = 0;
    end 
end

//================================================================
// FORMULA CALC
//================================================================
logic [13:0] R_5_acc , R_0_7_acc ,  R_0_6_acc;
Index R_0_7_acc_in;
logic [11:0] R_5_ans;

logic if_I_bigger_than_2047;
Index if_I_bigger_than_2047_in;
logic [2:0] R_3_acc;

Index cmp_I_TI_in1, cmp_I_TI_in2, cmp_I_TI_out;
Index cmp_I_TI_in1_1, cmp_I_TI_in2_1;
logic if_I_big_TI, if_I_big_TI_1;


//================================================================
// Index G  Calculations
//================================================================


always_ff @( posedge clk ) begin : index_G_sub_in
    case (c_cnt)
        0 : begin
           if (if_I_big_TI_1) begin
                sub_0_in[0] <= index_I[0];
                sub_0_in[1] <= index_TI[0];
           end 
           else begin
                sub_0_in[0] <= index_TI[0];
                sub_0_in[1] <= index_I[0];    
           end
        end 
        1 : begin
           if (if_I_big_TI_1) begin
                sub_0_in[0] <= index_I[1];
                sub_0_in[1] <= index_TI[1];
           end 
           else begin
                 sub_0_in[0] <= index_TI[1];
                sub_0_in[1] <= index_I[1];    
           end
        end
        2 : begin
           if (if_I_big_TI_1) begin
                sub_0_in[0] <= index_I[2];
                sub_0_in[1] <= index_TI[2];
           end 
           else begin
                sub_0_in[0] <= index_TI[2];
                sub_0_in[1] <= index_I[2];    
           end
        end
        3 : begin
           if (if_I_big_TI_1) begin
                sub_0_in[0] <= index_I[3];
                sub_0_in[1] <= index_TI[3];
           end 
           else begin
                sub_0_in[0] <= index_TI[3];
                sub_0_in[1] <= index_I[3];    
           end
        end
        // 5 : begin
        //     sub_0_in[0] <= index_MAX_I;  
        //     sub_0_in[1] <= index_MIN_I;
        // end
        default: begin
            sub_0_in[0] <= index_temp_max;  
            sub_0_in[1] <= index_temp_min;     
        end
    endcase
end


always_comb begin : R_sub_in
    sub_0_out = sub_0_in[0] + ~sub_0_in[1] + 1'b1;
end

// always_ff @( posedge clk ) begin : idx_G_reg
//     case (c_cnt)
//         1 : begin
//            index_G[0] <= sub_0_out;
//         end 
//         2 : begin
//            index_G[1] <= sub_0_out;
//         end
//         3 : begin
//            index_G[2] <= sub_0_out;
//         end
//         4 : begin
//            index_G[3] <= sub_0_out;
//         end
//     endcase
// end


//================================================================
// FORMULA  A  and H calculation
//================================================================

always_comb begin : R_0_7_acc_in_
        case (c_cnt)
            2 : begin
                R_0_7_acc_in = index_I[0]  ;
            end 
            3 : begin
                R_0_7_acc_in = index_I[1]  ;
            end
            4 : begin
                R_0_7_acc_in = index_I[2]  ;
            end
            5 : begin
                R_0_7_acc_in = index_I[3]  ;
            end
            default: R_0_7_acc_in = 0;
        endcase
end


always_ff @( posedge clk or negedge inf.rst_n )begin : R_0_7_acc_
    if (!inf.rst_n) begin
        R_0_7_acc <= 0;
    end
    else if (c_state == IDLE) begin
        R_0_7_acc <= 0;
    end
    else begin
        case (c_cnt)
            2,3,4,5 : begin
                if (order_reg.Formula_Type_O == Formula_G) begin
                    R_0_7_acc <= R_0_7_acc + ( R_0_7_acc_in >> 2) ;
                end
                else begin
                    R_0_7_acc <= R_0_7_acc + R_0_7_acc_in ;
                end
            end 

            default: R_0_7_acc <= R_0_7_acc;
        endcase
    end
end

//================================================================
// FORMULA F calculation
//================================================================


always_ff @( posedge clk)begin : R_5_acc_divide
    R_5_ans <= R_5_acc / 3;
end

always_ff @( posedge clk)begin : R_5_acc_
    if (c_state == IDLE) begin
        R_5_acc <= 0;
    end
    else begin
        case (c_cnt)
            4 : begin
                R_5_acc <= R_5_acc + index_G_temp_min1 ;
            end
            5 : begin
                R_5_acc <= R_5_acc + index_G_temp_min1 ;
            end
            6 : begin
                R_5_acc <= R_5_acc + index_G_temp_min1;
            end
            default: R_5_acc <= R_5_acc;
        endcase
    end
end


//================================================================
// FORMULA  B F and G comparison function
//================================================================

always_comb begin : R_1_cmp
    // max
    cmp_0_out[0] = (cmp_0_in[0] > cmp_0_in[1] ) ? cmp_0_in[0]:cmp_0_in[1] ;
    // min
    cmp_0_out[1] = (cmp_0_in[0] > cmp_0_in[1] ) ? cmp_0_in[1]:cmp_0_in[0] ;

    cmp_1_out[0] = (cmp_1_in[0] > cmp_1_in[1] ) ? cmp_1_in[0]:cmp_1_in[1] ;
    // min
    cmp_1_out[1] = (cmp_1_in[0] > cmp_1_in[1] ) ? cmp_1_in[1]:cmp_1_in[0] ;
end

always_comb begin : R_1_in_index_I
    case (c_cnt)
        2 : begin
            cmp_0_in[0] = index_I[0]; cmp_0_in[1] = index_I[1];
            cmp_1_in[0] = index_I[0]; cmp_1_in[1] = index_I[1];
        end 
        3 : begin
            if (order_reg.Formula_Type_O == Formula_G || order_reg.Formula_Type_O == Formula_F) begin
                // cmp_0_in[0] = index_G[0]; cmp_0_in[1] = index_G[1];
                // cmp_1_in[0] = index_G[0]; cmp_1_in[1] = index_G[1];     
                cmp_0_in[0] = index_I[0]; cmp_0_in[1] = index_I[1];
                cmp_1_in[0] = index_I[0]; cmp_1_in[1] = index_I[1];              
            end
            else begin
                cmp_0_in[0] = index_I[2]; cmp_0_in[1] = index_temp_max;
                cmp_1_in[0] = index_I[2]; cmp_1_in[1] = index_temp_min;
            end
        end
        4 : begin
            if (order_reg.Formula_Type_O == Formula_G || order_reg.Formula_Type_O == Formula_F) begin
                cmp_0_in[0] = index_I[2]; cmp_0_in[1] = index_temp_max;
                cmp_1_in[0] = index_I[2]; cmp_1_in[1] = index_temp_min;             
            end   
            else begin        
                cmp_0_in[0] = index_I[3]; cmp_0_in[1] = index_temp_max;
                cmp_1_in[0] = index_I[3]; cmp_1_in[1] = index_temp_min;
            end
        end
        5 : begin
            if (order_reg.Formula_Type_O == Formula_G || order_reg.Formula_Type_O == Formula_F) begin
                cmp_0_in[0] = index_I[3]; cmp_0_in[1] = index_temp_max;
                cmp_1_in[0] = index_I[3]; cmp_1_in[1] = index_temp_min;
            end
            else begin        
                cmp_0_in[0] = index_I[3]; cmp_0_in[1] = index_temp_max;
                cmp_1_in[0] = index_I[3]; cmp_1_in[1] = index_temp_min;
            end
        end
        default: begin
            cmp_0_in[0] = 0; cmp_0_in[1] = 0;
            cmp_1_in[0] = 0; cmp_1_in[1] = 0;      
        end
    endcase
end

always_comb begin : R_1_out
    index_temp_max_c =  cmp_0_out[0];
    index_temp_min_c =  cmp_1_out[1];           
end

always_ff @( posedge clk ) begin : R_1_temp_reg
    if (c_cnt < 6) begin
        index_temp_max <= index_temp_max_c;
        index_temp_min <= index_temp_min_c;        
    end

end


//================================================================
// FORMULA G comparison function
//================================================================
always_comb begin : R_G_out
    index_G_temp_min1_c =  cmp_0_out[1];       
end

always_ff @( posedge clk ) begin : R_G_
    index_G_temp_min1 <=  index_G_temp_min1_c;          
end


//================================================================
// FORMULA D and E calculation
//================================================================
// R_4 and R_3 CALCULATION
always_ff @( posedge clk ) begin : R_E_calc
    if (c_state == IDLE) begin
        R_result[4] <= 0;
    end
    else begin
        case (c_cnt)
            1,2,3,4 : begin
            if (order_reg.Formula_Type_O == Formula_E) begin
                R_result[4] <= R_result[4] + if_I_big_TI;
            end 
            else if (order_reg.Formula_Type_O == Formula_D) begin
                R_result[4] <= R_result[4] + if_I_bigger_than_2047;
            end
            end 
        endcase        
    end

end


always_comb begin : bigger_than_2047
    if_I_bigger_than_2047 = (if_I_bigger_than_2047_in >= 2047);
end

always_comb begin : bigger_than_2047_in
    case (c_cnt)
        1 : begin
            if_I_bigger_than_2047_in = index_I[0] ;
        end
        2 : begin
            if_I_bigger_than_2047_in = index_I[1];
        end
        3 : begin
            if_I_bigger_than_2047_in = index_I[2];
        end
        4 : begin
            if_I_bigger_than_2047_in = index_I[3];
        end
        default: if_I_bigger_than_2047_in = 0;
    endcase
end


//================================================================
// FORMULA E comparison function
//================================================================

always_comb begin : index_cmp_I_TI_1
    if_I_big_TI_1 = (cmp_I_TI_in1_1 >= cmp_I_TI_in2_1);
end

always_comb begin : index_cmp_I_TI_
    if_I_big_TI = (cmp_I_TI_in1 >= cmp_I_TI_in2);
end

always_comb begin : index_cmp_I_TI_input_1
    case (c_cnt)
        0 : begin
            cmp_I_TI_in1_1 = index_I[0]; cmp_I_TI_in2_1 = index_TI[0];    
        end 
        1 : begin
            cmp_I_TI_in1_1 = index_I[1]; cmp_I_TI_in2_1 = index_TI[1];
        end
        2 : begin
            cmp_I_TI_in1_1 = index_I[2]; cmp_I_TI_in2_1 = index_TI[2];
        end
        3 : begin
            cmp_I_TI_in1_1 = index_I[3]; cmp_I_TI_in2_1 = index_TI[3];
        end
        default: begin
            cmp_I_TI_in1_1 = 0; cmp_I_TI_in2_1 = 0;          
        end
    endcase
end

always_comb begin : index_cmp_I_TI_input
    case (c_cnt)
        1 : begin
            cmp_I_TI_in1 = index_I[0]; cmp_I_TI_in2 = index_TI[0];    
        end 
        2 : begin
            cmp_I_TI_in1 = index_I[1]; cmp_I_TI_in2 = index_TI[1];
        end
        3 : begin
            cmp_I_TI_in1 = index_I[2]; cmp_I_TI_in2 = index_TI[2];
        end
        4 : begin
            cmp_I_TI_in1 = index_I[3]; cmp_I_TI_in2 = index_TI[3];
        end
        default: begin
            cmp_I_TI_in1 = 0; cmp_I_TI_in2 = 0;          
        end
    endcase
end



//================================================================
// FORMULA Results
//================================================================

always_comb begin : R_0_A
    R_result[0] = R_0_7_acc >> 2;
end

always_comb begin : R_1_B
    R_result[1] = sub_0_out;
end
always_comb begin : R_2_C
    R_result[2] = index_temp_min;
end
always_comb begin : R_3_D
    R_result[3] = R_result[4] ; 
end
always_comb begin : R_5_F
    R_result[5] = R_5_ans ;
end
always_comb begin : R_6_G
    R_result[6] = R_0_7_acc - (index_temp_max >> 2) - (index_temp_min >>2)  + (index_temp_min >>1) ;
end
always_comb begin : R_7_H
    R_result[7] = R_0_7_acc >> 2;
end

always_comb begin : index_R_assign
   case ( order_reg.Formula_Type_O)
        Formula_A :  index_R = R_result[0];
        Formula_B :  index_R = R_result[1];
        Formula_C :  index_R = R_result[2];
        Formula_D :  index_R = R_result[3];
        Formula_E :  index_R = R_result[4];
        Formula_F :  index_R = R_result[5];
        Formula_G :  index_R = R_result[6];
        Formula_H :  index_R = R_result[7];
    endcase
end

//================================================================
// Update calculation
//================================================================

always_ff @( posedge clk or negedge inf.rst_n ) begin : index_update_calc
    integer i;
    if (!inf.rst_n) begin
        for (i = 0 ; i < 4 ; i++ ) begin
            index_I_updated[i] <= 0;
        end
    end
    else begin
        for (i = 0 ; i < 4 ; i++ ) begin
            index_I_updated[i] <= index_I_updated_c[i];
        end        
    end
end

always_comb begin : index_var_I
    integer i;
    for (i = 0 ; i < 4 ; i=i+1) begin
        index_I_VAR[i] = { index_TI[i][11],index_TI[i][11], index_TI[i]};
    end    
end

logic signed [12:0] add_var_in0, add_var_in1;
logic signed [13:0] add_var_out;

always_comb begin : index_update_add_func
    add_var_out = add_var_in0 + add_var_in1;
end

always_comb begin : index_update_add__input_c
    add_var_in0 = 0; add_var_in1 = 0;
    case (c_cnt)
        1 : begin
            add_var_in0 = {2'b00, index_I[0]};  add_var_in1 = index_I_VAR[0] ;
        end 
        2 : begin
            add_var_in0 = {2'b00, index_I[1]};  add_var_in1 = index_I_VAR[1] ;
        end
        3 : begin
            add_var_in0 = {2'b00, index_I[2]};  add_var_in1 = index_I_VAR[2] ;
        end  
        4 : begin
            add_var_in0 = {2'b00, index_I[3]};  add_var_in1 = index_I_VAR[3] ;
        end 
    endcase
end


always_comb begin : index_update_calc_c
    integer i;
    for (i = 0 ; i < 4 ; i=i+1) begin
        index_I_updated_c[i] = index_I_updated[i];
    end
    if (c_state == CHECK_RESULT && n_state == WRITEBACK) begin
        for (i = 0 ; i < 4 ; i=i+1) begin
            if(index_I_updated[i][13])begin
                index_I_updated_c[i] = 0;
            end
            else if (index_I_updated[i][12]) begin
                index_I_updated_c[i] = 4095;
            end
        end
    end
    else if (c_state == CALC) begin
        case (c_cnt)
            1 : begin
                index_I_updated_c[0] = add_var_out;
            end 
            2 : begin
                index_I_updated_c[1] = add_var_out;
            end
            3 : begin
                index_I_updated_c[2] = add_var_out;
            end  
            4 : begin
                index_I_updated_c[3] = add_var_out;
            end 
        endcase
    end

end

//================================================================
// RISK WARNING CHECK
//================================================================
always_ff @( posedge clk or negedge inf.rst_n ) begin : check_Risk
    if (!inf.rst_n) begin
        if_risk_warning <= 0;
    end
    else begin
        if_risk_warning <= if_risk_warning_c;
    end
end

always_comb begin : check_risk_warning
    if_risk_warning_c = if_risk_warning;
    if(c_state == IDLE)begin
        if_risk_warning_c = 0;
    end
    else if (c_state == CHECK_RESULT && action_reg == Index_Check) begin
        case (order_reg.Formula_Type_O)
            Formula_A, Formula_C :  begin
                case (order_reg.Mode_O)
                    Insensitive: begin
                        if (index_R >= 2047) begin
                            if_risk_warning_c = 1;
                        end                        
                    end
                    Normal: begin
                        if (index_R >= 1023) begin
                            if_risk_warning_c = 1;
                        end 
                    end 
                    Sensitive: begin
                        if (index_R >= 511) begin
                            if_risk_warning_c = 1;
                        end 
                    end
                endcase
            end
            Formula_B, Formula_F, Formula_G, Formula_H :  begin
                case ( order_reg.Mode_O)
                    Insensitive: begin
                        if (index_R >= 800) begin
                            if_risk_warning_c = 1;
                        end                        
                    end
                    Normal: begin
                        if (index_R >= 400) begin
                            if_risk_warning_c = 1;
                        end 
                    end 
                    Sensitive: begin
                        if (index_R >= 200) begin
                            if_risk_warning_c = 1;
                        end 
                    end
                endcase
            end
            Formula_D, Formula_E :  begin
                case ( order_reg.Mode_O)
                    Insensitive: begin
                        if (index_R >= 3) begin
                            if_risk_warning_c = 1;
                        end                        
                    end
                    Normal: begin
                        if (index_R >= 2) begin
                            if_risk_warning_c = 1;
                        end 
                    end 
                    Sensitive: begin
                        if (index_R >= 1) begin
                            if_risk_warning_c = 1;
                        end 
                    end
                endcase
            end
        endcase
    end
end

//================================================================
// DATA WARNING CHECK
//================================================================

always_ff @( posedge clk or negedge inf.rst_n ) begin : check_data_warning
    if (!inf.rst_n) begin
        if_data_warning <= 0;
    end
    else if(c_state == IDLE)begin
        if_data_warning <= 0;
    end

    else if (c_state == CHECK_RESULT && action_reg == Update) begin
        if ((index_I_updated[0][12] || index_I_updated[0][13] ) || (index_I_updated[1][12] || index_I_updated[1][13]) || (index_I_updated[2][12] || index_I_updated[2][13])|| (index_I_updated[3][12]|| index_I_updated[3][13])) begin
            if_data_warning <= 1;
        end
    end
end
//================================================================
// DRAM READ
//================================================================

// AR_VALID, AR_ADDR, R_READY
logic [63:0] dram_data_in;
logic [1:0]  dram_data_cnt,dram_data_cnt_c;
 logic [16:0] ADDR;

always_comb begin : dram_addr
    ADDR = 65536 + ( data_no_reg << 3 ) ;
end

always_comb begin : dram_ar_addr
    if (!inf.rst_n) begin
        inf.AR_ADDR = 0;
    end
    else inf.AR_ADDR = ADDR ;
end

always_ff @( posedge clk or negedge inf.rst_n ) begin : dram_ar_valid
    if (!inf.rst_n) begin
        inf.AR_VALID <= 0;
    end
    else if (c_state == IDLE)begin
        inf.AR_VALID <= 0;
    end
    else if (inf.data_no_valid)begin
        inf.AR_VALID <= 1;
    end
    else if(inf.AR_READY) begin
        inf.AR_VALID <= 0;
    end
    else inf.AR_VALID <= inf.AR_VALID;
end

//================================================================
// DRAM WRITE
//================================================================

// AW_VALID, AW_ADDR, W_VALID, W_DATA, B_READY
always_ff @( posedge clk or negedge inf.rst_n ) begin : dram_aw_valid
    if (!inf.rst_n) begin
        inf.AW_VALID <= 0;
    end
    else if (c_state == IDLE)begin
        inf.AW_VALID <= 0;
    end
    else if(inf.AW_READY) begin
        inf.AW_VALID <= 0;
    end
    else if (c_state == CHECK_RESULT && n_state == WRITEBACK  )begin
        inf.AW_VALID <= 1;
    end
    else inf.AW_VALID <= inf.AW_VALID;
end
always_comb begin : dram_aw_addr
    if (!inf.rst_n) begin
        inf.AW_ADDR = 0;
    end
    else inf.AW_ADDR = ADDR ;
end

always_ff @( posedge clk or negedge inf.rst_n ) begin : dram_w_valid
    if (!inf.rst_n) begin
        inf.W_VALID <= 0;
    end
    else if (!inf.W_READY) begin
        inf.W_VALID <= 1 ;
    end
    else begin
        inf.W_VALID <= 0;
    end

end

always_comb begin : dram_B_READY
	if (c_state == WRITEBACK) inf.B_READY = 1 ;
	else inf.B_READY = 0 ;
end

always_comb begin : WRITE_DATA_
    if (!inf.rst_n) begin
        inf.W_DATA  = 0;
    end
    else begin
        inf.W_DATA  = {index_I_updated[0][11:0],index_I_updated[1][11:0], {4'b0,date_reg.M}, index_I_updated[2][11:0],index_I_updated[3][11:0],{3'b0,date_reg.D}};
    end
end


//================================================================
// OUTPUT LOGIC 
//================================================================

always_comb begin : dram_r_ready
    inf.R_READY = 0;
    if (c_state == FETCH_DATA) begin
        inf.R_READY = 1;
    end else inf.R_READY = 0;
end

always_comb begin : out_logic
    inf.out_valid = 0;
    if (c_state == OUT || c_state == OUT_VIOLATE) begin
        inf.out_valid = 1;
    end
end


always_comb begin : out_violate_logic
    inf.warn_msg = 0;
    if ( c_state == OUT) begin
        inf.warn_msg = No_Warn;
    end
    else if(c_state == OUT_VIOLATE)begin
        if (!if_date_valid) begin
            inf.warn_msg = Date_Warn;
        end
        else if (if_risk_warning) begin
            inf.warn_msg = Risk_Warn;
        end
        else if (if_data_warning) begin
            inf.warn_msg = Data_Warn;
        end
    end
end

always_comb begin : out_compltet_logic
    inf.complete = 0;
    if (c_state == OUT) begin
        inf.complete = 1;
    end else if (c_state == OUT_VIOLATE) begin
        inf.complete = 0;
    end else begin
        inf.complete = 0;
    end
end



endmodule



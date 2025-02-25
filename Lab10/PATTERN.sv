
// `include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype.sv"
//`define CYCLE_TIME 10.0

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;
//================================================================
// parameters & integer
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";
parameter PAT_NUM = 5400;
parameter MAX_CYCLE = 1000;
parameter SEED = 10;//12345;

integer rand_stimulus;
integer exe_lat;
integer pat_cnt;
integer formula_cnt, mode_cnt;
integer i_pat;
integer i,j;
//================================================================
// wire & registers 
//================================================================
logic [7:0] golden_DRAM [((65536+8*256)-1):(65536+0)];  
logic [63:0] dram_data,_dram_data;
Warn_Msg _warn_msg;
logic _complete;
Index _index;
Index _index_R[0:7];
Index _index_MAX;
Index _index_MAX_G;
Index _index_MIN;
Index _index_I[0:3],w_index_I[0:3],wp_index_I[0:3];
Index _index_TI [0:3];
Index _index_G [0:3];
Index _index_sorted [0:3];
logic [13:0] _index_updated [0:3];
Index _index_final [0:3];
Index _index_temp [0:3],_index_temp_I [0:3];
Warn_Msg wraning_msg;
Date _date, w_date,wp_date;


class random_act_num;
    randc Action act_no;
    function new (int seed);
        this.srandom(seed);
    endfunction
    constraint limit{
        act_no inside {Index_Check, Update, Check_Valid_Date};
    }
endclass

Action in_action;
random_act_num action_rand = new(SEED);


class random_formula;
    randc Formula_Type formula_type;
    function new (int seed);
        this.srandom(seed);
    endfunction
    constraint limit{
        formula_type inside {Formula_A, Formula_B, Formula_C, Formula_D, Formula_E, Formula_F,Formula_G, Formula_H};
    }
endclass

Formula_Type in_formula;
random_formula formula_rand = new(SEED);


class   random_mode;
    randc Mode mode_type;
    function new(int seed);
        this.srandom(seed);        
    endfunction //new()
    constraint limit{
        mode_type inside {Insensitive,Normal,Sensitive};
    }
endclass 

Mode in_mode;
random_mode mode_rand = new(SEED);

// logic [12:0] in_index;
Index in_index;

class  random_today;
    randc Day   today_d;
    randc Month today_m;

    function new(int seed);
        this.srandom(seed);
    endfunction

    constraint limit{
        today_m inside {[1:12]};
        today_d inside {[1:31]};

        if (today_m == 2) {
            today_d inside {[1:28]};
        } else if (today_m == 4 || today_m == 6 || today_m == 9 || today_m == 11 ) {
            today_d inside {[1:30]};
        }
    }
endclass



Day   in_day, in_data_day, w_data_day;
Month in_month, in_data_month, w_data_month;
random_today today_rand = new(SEED);
random_today data_day_rand = new(SEED);

class random_data_no;
    randc Data_No data_no;

    function new (int seed);
        this.srandom(seed);
    endfunction

    constraint limit{
        data_no inside {[0:255]};
    }
endclass

Data_No in_data_no;
random_data_no data_no_rand = new(SEED);

//TO be Checked
class random_var_index;
    randc logic signed [11:0] var_index;

    function new(int seed);
        this.srandom(seed);
    endfunction

    constraint limit{
        var_index inside {[-2048:2047]};
    }
endclass

logic signed [13:0] in_var_index_A;
random_var_index var_index_rand_A = new(SEED);
logic signed [13:0] in_var_index_B;
random_var_index var_index_rand_B = new(123);
logic signed [13:0] in_var_index_C;
random_var_index var_index_rand_C = new(412);
logic signed [13:0] in_var_index_D;
random_var_index var_index_rand_D = new(55);

//TO be Checked
class random_index;
    randc Index _index;

    function new(int seed);
        this.srandom(seed);
    endfunction

    constraint limit{
        _index inside {[0:4095]};
    }
endclass

Index in_index_A;
random_index index_rand_A = new(SEED);
Index in_index_B;
random_index index_rand_B = new(312);
Index in_index_C;
random_index index_rand_C = new(666);
Index in_index_D;
random_index index_rand_D = new(7768);


//================================================================
//  Procedure
//================================================================
initial $readmemh(DRAM_p_r, golden_DRAM); // load memory
initial begin
    reset_task;
    pat_cnt = 0;
    mode_cnt = 0;
    formula_cnt = 0;
    for (i_pat = 0 ; i_pat < PAT_NUM ; i_pat = i_pat + 1 ) begin
        input_task;       
        cal_task;
        wait_task;
        check_ans_task;   
        pat_cnt = pat_cnt + 1;        
    end
    pass_task;
    $finish;
end

//================================================================
//  Task
//================================================================
//rst_n, sel_action_valid, formula_valid, mode_valid, date_valid, data_no_valid, index_valid, D,
task reset_task; begin
    inf.rst_n = 1;
    inf.sel_action_valid = 0;
    inf.formula_valid    = 0;
    inf.mode_valid       = 0;
    inf.date_valid       = 0;
    inf.data_no_valid    = 0;
    inf.index_valid      = 0;
    inf.D                ='dx;
    in_action            = 0;
    in_data_no           = 0;
    in_mode              = 0;
    in_formula           = 0;
    in_index_A =0;
    in_index_B =0;
    in_index_C =0;
    in_index_D =0;

    
    #(15) inf.rst_n = 0;
    #(15) inf.rst_n = 1;
end
endtask


Action act_sequence [0:8];
assign act_sequence[0] = Index_Check;
assign act_sequence[1] = Index_Check;
assign act_sequence[2] = Update;
assign act_sequence[3] = Update;
assign act_sequence[4] = Check_Valid_Date;
assign act_sequence[5] = Check_Valid_Date;
assign act_sequence[6] = Index_Check ;
assign act_sequence[7] = Check_Valid_Date;
assign act_sequence[8] = Update ;

Formula_Type f_sequence [0:8];
assign f_sequence[0] = Formula_A;
assign f_sequence[1] = Formula_B;
assign f_sequence[2] = Formula_C;
assign f_sequence[3] = Formula_D;
assign f_sequence[4] = Formula_E;
assign f_sequence[5] = Formula_F;
assign f_sequence[6] = Formula_G;
assign f_sequence[7] = Formula_H;

Mode m_sequence [0:2];
assign m_sequence[0] = Insensitive;
assign m_sequence[1] = Normal;
assign m_sequence[2] = Sensitive;

task in_action_gen_task ; begin 
    
    if (pat_cnt <= 2700 ) begin
        in_action = act_sequence[pat_cnt % 9];
    end
    else begin
        in_action = Index_Check;
    end
end
endtask

task in_formula_gen_task ; begin
    in_formula = f_sequence[formula_cnt % 8];
    formula_cnt = formula_cnt + 1;
end
endtask

task in_mode_gen_task ; begin
    in_mode = m_sequence[ mode_cnt % 3];
    mode_cnt = mode_cnt + 1;
end
endtask

task in_date_task ; begin
    rand_stimulus = today_rand.randomize();
    in_day = today_rand.today_d;
    in_month = today_rand.today_m;
end
endtask


task input_task; begin
    @(negedge clk);
    _warn_msg = No_Warn;
    _complete = 0;
    // action stimulus
    // rand_stimulus = action_rand.randomize();
    // in_action = action_rand.act_no;
    in_action_gen_task ; 
    inf.sel_action_valid = 1;
    inf.D = {70'dx,in_action};
    @(negedge clk)
    inf.sel_action_valid = 0;
    inf.D = 'dx ;
    //@(negedge clk);
    //================================================================
    case (in_action) 
        // Index Check
        Index_Check : begin     
            // formula
            in_formula_gen_task;
            inf.formula_valid = 1;
            inf.D = {69'dx,in_formula};
            @(negedge clk)
            inf.formula_valid = 0;
            inf.D = 'dx ;
           // @(negedge clk);

            // mode
            in_mode_gen_task ;
            inf.mode_valid = 1;
            inf.D = {70'dx,in_mode};
            @(negedge clk)
            inf.mode_valid = 0;
            inf.D = 'dx ;
            //@(negedge clk);

            // Today's date
            // rand_stimulus = today_rand.randomize();
            // in_day = today_rand.today_d;
            // in_month = today_rand.today_m;
            in_date_task ;
            inf.date_valid = 1;
            inf.D = {63'dx,in_month, in_day};
            @(negedge clk);
            inf.date_valid = 0;
            inf.D = 'dx ;
            //@(negedge clk);

            // Data No
            rand_stimulus = data_no_rand.randomize();
            in_data_no = data_no_rand.data_no;
            inf.data_no_valid = 1;
            inf.D = {64'dx,in_data_no};
            @(negedge clk);
            inf.data_no_valid = 0;
            inf.D = 'dx ;
           // @(negedge clk);

            // Index A
            rand_stimulus = index_rand_A.randomize();
            in_index_A = index_rand_A._index;
            inf.index_valid = 1;
            inf.D = {64'dx,in_index_A};
            @(negedge clk);
            inf.index_valid = 0;
            inf.D = 'dx ;
           // @(negedge clk);

            // Index B
            rand_stimulus = index_rand_B.randomize();
            inf.index_valid = 1;
            in_index_B = index_rand_B._index;
            inf.D = {64'dx,in_index_B};
            @(negedge clk);
            inf.index_valid = 0;
            inf.D = 'dx ;
           // @(negedge clk);

            // Index C
            rand_stimulus = index_rand_C.randomize();
            inf.index_valid = 1;
            in_index_C = index_rand_C._index;
            inf.D = {64'dx,in_index_C};
            @(negedge clk);
            inf.index_valid = 0;
            inf.D = 'dx ;
           // @(negedge clk); 

            // Index D
            rand_stimulus = index_rand_D.randomize();
            inf.index_valid = 1;
            in_index_D = index_rand_D._index;
            inf.D = {64'dx,in_index_D};
            @(negedge clk);
            inf.index_valid = 0;
            inf.D = 'dx ;
            // @(negedge clk);        
        end 

        // Update
        Update : begin
            // Data date
            rand_stimulus = data_day_rand.randomize();
            in_data_day = data_day_rand.today_d;
            in_data_month = data_day_rand.today_m;
            inf.date_valid = 1;
            inf.D = {63'dx,in_data_month, in_data_day};
            @(negedge clk);
            inf.date_valid = 0;
            inf.D = 'dx ;
           // @(negedge clk);

            // Data No
            rand_stimulus = data_no_rand.randomize();
            in_data_no = data_no_rand.data_no;
            inf.data_no_valid = 1;
            inf.D = {64'dx,in_data_no};
            @(negedge clk);
            inf.data_no_valid = 0;
            inf.D = 'dx ;
            //@(negedge clk);  

            // Index A
            rand_stimulus = var_index_rand_A.randomize();
            inf.index_valid = 1;
            in_var_index_A = var_index_rand_A.var_index;
            inf.D =  {64'dx,in_var_index_A};
            @(negedge clk);
            inf.index_valid = 0;
            inf.D = 'dx ;
            //@(negedge clk);

            // Index B
            rand_stimulus = var_index_rand_B.randomize();
            inf.index_valid = 1;
            in_var_index_B = var_index_rand_B.var_index;
            inf.D =  {64'dx,in_var_index_B};
            @(negedge clk);
            inf.index_valid = 0;
            inf.D = 'dx ;
           // @(negedge clk);

            // Index C
            rand_stimulus = var_index_rand_C.randomize();
            inf.index_valid = 1;
            in_var_index_C = var_index_rand_C.var_index;
            inf.D =  {64'dx,in_var_index_C};
            @(negedge clk);
            inf.index_valid = 0;
            inf.D = 'dx ;
            //@(negedge clk); 

            // Index D
            rand_stimulus = var_index_rand_D.randomize();
            inf.index_valid = 1;
            in_var_index_D = var_index_rand_D.var_index;
            inf.D =  {64'dx,in_var_index_D};
            @(negedge clk);
            inf.index_valid = 0;
            inf.D = 'dx ;
            // @(negedge clk);          
        end

        // Check valid date
        Check_Valid_Date : begin
            // Today's date
            // rand_stimulus = today_rand.randomize();
            // in_day = today_rand.today_d;
            // in_month = today_rand.today_m;
            in_date_task ;
            inf.date_valid = 1;
            inf.D =  {63'dx,in_month, in_day};
            @(negedge clk);
            inf.date_valid = 0;
            inf.D = 'dx ;
            //@(negedge clk);

             // Data No
            rand_stimulus = data_no_rand.randomize();
            in_data_no = data_no_rand.data_no;
            inf.data_no_valid = 1;
            inf.D =  {64'dx,in_data_no};
            @(negedge clk);
            inf.data_no_valid = 0;
            inf.D = 'dx ;          
        end
    endcase
end
endtask

task cal_task; begin

    dram_data[7:0]   = golden_DRAM[65536+(in_data_no*8)] ;
    dram_data[15:8]  = golden_DRAM[65536+(in_data_no*8) + 1] ;
    dram_data[23:16] = golden_DRAM[65536+(in_data_no*8) + 2] ;
    dram_data[31:24] = golden_DRAM[65536+(in_data_no*8) + 3] ;
    dram_data[39:32] = golden_DRAM[65536+(in_data_no*8) + 4] ;
    dram_data[47:40] = golden_DRAM[65536+(in_data_no*8) + 5] ;
    dram_data[55:48] = golden_DRAM[65536+(in_data_no*8) + 6] ;
    dram_data[63:56] = golden_DRAM[65536+(in_data_no*8) + 7] ;

    _warn_msg = No_Warn;
    _complete = 0;

    _index_R[0] = 0;
    _index_R[1] = 0;
    _index_R[2] = 0;
    _index_R[3] = 0;
    _index_R[4] = 0;
    _index_R[5] = 0;
    _index_R[6] = 0;
    _index_R[7] = 0;
    _index_MAX = 0;
    _index_MIN = 0;
    _date.M = 0;
    _date.D = 0;
    
    _index_I[0] =  dram_data[63:52]; 
    _index_I[1] =  dram_data[51:40];
    _index_I[2] =  dram_data[31:20];
    _index_I[3] =  dram_data[19:8];
    _date.M = dram_data[39:32];
    _date.D = dram_data[7:0];

    _index_TI[0] = in_index_A;
    _index_TI[1] = in_index_B;
    _index_TI[2] = in_index_C;
    _index_TI[3] = in_index_D;

    for (i =0 ;i<4 ;i=i+1 ) begin
        if (_index_I[i] > _index_TI[i]) begin
            _index_G[i] = _index_I[i] - _index_TI[i];
        end else begin
            _index_G[i] = _index_TI[i] - _index_I[i];
        end
    end

    _index_temp_I[0] = (_index_I[0] > _index_I[1]) ? _index_I[0] : _index_I[1] ;
    _index_temp_I[1] = (_index_I[0] > _index_I[1]) ? _index_I[1] : _index_I[0] ;
    _index_temp_I[2] = (_index_I[2] > _index_I[3]) ? _index_I[2] : _index_I[3] ;
    _index_temp_I[3] = (_index_I[2] > _index_I[3]) ? _index_I[3] : _index_I[2] ;
    _index_MAX = (_index_temp_I[0] > _index_temp_I[2])? _index_temp_I[0] : _index_temp_I[2];
    _index_MIN = (_index_temp_I[1] < _index_temp_I[3])? _index_temp_I[1] : _index_temp_I[3];

    
    //sorting 
    _index_temp[0] = (_index_G[0] > _index_G[1]) ? _index_G[0] : _index_G[1] ;
    _index_temp[1] = (_index_G[0] > _index_G[1]) ? _index_G[1] : _index_G[0] ;
    _index_temp[2] = (_index_G[2] > _index_G[3]) ? _index_G[2] : _index_G[3] ;
    _index_temp[3] = (_index_G[2] > _index_G[3]) ? _index_G[3] : _index_G[2] ;

    _index_sorted[0] = (_index_temp[1] > _index_temp[3]) ?  _index_temp[3] : _index_temp[1]; // min
    _index_sorted[1] = (_index_temp[1] > _index_temp[3]) ?  _index_temp[1] : _index_temp[3];
    _index_sorted[2] = (_index_temp[0] > _index_temp[2]) ?  _index_temp[2] : _index_temp[0];
    _index_sorted[3] = (_index_temp[0] > _index_temp[2]) ?  _index_temp[0] : _index_temp[2]; // Max



    case (in_action)
        Index_Check : begin
            //=============
            // CHECK DATE
            //=============
            if ( _date.M < in_month  )begin
                _warn_msg = No_Warn; // Date_warn
            end 
            else if ((in_month == _date.M) && in_day >= _date.D) begin
                _warn_msg = No_Warn; 
            end
            else _warn_msg = Date_Warn;   

            //=====================================
            // CALCULATE  & CHECK RESULT OF FORMULA
            //=====================================
            if (_warn_msg !== Date_Warn) begin
            case (in_formula)
                Formula_A : begin
                    _index_R[0] = (_index_I[0] + _index_I[1] + _index_I[2] + _index_I[3]) / 4;
                        case (in_mode)
                            Insensitive:  _warn_msg = (_index_R[0] >= 2047) ? Risk_Warn : No_Warn;
                            Normal:       _warn_msg = (_index_R[0] >= 1023) ? Risk_Warn : No_Warn;
                            Sensitive:    _warn_msg = (_index_R[0] >= 511)  ? Risk_Warn : No_Warn;
                        endcase
                end
                Formula_B : begin
                    _index_R[1] = _index_MAX - _index_MIN;
                        case (in_mode)
                            Insensitive:  _warn_msg = (_index_R[1] >= 800) ? Risk_Warn : No_Warn;
                            Normal:       _warn_msg = (_index_R[1] >= 400)      ? Risk_Warn : No_Warn;
                            Sensitive:    _warn_msg = (_index_R[1] >= 200)   ? Risk_Warn : No_Warn;
                        endcase
                end
                Formula_C : begin
                    _index_R[2] =  _index_MIN;
                        case (in_mode)
                            Insensitive:  _warn_msg = (_index_R[2] >= 2047) ? Risk_Warn : No_Warn;
                            Normal:       _warn_msg = (_index_R[2] >= 1023)      ? Risk_Warn : No_Warn;
                            Sensitive:    _warn_msg = (_index_R[2] >= 511)   ? Risk_Warn : No_Warn;
                        endcase
                end
                Formula_D : begin
                    _index_R[3] = (_index_I[0] >= 2047) + (_index_I[1] >= 2047) + (_index_I[2] >= 2047) + (_index_I[3] >= 2047);
                        case (in_mode)
                            Insensitive:  _warn_msg = (_index_R[3] >= 3) ? Risk_Warn : No_Warn;
                            Normal:       _warn_msg = (_index_R[3] >= 2)      ? Risk_Warn : No_Warn;
                            Sensitive:    _warn_msg = (_index_R[3] >= 1)   ? Risk_Warn : No_Warn;
                        endcase                
                end
                Formula_E : begin
                    _index_R[4] = (_index_I[0] >= _index_TI[0]) + (_index_I[1] >= _index_TI[1]) + (_index_I[2] >= _index_TI[2]) + (_index_I[3] >= _index_TI[3]);
                        case (in_mode)
                            Insensitive:  _warn_msg = (_index_R[4] >= 3) ? Risk_Warn : No_Warn;
                            Normal:       _warn_msg = (_index_R[4] >= 2)      ? Risk_Warn : No_Warn;
                            Sensitive:    _warn_msg = (_index_R[4] >= 1)   ? Risk_Warn : No_Warn;
                        endcase
                end
                Formula_F : begin
                    _index_R[5] = (_index_G[0] + _index_G[1] + _index_G[2] + _index_G[3] - _index_sorted[3]) / 3;
                        case (in_mode)
                            Insensitive:  _warn_msg = (_index_R[5] >= 800) ? Risk_Warn : No_Warn;
                            Normal:       _warn_msg = (_index_R[5] >= 400) ? Risk_Warn : No_Warn;
                            Sensitive:    _warn_msg = (_index_R[5] >= 200) ? Risk_Warn : No_Warn;
                        endcase
                end

                Formula_G : begin
                    _index_R[6] =(_index_sorted[0] >> 1 )+ (_index_sorted[1] >> 2 )+ (_index_sorted[2] >> 2);
                    if (in_mode == Insensitive) begin
                        if (_index_R[6] >= 800) begin
                            _warn_msg =Risk_Warn;
                        end else _warn_msg =No_Warn;
                    end
                    else if (in_mode == Normal) begin
                        if (_index_R[6] >= 400) begin
                            _warn_msg = Risk_Warn;
                        end else _warn_msg = No_Warn;
                    end
                    else  begin
                        if (_index_R[6] >= 200) begin
                            _warn_msg = Risk_Warn;
                        end else _warn_msg = No_Warn;
                    end
                end
                Formula_H : begin
                    _index_R[7] = (_index_G[0] + _index_G[1] + _index_G[2] + _index_G[3]) / 4;
                        case (in_mode)
                            Insensitive:  _warn_msg = (_index_R[7] >= 800) ? Risk_Warn : No_Warn;
                            Normal:       _warn_msg = (_index_R[7] >= 400) ? Risk_Warn : No_Warn;
                            Sensitive:    _warn_msg = (_index_R[7] >= 200) ? Risk_Warn : No_Warn;
                        endcase
                end 
            endcase
            end
        end

        Update : begin

            _index_updated[0] =   {1'b0, _index_I[0]} + in_var_index_A;
            _index_updated[1] =   {1'b0, _index_I[1]} + in_var_index_B;
            _index_updated[2] =   {1'b0, _index_I[2]} + in_var_index_C;
            _index_updated[3] =   {1'b0, _index_I[3]} + in_var_index_D;

            if ((_index_updated[0] > 4095 || _index_updated[0] < 0) || (_index_updated[1] > 4095 || _index_updated[1] < 0) || (_index_updated[2]> 4095 || _index_updated[2] < 0) || (_index_updated[3] > 4095 || _index_updated[3] < 0)) begin
                _warn_msg = Data_Warn;
            end
            for (i = 0 ; i < 4 ; i=i+1) begin
                if(_index_updated[i][13])begin
                    _index_updated[i] = 0;
                end
                else if (_index_updated[i][12]) begin
                    _index_updated[i] = 4095;
                end
            end
            //==================
            // UPDATE DRAM DATA
            //==================
            dram_data[63:52] = _index_updated[0]; 
            dram_data[51:40] = _index_updated[1];
            dram_data[39:32] = in_data_month;
            dram_data[31:20] = _index_updated[2];
            dram_data[19:8]  = _index_updated[3]; 
            dram_data[7:0]   =  in_data_day;

            w_index_I[0] =  dram_data[63:52]; 
            w_index_I[1] =  dram_data[51:40];
            w_index_I[2] =  dram_data[31:20];
            w_index_I[3] =  dram_data[19:8];
            w_date.M     = dram_data[39:32];
            w_date.D     = dram_data[7:0];


            golden_DRAM[65536+(in_data_no*8)] = dram_data[7:0] ;
            golden_DRAM[65536+(in_data_no*8) + 1] = dram_data[15:8] ;
            golden_DRAM[65536+(in_data_no*8) + 2] = dram_data[23:16] ;
            golden_DRAM[65536+(in_data_no*8) + 3] = dram_data[31:24] ;
            golden_DRAM[65536+(in_data_no*8) + 4] = dram_data[39:32] ;
            golden_DRAM[65536+(in_data_no*8) + 5] = dram_data[47:40] ;
            golden_DRAM[65536+(in_data_no*8) + 6] = dram_data[55:48] ;
            golden_DRAM[65536+(in_data_no*8) + 7] = dram_data[63:56];       


            _dram_data[7:0]   = golden_DRAM[65536+(in_data_no*8)] ;
            _dram_data[15:8]  = golden_DRAM[65536+(in_data_no*8) + 1] ;
            _dram_data[23:16] = golden_DRAM[65536+(in_data_no*8) + 2] ;
            _dram_data[31:24] = golden_DRAM[65536+(in_data_no*8) + 3] ;
            _dram_data[39:32] = golden_DRAM[65536+(in_data_no*8) + 4] ;
            _dram_data[47:40] = golden_DRAM[65536+(in_data_no*8) + 5] ;
            _dram_data[55:48] = golden_DRAM[65536+(in_data_no*8) + 6] ;
            _dram_data[63:56] = golden_DRAM[65536+(in_data_no*8) + 7] ;

            wp_index_I[0] =  _dram_data[63:52]; 
            wp_index_I[1] =  _dram_data[51:40];
            wp_index_I[2] =  _dram_data[31:20];
            wp_index_I[3] =  _dram_data[19:8];
            wp_date.M     =  _dram_data[39:32];
            wp_date.D     =  _dram_data[7:0];


        end

        Check_Valid_Date : begin
            if ( _date.M < in_month  )begin
                _warn_msg = No_Warn; // Date_warn
            end 
            else if ((in_month == _date.M) && in_day >= _date.D) begin
                _warn_msg = No_Warn; 
            end
            else _warn_msg = Date_Warn;             
        end 
    endcase

    //=============================
    // COMPLETE
    //=============================

    if (_warn_msg == No_Warn) begin
        _complete = 1;
    end else _complete = 0;


end
endtask

task wait_task ; begin
    exe_lat = 1;
    while (inf.out_valid !== 1'b1) begin
        exe_lat = exe_lat + 1;
        // if (exe_lat == 200) begin
        // $display("Wrong Answer") ;
        // repeat (1) @(negedge clk);
        // $finish;
        // end
       @(negedge clk);
    end
end
endtask
integer cnt;

task check_ans_task ; begin
    cnt = 0;
    if (inf.out_valid === 1'b1) begin
        if (inf.complete !== _complete || inf.warn_msg !== _warn_msg ) begin
            $display("Wrong Answer") ;
            repeat (2) @(negedge clk);
            $finish ;        
        end 
        else begin
            cnt = cnt + 1;
        end       
    end

end
endtask

task pass_task ; begin 
    $display("Congratulations") ;
end endtask 

endprogram

/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2023 Autumn IC Design Laboratory 
Lab10: SystemVerilog Coverage & Assertion
File Name   : CHECKER.sv
Module Name : CHECKER
Release version : v1.0 (Release Date: Nov-2023)
Author : Jui-Huang Tsai (erictsai.10@nycu.edu.tw)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

`include "Usertype.sv"
module Checker(input clk, INF.CHECKER inf);
import usertype::*;

// integer fp_w;

// initial begin
// fp_w = $fopen("out_valid.txt", "w");
// end

/**
 * This section contains the definition of the class and the instantiation of the object.
 *  * 
 * The always_ff blocks update the object based on the values of valid signals.
 * When valid signal is true, the corresponding property is updated with the value of inf.D
 */
logic last_in ;
logic [1:0] action_store;

logic [2:0] idx_cnt;

class Formula_and_mode;
    Formula_Type f_type;
    Mode f_mode;
endclass

Formula_and_mode fm_info = new();

always_ff @(posedge clk) begin
    if (inf.formula_valid) begin
        fm_info.f_type = inf.D.d_formula[0] ;
    end
end

always_ff @(posedge clk) begin
    if (inf.mode_valid) begin
        fm_info.f_mode = inf.D.d_mode[0];
    end
end

//================================================================
// CONVERAGE
//================================================================
covergroup c_1_formula @(posedge clk iff(inf.formula_valid) );
    option.per_instance =  1;
    option.at_least = 150;
    F_type: coverpoint inf.D.d_formula[0]{
        bins bin_formula_type[] = {[Formula_A:Formula_H]};

    }
endgroup

c_1_formula c_formula = new();

covergroup c_2_mode @(posedge clk iff(inf.mode_valid) );
    option.per_instance =  1;
    option.at_least = 150;
    M_type: coverpoint fm_info.f_mode{
        bins bin_mode_type[] = {Sensitive,Normal ,Insensitive};
    }
endgroup

c_2_mode c_mode = new();


covergroup c_3_mode @(posedge clk iff(inf.date_valid && action_store == Index_Check) );
    option.per_instance =  1;
    option.at_least = 150;   

    cross  fm_info.f_mode, fm_info.f_type;
endgroup

c_3_mode c_3mode = new();


covergroup c_4_warn @(posedge clk iff(inf.out_valid));
    option.per_instance =  1;
    option.at_least = 50;
    W_type: coverpoint inf.warn_msg{
        bins bin_warn_msg[] = {[No_Warn:Data_Warn]};
    }
endgroup

c_4_warn c_4_msg = new();

covergroup c_5_act_tran @(posedge clk iff inf.sel_action_valid);
    option.per_instance =  1;
    option.at_least = 300;
    W5_type: coverpoint inf.D.d_act[0]{
        bins bin_act_tran[] = (Index_Check, Update, Check_Valid_Date => Index_Check, Update, Check_Valid_Date);
    }
endgroup
c_5_act_tran c_5_action_transition = new();


covergroup c_6_Idx_var @(posedge clk iff (action_store == Update && inf.index_valid));
    option.per_instance =  1;
    option.at_least = 1;
    W6_type: coverpoint inf.D.d_index[0]{
        option.auto_bin_max = 32;
    }
endgroup
c_6_Idx_var c_6_var = new();


//================================================================
// Assertion
//================================================================


// SPEC 1 : All outputs signals (Program.sv) should be zero after reset.
always @(negedge inf.rst_n) begin
    #(1) ;
    Assertion1 : assert (inf.out_valid === 0 && inf.warn_msg === 0 && inf.complete === 0 && inf.AR_VALID === 0 &&
                         inf.AR_ADDR === 0 && inf.R_READY === 0 && inf.AW_VALID === 0 && inf.AW_ADDR === 0 && inf.W_VALID === 0 &&
                         inf.W_DATA === 0 && inf.B_READY === 0  ) 

    else begin 
        $display("Assertion 1 is violated") ;			
        $fatal ;
    end    
end


always_ff @( posedge clk or negedge inf.rst_n  ) begin : idx_cnt_logic
    if (!inf.rst_n) begin
        idx_cnt <= 0;
    end
    else if (idx_cnt == 4) begin
        idx_cnt <= 0;
    end
    else if (inf.index_valid) begin
        idx_cnt <= idx_cnt + 1;
    end
end

always_ff @( posedge clk or negedge inf.rst_n  ) begin : axt_store
    if (!inf.rst_n) begin
        action_store <= 0;
    end
    else if (inf.sel_action_valid) begin
        action_store <= inf.D.d_act[0];
    end
end

always_ff @( posedge clk or negedge inf.rst_n ) begin : last_signal
    if (!inf.rst_n) begin
        last_in <= 0;
    end
    else begin
        case (action_store)
            2'b00: begin
                if (idx_cnt == 4) begin
                    last_in <= 1;
                end
                else last_in <= 0;
            end 

            2'b01: begin
                if (idx_cnt == 4) begin
                    last_in <= 1;
                end
                else last_in <= 0;                
            end

            2'b10: begin
                if (inf.data_no_valid) begin
                    last_in <= 1;
                end
                else last_in <= 0;               
            end
            default: last_in <= 0;     
        endcase
    end    
end

// SPEC 2 : Latency should be less than 1000 cycles for each operation.
property Total_latency ;
    @(posedge clk) last_in |-> (##[1:1000] inf.out_valid);

endproperty :Total_latency

always @(posedge clk) begin
    Assertion2 : assert property (Total_latency)
    else begin
        $display("Assertion 2 is violated") ;            
        $fatal ;
    end
end

// SPEC 3 : If action is completed (complete=1), warn_msg should be 2’b0 (No_Warn).
property Complete_No_Warn ;
    @(negedge clk) inf.complete |-> ( inf.warn_msg == No_Warn);
endproperty : Complete_No_Warn 

always @(posedge clk) begin
    Assertion3 : assert property(Complete_No_Warn)
    else begin
        $display("Assertion 3 is violated") ;            
        $fatal ;
    end
end

// SPEC 4 : Next input valid will be valid 1-4 cycles after previous input valid fall.
always @(posedge clk)begin
    if (inf.sel_action_valid) begin
        Assertion4 : assert property(invalid_begin)
        else begin 
        $display("Assertion 4 is violated") ;
        $fatal ;
        end
    end 
    else if (action_store == Index_Check) begin
        Assertion4_index_check : assert property(in_valid_index_check) 
        else begin 
        $display("Assertion 4 is violated") ;
        $fatal ;
        end
    end
    else if (action_store == Update) begin
        Assertion4_update : assert property(in_valid_update)
        else begin 
        $display("Assertion 4 is violated") ;
        $fatal ;
        end
    end
    else if (action_store == Check_Valid_Date) begin
        Assertion4_checkDate : assert property(in_valid_check_Date)
        else begin 
        $display("Assertion 4 is violated") ;
        $fatal ;
        end
    end
end

property invalid_begin ;
    @(posedge clk) inf.sel_action_valid |-> (##[1:4] (inf.formula_valid || inf.date_valid));
endproperty : invalid_begin

property in_valid_index_check ;
    @(posedge clk) inf.formula_valid |-> (##[1:4] inf.mode_valid ##[1:4] inf.date_valid ##[1:4] inf.data_no_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid);
endproperty : in_valid_index_check

property in_valid_update ;
    @(posedge clk) inf.date_valid |-> (##[1:4] inf.data_no_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid ##[1:4] inf.index_valid);
endproperty : in_valid_update

property in_valid_check_Date ;
    @(posedge clk) inf.date_valid |-> (##[1:4] inf.data_no_valid );
endproperty : in_valid_check_Date

// SPEC 5 : All input valid signals won’t overlap with each other.
// sel_action_valid, formula_valid, mode_valid, date_valid, data_no_valid, index_valid, 
always @(posedge clk) begin
    Assertion5_act : assert property(in_act)
    else begin 
    $display("Assertion 5 is violated") ;
    $fatal ;
    end

    Assertion5_f : assert property(in_formula)
    else begin 
    $display("Assertion 5 is violated") ;
    $fatal ;
    end

    Assertion5_date : assert property(in_date)
    else begin 
    $display("Assertion 5 is violated") ;
    $fatal ;
    end

    Assertion5_mode : assert property(in_mode)
    else begin 
    $display("Assertion 5 is violated") ;
    $fatal ;
    end

    Assertion5_data_no : assert property(in_data_no)
    else begin 
    $display("Assertion 5 is violated") ;
    $fatal ;
    end

    Assertion5_idx : assert property(in_idx)
    else begin 
    $display("Assertion 5 is violated") ;
    $fatal ;
    end

end

property in_act ;
    @(posedge clk) inf.sel_action_valid |-> ((inf.formula_valid === 0) && (inf.date_valid === 0) && (inf.mode_valid === 0) && (inf.data_no_valid === 0) && (inf.index_valid === 0));
endproperty : in_act

property in_formula ;
    @(posedge clk) inf.formula_valid |-> (inf.sel_action_valid === 0 && inf.date_valid === 0 && inf.mode_valid === 0  && inf.data_no_valid === 0 && (inf.index_valid === 0));
endproperty : in_formula

property in_date ;
    @(posedge clk) inf.date_valid |-> (inf.sel_action_valid === 0 &&  inf.formula_valid === 0 && inf.mode_valid === 0 && inf.data_no_valid === 0 && (inf.index_valid === 0 ));
endproperty : in_date

property in_mode ;
    @(posedge clk) inf.mode_valid |-> (inf.sel_action_valid === 0 &&  inf.formula_valid === 0 && inf.date_valid === 0 && inf.data_no_valid === 0 && (inf.index_valid === 0));
endproperty : in_mode

property in_data_no ;
    @(posedge clk) inf.data_no_valid |-> (inf.sel_action_valid === 0 &&  inf.formula_valid === 0 && inf.date_valid === 0 && inf.mode_valid === 0 && (inf.index_valid === 0));
endproperty : in_data_no

property in_idx ;
    @(posedge clk) inf.index_valid |-> (inf.sel_action_valid === 0 &&  inf.formula_valid === 0 && inf.date_valid === 0 && inf.mode_valid === 0 && (inf.data_no_valid === 0));
endproperty : in_idx


// SPEC 6 : Out_valid can only be high for exactly one cycle.
always @(posedge clk) begin
    Assertion6 : assert property(out_one)
    else begin 
    $display("Assertion 6 is violated") ;
    $fatal ;
    end
end

property out_one;
    @(posedge clk) inf.out_valid |=> (inf.out_valid === 0);
endproperty : out_one

// SPEC 7 : Next operation will be valid 1-4 cycles after out_valid fall.
always @(posedge clk) begin
    Assertion7 : assert property(out_in_valid)
    else begin 
    $display("Assertion 7 is violated") ;
    $fatal ;
    end
end

property out_in_valid;
    @(posedge clk) inf.out_valid |-> (##[1:4] inf.sel_action_valid);
endproperty : out_in_valid


// SPEC 8 : The input date from pattern should adhere to the real calendar.

always @(posedge clk) begin
    Assertion_valid_month : assert property(valid_month)
    else begin 
    $display("Assertion 8 is violated") ;
    $fatal ;
    end

    Assertion_valid_day_1 : assert property(valid_day_1)
    else begin 
    $display("Assertion 8 is violated") ;
    $fatal ;
    end 

    Assertion_valid_day_2 : assert property(valid_day_2)
    else begin 
    $display("Assertion 8 is violated") ;
    $fatal ;
    end

    Assertion_valid_day_3 : assert property(valid_day_3)
    else begin 
    $display("Assertion 8 is violated") ;
    $fatal ;
    end
end

property valid_month;
    @(posedge clk) inf.date_valid |-> (inf.D.d_date[0].M >= 1 && inf.D.d_date[0].M <= 12);
endproperty  : valid_month

property valid_day_1; // big month
    @(posedge clk) (inf.date_valid && ( inf.D.d_date[0].M === 1 ||  inf.D.d_date[0].M === 3 || inf.D.d_date[0].M === 5 || inf.D.d_date[0].M === 7 || inf.D.d_date[0].M === 8 || inf.D.d_date[0].M === 10 || inf.D.d_date[0].M === 12) ) |-> (inf.D.d_date[0].D > 0 && inf.D.d_date[0].D < 32);
endproperty

property valid_day_2; // small month
    @(posedge clk) (inf.date_valid && ( inf.D.d_date[0].M === 4 || inf.D.d_date[0].M === 6 || inf.D.d_date[0].M === 9 || inf.D.d_date[0].M === 11 ) |-> (inf.D.d_date[0].D > 0 && inf.D.d_date[0].D < 31));
endproperty

property valid_day_3; // February
    @(posedge clk) (inf.date_valid && ( inf.D.d_date[0].M === 2 ) |-> (inf.D.d_date[0].D > 0 && inf.D.d_date[0].D < 29));
endproperty


//SPEC 9 : The AR_VALID signal should not overlap with the AW_VALID signal.
always @(posedge clk) begin
    Assertion9 : assert property(AR_AW_valid)
    else begin 
    $display("Assertion 9 is violated") ;
    $fatal ;
    end
end

property AR_AW_valid;
    @(posedge clk) inf.AR_VALID |-> ( inf.AW_VALID === 0);
endproperty : AR_AW_valid

endmodule
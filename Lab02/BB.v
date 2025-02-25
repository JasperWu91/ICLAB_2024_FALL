
module BB(
    //Input Ports
    input clk,
    input rst_n,
    input in_valid,
    input [1:0] inning,   // Current inning number
    input half,           // 0: top of the inning, 1: bottom of the inning
    input [2:0] action,   // Action code

    //Output Ports
    output reg out_valid,  // Result output valid
    output reg [7:0] score_A,  // Score of team A (guest team)
    output reg [7:0] score_B,  // Score of team B (home team)
    output reg [1:0] result    // 0: Team A wins, 1: Team B wins, 2: Darw
);

//==============================================//
//             Action Memo for Students         //
// Action code interpretation:
// 3’d0: Walk (BB)
// 3’d1: 1H (single hit)
// 3’d2: 2H (double hit)
// 3’d3: 3H (triple hit)
// 3’d4: HR (home run)
// 3’d5: Bunt (short hit)
// 3’d6: Ground ball
// 3’d7: Fly ball
//==============================================//

//==============================================//
//             Parameter and Integer            //
//==============================================//
// State declaration for FSM
// Example: parameter IDLE = 3'b000;

parameter Walk = 3'd0;
parameter H = 3'd1;
parameter HH = 3'd2;
parameter HHH = 3'd3;
parameter HR = 3'd4;
parameter Bunt = 3'd5;
parameter Ground_ball = 3'd6;
parameter Fly_ball = 3'd7;

//==============================================//
//                 reg declaration              //
//==============================================//

reg [2:0] c_base, n_base; //current state record the current field base condition , next state for field base , 3'b000 , 3'b001    

reg [1:0] out; // out number
reg [2:0] score;
wire [3:0] t_score;
reg [3:0] n_score;
wire [3:0] total_score;
reg  secure_victory; // Team B's score in the bottom half will not count
reg  inning_cnt;
reg [3:0] next_score_A; 
reg [2:0] next_score_B; 
reg half_reg;
reg in_valid_reg;
// score calculation
wire [2:0] base_1_2_3_4 ;
wire [2:0] base_1_2_3 ;
wire [2:0] base_2_3 ; 
wire base_2 ;
wire [1:0] out_c;
wire out_2_flag; // out ==2 
wire out_3_flag; // out ==3
wire half_c;
//==============================================//
//             Current State Block              //
//==============================================//




always @(posedge clk ) begin
    half_reg <= half;
end

assign half_c = half_reg;

always @(posedge clk ) begin
    in_valid_reg <= in_valid;
end

always @(posedge clk ) begin
    inning_cnt <= half_reg;
end



//==============================================//
//             Base and Score Logic             //
//==============================================//
// Handle base runner movements and score calculation.
// Update bases and score depending on the action:
// Example: Walk, Hits (1H, 2H, 3H), Home Runs, etc.



always @(posedge clk) begin
    c_base[0] <= n_base[0];
    c_base[1] <= n_base[1];
    c_base[2] <= n_base[2];
end


always @(*) begin
    n_base[0] = 1'b0;

    if (in_valid) begin
        if (action == Walk || action == H) begin
            n_base[0] = 1'b1;
        end
        else if (action == Fly_ball) begin
            if (!out_2_flag) begin
                n_base[0] =  c_base[0] ;
            end
        end
        else n_base[0] = 1'b0;
    end
end

always @(*) begin

    n_base[1] = 1'b0;

    if (in_valid) begin

        case (action)
            Walk: begin
                //n_base[1] = c_base[0] | c_base[1];
                if (c_base[0]) begin
                     n_base[1] = 1;
                end
                else if (c_base[1]) begin
                     n_base[1] = 1;
                end
            end
            H: begin
                n_base[1] = (!out_2_flag) ? c_base[0] : 1'b0;
            end
            HH: begin
                n_base[1] = 1'b1;
            end

            Bunt: begin
                n_base[1] = c_base[0];
            end

            Fly_ball: begin
                n_base[1] = (!out_2_flag) ? c_base[1] : 1'b0;
            end
            default: n_base[1] = 1'b0;
        endcase
    end
end

always @(*) begin

    n_base[2] = 1'b0;

    if (in_valid) begin
        case (action)
            Walk: begin
                n_base[2] = c_base[2] | (c_base[1] & c_base[0]);
            end
            H: begin
                if (out_2_flag) begin
                    n_base[2] = c_base[0];
                end else begin
                    n_base[2] = c_base[1];
                end
            end
            HHH:    n_base[2] = 1'b1;
            Bunt: begin
                    n_base[2] = c_base[1];
            end
            HH: begin
                if (!out_2_flag) begin
                    n_base[2] = c_base[0];
                end
            end

            Ground_ball: begin
                if (!out_2_flag) begin
                    n_base[2] = c_base[1];
                end
            end
            default: n_base[2] = 1'b0;
        endcase
    end
end


assign base_1_2_3_4 = base_1_2_3 + 1'b1;
assign base_1_2_3   = base_2_3 + c_base[0]; //   c_base[0] + c_base[1] + c_base[2];
assign base_2_3     = c_base[2]  + c_base[1];
assign base_2       = ( c_base[2]) ? 1 : 0;



wire [3:0] score_A_c , score_B_c;

assign score_A_c = score_A ;
assign score_B_c = score_B ;



assign t_score = (half_c) ?  score_B_c : score_A_c ;
assign total_score = t_score + score; 



always @(*) begin
    next_score_A = score_A; 
    if (!in_valid_reg) begin
        next_score_A = 0;
    end 
    else if (!half_c) begin
        next_score_A =  total_score;
    end

end

always @(*) begin
    next_score_B = score_B;

    if (!in_valid_reg) begin
        next_score_B = 0;
    end 
    else if (half_c) begin
        next_score_B = (secure_victory) ? score_B_c :  total_score;
    end

end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        score_A <= 0;
    end 
    else begin
        score_A <= next_score_A; 
    end 
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        score_B <= 0;
    end 
    else begin
        score_B <= next_score_B; 
    end 
end


assign out_2_flag = (out_c[1]) ;
assign out_3_flag = (&out_c) ;

always @(posedge clk) begin
    begin
        score <= n_score;
    end
end

always @(*) begin
    // Default assignment
    n_score = 0;
    //if (in_valid) begin
    // Reset condition
        if (out_3_flag) begin
            n_score = (action == HR) ? 1 : 0;
        end
    // Main state operations
        else begin
            case (action)
                Walk: begin
                    if ( &c_base ) begin // Check if all bits in 'c_base' are 1 (bases loaded)
                        n_score =  1;
                    end
                end 
                
                H: begin
                    if (out_2_flag) begin
                        n_score =  base_2_3;

                    end else begin
                        n_score =  base_2;
                    end
                end

                HH: begin
                    if (out_2_flag) begin
                        n_score =  base_1_2_3;
                    end else begin
                        n_score =  base_2_3;
                    end
                end

                HHH: begin
                    n_score =  base_1_2_3 ;
                end

                HR: begin
                    n_score =  base_1_2_3_4;
                end

                Bunt: begin
                    n_score =  base_2;
                end
                
                Ground_ball: begin
                    if (!out_2_flag && !(out_c && c_base[0])) begin
                        n_score =  base_2;
                    end
                end
                
                Fly_ball: begin
                    if (!out_2_flag) begin
                        n_score = base_2;
                    end
                end
            endcase
        end
    //end
end


reg  [1:0] n_out; 
wire [1:0] s_out_1 , s_out_2 ;

assign s_out_1 = out_c + 1'b1;
assign s_out_2 = out_c + 2'd2;

always @(posedge clk ) begin
    out <= n_out;
end

always @(*) begin
    if (!in_valid) begin
        n_out = 0;
    end 

    else if (out_3_flag) begin
        if (action == Bunt || action == Ground_ball || action == Fly_ball ) begin
            n_out =  1'b1;
        end
        else n_out = 0;
    end

    else begin
        case (action)
            Bunt, Fly_ball: n_out = s_out_1;

            Ground_ball: begin
                if ( c_base[0] && (!out_2_flag) ) begin
                    n_out = s_out_2;
                end else begin
                    n_out = s_out_1;
                end
            end
            default: n_out = out_c;
        endcase
    end
end

assign out_c = out;

wire AB_cmp ;
assign AB_cmp = (score_A_c < score_B_c);


reg next_secure_victory; 

always @(posedge clk) begin
    secure_victory <= next_secure_victory;
end


always @(*) begin
    //next_secure_victory = secure_victory; 
    if (!in_valid) begin
        next_secure_victory = 0;
    end 
    else if ((&inning)  && AB_cmp && (half_c == 0) && (half == 1)) begin
        next_secure_victory = 1;
    end 
 else  next_secure_victory = secure_victory;
end

//==============================================//
//                Output Block                  //
//==============================================//


// result
always @(*) begin
    if (!out_valid) begin
        result = 0;
    end 
    
    else if (AB_cmp ) begin
        result = 1;
    end     
    else if (score_A > score_B) begin
        result = 0;
    end 

    else begin
        result = 2;
    end 
end


always @(*) begin
    if (!rst_n) begin
       	out_valid <= 1'b0;
    end 
    else if(!in_valid_reg && inning_cnt) out_valid <= 1'b1;
    else out_valid <= 1'b0;
end

endmodule

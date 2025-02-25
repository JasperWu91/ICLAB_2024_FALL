////############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2024 Fall
//   Lab01 Exercise		: Snack Shopping Calculator
//   Author     		  : Yu-Hsiang Wang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : SSC.v
//   Module Name : SSC
//   Release version : V1.0 (Release Date: 2024-09)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module SSC(
    // Input signals
    card_num,
    input_money,
    snack_num,
    price, 
    // Output signals
    out_valid,
    out_change
);

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
input [63:0] card_num;
input [8:0] input_money;
input [31:0] snack_num;
input [31:0] price;
output out_valid;
output [8:0] out_change;    

//================================================================
//    Wire & Registers 
//================================================================
// Declare the wire/reg you would use in your circuit
// remember 
// wire for port connection and cont. assignment
// reg for proc. assignment

wire [3:0] n [15:0];
wire [3:0] n0_, n2_, n4_, n6_, n8_, n10_, n12_,  n14_; // multiply by 2 a
wire [7:0] sum; 
wire [7:0] sum1 , sum2;
wire num_valid;
wire [3:0] sn [7:0]; //snack amount
wire [3:0] sp [7:0]; //snack price
wire [7:0] cost [7:0] ; // totoal cost for each items
wire [7:0] cost_s [7:0] ; // cost after sorting 

//================================================================
//    DESIGN
//================================================================

assign n[0]  = card_num[63:60];
assign n[1]  = card_num[59:56];
assign n[2]  = card_num[55:52];
assign n[3]  = card_num[51:48];
assign n[4]  = card_num[47:44];
assign n[5]  = card_num[43:40];
assign n[6]  = card_num[39:36];
assign n[7]  = card_num[35:32];
assign n[8]  = card_num[31:28];
assign n[9]  = card_num[27:24];
assign n[10] = card_num[23:20];
assign n[11] = card_num[19:16];
assign n[12] = card_num[15:12];
assign n[13] = card_num[11:8];
assign n[14] = card_num[7:4];
assign n[15] = card_num[3:0];

assign sn[0]  = snack_num[31:28];
assign sn[1]  = snack_num[27:24];
assign sn[2]  = snack_num[23:20];
assign sn[3]  = snack_num[19:16];
assign sn[4]  = snack_num[15:12];
assign sn[5]  = snack_num[11:8];
assign sn[6]  = snack_num[7:4];
assign sn[7]  = snack_num[3:0];

assign sp[0] = price[31:28];
assign sp[1] = price[27:24];
assign sp[2] = price[23:20];
assign sp[3] = price[19:16];
assign sp[4] = price[15:12];
assign sp[5] = price[11:8];
assign sp[6] = price[7:4];
assign sp[7] = price[3:0];

wire [4:0] n0_1, n2_1, n4_1, n6_1, n8_1, n10_1, n12_1,  n14_1;

assign n0_1 = n[0] << 1'b1;
assign n2_1 = n[2] << 1'b1;
assign n4_1 = n[4] << 1'b1;
assign n6_1 = n[6] << 1'b1;
assign n8_1 = n[8] << 1'b1;
assign n10_1 = n[10] << 1'b1;
assign n12_1 = n[12] << 1'b1;
assign n14_1 = n[14] << 1'b1;

assign n0_  = (n[0] > 3'd4  )  ?  n0_1 + 5'b10111 : n0_1 ;
assign n2_  = (n[2] > 3'd4  )  ?  n2_1 - 5'd9 : n2_1 ;
assign n4_  = (n[4] > 3'd4  )  ?  n4_1 + 5'b10111:  n4_1;
assign n6_  = (n[6] > 3'd4  )  ?  n6_1 - 5'd9 :  n6_1;
assign n8_  = (n[8] > 3'd4  )  ?  n8_1 + 5'b10111:  n8_1;
assign n10_ = (n[10] > 3'd4 )  ? n10_1 - 5'd9: n10_1;
assign n12_ = (n[12] > 3'd4 )  ? n12_1 + 5'b10111: n12_1;
assign n14_ = (n[14] > 3'd4 )  ? n14_1 - 5'd9: n14_1;



wire [7:0] sum3 , sum4 , sum5 , sum6 ;

assign sum3 = n0_ + n[3]   +  n4_  + n[11];
assign sum4 = n8_  + n[7]   +   n12_ + n14_   ;

assign sum5 = n[1] +  n2_ +  n[5] + n6_;
assign sum6 = n[9] +n10_ + n[13] + n[15] ;
assign sum1 = sum3 + sum4;
assign sum2 = sum5 + sum6;
assign sum  = sum1 + sum2;


div_10_LUT d_0(.in(sum), .out(num_valid)); 


mul4 m0(.in2(sn[0]), .in1(sp[0]), .out(cost[0]));
mul4 m1(.in1(sn[1]), .in2(sp[1]), .out(cost[1]));
mul4 m2(.in1(sn[2]), .in2(sp[2]), .out(cost[2]));
mul4 m3(.in1(sn[3]), .in2(sp[3]), .out(cost[3]));
mul4 m4(.in1(sn[4]), .in2(sp[4]), .out(cost[4]));
mul4 m5(.in1(sn[5]), .in2(sp[5]), .out(cost[5]));
mul4 m6(.in1(sn[6]), .in2(sp[6]), .out(cost[6]));
mul4 m7(.in1(sn[7]), .in2(sp[7]), .out(cost[7]));


sort  s_1(cost[0],cost[1],cost[2],cost[3],cost[4],cost[5],cost[6],cost[7], cost_s[0],cost_s[1],cost_s[2],cost_s[3],cost_s[4],cost_s[5],cost_s[6],cost_s[7]);


wire signed  [9:0] money_change;
reg  signed [9:0] out_change0;
assign money_change = input_money;

wire signed [9:0] mm [0:7];

assign mm[0] = money_change - cost_s[0];
assign mm[1] = mm[0]  - cost_s[1];
assign mm[2] = mm[1] - cost_s[2] ;
assign mm[3] = mm[2] + ~cost_s[3] + 1'b1;
assign mm[4] = mm[3] - cost_s[4] ;
assign mm[5] = mm[4] + ~cost_s[5] + 1'b1;
assign mm[6] = mm[5] - cost_s[6] ;
assign mm[7] = mm[6] + ~cost_s[7] + 1'b1;

always @(*) begin
    if (mm[0][9] ) out_change0 = money_change;
    else if (mm[1][9] ) out_change0 = mm[0];
    else if (mm[2][9] ) out_change0 = mm[1];
    else if (mm[3][9] ) out_change0 = mm[2];
    else if (mm[4][9] ) out_change0 = mm[3];
    else if (mm[5][9] ) out_change0 = mm[4];
    else if (mm[6][9] ) out_change0 = mm[5];
    else if (mm[7][9] ) out_change0 = mm[6];
    else  out_change0 = mm[7];
end

assign out_valid  = (num_valid) ? 1'b1 : 1'b0;
assign out_change = (out_valid) ? out_change0 : money_change;

endmodule

module cmp(in1, in2, out1 , out2);
input  [7:0] in1 ;
input  [7:0] in2 ;
output [7:0] out1 ;
output [7:0] out2 ;

assign out1 = (in1 > in2)? in1 : in2;
assign out2 = (in1 > in2)? in2 : in1;
endmodule


module div_10_LUT (in, out);
input [7:0] in;
output reg out;

always @(*) begin
    case (in) 
        8'd50  : out = 1'b1;
        8'd60  : out = 1'b1; 
        8'd70  : out = 1'b1;  
        8'd80  : out = 1'b1;
        8'd90  : out = 1'b1; 
        8'd100 : out = 1'b1;  
        8'd110 : out = 1'b1;
        8'd120 : out = 1'b1;
        default: out = 1'b0;
    endcase
end
endmodule

//Sorting network 
module sort(
   in0, in1, in2 , in3 , in4 , in5 , in6 , in7,
   out0 , out1, out2 , out3 , out4, out5, out6, out7
);
    input  [7:0] in0, in1, in2 , in3 , in4 , in5 , in6 , in7;
    output [7:0] out0 , out1, out2 , out3 , out4, out5, out6, out7;

    wire[7:0] a[0:7], b[0:7], c[0:7], d[0:3], e[0:3], f[0:5];

    cmp c0(.in1(in0), .in2(in2), .out1(a[0]), .out2(a[2]) );
    cmp c1(.in1(in1), .in2(in3), .out1(a[1]), .out2(a[3]) );
    cmp c2(.in1(in4), .in2(in6), .out1(a[4]), .out2(a[6]) );
    cmp c3(.in1(in5), .in2(in7), .out1(a[5]), .out2(a[7]) );


    cmp c6(.in1(a[2]), .in2(a[6]), .out1(b[2]), .out2(b[6]) );
    cmp c7(.in1(a[3]), .in2(a[7]), .out1(b[3]), .out2(b[7]) );
    cmp c4(.in1(a[0]), .in2(a[4]), .out1(b[0]), .out2(b[4]) );
    cmp c5(.in1(a[1]), .in2(a[5]), .out1(b[1]), .out2(b[5]) );

    cmp c8(.in1(b[0]), .in2(b[1]), .out1(c[0]), .out2(c[1]) );
    cmp c9(.in1(b[2]), .in2(b[3]), .out1(c[2]), .out2(c[3]) );
    cmp c10(.in1(b[4]), .in2(b[5]), .out1(c[4]), .out2(c[5]) );

    cmp c11(.in1(b[6]), .in2(b[7]), .out1(c[6]), .out2(c[7]) );

    cmp c12(.in1(c[2]), .in2(c[4]), .out1(d[0]), .out2(d[2]) );
    cmp c13(.in1(c[3]), .in2(c[5]), .out1(d[1]), .out2(d[3]) );
    cmp c14(.in1(c[1]), .in2(d[2]), .out1(e[0]), .out2(e[2]) );
    cmp c15(.in1(d[1]), .in2(c[6]), .out1(e[1]), .out2(e[3]) );
    cmp c16(.in1(e[0]), .in2(d[0]), .out1(f[0]), .out2(f[1]) );
    cmp c17(.in1(e[1]), .in2(e[2]), .out1(f[2]), .out2(f[3]) );
    cmp c18(.in1(d[3]), .in2(e[3]), .out1(f[4]), .out2(f[5]) );

    assign out0 = c[0];
    assign out1 = f[0];
    assign out2 = f[1];
    assign out3 = f[2];
    assign out4 = f[3];
    assign out5 = f[4];
    assign out6 = f[5];
    assign out7 = c[7];

endmodule


module mul4(in1, in2, out) ;

input [3:0] in1 ;
input [3:0] in2 ;
output [7:0] out ;

wire [7:0] temp1, temp2;


assign temp1 =  ( ( {in1, 2'd0} & {6{in2[2]}}) + ({in1, 3'd0} & {7{in2[3]}}) ) ;
assign temp2 =  ( ({1'b0, in1 & {4{in2[0]}}}) + ({in1, 1'b0} & {5{in2[1]}}) );
assign out = temp1 + temp2;

endmodule

//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2023 Fall
//   Lab04 Exercise		: Convolution Neural Network 
//   Author     		: Yu-Chi Lin (a6121461214.st12@nycu.edu.tw)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CNN.v
//   Module Name : CNN
//   Release version : V1.0 (Release Date: 2024-10)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module CNN(
    //Input Port
    clk,
    rst_n,
    in_valid,
    Img,
    Kernel_ch1,
    Kernel_ch2,
	Weight,
    Opt,

    //Output Port
    out_valid,
    out
    );


//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

// IEEE floating point parameter
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

// parameter IDLE = 3'd0;
// parameter IN = 3'd1;
// parameter CAL = 3'd2;
// parameter OUT = 3'd3;
parameter bit_width = 31;
parameter fp_zero = 32'h00000000;
parameter fp_neg_min_normal = 32'hFF800000;// change to negative large value
parameter fp_one = 32'h3F800000;
parameter fp_two = 32'h40000000; // 2
parameter fp_neg_one = 32'hBF800000; //-1

integer i;

input rst_n, clk, in_valid;
input [inst_sig_width+inst_exp_width:0] Img, Kernel_ch1, Kernel_ch2, Weight;
input Opt;

output reg	out_valid;
output reg [inst_sig_width+inst_exp_width:0] out;

//---------------------------------------------------------------------
//   Reg & Wires
//---------------------------------------------------------------------

reg opt_reg;
reg nxt_opt;
reg [6:0] cnt, nxt_cnt;
reg [5:0] cnt_conv, nxt_cnt_conv;
reg [4:0] cnt_max_pool, nxt_cnt_max_pool;
// reg [4:0] cnt_act, nxt_cnt_act;

reg [bit_width:0] img_2_reg [0:24];
reg [bit_width:0] nxt_img_2_reg [0:24];

reg [bit_width:0] img_1_reg [0:24];
reg [bit_width:0] nxt_img_1_reg [0:24];

reg [bit_width:0] img_3_reg [0:24];
reg [bit_width:0] nxt_img_3_reg [0:24];

reg [bit_width:0] kernel_1_1_reg [0:3];
reg [bit_width:0] n_kernel_1_1_reg [0:3];
reg [bit_width:0] kernel_1_2_reg [0:3];
reg [bit_width:0] n_kernel_1_2_reg [0:3];
reg [bit_width:0] kernel_1_3_reg [0:3];
reg [bit_width:0] n_kernel_1_3_reg [0:3];

reg [bit_width:0] kernel_2_1_reg [0:3];
reg [bit_width:0] n_kernel_2_1_reg [0:3];
reg [bit_width:0] kernel_2_2_reg [0:3];
reg [bit_width:0] n_kernel_2_2_reg [0:3];
reg [bit_width:0] kernel_2_3_reg [0:3];
reg [bit_width:0] n_kernel_2_3_reg [0:3];

reg [bit_width:0] weight_1_reg [0:7];
reg [bit_width:0] n_weight_1_reg [0:7];
reg [bit_width:0] weight_2_reg [0:7];
reg [bit_width:0] n_weight_2_reg [0:7];
reg [bit_width:0] weight_3_reg [0:7];
reg [bit_width:0] n_weight_3_reg [0:7];


reg [inst_sig_width+inst_exp_width:0] PE_weight         [0:3]; 
reg [inst_sig_width+inst_exp_width:0] PE_image       [0:3]; 
reg [inst_sig_width+inst_exp_width:0] PE_partial_sum_input  [0:3]; 
wire [inst_sig_width+inst_exp_width:0] PE_partial_sum_output [0:3]; 
reg [inst_sig_width+inst_exp_width:0] partial_sum_reg    [0:13]; //shift register


reg [inst_sig_width+inst_exp_width:0] PE_weight1         [0:3]; 
reg [inst_sig_width+inst_exp_width:0] PE_image1       [0:3]; 
reg [inst_sig_width+inst_exp_width:0] PE_partial_sum_input1  [0:3]; 
wire [inst_sig_width+inst_exp_width:0] PE_partial_sum_output1 [0:3]; 
reg [inst_sig_width+inst_exp_width:0] partial_sum_reg1    [0:13]; //shift register


reg [inst_sig_width+inst_exp_width:0] PE_weight_2         [0:3]; 
reg [inst_sig_width+inst_exp_width:0] PE_image_2       [0:3]; 
reg [inst_sig_width+inst_exp_width:0] PE_partial_sum_input_2  [0:3]; 
wire [inst_sig_width+inst_exp_width:0] PE_partial_sum_output_2 [0:3]; 
reg [inst_sig_width+inst_exp_width:0] partial_sum_reg_2    [0:31]; //shift register


reg [inst_sig_width+inst_exp_width:0] PE_weight_21         [0:3]; 
reg [inst_sig_width+inst_exp_width:0] PE_image_21       [0:3]; 
reg [inst_sig_width+inst_exp_width:0] PE_partial_sum_input_21  [0:3]; 
wire [inst_sig_width+inst_exp_width:0] PE_partial_sum_output_21 [0:3]; 
reg [inst_sig_width+inst_exp_width:0] partial_sum_reg_21    [0:31]; //shift register
//---------------------------------------------------------------------
// IPs
//---------------------------------------------------------------------


//---------------------------------------------------------------------
// Design
//---------------------------------------------------------------------
always @(*) begin
    if (cnt == 0 && in_valid) begin
        nxt_opt = Opt;
    end else nxt_opt = opt_reg;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        opt_reg<= 0;
    end else opt_reg <=  nxt_opt;
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
    end else if (cnt == 97) begin
        nxt_cnt = 0;
    end
    else nxt_cnt = cnt + 1;
end

// conv cnt
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt_conv <= 0;
    end else cnt_conv <= nxt_cnt_conv;
end

always @(*) begin
    if (!in_valid && cnt == 0) begin
        nxt_cnt_conv = 0;
    end else if (cnt_conv == 17) begin
        nxt_cnt_conv = 0;
    end else if (cnt > 23) begin
        nxt_cnt_conv = cnt_conv + 1;
    end else nxt_cnt_conv = 0;
end



always @(posedge clk) begin
    for(i=0; i<25; i=i+1) begin
        img_1_reg[i] <= nxt_img_1_reg[i];
    end
    
    for(i=0; i<25; i=i+1) begin
        img_2_reg[i] <= nxt_img_2_reg[i];
    end

    for(i=0; i<25; i=i+1) begin
        img_3_reg[i] <= nxt_img_3_reg[i];
    end


    for(i=0; i<4; i=i+1) begin
        kernel_1_1_reg[i] <= n_kernel_1_1_reg[i];
    end
    for(i=0; i<4; i=i+1) begin
        kernel_1_2_reg[i] <= n_kernel_1_2_reg[i];
    end
    for(i=0; i<4; i=i+1) begin
        kernel_1_3_reg[i] <= n_kernel_1_3_reg[i];
    end
    for(i=0; i<4; i=i+1) begin
        kernel_2_1_reg[i] <= n_kernel_2_1_reg[i];
    end
    for(i=0; i<4; i=i+1) begin
        kernel_2_2_reg[i] <= n_kernel_2_2_reg[i];
    end
    for(i=0; i<4; i=i+1) begin
        kernel_2_3_reg[i] <= n_kernel_2_3_reg[i];
    end

    for(i=0; i<8; i=i+1) begin
        weight_1_reg[i] <= n_weight_1_reg[i];
    end

    for(i=0; i<8; i=i+1) begin
        weight_2_reg[i] <= n_weight_2_reg[i];
    end

    for(i=0; i<8; i=i+1) begin
        weight_3_reg[i] <= n_weight_3_reg[i];
    end
end
//Store 3 5*5 img 
always @(*) begin
    // img 1
    for (i = 0 ; i < 25 ; i = i + 1 ) begin
        if (cnt < 25 && (cnt == i)) begin
            nxt_img_1_reg[i] <= Img; 
        end
        else if (cnt > 27 && (cnt == (i+28))) begin
            nxt_img_1_reg[i] <= nxt_img_2_reg[i]; 
        end 
        
        else if (cnt > 51 && (cnt == (i+52))) begin
            nxt_img_1_reg[i] <= nxt_img_3_reg[i]; 
        end 
        
        else begin
            nxt_img_1_reg[i] <= img_1_reg[i];
        end
    end
    // img 2
    for (i = 0 ; i < 25 ; i = i + 1 ) begin
        if ( cnt >= 25 && (cnt == (i+25))) begin
            nxt_img_2_reg[i] <= Img; 
        end
        else begin
            nxt_img_2_reg[i] <= img_2_reg[i];
        end
    end
        // img 3
    for (i = 0 ; i < 25 ; i = i + 1 ) begin
        if ( cnt >= 50 && (cnt == (i+50))) begin
            nxt_img_3_reg[i] <= Img; 
        end
        else begin
            nxt_img_3_reg[i] <= img_3_reg[i];
        end
    end
end

//Store kernel 2 channel 
always @(*) begin
    for (i = 0 ; i < 4 ; i = i + 1 ) begin
        if (cnt == i) begin
            n_kernel_1_1_reg[i] <= Kernel_ch1;
            n_kernel_2_1_reg[i] <= Kernel_ch2;               
        end
        else  if (cnt > 41 && (cnt == (i+42))) begin
            n_kernel_1_1_reg[i] <= kernel_1_2_reg[i];
            n_kernel_2_1_reg[i] <= kernel_2_2_reg[i];               
        end
        else  if (cnt > 59 && (cnt == (i+60))) begin
            n_kernel_1_1_reg[i] <= kernel_1_3_reg[i];
            n_kernel_2_1_reg[i] <= kernel_2_3_reg[i];               
        end
        else begin
            n_kernel_1_1_reg[i] <= kernel_1_1_reg[i];
            n_kernel_2_1_reg[i] <= kernel_2_1_reg[i];
        end
    end

    for (i = 0 ; i < 4 ; i = i + 1 ) begin
        if (cnt == (i+4)) begin
            n_kernel_1_2_reg[i] <= Kernel_ch1;
            n_kernel_2_2_reg[i] <= Kernel_ch2;               
        end
        else begin
            n_kernel_1_2_reg[i] <= kernel_1_2_reg[i];
            n_kernel_2_2_reg[i] <= kernel_2_2_reg[i];
        end
    end

    for (i = 0 ; i < 4 ; i = i + 1 ) begin
        if (cnt == (i+8)) begin
            n_kernel_1_3_reg[i] <= Kernel_ch1;
            n_kernel_2_3_reg[i] <= Kernel_ch2;               
        end
        else begin
            n_kernel_1_3_reg[i] <= kernel_1_3_reg[i];
            n_kernel_2_3_reg[i] <= kernel_2_3_reg[i];
        end
    end
end

//Store weight
always @(*) begin
    for (i = 0 ; i < 8 ; i = i + 1 ) begin
        if (cnt == i) begin
            n_weight_1_reg[i] <= Weight;           
        end
        else begin
            n_weight_1_reg[i]  <= weight_1_reg[i];
        end
    end

    for (i = 0 ; i < 8 ; i = i + 1 ) begin
        if (cnt == (i+8)) begin
            n_weight_2_reg[i] <= Weight;           
        end
        else begin
            n_weight_2_reg[i]  <= weight_2_reg[i];
        end
    end

        for (i = 0 ; i < 8 ; i = i + 1 ) begin
        if (cnt == (i+16)) begin
            n_weight_3_reg[i] <= Weight;           
        end
        else begin
            n_weight_3_reg[i]  <= weight_3_reg[i];
        end
    end
end

// PE units 01
genvar p_i;
generate
    for(p_i=0; p_i<4; p_i=p_i+1) begin
        PE u_PE(.clk(clk), .weight(PE_weight[p_i]), .img(PE_image[p_i]), .partial_sum_input(PE_partial_sum_input[p_i]), .partial_sum_output(PE_partial_sum_output[p_i]));
        PE u_PE_0(.clk(clk), .weight(PE_weight1[p_i]), .img(PE_image1[p_i]), .partial_sum_input(PE_partial_sum_input1[p_i]), .partial_sum_output(PE_partial_sum_output1[p_i]));
    end
endgenerate

reg [inst_sig_width+inst_exp_width:0] PE_image_3to1_reg, PE_image_3to1_reg1;
reg [inst_sig_width+inst_exp_width:0] PE_image_2to0_reg, PE_image_2to0_reg1;


always@(posedge clk) begin
    PE_image_3to1_reg <= PE_image[3];
    PE_image_2to0_reg <= PE_image[2];
    PE_image_3to1_reg1 <= PE_image1[3];
    PE_image_2to0_reg1 <= PE_image1[2];
end

// PE[0]
always @(*) begin
    case(cnt_conv)
        // 1st row
        6'd1    : PE_image[0] = opt_reg ? img_1_reg[0] : fp_zero;
        6'd2    : PE_image[0] = opt_reg ? img_1_reg[1] : fp_zero;
        6'd3    : PE_image[0] = opt_reg ? img_1_reg[3] : fp_zero;
        default : PE_image[0] = PE_image_2to0_reg;
    endcase

end
// PE[1]
always @(*) begin

    case(cnt_conv)
        // 1st row
        6'd2    : PE_image[1] = opt_reg ? img_1_reg[0] : fp_zero;
        6'd3    : PE_image[1] = opt_reg ? img_1_reg[2] : fp_zero;
        6'd4    : PE_image[1] = opt_reg ? img_1_reg[4] : fp_zero;
        default : PE_image[1] = PE_image_3to1_reg ;
    endcase

end
// PE[2]
always @(*) begin
    if (cnt > 24) begin
    case(cnt_conv)
        6'd0   : PE_image[2] = opt_reg ? img_1_reg[20] : fp_zero;
        6'd1   : PE_image[2] = opt_reg ? img_1_reg[21] : fp_zero;
        6'd2   : PE_image[2] = opt_reg ? img_1_reg[23] : fp_zero;

        6'd3    : PE_image[2] = opt_reg ? img_1_reg[0] : fp_zero;
        6'd4    : PE_image[2] = img_1_reg[1];
        6'd5    : PE_image[2] = img_1_reg[3];
        6'd6    : PE_image[2] = opt_reg ? img_1_reg[5]: fp_zero;
        6'd7    : PE_image[2] = img_1_reg[6];
        6'd8    : PE_image[2] = img_1_reg[8];
        6'd9    : PE_image[2] = opt_reg ? img_1_reg[10] : fp_zero;
        6'd10   : PE_image[2] = img_1_reg[11];
        6'd11   : PE_image[2] = img_1_reg[13];
        6'd12   : PE_image[2] = opt_reg ? img_1_reg[15] : fp_zero;
        6'd13   : PE_image[2] = img_1_reg[16];
        6'd14   : PE_image[2] = img_1_reg[18];
        6'd15   : PE_image[2] = opt_reg ? img_1_reg[20] : fp_zero;
        6'd16   : PE_image[2] = img_1_reg[21];
        6'd17   : PE_image[2] = img_1_reg[23];
        default : PE_image[2] =  fp_zero;
    endcase
    end
    else begin
       PE_image[2] =  fp_zero;
    end
end
// PE[3]
always @(*) begin
    if (cnt > 24) begin
    case(cnt_conv)

        6'd0   : PE_image[3] = img_1_reg[24];
        6'd1   : PE_image[3] = opt_reg ? img_1_reg[20] : fp_zero;
        6'd2   : PE_image[3] = opt_reg ? img_1_reg[22] : fp_zero;
        6'd3   : PE_image[3] = opt_reg ? img_1_reg[24] : fp_zero;

        6'd4    : PE_image[3] = img_1_reg[0];
        6'd5    : PE_image[3] = img_1_reg[2];
        6'd6    : PE_image[3] = img_1_reg[4];
        6'd7    : PE_image[3] = img_1_reg[5];
        6'd8    : PE_image[3] = img_1_reg[7];
        6'd9    : PE_image[3] = img_1_reg[9];
        6'd10   : PE_image[3] = img_1_reg[10];
        6'd11   : PE_image[3] = img_1_reg[12];
        6'd12   : PE_image[3] = img_1_reg[14];
        6'd13   : PE_image[3] = img_1_reg[15];
        6'd14   : PE_image[3] = img_1_reg[17];
        6'd15   : PE_image[3] = img_1_reg[19];
        6'd16   : PE_image[3] = img_1_reg[20];
        6'd17   : PE_image[3] = img_1_reg[22];
        default : PE_image[3] = fp_zero;
    endcase
    end
    else begin
       PE_image[3] =  fp_zero;
    end
end

//Parallel

// PE[0]
always @(*) begin
    case(cnt_conv)
        // 1st row
        6'd1    : PE_image1[0] = opt_reg ? img_1_reg[0] : fp_zero;
        6'd2    : PE_image1[0] = opt_reg ? img_1_reg[2] : fp_zero;
        6'd3    : PE_image1[0] = opt_reg ? img_1_reg[4] : fp_zero;
        default : PE_image1[0] = PE_image_2to0_reg1;
    endcase
end
// PE[1]
always @(*) begin
    case(cnt_conv)
        // 1st row
        6'd2    : PE_image1[1] = opt_reg ? img_1_reg[1] : fp_zero;
        6'd3    : PE_image1[1] = opt_reg ? img_1_reg[3] : fp_zero;
        6'd4    : PE_image1[1] = opt_reg ? img_1_reg[4] : fp_zero;
        default : PE_image1[1] = PE_image_3to1_reg1 ;
    endcase
end
// PE[2]
always @(*) begin
    if (cnt > 24) begin
    case(cnt_conv)
        6'd0   : PE_image1[2] = opt_reg ? img_1_reg[20] : fp_zero;
        6'd1   : PE_image1[2] = opt_reg ? img_1_reg[22] : fp_zero;
        6'd2   : PE_image1[2] = opt_reg ? img_1_reg[24] : fp_zero;

        6'd3    : PE_image1[2] = img_1_reg[0] ;
        6'd4    : PE_image1[2] = img_1_reg[2];
        6'd5    : PE_image1[2] = img_1_reg[4];
        6'd6    : PE_image1[2] = img_1_reg[5];
        6'd7    : PE_image1[2] = img_1_reg[7];
        6'd8    : PE_image1[2] = img_1_reg[9];
        6'd9    : PE_image1[2] = img_1_reg[10];
        6'd10   : PE_image1[2] = img_1_reg[12];
        6'd11   : PE_image1[2] = img_1_reg[14];
        6'd12   : PE_image1[2] = img_1_reg[15];
        6'd13   : PE_image1[2] = img_1_reg[17];
        6'd14   : PE_image1[2] = img_1_reg[19];
        6'd15   : PE_image1[2] = img_1_reg[20];
        6'd16   : PE_image1[2] = img_1_reg[22];
        6'd17   : PE_image1[2] = img_1_reg[24];
    
        default : PE_image1[2] =  fp_zero;
    endcase
    end
    else begin
       PE_image1[2] =  fp_zero;
    end
end
// PE[3]
always @(*) begin
    if (cnt > 24) begin
    case(cnt_conv)

        6'd0   : PE_image1[3] = opt_reg ? img_1_reg[24] : fp_zero;
        6'd1   : PE_image1[3] = opt_reg ? img_1_reg[21] : fp_zero;
        6'd2   : PE_image1[3] = opt_reg ? img_1_reg[23] : fp_zero;
        6'd3   : PE_image1[3] = opt_reg ? img_1_reg[24] : fp_zero;

        6'd4    : PE_image1[3] = img_1_reg[1];
        6'd5    : PE_image1[3] = img_1_reg[3];
        6'd6    : PE_image1[3] = opt_reg ? img_1_reg[4] : fp_zero;
        6'd7    : PE_image1[3] = img_1_reg[6];
        6'd8    : PE_image1[3] = img_1_reg[8];
        6'd9    : PE_image1[3] = opt_reg ? img_1_reg[9] : fp_zero;
        6'd10   : PE_image1[3] = img_1_reg[11];
        6'd11   : PE_image1[3] = img_1_reg[13];
        6'd12   : PE_image1[3] = opt_reg ? img_1_reg[14] : fp_zero;
        6'd13   : PE_image1[3] = img_1_reg[16];
        6'd14   : PE_image1[3] = img_1_reg[18];
        6'd15   : PE_image1[3] = opt_reg ? img_1_reg[19] : fp_zero;
        6'd16   : PE_image1[3] = img_1_reg[21];
        6'd17   : PE_image1[3] = img_1_reg[23];
        default : PE_image1[3] = fp_zero;
    endcase
    end
    else begin
       PE_image1[3] =  fp_zero;
    end
end


always @(*) begin
    for(i=0; i<4; i=i+1) begin
        PE_weight[i] = kernel_1_1_reg[i];
        PE_weight1[i] = kernel_1_1_reg[i];
    end
end

always @(posedge clk) begin
    for(i=0; i<13; i=i+1) begin
        partial_sum_reg[i] <= partial_sum_reg[i+1];
        partial_sum_reg1[i] <= partial_sum_reg1[i+1];
    end
    partial_sum_reg[13] <= PE_partial_sum_output[3];
    partial_sum_reg1[13] <= PE_partial_sum_output1[3];
end

// partial sum flow in PE: PE[0] -> PE[1] -> PE[2] -> ... -> PE[8]
always @(*) begin
    for(i=1; i<4; i=i+1) begin
        PE_partial_sum_input[i] = PE_partial_sum_output[i-1];
        PE_partial_sum_input1[i] = PE_partial_sum_output1[i-1];
    end
end

always @(*) begin
    if((cnt>42 && cnt<61) ) begin
        // PE_partial_sum_input[0] = partial_sum_reg[0];
        PE_partial_sum_input[0] = partial_sum_reg[0];
        PE_partial_sum_input1[0] = partial_sum_reg1[0];
    end
    else if((cnt>60 && cnt<79) ) begin
        // PE_partial_sum_input[0] = partial_sum_reg[0];
        PE_partial_sum_input[0] = partial_sum_reg[0];
        PE_partial_sum_input1[0] = partial_sum_reg1[0];
    end
    else begin
        PE_partial_sum_input[0] = fp_zero;
        PE_partial_sum_input1[0] = fp_zero;
    end
end

//PE unit 02
genvar p_j;
generate
    for(p_j=0; p_j<4; p_j=p_j+1) begin
        PE u_PE_2(.clk(clk), .weight(PE_weight_2[p_j]), .img(PE_image_2[p_j]), .partial_sum_input(PE_partial_sum_input_2[p_j]), .partial_sum_output(PE_partial_sum_output_2[p_j]));
        PE u_PE_21(.clk(clk), .weight(PE_weight_21[p_j]), .img(PE_image_21[p_j]), .partial_sum_input(PE_partial_sum_input_21[p_j]), .partial_sum_output(PE_partial_sum_output_21[p_j]));
    end
endgenerate

reg [inst_sig_width+inst_exp_width:0] PE_image_3to1_reg_2,PE_image_3to1_reg_21;
reg [inst_sig_width+inst_exp_width:0] PE_image_2to0_reg_2,PE_image_2to0_reg_21;


always@(posedge clk) begin
    PE_image_3to1_reg_2 <= PE_image_2[3];
    PE_image_2to0_reg_2 <= PE_image_2[2];

    PE_image_3to1_reg_21 <= PE_image_21[3];
    PE_image_2to0_reg_21 <= PE_image_21[2];

end
// PE[0]
always @(*) begin
    case(cnt_conv)
        // 1st row
        6'd1    : PE_image_2[0] = opt_reg ? img_1_reg[0] : fp_zero;
        6'd2    : PE_image_2[0] = opt_reg ? img_1_reg[1] : fp_zero;
        6'd3    : PE_image_2[0] = opt_reg ? img_1_reg[3] : fp_zero;

        default : PE_image_2[0] = PE_image_2to0_reg_2;
    endcase
end
// PE[1]
always @(*) begin
    case(cnt_conv)
        // 1st row
        6'd2    : PE_image_2[1] = opt_reg ? img_1_reg[0] : fp_zero;
        6'd3    : PE_image_2[1] = opt_reg ? img_1_reg[2] : fp_zero;
        6'd4    : PE_image_2[1] = opt_reg ? img_1_reg[4] : fp_zero;
        default : PE_image_2[1] = PE_image_3to1_reg_2 ;
    endcase
end
// PE[2]
always @(*) begin
        if (cnt > 24) begin
    case(cnt_conv)
        6'd0   : PE_image_2[2] = opt_reg ? img_1_reg[20] : fp_zero;
        6'd1   : PE_image_2[2] = opt_reg ? img_1_reg[21] : fp_zero;
        6'd2   : PE_image_2[2] = opt_reg ? img_1_reg[23] : fp_zero;

        6'd3    : PE_image_2[2] = opt_reg ? img_1_reg[0] : fp_zero;
        6'd4    : PE_image_2[2] = img_1_reg[1];
        6'd5    : PE_image_2[2] = img_1_reg[3];
        6'd6    : PE_image_2[2] = opt_reg ? img_1_reg[5]: fp_zero;
        6'd7    : PE_image_2[2] = img_1_reg[6];
        6'd8    : PE_image_2[2] = img_1_reg[8];
        6'd9    : PE_image_2[2] = opt_reg ? img_1_reg[10] : fp_zero;
        6'd10   : PE_image_2[2] = img_1_reg[11];
        6'd11   : PE_image_2[2] = img_1_reg[13];
        6'd12   : PE_image_2[2] = opt_reg ? img_1_reg[15] : fp_zero;
        6'd13   : PE_image_2[2] = img_1_reg[16];
        6'd14   : PE_image_2[2] = img_1_reg[18];
        6'd15   : PE_image_2[2] = opt_reg ? img_1_reg[20] : fp_zero;
        6'd16   : PE_image_2[2] = img_1_reg[21];
        6'd17   : PE_image_2[2] = img_1_reg[23];
    
        default : PE_image_2[2] =  fp_zero;
    endcase
        end
        else begin
       PE_image_2[2] =  fp_zero;
    end
end
// PE[3]
always @(*) begin
        if (cnt > 24) begin
    case(cnt_conv)
        6'd0   : PE_image_2[3] = img_1_reg[24];
        6'd1   : PE_image_2[3] = opt_reg ? img_1_reg[20] : fp_zero;
        6'd2   : PE_image_2[3] = opt_reg ? img_1_reg[22] : fp_zero;
        6'd3   : PE_image_2[3] = opt_reg ? img_1_reg[24] : fp_zero;

        6'd4    : PE_image_2[3] = img_1_reg[0];
        6'd5    : PE_image_2[3] = img_1_reg[2];
        6'd6    : PE_image_2[3] = img_1_reg[4];
        6'd7    : PE_image_2[3] = img_1_reg[5];
        6'd8    : PE_image_2[3] = img_1_reg[7];
        6'd9    : PE_image_2[3] = img_1_reg[9];
        6'd10   : PE_image_2[3] = img_1_reg[10];
        6'd11   : PE_image_2[3] = img_1_reg[12];
        6'd12   : PE_image_2[3] = img_1_reg[14];
        6'd13   : PE_image_2[3] = img_1_reg[15];
        6'd14   : PE_image_2[3] = img_1_reg[17];
        6'd15   : PE_image_2[3] = img_1_reg[19];
        6'd16   : PE_image_2[3] = img_1_reg[20];
        6'd17   : PE_image_2[3] = img_1_reg[22];

        default : PE_image_2[3] = fp_zero;
    endcase
        end
    else begin
       PE_image_2[3] =  fp_zero;
    end
end

//Parallel
// PE[0]
always @(*) begin
    case(cnt_conv)
        // 1st row
        6'd1    : PE_image_21[0] = opt_reg ? img_1_reg[0] : fp_zero;
        6'd2    : PE_image_21[0] = opt_reg ? img_1_reg[2] : fp_zero;
        6'd3    : PE_image_21[0] = opt_reg ? img_1_reg[4] : fp_zero;
        default : PE_image_21[0] = PE_image_2to0_reg_21;
    endcase
end
// PE[1]
always @(*) begin
    case(cnt_conv)
        // 1st row
        6'd2    : PE_image_21[1] = opt_reg ? img_1_reg[1] : fp_zero;
        6'd3    : PE_image_21[1] = opt_reg ? img_1_reg[3] : fp_zero;
        6'd4    : PE_image_21[1] = opt_reg ? img_1_reg[4] : fp_zero;
        default : PE_image_21[1] = PE_image_3to1_reg_21 ;
    endcase
end
// PE[2]
always @(*) begin
    if (cnt > 24) begin
    case(cnt_conv)
        6'd0   : PE_image_21[2] = opt_reg ? img_1_reg[20] : fp_zero;
        6'd1   : PE_image_21[2] = opt_reg ? img_1_reg[22] : fp_zero;
        6'd2   : PE_image_21[2] = opt_reg ? img_1_reg[24] : fp_zero;

        6'd3    : PE_image_21[2] = img_1_reg[0] ;
        6'd4    : PE_image_21[2] = img_1_reg[2];
        6'd5    : PE_image_21[2] = img_1_reg[4];
        6'd6    : PE_image_21[2] = img_1_reg[5];
        6'd7    : PE_image_21[2] = img_1_reg[7];
        6'd8    : PE_image_21[2] = img_1_reg[9];
        6'd9    : PE_image_21[2] = img_1_reg[10];
        6'd10   : PE_image_21[2] = img_1_reg[12];
        6'd11   : PE_image_21[2] = img_1_reg[14];
        6'd12   : PE_image_21[2] = img_1_reg[15];
        6'd13   : PE_image_21[2] = img_1_reg[17];
        6'd14   : PE_image_21[2] = img_1_reg[19];
        6'd15   : PE_image_21[2] = img_1_reg[20];
        6'd16   : PE_image_21[2] = img_1_reg[22];
        6'd17   : PE_image_21[2] = img_1_reg[24];
    
        default : PE_image_21[2] =  fp_zero;
    endcase
    end
    else begin
       PE_image_21[2] =  fp_zero;
    end
end
// PE[3]
always @(*) begin
    if (cnt > 24) begin
    case(cnt_conv)

        6'd0   : PE_image_21[3] = opt_reg ? img_1_reg[24] : fp_zero;
        6'd1   : PE_image_21[3] = opt_reg ? img_1_reg[21] : fp_zero;
        6'd2   : PE_image_21[3] = opt_reg ? img_1_reg[23] : fp_zero;
        6'd3   : PE_image_21[3] = opt_reg ? img_1_reg[24] : fp_zero;

        6'd4    : PE_image_21[3] = img_1_reg[1];
        6'd5    : PE_image_21[3] = img_1_reg[3];
        6'd6    : PE_image_21[3] = opt_reg ? img_1_reg[4] : fp_zero;
        6'd7    : PE_image_21[3] = img_1_reg[6];
        6'd8    : PE_image_21[3] = img_1_reg[8];
        6'd9    : PE_image_21[3] = opt_reg ? img_1_reg[9] : fp_zero;
        6'd10   : PE_image_21[3] = img_1_reg[11];
        6'd11   : PE_image_21[3] = img_1_reg[13];
        6'd12   : PE_image_21[3] = opt_reg ? img_1_reg[14] : fp_zero;
        6'd13   : PE_image_21[3] = img_1_reg[16];
        6'd14   : PE_image_21[3] = img_1_reg[18];
        6'd15   : PE_image_21[3] = opt_reg ? img_1_reg[19] : fp_zero;
        6'd16   : PE_image_21[3] = img_1_reg[21];
        6'd17   : PE_image_21[3] = img_1_reg[23];
        
        default : PE_image_21[3] = fp_zero;
    endcase
    end
    else begin
       PE_image_21[3] =  fp_zero;
    end
end

always @(*) begin
    for(i=0; i<4; i=i+1) begin
        PE_weight_2[i] = kernel_2_1_reg[i];
        PE_weight_21[i] = kernel_2_1_reg[i];
    end
end

always @(posedge clk) begin
    for(i=0; i<13; i=i+1) begin
        partial_sum_reg_2[i] <= partial_sum_reg_2[i+1];
        partial_sum_reg_21[i] <= partial_sum_reg_21[i+1];
    end
    partial_sum_reg_2[13] <= PE_partial_sum_output_2[3];
    partial_sum_reg_21[13] <= PE_partial_sum_output_21[3];
end

always @(*) begin
    for(i=1; i<4; i=i+1) begin
        PE_partial_sum_input_2[i] = PE_partial_sum_output_2[i-1];
        PE_partial_sum_input_21[i] = PE_partial_sum_output_21[i-1];
    end
end

always @(*) begin
    if((cnt>42 && cnt<61) ) begin
        PE_partial_sum_input_2[0] = partial_sum_reg_2[0];
        PE_partial_sum_input_21[0] = partial_sum_reg_21[0];
    end
    else if((cnt>60 && cnt<79) ) begin
        // PE_partial_sum_input[0] = partial_sum_reg[0];
        PE_partial_sum_input_2[0] = partial_sum_reg_2[0];
        PE_partial_sum_input_21[0] = partial_sum_reg_21[0];
    end
    else begin
        PE_partial_sum_input_2[0] = fp_zero;
        PE_partial_sum_input_21[0] = fp_zero;
    end
end

// max-pooling
// conv cnt
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt_max_pool <= 0;
    end else cnt_max_pool <= nxt_cnt_max_pool;
end

always @(*) begin
    if (cnt == 97) begin
        nxt_cnt_max_pool  = 0;
    end
    else if (cnt_max_pool == 8) begin
        nxt_cnt_max_pool = 0;
    end 
    else if ( cnt > 64) begin
        nxt_cnt_max_pool  = cnt_max_pool + 1;
    end  else nxt_cnt_max_pool = cnt_max_pool ;
end



// comparison
// wire [inst_sig_width+inst_exp_width:0] tmp_max1, tmp_max2, max_pooling_out;
reg [inst_sig_width+inst_exp_width:0] in1_1, in1_2, in2_1, in2_2, in3_1, in3_2, in0_1, in0_2;
reg [inst_sig_width+inst_exp_width:0] in1_1_reg, in0_1_reg;
reg [inst_sig_width+inst_exp_width:0] tmp_max1, tmp_max2;
reg [inst_sig_width+inst_exp_width:0] tmp_max1_reg, tmp_max2_reg;


reg [inst_sig_width+inst_exp_width:0] in2_1_reg, in3_1_reg,add_in_1, add_in_2,add_out,add_out_reg;
reg [inst_sig_width+inst_exp_width:0] tmp_max3, tmp_max4, pool_3_max,pool_4_max,pool_3_max_reg,pool_4_max_reg;
reg [inst_sig_width+inst_exp_width:0] tmp_max3_reg, tmp_max4_reg,pool_1_max,pool_2_max,pool_1_max_reg,pool_2_max_reg;



DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
         U1_mp_cmp0 ( .a(in0_1), .b(in0_2), .zctr(1'b0), .aeqb(),
        .altb(), .agtb(), .unordered(),
        .z0(), .z1(tmp_max1), .status0(),
        .status1() );
DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
         U1_mp_cmp1 ( .a(in1_1), .b(in1_2), .zctr(1'b0), .aeqb(),
        .altb(), .agtb(), .unordered(),
        .z0(), .z1(tmp_max2), .status0(),
        .status1() );
// for 2nd f map
DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
         U1_mp_cmp2 ( .a(in2_1), .b(in2_2), .zctr(1'b0), .aeqb(),
        .altb(), .agtb(), .unordered(),
        .z0(), .z1(tmp_max3), .status0(),
        .status1() );
DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
         U1_mp_cmp3 ( .a(in3_1), .b(in3_2), .zctr(1'b0), .aeqb(),
        .altb(), .agtb(), .unordered(),
        .z0(), .z1(tmp_max4), .status0(),
        .status1() );

DW_fp_addsub #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        U_adder1 ( .a(add_in_1), .b(add_in_2), .rnd(3'd0),
        .op(1'b0), .z(add_out), .status() );

always @(posedge clk ) begin
    tmp_max1_reg <= tmp_max1;
    tmp_max2_reg <= tmp_max2;
    tmp_max3_reg <= tmp_max3;
    tmp_max4_reg <= tmp_max4;

    in1_1_reg <= in1_1;
    in0_1_reg <= in0_1;
    in2_1_reg <= in2_1;
    in3_1_reg <= in3_1;

    pool_1_max_reg <= pool_1_max;
    pool_2_max_reg <= pool_2_max;
    pool_3_max_reg <= pool_3_max;
    pool_4_max_reg <= pool_4_max;

end
always @(*) begin
    pool_1_max = pool_1_max_reg;
    pool_2_max = pool_2_max_reg;
    pool_3_max = pool_3_max_reg;
    pool_4_max = pool_4_max_reg;
    in0_1 = in0_1_reg ;
    in0_2 = tmp_max1_reg;
    in1_1 = in1_1_reg;
    in1_2 = tmp_max2_reg;

    in2_1 = in2_1_reg ;
    in2_2 = tmp_max3_reg;
    in3_1 = in3_1_reg;
    in3_2 = tmp_max4_reg;
    case (cnt_max_pool)
        0 :  begin
            in0_1 = PE_partial_sum_output[3];
            in0_2 = PE_partial_sum_output1[3];

            in2_1 = PE_partial_sum_output_2[3];
            in2_2 = PE_partial_sum_output_21[3];
        end
        1 :  begin
            in0_1 = PE_partial_sum_output[3];
            in0_2 = tmp_max1_reg;
            in1_1 = PE_partial_sum_output1[3];
            in1_2 = fp_neg_min_normal;

            in2_1 = PE_partial_sum_output_2[3];
            in2_2 = tmp_max3_reg;
            in3_1 = PE_partial_sum_output_21[3];
            in3_2 = fp_neg_min_normal;

        end
        2 :  begin
            pool_1_max = tmp_max1_reg ;
            in1_1 = PE_partial_sum_output[3];
            in1_2 = PE_partial_sum_output1[3];
            in0_1 = tmp_max2_reg;
            in0_2 = tmp_max2; 
            pool_2_max = tmp_max1;

            pool_3_max = tmp_max3_reg ;
            in3_1 = PE_partial_sum_output_2[3];
            in3_2 = PE_partial_sum_output_21[3];
            in2_1 = tmp_max4_reg;
            in2_2 = tmp_max4; 
            pool_4_max = tmp_max3;
        end
        3 :  begin
            pool_2_max = tmp_max1_reg;
            in1_1 = PE_partial_sum_output1[3];
            in1_2 = PE_partial_sum_output[3];
            in0_1 = pool_1_max_reg;
            in0_2 = tmp_max2; 

            pool_1_max = tmp_max1;

            pool_4_max = tmp_max3_reg;
            in3_1 = PE_partial_sum_output_21[3];
            in3_2 = PE_partial_sum_output_2[3];
            in2_1 = pool_3_max_reg;
            in2_2 = tmp_max4;;

            pool_3_max = tmp_max3;
        end
        4 :  begin
            in0_1 = pool_1_max_reg;
            in0_2 = PE_partial_sum_output[3];
            in1_1 = PE_partial_sum_output1[3];
            in1_2 = pool_2_max_reg; 
            pool_1_max = tmp_max1;
            pool_2_max = tmp_max2;

            in2_1 = pool_3_max_reg;
            in2_2 = PE_partial_sum_output_2[3];
            in3_1 = PE_partial_sum_output_21[3];
            in3_2 = pool_4_max_reg; 
            pool_3_max = tmp_max3;
            pool_4_max = tmp_max4;
        end
        5 :  begin
            in1_1 = PE_partial_sum_output[3];
            in1_2 = PE_partial_sum_output1[3];
            in0_1 = pool_2_max_reg;
            in0_2 = tmp_max2; 
            pool_2_max = tmp_max1;

            in3_1 = PE_partial_sum_output_2[3];
            in3_2 = PE_partial_sum_output_21[3];
            in2_1 = pool_4_max_reg;
            in2_2 = tmp_max4; 
            pool_4_max = tmp_max3;
        end
        6 :  begin
            in1_1 = PE_partial_sum_output[3];
            in1_2 = PE_partial_sum_output1[3];
            in0_1 = pool_1_max_reg;
            in0_2 = tmp_max2;
            pool_1_max = tmp_max1;

            in3_1 = PE_partial_sum_output_2[3];
            in3_2 = PE_partial_sum_output_21[3];
            in2_1 = pool_3_max_reg;
            in2_2 = tmp_max4; 
            pool_3_max = tmp_max3;
        end
        7 :  begin
            in0_1 = pool_1_max_reg;
            in0_2 = PE_partial_sum_output[3];
            in1_1 = PE_partial_sum_output1[3];
            in1_2 = pool_2_max_reg; 
            pool_1_max = tmp_max1;
            pool_2_max = tmp_max2;

            in2_1 = pool_3_max_reg;
            in2_2 = PE_partial_sum_output_2[3];
            in3_1 = PE_partial_sum_output_21[3];
            in3_2 = pool_4_max_reg; 
            pool_3_max = tmp_max3;
            pool_4_max = tmp_max4;
        end
        8 :  begin
            in1_1 = PE_partial_sum_output[3];
            in1_2 = PE_partial_sum_output1[3];
            in0_1 = pool_2_max_reg;
            in0_2 = tmp_max2; 
            pool_2_max = tmp_max1;

            in3_1 = PE_partial_sum_output_2[3];
            in3_2 = PE_partial_sum_output_21[3];
            in2_1 = pool_4_max_reg;
            in2_2 = tmp_max4; 
            pool_4_max = tmp_max3;
        end

        default: begin
            in0_1 = in0_1_reg ;
            in0_2 = tmp_max1_reg;
            in1_1 = in1_1_reg;
            in1_2 = tmp_max2_reg;

            in2_1 = in2_1_reg ;
            in2_2 = tmp_max3_reg;
            in3_1 = in3_1_reg;
            in3_2 = tmp_max4_reg;
        end
    endcase 
end

reg [inst_sig_width+inst_exp_width:0]  exp_in_reg, exp_out_reg, div_out_reg, div_in1_reg, div_in2_reg , sub_in_1, sub_in_2 ;
wire [inst_sig_width+inst_exp_width:0] exp_out, div_out, sub_out, mac_out_o_0, mac_out_o_1;
reg [inst_sig_width+inst_exp_width:0] mac_in_a_0, mac_in_b_0, mac_in_c_0;
reg [inst_sig_width+inst_exp_width:0] mac_in_a_1, mac_in_b_1, mac_in_c_1;

reg [inst_sig_width+inst_exp_width:0]  mac_out_0_reg,  mac_out_1_reg, sub_out_reg;

// Activation function
DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) 
    U1_exp (.a(exp_in_reg), .z(exp_out), .status() ); 


DW_fp_div #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_faithful_round)
    U1_div ( .a(div_in1_reg), .b(div_in2_reg), .rnd(3'd0), .z(div_out), .status() );

DW_fp_addsub #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    U_sub ( .a(sub_in_1), .b(sub_in_2), .rnd(3'd0),.op(1'b1), .z(sub_out), .status() );


// step 1: Exponential
always @(posedge clk) begin
    exp_out_reg <= exp_out;
end

// step 2: add + sub
always @(posedge clk) begin
    add_out_reg <= add_out;
end

always @(*) begin
    add_in_1 = exp_out_reg ;
    add_in_2 = fp_one;
end

always @(posedge clk) begin
    sub_out_reg <= sub_out;
end

always @(*) begin
    sub_in_1 =  exp_out_reg;
    sub_in_2 =  (opt_reg)? fp_one: fp_zero;
end
// step 3: DIV


// activation complete
// Fully connected
// 97 , 100, 115, 118

wire [inst_sig_width+inst_exp_width:0]  mac_out_f_1, mac_out_f_2, mac_out_f_3;
reg  [inst_sig_width+inst_exp_width:0]  mac_out_f_1_reg, mac_out_f_2_reg, mac_out_f_3_reg;
reg  [inst_sig_width+inst_exp_width:0]  mac_in_f_1_1, mac_in_f_1_2, mac_in_f_1_3 ;
reg  [inst_sig_width+inst_exp_width:0]  mac_in_f_2_1, mac_in_f_2_2, mac_in_f_2_3 ;
reg  [inst_sig_width+inst_exp_width:0]  mac_in_f_3_1, mac_in_f_3_2, mac_in_f_3_3 ;


DW_fp_mac #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
    MAC_f_1 (.a(mac_in_f_1_1), .b(mac_in_f_1_2), .c(mac_in_f_1_3), .rnd(3'd0), .z(mac_out_f_1), .status() );

DW_fp_mac #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
    MAC_f_2 (.a(mac_in_f_2_1), .b(mac_in_f_2_2), .c(mac_in_f_2_3), .rnd(3'd0), .z(mac_out_f_2), .status() );

DW_fp_mac #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
    MAC_f_3 (.a(mac_in_f_3_1), .b( mac_in_f_3_2), .c(mac_in_f_3_3), .rnd(3'd0), .z(mac_out_f_3), .status() );

always @(posedge clk) begin
    mac_out_f_1_reg <= mac_out_f_1;
    mac_out_f_2_reg <= mac_out_f_2;
    mac_out_f_3_reg <= mac_out_f_3;
end

always @(*) begin
    mac_in_f_1_1 = div_out_reg;
    mac_in_f_2_1 = div_out_reg;
    mac_in_f_3_1 = div_out_reg;

    mac_in_f_1_3 = mac_out_f_1_reg;
    mac_in_f_2_3 = mac_out_f_2_reg;
    mac_in_f_3_3 = mac_out_f_3_reg;

    case (cnt)
        76: begin
            mac_in_f_1_2 = weight_1_reg[0];
            mac_in_f_2_2 = weight_2_reg[0];
            mac_in_f_3_2 = weight_3_reg[0];

            mac_in_f_1_3 = fp_zero;
            mac_in_f_2_3 = fp_zero;
            mac_in_f_3_3 = fp_zero;
        end
        77: begin
            mac_in_f_1_2 = weight_1_reg[4];
            mac_in_f_2_2 = weight_2_reg[4];
            mac_in_f_3_2 = weight_3_reg[4];
        end
        78: begin
            mac_in_f_1_2 = weight_1_reg[1];
            mac_in_f_2_2 = weight_2_reg[1];
            mac_in_f_3_2 = weight_3_reg[1];
        end
        79: begin
            mac_in_f_1_2 = weight_1_reg[5];
            mac_in_f_2_2 = weight_2_reg[5];
            mac_in_f_3_2 = weight_3_reg[5];
        end
        85: begin
            mac_in_f_1_2 = weight_1_reg[2];
            mac_in_f_2_2 = weight_2_reg[2];
            mac_in_f_3_2 = weight_3_reg[2];
        end
        86: begin
            mac_in_f_1_2 = weight_1_reg[6];
            mac_in_f_2_2 = weight_2_reg[6];
            mac_in_f_3_2 = weight_3_reg[6];
        end
        87: begin
            mac_in_f_1_2 = weight_1_reg[3];
            mac_in_f_2_2 = weight_2_reg[3];
            mac_in_f_3_2 = weight_3_reg[3];
        end
        88: begin
            mac_in_f_1_2 = weight_1_reg[7];
            mac_in_f_2_2 = weight_2_reg[7];
            mac_in_f_3_2 = weight_3_reg[7];
        end
        default: begin
            mac_in_f_1_1 = fp_zero;
            mac_in_f_2_1 = fp_zero;
            mac_in_f_3_1 = fp_zero;

            mac_in_f_1_2 = fp_one;
            mac_in_f_2_2 = fp_one;
            mac_in_f_3_2 = fp_one;
        end
    endcase
end


// Softmax
// cnt == 120 have results


reg [inst_sig_width+inst_exp_width:0]  exp_1_out, exp_2_out , exp_3_out ;
reg  [inst_sig_width+inst_exp_width:0]  exp_in_1_reg, exp_in_2_reg, exp_in_3_reg,exp_1_out_reg, exp_2_out_reg, exp_3_out_reg;

always @(*) begin
    case (cnt)
        73:  exp_in_reg = (opt_reg)  ? {pool_1_max_reg[31],pool_1_max_reg[30:23] + 1'b1, pool_1_max_reg[22:0]} : pool_1_max_reg;
        74:  exp_in_reg = (opt_reg)  ? {pool_3_max_reg[31],pool_3_max_reg[30:23] + 1'b1, pool_3_max_reg[22:0]} : pool_3_max_reg;
        75:  exp_in_reg = (opt_reg)  ? {pool_2_max_reg[31],pool_2_max_reg[30:23] + 1'b1, pool_2_max_reg[22:0]} : pool_2_max_reg;
        76:  exp_in_reg = (opt_reg)  ? {pool_4_max_reg[31],pool_4_max_reg[30:23] + 1'b1, pool_4_max_reg[22:0]} : pool_4_max_reg;
        82:  exp_in_reg = (opt_reg)  ? {pool_1_max_reg[31],pool_1_max_reg[30:23] + 1'b1, pool_1_max_reg[22:0]} : pool_1_max_reg;
        83:  exp_in_reg = (opt_reg)  ? {pool_3_max_reg[31],pool_3_max_reg[30:23] + 1'b1, pool_3_max_reg[22:0]} : pool_3_max_reg;
        84:  exp_in_reg = (opt_reg)  ? {pool_2_max_reg[31],pool_2_max_reg[30:23] + 1'b1, pool_2_max_reg[22:0]} : pool_2_max_reg;
        85:  exp_in_reg = (opt_reg)  ? {pool_4_max_reg[31],pool_4_max_reg[30:23] + 1'b1, pool_4_max_reg[22:0]} : pool_4_max_reg;
        89:  exp_in_reg = mac_out_f_1_reg;  // soft max
        90:  exp_in_reg = mac_out_f_2_reg;
        91:  exp_in_reg = mac_out_f_3_reg;
        default: exp_in_reg = fp_zero;
    endcase
end



always @(posedge clk) begin
    exp_1_out_reg <= exp_1_out;
    exp_2_out_reg <= exp_2_out;
    exp_3_out_reg <= exp_3_out;
end

always @(*) begin
        exp_1_out = exp_1_out_reg;
        exp_2_out = exp_2_out_reg;
        exp_3_out = exp_3_out_reg;

     if (cnt == 89) begin // soft max
        exp_1_out = exp_out;
    end else if (cnt == 90) begin
        exp_2_out = exp_out;
    end else if (cnt == 91) begin
        exp_3_out = exp_out;
    end else begin
        exp_1_out = exp_1_out_reg;
        exp_2_out = exp_2_out_reg;
        exp_3_out = exp_3_out_reg;
    end
end

wire [inst_sig_width+inst_exp_width:0]  mac_out_f_4;
reg  [inst_sig_width+inst_exp_width:0]  mac_out_f_4_reg, denominator;
reg  [inst_sig_width+inst_exp_width:0]  mac_in_f_4_1, mac_in_f_4_2, mac_in_f_4_3 ;

DW_fp_mac #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
    MAC_f_4 (.a(mac_in_f_4_1), .b(mac_in_f_4_2), .c(mac_in_f_4_3), .rnd(3'd0), .z(mac_out_f_4), .status() );

always @(posedge clk) begin
    mac_out_f_4_reg <= mac_out_f_4;
end

//change to exp_out_reg
always @(*) begin
    if (cnt == 90) begin
        mac_in_f_4_1 = exp_1_out_reg;
        mac_in_f_4_2 = fp_one;
        mac_in_f_4_3 = fp_zero;
    end else if (cnt == 91) begin
        mac_in_f_4_1 = exp_2_out_reg;
        mac_in_f_4_2 = fp_one;
        mac_in_f_4_3 = mac_out_f_4_reg;
    end else if (cnt == 92) begin
        mac_in_f_4_1 = exp_3_out_reg;
        mac_in_f_4_2 = fp_one;
        mac_in_f_4_3 = mac_out_f_4_reg;
    end else begin
        mac_in_f_4_1 = fp_one;
        mac_in_f_4_2 = fp_zero;
        mac_in_f_4_3 = mac_out_f_4_reg;
    end
end


reg  [inst_sig_width+inst_exp_width:0]  ans1;
reg  [inst_sig_width+inst_exp_width:0]  ans1_c;

always @(posedge clk) begin
    ans1 <= ans1_c;
end

//repeat the use of div
always @(posedge clk) begin
    div_out_reg <= div_out;
end

always @(*) begin
    ans1_c = ans1;
    div_in2_reg = mac_out_0_reg;
    div_in1_reg = fp_one;

    if (cnt == 93) begin
        div_in1_reg = exp_1_out_reg;
        div_in2_reg = mac_out_f_4_reg;
        ans1_c =  div_out;
    end else if (cnt == 94) begin
        div_in1_reg = exp_2_out_reg;
        div_in2_reg = mac_out_f_4_reg;
        ans1_c =  div_out;
    end else if (cnt == 95) begin
        div_in1_reg = exp_3_out_reg;
        div_in2_reg = mac_out_f_4_reg;
        ans1_c = div_out;
    end else begin
        div_in2_reg = add_out_reg;
        div_in1_reg = sub_out_reg;
        ans1_c = ans1;
    end
end

always @(*) begin
    if(cnt == 94 || cnt == 95 || cnt == 96 ) begin
        out_valid = 1;
    end
    else begin
        out_valid = 0;
    end
end 

always @(*) begin
    if (!rst_n) begin
        out = 0;
    end else if (cnt == 94) begin
        out = ans1;
    end else if (cnt == 95) begin
        out = ans1;
    end else if (cnt == 96) begin
        out = ans1;
    end
    else  out = 0;
end

endmodule

//processing unit

module PE(
    clk,
    weight,
    img, 
    partial_sum_input,
    partial_sum_output
);
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

input clk;
input [inst_sig_width+inst_exp_width:0] weight;
input [inst_sig_width+inst_exp_width:0] img;
input [inst_sig_width+inst_exp_width:0] partial_sum_input;
output reg [inst_sig_width+inst_exp_width:0] partial_sum_output;

wire [inst_sig_width+inst_exp_width:0] n_psum_out;
wire [inst_sig_width+inst_exp_width:0] tmp;


DW_fp_addsub #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        U_adder ( .a(partial_sum_input), .b(tmp), .rnd(3'd0),
        .op(1'b0), .z(n_psum_out), .status() );

DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
    U_mult ( .a(weight), .b(img), .rnd(3'd0), .z(tmp), .status( ) );


always @(posedge clk) begin
    partial_sum_output <= n_psum_out;
end

endmodule


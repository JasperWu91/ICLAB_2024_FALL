module FIFO_syn #(parameter WIDTH=8, parameter WORDS=64) (
    wclk,
    rclk,
    rst_n,
    winc,
    wdata,
    wfull,
    rinc,
    rdata,
    rempty,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo,

    flag_fifo_to_clk1,
	flag_clk1_to_fifo
);

input wclk, rclk;
input rst_n;
input winc; 
input [WIDTH-1:0] wdata;
output reg wfull;
input rinc;
output reg [WIDTH-1:0] rdata;
output reg rempty;

// You can change the input / output of the custom flag ports
output  flag_fifo_to_clk2;
input flag_clk2_to_fifo;

output flag_fifo_to_clk1;
input flag_clk1_to_fifo;

wire [WIDTH-1:0] rdata_q;

// Remember: 
//   wptr and rptr should be gray coded
//   Don't modify the signal name
reg [$clog2(WORDS):0] wptr;
reg [$clog2(WORDS):0] rptr;

//==========================================
// Design
//==========================================

reg [$clog2(WORDS)-1:0] w_addr, r_addr;
wire W_enable;

//read
wire [$clog2(WORDS):0]  r_to_w_ptr;
reg [$clog2(WORDS):0] rptr_n; // gray
reg [$clog2(WORDS):0] rptr_b;
reg [$clog2(WORDS):0] rptr_b_n; //bianry
wire rempty_n;

//write
wire [$clog2(WORDS):0]  w_to_r_ptr;
reg [$clog2(WORDS):0] wptr_n; // gray
reg [$clog2(WORDS):0] wptr_b;
reg [$clog2(WORDS):0] wptr_b_n; //bianry
wire wfull_n;


// Signal assignments
assign W_enable = !(winc && ~wfull);
assign rempty_n = (rptr_n == w_to_r_ptr);
assign wfull_n = (wptr_n == {~r_to_w_ptr[$clog2(WORDS):$clog2(WORDS)-1], r_to_w_ptr[$clog2(WORDS)-2:0]});


always @(*) begin
    rptr_b_n =rptr_b +  (!rempty && rinc) ;
    rptr_n = (rptr_b_n >> 1) ^ rptr_b_n; 
end

always @(*) begin
    wptr_b_n = wptr_b + (!wfull && winc) ;
    wptr_n = (wptr_b_n >> 1) ^ wptr_b_n;
end


always @(posedge rclk or negedge rst_n) begin
    if (!rst_n) begin
        rptr_b <= 0;
        rptr <= 0;
        r_addr <= 0;
    end else begin
        rptr_b <= rptr_b_n;
        rptr <= rptr_n;
        r_addr <= rptr_b_n[$clog2(WORDS)-1:0];
    end
end

always @(posedge rclk or negedge rst_n) begin
    if (!rst_n) begin
        rdata <= 0;
    end else begin
        rdata <= rdata_q;
    end
end



always @(posedge rclk or negedge rst_n) begin
    if (!rst_n) begin
        rempty <= 1'b1;
    end else begin
        rempty <= rempty_n;
    end
end


always @(posedge wclk or negedge rst_n) begin
    if (!rst_n) begin
        wptr_b <= 0;
        wptr <= 0;
        w_addr <= 0;
    end else begin
        wptr_b <= wptr_b_n;
        wptr <= wptr_n;
        w_addr <= wptr_b_n[$clog2(WORDS)-1:0];
    end
end


always @(posedge wclk or negedge rst_n) begin
    if (!rst_n) begin
        wfull <= 1'b0;
    end else begin
        wfull <= wfull_n;
    end
end


DUAL_64X8X1BM1 u_dual_sram(.A0(w_addr[0]), .A1(w_addr[1]) , .A2(w_addr[2]), .A3(w_addr[3]), .A4(w_addr[4]), .A5(w_addr[5]),
                      .B0(r_addr[0]), .B1(r_addr[1]), .B2(r_addr[2]), .B3(r_addr[3]), .B4(r_addr[4]), .B5(r_addr[5]),
                      .DOA0(),.DOA1(), .DOA2(), .DOA3() , .DOA4() , .DOA5(), .DOA6() , .DOA7(), 
                      .DOB0(rdata_q[0]),.DOB1(rdata_q[1]),.DOB2(rdata_q[2]), .DOB3(rdata_q[3]), .DOB4(rdata_q[4]), .DOB5(rdata_q[5]), .DOB6(rdata_q[6]), .DOB7(rdata_q[7]),
                      .DIA0(wdata[0]),.DIA1(wdata[1]),.DIA2(wdata[2]),.DIA3(wdata[3]),.DIA4(wdata[4]), .DIA5(wdata[5]) , .DIA6(wdata[6]) , .DIA7(wdata[7]),
                      .DIB0(1'b0),.DIB1(1'b0),.DIB2(1'b0),.DIB3(1'b0),.DIB4(1'b0), .DIB5(1'b0), .DIB6(1'b0), .DIB7(1'b0),
                      .WEAN(W_enable),.WEBN(1'b1),.CKA(wclk),.CKB(rclk),.CSA(1'b1),.CSB(1'b1),.OEA(1'b1),.OEB(1'b1));



NDFF_BUS_syn #($clog2(WORDS) +1 ) W_2_R(wptr, w_to_r_ptr, rclk, rst_n);
NDFF_BUS_syn #($clog2(WORDS) +1 ) R_2_W(rptr, r_to_w_ptr, wclk, rst_n);
endmodule

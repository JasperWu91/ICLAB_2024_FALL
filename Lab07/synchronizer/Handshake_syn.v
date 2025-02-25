module Handshake_syn #(parameter WIDTH=8) (
    sclk,
    dclk,
    rst_n,
    sready,
    din,
    dbusy,
    sidle,
    dvalid,
    dout,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake
);

input sclk, dclk;
input rst_n;
input sready;
input [WIDTH-1:0] din;
input dbusy;
output sidle;
output reg dvalid;
output reg [WIDTH-1:0] dout;

// You can change the input / output of the custom flag ports
output reg flag_handshake_to_clk1;
input flag_clk1_to_handshake;

output flag_handshake_to_clk2;
input flag_clk2_to_handshake;

// Remember:
//   Don't modify the signal name
reg sreq;
wire dreq;
reg dack;
wire sack;
//==========================================
// Design
//==========================================
reg [WIDTH-1:0] data_temp;

assign sidle = (sreq  || sack ) ? 0 : 1;

always @ (posedge sclk or negedge rst_n) begin  
    if (!rst_n) begin
        data_temp <= 0;
    end
    else if (sready) begin
        data_temp <= din;
    end 
    else begin
        data_temp <= data_temp;
    end
end

always @(posedge dclk or negedge rst_n) begin
    if (!rst_n) begin
        dout <= 0;
    end   
    else if (dreq && !dbusy) begin
        dout <= data_temp;
    end
end

always @(posedge dclk or negedge rst_n) begin
    if (!rst_n) begin
        dvalid <= 0;
    end   
    else if (dreq && !dbusy) begin
        dvalid <= 1;
    end
    else begin 
        dvalid <= 0;
    end
end


NDFF_syn N_SRC (.D(sreq), .Q(dreq), .clk(dclk), .rst_n(rst_n));

// Src Ctrl
always @(posedge sclk or negedge rst_n) begin
    if (!rst_n) begin
        sreq <= 0;
    end
    else if (sack) begin
        sreq <= 0; 
    end
    else if (sready) begin
        sreq <= 1;
    end
    else sreq <= sreq;
end

NDFF_syn N_DEST (.D(dack), .Q(sack), .clk(sclk), .rst_n(rst_n));

// Dest Ctrl
always @(posedge dclk or negedge rst_n) begin
    if (!rst_n) begin
        dack <= 0;
    end   
    else if (dreq) begin
        dack <= 1;
    end
    else dack <= 0;
end


endmodule
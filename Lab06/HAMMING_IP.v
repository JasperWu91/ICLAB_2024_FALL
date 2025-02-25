//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2024/10
//		Version		: v1.0
//   	File Name   : HAMMING_IP.v
//   	Module Name : HAMMING_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module HAMMING_IP #(parameter IP_BIT = 8) (
    // Input signals
    IN_code,
    // Output signals
    OUT_code
);

// ===============================================================
// Input & Output
// ===============================================================
input [IP_BIT+4-1:0]  IN_code;

output reg [IP_BIT-1:0] OUT_code;

// ===============================================================
// Design
// ===============================================================
integer i;
reg [IP_BIT-1:0] OUT_code_;
reg [IP_BIT+4-1:0]IN_code_;
reg corret_;
reg [3:0] bits;


always @(*) begin
    case (IP_BIT)
        5: begin
            bits[0] = IN_code[8] ^ IN_code[6] ^ IN_code[4] ^ IN_code[2] ^ IN_code[0];  
            bits[1] = IN_code[7] ^ IN_code[6] ^ IN_code[3] ^ IN_code[2] ; 
            bits[2] = IN_code[5] ^ IN_code[4] ^ IN_code[3] ^ IN_code[2] ; 
            bits[3] =  IN_code[1] ^ IN_code[0];              
        end 
        
        6: begin
            bits[0] = IN_code[9] ^ IN_code[7] ^ IN_code[5] ^ IN_code[3] ^ IN_code[1];  
            bits[1] = IN_code[8] ^ IN_code[7] ^ IN_code[4] ^ IN_code[3] ^ IN_code[0]; 
            bits[2] = IN_code[6] ^ IN_code[5] ^ IN_code[4] ^ IN_code[3]; 
            bits[3] =  IN_code[2] ^ IN_code[1] ^ IN_code[0];                
        end

        7: begin 
            bits[0] = IN_code[10] ^ IN_code[8] ^ IN_code[6] ^ IN_code[4] ^ IN_code[2] ^ IN_code[0];   
            bits[1] = IN_code[9] ^ IN_code[8] ^ IN_code[5] ^ IN_code[4] ^ IN_code[1] ^ IN_code[0]; 
            bits[2] = IN_code[7] ^ IN_code[6] ^ IN_code[5] ^ IN_code[4] ;  
            bits[3] = IN_code[3] ^ IN_code[2] ^ IN_code[1] ^ IN_code[0];                     
        end

        8: begin
            bits[0] = IN_code[11] ^ IN_code[9] ^ IN_code[7] ^ IN_code[5] ^ IN_code[3] ^ IN_code[1];  
            bits[1] = IN_code[10] ^ IN_code[9] ^ IN_code[6] ^ IN_code[5] ^ IN_code[2] ^ IN_code[1]; 
            bits[2] = IN_code[8] ^ IN_code[7] ^ IN_code[6] ^ IN_code[5] ^ IN_code[0] ; 
            bits[3] = IN_code[4] ^ IN_code[3] ^ IN_code[2] ^ IN_code[1] ^ IN_code[0];              
        end

        9: begin
            bits[0] = IN_code[12] ^ IN_code[10] ^ IN_code[8] ^ IN_code[6] ^ IN_code[4] ^ IN_code[2] ^ IN_code[0];   
            bits[1] = IN_code[11] ^ IN_code[10] ^ IN_code[7] ^ IN_code[6] ^ IN_code[3] ^ IN_code[2]; 
            bits[2] = IN_code[9]  ^ IN_code[8] ^ IN_code[7] ^ IN_code[6] ^ IN_code[1] ^ IN_code[0]; 
            bits[3] = IN_code[5] ^ IN_code[4] ^ IN_code[3] ^ IN_code[2] ^ IN_code[1] ^ IN_code[0];                  
        end

        10: begin
            bits[0] = IN_code[13] ^ IN_code[11] ^ IN_code[9] ^ IN_code[7] ^ IN_code[5] ^ IN_code[3] ^ IN_code[1]; 
            bits[1] = IN_code[12] ^ IN_code[11] ^ IN_code[8] ^ IN_code[7] ^ IN_code[4] ^ IN_code[3] ^ IN_code[0]; 
            bits[2] = IN_code[10] ^ IN_code[9] ^ IN_code[8] ^ IN_code[7] ^ IN_code[2] ^ IN_code[1] ^ IN_code[0]; 
            bits[3] = IN_code[6] ^ IN_code[5] ^ IN_code[4] ^ IN_code[3] ^ IN_code[2] ^ IN_code[1] ^ IN_code[0];              
        end

        11: begin
            bits[0] = IN_code[14] ^ IN_code[12] ^ IN_code[10] ^ IN_code[8] ^ IN_code[6] ^ IN_code[4] ^ IN_code[2] ^ IN_code[0];  
            bits[1] = IN_code[13] ^ IN_code[12] ^ IN_code[9] ^ IN_code[8] ^ IN_code[5] ^ IN_code[4] ^ IN_code[1] ^ IN_code[0]; 
            bits[2] = IN_code[11] ^ IN_code[10] ^ IN_code[9] ^ IN_code[8] ^ IN_code[3] ^ IN_code[2] ^ IN_code[1] ^ IN_code[0]; 
            bits[3] = IN_code[7] ^ IN_code[6] ^ IN_code[5] ^ IN_code[4] ^ IN_code[3] ^ IN_code[2] ^ IN_code[1] ^ IN_code[0];         
        end

    default: begin
        bits[0] = 0;
        bits[1] = 0;
        bits[2] = 0;
        bits[3] = 0;
    end
endcase
end





always @(*) begin
    for (i = 0 ; i < IP_BIT+4 ; i=i+1 ) begin
         IN_code_[i] = IN_code[i];
    end

    if (bits != 0) begin
        for (i = 0 ; i < IP_BIT+4 ; i=i+1 ) begin
            if (i == ((4+IP_BIT) - bits)) begin
                corret_ = ~IN_code[i];
                IN_code_[ i] = corret_;
            end
            else IN_code_[i] = IN_code[i];
        end
    end else begin
        for (i = 0 ; i < IP_BIT+4 ; i=i+1 ) begin
            IN_code_[i] = IN_code[i];
        end
    end

end


always @(*) begin
    OUT_code = {IN_code_[IP_BIT + 1 ], IN_code_[IP_BIT-1:IP_BIT-3], IN_code_[IP_BIT - 5 :0]};
end


endmodule
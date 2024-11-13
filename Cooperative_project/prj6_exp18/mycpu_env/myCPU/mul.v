module my_full_adder(      // 1 bit Full Adder
    input a,
    input b,
    input cin,
    output C,
    output S
);
    assign {C,S} = a+b+cin;
endmodule
module wallace_add_unit(
    input    [16:0] pin,
    input    [13:0] cin,
    output   [13:0] cout,
    output          S,
    output          C
);
/*-------------------------level 1---------------------------------------*/
    wire [4:0]  S_level_1;
    my_full_adder adder1_4(
        .a          (pin[16]),
        .b          (pin[15]),
        .cin        (pin[14]),
        .S          (S_level_1[4]),
        .C          (cout[4])
    );
    my_full_adder adder1_3(
        .a          (pin[13]),
        .b          (pin[12]),
        .cin        (pin[11]),
        .S          (S_level_1[3]),
        .C          (cout[3])
    );
    my_full_adder adder1_2(
        .a          (pin[10]),
        .b          (pin[9]),
        .cin        (pin[8]),
        .S          (S_level_1[2]),
        .C          (cout[2])
    );
    my_full_adder adder1_1(
        .a          (pin[7]),
        .b          (pin[6]),
        .cin        (pin[5]),
        .S          (S_level_1[1]),
        .C          (cout[1])
    );
    my_full_adder adder1_0(
        .a          (pin[4]),
        .b          (pin[3]),
        .cin        (pin[2]),
        .S          (S_level_1[0]),
        .C          (cout[0])
    );
/*-------------------------level 2---------------------------------------*/
    wire [3:0]       S_level_2;
    my_full_adder adder2_3(
        .a          (S_level_1[4]),
        .b          (S_level_1[3]),
        .cin        (S_level_1[2]),
        .S          (S_level_2[3]),
        .C          (cout[8])
    );
    my_full_adder adder2_2(
        .a          (S_level_1[1]),
        .b          (S_level_1[0]),
        .cin        (pin[1]),
        .S          (S_level_2[2]),
        .C          (cout[7])
    );
    my_full_adder adder2_1(
        .a          (pin[0]),
        .b          (cin[4]),
        .cin        (cin[3]),
        .S          (S_level_2[1]),
        .C          (cout[6])
    );
    my_full_adder adder2_0(
        .a          (cin[2]),
        .b          (cin[1]),
        .cin        (cin[0]),
        .S          (S_level_2[0]),
        .C          (cout[5])
    );
/*-------------------------level 3---------------------------------------*/ 
    wire [1:0]       S_level_3;
    my_full_adder adder3_1(
        .a          (S_level_2[3]),
        .b          (S_level_2[2]),
        .cin        (S_level_2[1]),
        .S          (S_level_3[1]),
        .C          (cout[10])
    );
    my_full_adder adder3_0(
        .a          (S_level_2[0]),
        .b          (cin[6]),
        .cin        (cin[5]),
        .S          (S_level_3[0]),
        .C          (cout[9])
    );
/*-------------------------level 4---------------------------------------*/    
    wire [1:0]       S_level_4;
    my_full_adder adder4_1(
        .a          (S_level_3[1]),
        .b          (S_level_3[0]),
        .cin        (cin[10]),
        .S          (S_level_4[1]),
        .C          (cout[12])
    );
    my_full_adder adder4_0(
        .a          (cin[9]),
        .b          (cin[8]),
        .cin        (cin[7]),
        .S          (S_level_4[0]),
        .C          (cout[11])
    );
/*-------------------------level 5---------------------------------------*/   
    wire            S_level_5;
    my_full_adder adder5_0(
        .a          (S_level_4[1]),
        .b          (S_level_4[0]),
        .cin        (cin[11]),
        .S          (S_level_5),
        .C          (cout[13])
    );
/*-------------------------level 6---------------------------------------*/   
    my_full_adder adder6_0(
        .a          (S_level_5),
        .b          (cin[13]),
        .cin        (cin[12]),
        .S          (S),
        .C          (C)
    );
endmodule


module Wallace_Mul (
    input          mul_clk,
    input          resetn,
    input          mul_signed,
    input   [31:0] A,
    input   [31:0] B,
    output  [63:0] result
);
    /*=====================================First level: Booth two-digit one-mul, partial product generation==============================*/
    wire [63:0] A_add;  
    wire [63:0] A_sub;
    wire [63:0] A2_add;
    wire [63:0] A2_sub;
    wire [34:0] sel_x;
    wire [34:0] sel_2x;
    wire [34:0] sel_neg_x;
    wire [34:0] sel_neg_2x;
    wire [34:0] sel_0;
    wire [16:0] sel_x_val;
    wire [16:0] sel_2x_val;
    wire [16:0] sel_neg_x_val;
    wire [16:0] sel_neg_2x_val;
    wire [16:0] sel_0_val;
    wire [18:0] debug;
    // 扩展成34位以兼容无符号数乘法（偶数位易于处理）
    wire [33:0] B_r;
    wire [33:0] B_m;
    wire [33:0] B_l;
    // 未对齐的部分积
    wire [63:0] P [16:0];
    assign B_m  = {{2{B[31] & mul_signed}}, B};
    assign B_l  = {1'b0, B_m[33:1]};
    assign B_r  = {B_m[32:0], 1'b0};

    assign sel_neg_x   = ( B_l &  B_m & ~B_r) | (B_l & ~B_m & B_r);    // 110, 101
    assign sel_x       = (~B_l &  B_m & ~B_r) | (~B_l & ~B_m& B_r);    // 010, 001
    assign sel_neg_2x  = ( B_l & ~B_m & ~B_r) ;                      //  100
    assign sel_2x      = (~B_l & B_m & B_r);                         // 011
    assign sel_0       = (B_l & B_m & B_r) | (~B_l & ~B_m & ~B_r);     // 000, 111
    assign A_add       = {{32{A[31] & mul_signed}}, A};
    assign A_sub       = ~ A_add + 1'b1;
    assign A2_add      = {A_add, 1'b0};
    assign A2_sub      = ~A2_add + 1'b1; 
    // 奇数位才是有效的选取信号
    assign sel_x_val    = { sel_x[32], sel_x[30], sel_x[28], sel_x[26], sel_x[24],
                            sel_x[22], sel_x[20], sel_x[18], sel_x[16],
                            sel_x[14], sel_x[12], sel_x[10], sel_x[ 8],
                            sel_x[ 6], sel_x[ 4], sel_x[ 2], sel_x[ 0]};
    assign sel_neg_x_val= { sel_neg_x[32], sel_neg_x[30], sel_neg_x[28], sel_neg_x[26], sel_neg_x[24],
                            sel_neg_x[22], sel_neg_x[20], sel_neg_x[18], sel_neg_x[16],
                            sel_neg_x[14], sel_neg_x[12], sel_neg_x[10], sel_neg_x[ 8],
                            sel_neg_x[ 6], sel_neg_x[ 4], sel_neg_x[ 2], sel_neg_x[ 0]};     
    assign sel_2x_val   =  {sel_2x[32], sel_2x[30], sel_2x[28], sel_2x[26], sel_2x[24],
                            sel_2x[22], sel_2x[20], sel_2x[18], sel_2x[16],
                            sel_2x[14], sel_2x[12], sel_2x[10], sel_2x[ 8],
                            sel_2x[ 6], sel_2x[ 4], sel_2x[ 2], sel_2x[ 0]};        
    assign sel_neg_2x_val= {sel_neg_2x[32], sel_neg_2x[30], sel_neg_2x[28], sel_neg_2x[26], sel_neg_2x[24],
                            sel_neg_2x[22], sel_neg_2x[20], sel_neg_2x[18], sel_neg_2x[16],
                            sel_neg_2x[14], sel_neg_2x[12], sel_neg_2x[10], sel_neg_2x[ 8],
                            sel_neg_2x[ 6], sel_neg_2x[ 4], sel_neg_2x[ 2], sel_neg_2x[ 0]};   
    assign sel_0_val    =  {sel_0[32], sel_0[30], sel_0[28], sel_0[26], sel_0[24],
                            sel_0[22], sel_0[20], sel_0[18], sel_0[16],
                            sel_0[14], sel_0[12], sel_0[10], sel_0[ 8],
                            sel_0[ 6], sel_0[ 4], sel_0[ 2], sel_0[ 0]}; 
    // debug信号应为0FFFF                                                                                              
    assign debug        = sel_x_val + sel_neg_2x_val + sel_neg_x_val + sel_2x_val + sel_0_val;
    // 17个 * 64 bit 部分积, 未对齐
    assign {P[16], P[15], P[14], P[13], P[12],
            P[11], P[10], P[ 9], P[ 8],
            P[ 7], P[ 6], P[ 5], P[ 4],
            P[ 3], P[ 2], P[ 1], P[ 0]} 
            =  {{64{sel_x_val[16]}}, {64{sel_x_val[15]}}, {64{sel_x_val[14]}}, {64{sel_x_val[13]}}, {64{sel_x_val[12]}},
                {64{sel_x_val[11]}}, {64{sel_x_val[10]}}, {64{sel_x_val[ 9]}}, {64{sel_x_val[ 8]}},
                {64{sel_x_val[ 7]}}, {64{sel_x_val[ 6]}}, {64{sel_x_val[ 5]}}, {64{sel_x_val[ 4]}},
                {64{sel_x_val[ 3]}}, {64{sel_x_val[ 2]}}, {64{sel_x_val[ 1]}}, {64{sel_x_val[ 0]}}} & {17{A_add}} |
               {{64{sel_neg_x_val[16]}}, {64{sel_neg_x_val[15]}}, {64{sel_neg_x_val[14]}}, {64{sel_neg_x_val[13]}}, {64{sel_neg_x_val[12]}},
                {64{sel_neg_x_val[11]}}, {64{sel_neg_x_val[10]}}, {64{sel_neg_x_val[ 9]}}, {64{sel_neg_x_val[ 8]}},
                {64{sel_neg_x_val[ 7]}}, {64{sel_neg_x_val[ 6]}}, {64{sel_neg_x_val[ 5]}}, {64{sel_neg_x_val[ 4]}},
                {64{sel_neg_x_val[ 3]}}, {64{sel_neg_x_val[ 2]}}, {64{sel_neg_x_val[ 1]}}, {64{sel_neg_x_val[ 0]}}}  & {17{A_sub}} |
               {{64{sel_2x_val[16]}}, {64{sel_2x_val[15]}}, {64{sel_2x_val[14]}}, {64{sel_2x_val[13]}}, {64{sel_2x_val[12]}},
                {64{sel_2x_val[11]}}, {64{sel_2x_val[10]}}, {64{sel_2x_val[ 9]}}, {64{sel_2x_val[ 8]}},
                {64{sel_2x_val[ 7]}}, {64{sel_2x_val[ 6]}}, {64{sel_2x_val[ 5]}}, {64{sel_2x_val[ 4]}},
                {64{sel_2x_val[ 3]}}, {64{sel_2x_val[ 2]}}, {64{sel_2x_val[ 1]}}, {64{sel_2x_val[ 0]}}} & {17{A2_add}} |
               {{64{sel_neg_2x_val[16]}}, {64{sel_neg_2x_val[15]}}, {64{sel_neg_2x_val[14]}}, {64{sel_neg_2x_val[13]}}, {64{sel_neg_2x_val[12]}},
                {64{sel_neg_2x_val[11]}}, {64{sel_neg_2x_val[10]}}, {64{sel_neg_2x_val[ 9]}}, {64{sel_neg_2x_val[ 8]}},
                {64{sel_neg_2x_val[ 7]}}, {64{sel_neg_2x_val[ 6]}}, {64{sel_neg_2x_val[ 5]}}, {64{sel_neg_2x_val[ 4]}},
                {64{sel_neg_2x_val[ 3]}}, {64{sel_neg_2x_val[ 2]}}, {64{sel_neg_2x_val[ 1]}}, {64{sel_neg_2x_val[ 0]}}} & {17{A2_sub}}; 
    // 对齐的17个部分积
    wire [63:0] p_aligned[16:0];
    assign {p_aligned[16], p_aligned[15], p_aligned[14], p_aligned[13], p_aligned[12],
            p_aligned[11], p_aligned[10], p_aligned[ 9], p_aligned[ 8],
            p_aligned[ 7], p_aligned[ 6], p_aligned[ 5], p_aligned[ 4],
            p_aligned[ 3], p_aligned[ 2], p_aligned[ 1], p_aligned[ 0]}
            =   {P[16]<<32, P[15]<<30, P[14]<<28, P[13]<<26, P[12]<<24,
                 P[11]<<22, P[10]<<20, P[ 9]<<18, P[ 8]<<16,
                 P[ 7]<<14, P[ 6]<<12, P[ 5]<<10, P[ 4]<<8,
                 P[ 3]<<6 , P[ 2]<<4 , P[ 1]<<2 , P[ 0]} ;
    wire [13:0] cin [64:0];
    wire  [63:0] S_top;
    wire  [63:0] C_top;
    genvar i;
    assign cin[0] = 14'b0;
    /* ===================================Second level: Wallace Tree===========================================================*/
    generate
        for (i = 0; i < 64; i = i + 1) begin : generate_for_loop
            wallace_add_unit wallace_add(
                .pin        ({p_aligned[16][i], p_aligned[15][i], p_aligned[14][i], p_aligned[13][i], p_aligned[12][i],
                            p_aligned[11][i], p_aligned[10][i], p_aligned[ 9][i], p_aligned[ 8][i],
                            p_aligned[ 7][i], p_aligned[ 6][i], p_aligned[ 5][i], p_aligned[ 4][i],
                            p_aligned[ 3][i], p_aligned[ 2][i], p_aligned[ 1][i], p_aligned[ 0][i]}),
                .cin        (cin[i]),
                .cout       (cin[i+1]),
                .S          (S_top[i]),
                .C          (C_top[i])
        );
        end
    endgenerate
    // Set reg to divide pipeline stages
    reg [63:0] S_top_reg;
    reg [63:0] C_top_reg;
    always @(posedge mul_clk)begin
        if(~resetn)begin
            S_top_reg <= 64'b0;
            C_top_reg <= 64'b0;
        end
        else begin
            S_top_reg <= S_top;
            C_top_reg <= C_top;
        end
    end
    /* ===========================Third level: Top 64 bit adder===========================================================================*/
    assign result = S_top_reg + (C_top_reg << 1);
endmodule

module IDreg(
    input  wire                   clk,
    input  wire                   resetn,
    //if模块与id模块交互接口
    input  wire                   if_to_id_valid,
    output wire                   id_allowin,
    output wire [33:0]            id_to_if_bus,//{br_taken, br_target}
    input  wire [65:0]            if_to_id_bus,//{if_inst, if_pc}
    //id模块与ex模块交互接口
    input  wire                   ex_allowin,
    output wire                   id_to_ex_valid,
    output wire [225:0]           id_to_ex_bus,
    //数据前递总线
    input  wire [37:0]            wb_to_id_bus, // {wb_rf_we, wb_rf_waddr, wb_rf_wdata}
    input  wire [38:0]            mem_to_id_bus,// {mem_rf_we, mem_rf_waddr, mem_rf_wdata}
    input  wire [39:0]            ex_to_id_bus,  // {ex_res_from_mem, ex_rf_we, ex_rf_waddr, ex_alu_result}

    input  wire                   flush,
    input  wire                   has_int
);
    wire        stuck;
    wire        id_ready_go;
    reg         id_valid;
    reg  [31:0] id_inst;

    wire [18:0] id_alu_op;
    wire [31:0] id_alu_src1   ;
    wire [31:0] id_alu_src2   ;
    wire        id_src1_is_pc;
    wire        id_src_is_imm;
    wire        id_res_from_mem;
    reg  [31:0] id_pc;
    wire [31:0] id_rkd_value;
    wire        id_mem_we;
    wire        id_op_st_ld_b;             // byte
    wire        id_op_st_ld_h;             // half word
    wire        id_op_st_ld_w;             // word
    wire        id_op_st_ld_u;         // zero extended

    wire        dst_is_r1;
    wire        gr_we;
    wire        src_reg_is_rd;
    wire        rj_eq_rd;
    wire        rj_ltu_rd;
    wire [4: 0] dest;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] imm;
    wire [31:0] br_offs;
    wire [31:0] jirl_offs;

    wire [ 5:0] op_31_26;
    wire [ 3:0] op_25_22;
    wire [ 1:0] op_21_20;
    wire [ 4:0] op_19_15;
    wire [ 4:0] rd;
    wire [ 4:0] rj;
    wire [ 4:0] rk;
    wire [11:0] i12;
    wire [19:0] i20;
    wire [15:0] i16;
    wire [25:0] i26;
    wire [13:0] csr_num;
    wire [14:0] code;

    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [ 3:0] op_21_20_d;
    wire [31:0] op_19_15_d;

    wire        inst_add_w;
    wire        inst_sub_w;
    wire        inst_slt;
    wire        inst_sltu;
    wire        inst_nor;
    wire        inst_and;
    wire        inst_or;
    wire        inst_xor;
    wire        inst_slli_w;
    wire        inst_srli_w;
    wire        inst_srai_w;
    wire        inst_addi_w;
    wire        inst_ld_w;
    wire        inst_st_w;
    wire        inst_jirl;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_beq;
    wire        inst_bne;
    wire        inst_blt;
    wire        inst_bge;
    wire        inst_bltu;
    wire        inst_bgeu;
    wire        inst_lu12i_w;
    wire        inst_slti;
    wire        inst_sltui;
    wire        inst_andi;
    wire        inst_ori;
    wire        inst_xori;
    wire        inst_sll_w;
    wire        inst_srl_w;
    wire        inst_sra_w;
    wire        inst_pcaddul2i;
    wire        inst_mul_w;
    wire        inst_mulh_w;
    wire        inst_mulh_wu;
    wire        inst_div_w;
    wire        inst_div_wu;
    wire        inst_mod_w;
    wire        inst_mod_wu;
    wire        inst_ld_b;
    wire        inst_ld_h;
    wire        inst_ld_bu;
    wire        inst_ld_hu;
    wire        inst_st_b;
    wire        inst_st_h;
    wire        inst_csrrd;
    wire        inst_csrwr;
    wire        inst_csxchg;
    wire        inst_ertn;
    wire        inst_syscall;
    wire        inst_break;
    wire        inst_rdcntvl_w;
    wire        inst_rdcntvh_w;
    wire        inst_rdcntid;
    wire        no_inst;

    wire        need_ui5;
    wire        need_si12;
    wire        need_si16;
    wire        need_si20;
    wire        need_si26;
    wire        src2_is_4;

    wire        br_taken;
    wire [31:0] br_target;
    wire        br_stall;

    wire [ 4:0] rf_raddr1;
    wire [31:0] rf_rdata1;
    wire [ 4:0] rf_raddr2;
    wire [31:0] rf_rdata2;

    wire        conflict_r1_wb;
    wire        conflict_r2_wb;
    wire        conflict_r1_mem;
    wire        conflict_r2_mem;
    wire        conflict_r1_ex;
    wire        conflict_r2_ex;
    wire        need_r1;
    wire        need_r2;

    wire        wb_rf_we   ;
    wire [ 4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;
    wire        mem_rf_we   ;
    wire [ 4:0] mem_rf_waddr;
    wire [31:0] mem_rf_wdata;
    wire        ex_rf_we   ;
    wire [ 4:0] ex_rf_waddr;
    wire [31:0] ex_rf_wdata;
    wire        ex_res_from_mem;
    wire        ex_res_from_wb;
    wire        mem_res_from_wb;

    wire        id_rf_we   ;
    wire [ 4:0] id_rf_waddr;

    wire        id_read_counter;
    wire        id_read_counter_low;
    wire        id_read_TID;

    wire        id_csr_re;
    wire [13:0] id_csr_num;
    wire        id_csr_we;
    wire [31:0] id_csr_wmask;

    wire        id_ertn_flush;

    // 异常相关
    wire        id_excep_INT;//中断
    wire        id_excep_en;
    wire        id_excep_SYSCALL;
    wire        id_excep_BRK;
    wire        id_excep_INE;
    wire [8:0]  id_excep_esubcode;

    reg        if_excep_en;
    reg        id_excep_ADEF;

//---------------------------------------------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------------------------------------------

// 流水线控制信号
    assign id_ready_go      = ~stuck;//流水线阻塞的时候，id_ready_go值为零
    assign id_allowin       =   ~id_valid 
                                | id_ready_go & ex_allowin 
                                | br_taken | flush;             // 消耗if级错误指令缓存 
    assign id_to_ex_valid   = id_valid & id_ready_go;


//更新id模块中的寄存器
    always @(posedge clk) begin
        if(~resetn)
            id_valid <= 1'b0;
        else if(br_taken || flush)
            id_valid <= 1'b0;
        else if(id_allowin)
            id_valid <= if_to_id_valid;
    end
    always @(posedge clk) begin
        if(~resetn)
            {id_inst, id_pc, if_excep_en, id_excep_ADEF} <= 66'b0;
        if(if_to_id_valid & id_allowin) begin
            {id_inst, id_pc, if_excep_en, id_excep_ADEF} <= if_to_id_bus;
        end
    end

//模块间通信
    assign {wb_rf_we, wb_rf_waddr, wb_rf_wdata} = wb_to_id_bus;
    assign {mem_rf_we, mem_rf_waddr, mem_rf_wdata, mem_res_from_wb} = mem_to_id_bus;
    assign {ex_res_from_mem, ex_rf_we, ex_rf_waddr, ex_rf_wdata, ex_res_from_wb} = ex_to_id_bus;
    assign id_to_if_bus = {br_taken, br_target, br_stall}; 

    assign id_rkd_value = rkd_value; 
    assign id_to_ex_bus = {id_alu_op,          //19 bit
                           id_res_from_mem,    //1  bit
                           id_alu_src1,        //32 bit
                           id_alu_src2,        //32 bit
                           id_mem_we,          //1  bit
                           id_rf_we,           //1  bit
                           id_rf_waddr,        //5  bit
                           id_rkd_value,       //32 bit
                           id_pc,               //32 bit
                           id_op_st_ld_b,       // 1 bit
                           id_op_st_ld_h,       // 1 bit
                           id_op_st_ld_w,       // 1 bit
                           id_op_st_ld_u,       // 1 bit
                           id_read_counter,     // 1 bit
                           id_read_counter_low, // 1 bit
                           id_read_TID,         // 1 bit
                           id_csr_re,           // 1 bit
                           id_csr_we,           // 1 bit
                           id_csr_num,           // 14 bit
                           id_csr_wmask,         // 32 bit
                           id_ertn_flush,        // 1 bit
                           id_excep_en,          // 1 bit
                           id_excep_ADEF,        // 1 bit
                           id_excep_SYSCALL,       // 1 bit
                           id_excep_BRK,         // 1 bit
                           id_excep_INE,         // 1 bit
                           id_excep_INT,         //1 bit
                           id_excep_esubcode     // 9 bit
                        //    inst_st_b,               //1 bit
                        //    inst_st_h,               //1 bit
                        //    inst_st_w                //1 bit
                          };

//译码逻辑信号-----------------------------------------------------------------------------------------------------------------------------------
    assign op_31_26  = id_inst[31:26];
    assign op_25_22  = id_inst[25:22];
    assign op_21_20  = id_inst[21:20];
    assign op_19_15  = id_inst[19:15];
    assign rd        = id_inst[ 4: 0];
    assign rj        = id_inst[ 9: 5];
    assign rk        = id_inst[14:10];
    assign i12       = id_inst[21:10];
    assign i20       = id_inst[24: 5];
    assign i16       = id_inst[25:10];
    assign i26       = {id_inst[ 9: 0], id_inst[25:10]};
    assign csr_num   = {id_inst[23:10]};
    assign code      = id_inst[14:0];

    decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
    decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
    decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
    decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

    //每一条指令的译码信号
    assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
    assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
    assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
    assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
    assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
    assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
    assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
    assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
    assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
    assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_jirl   = op_31_26_d[6'h13];
    assign inst_b      = op_31_26_d[6'h14];
    assign inst_bl     = op_31_26_d[6'h15];
    assign inst_beq    = op_31_26_d[6'h16];
    assign inst_bne    = op_31_26_d[6'h17];
    assign inst_blt    = op_31_26_d[6'h18];
    assign inst_bge    = op_31_26_d[6'h19];
    assign inst_bltu   = op_31_26_d[6'h1a];
    assign inst_bgeu   = op_31_26_d[6'h1b];
    assign inst_lu12i_w= op_31_26_d[6'h05] & ~id_inst[25];
    assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
    assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
    assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
    assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
    assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
    assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
    assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
    assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
    assign inst_pcaddul2i = op_31_26_d[6'h07] & ~id_inst[25];
    assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
    assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
    assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
    assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
    assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
    assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
    assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
    assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
    assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
    assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
    assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
    assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
    assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
    assign inst_csrrd  = op_31_26_d[6'h01] & id_inst[25:24] == 2'b0 & rj == 5'b0;
    assign inst_csrwr  = op_31_26_d[6'h01] & id_inst[25:24] == 2'b0 & rj == 5'b1;
    assign inst_csxchg = op_31_26_d[6'h01] & id_inst[25:24] == 2'b0 & rj[4:1] != 4'b0;
    assign inst_ertn   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0e;
    assign inst_syscall= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
    assign inst_break  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
    assign inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & rk == 5'h18 & rj == 5'h00;
    assign inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & rk == 5'h19 & rj == 5'h00;
    assign inst_rdcntid   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & rk == 5'h18 & rd == 5'h00;
    assign no_inst = ~(inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and | inst_or | inst_xor | inst_slli_w | inst_srli_w | inst_srai_w  
                    | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_b | inst_bl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu
                    | inst_lu12i_w | inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori | inst_sll_w | inst_srl_w | inst_sra_w | inst_pcaddul2i
                    | inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu | inst_ld_b | inst_ld_h | inst_ld_bu
                    | inst_ld_hu | inst_st_b | inst_st_h | inst_csrrd | inst_csrwr | inst_csxchg | inst_ertn | inst_syscall | inst_break
                    | inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid);          //指令不存在


    //各条指令对应的alu_op（b、beq、bne不需要用到alu运算）
    assign id_alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w  | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h
                        | inst_jirl | inst_bl | inst_pcaddul2i;
    assign id_alu_op[ 1] = inst_sub_w;
    assign id_alu_op[ 2] = inst_slt | inst_slti;
    assign id_alu_op[ 3] = inst_sltu | inst_sltui;
    assign id_alu_op[ 4] = inst_and | inst_andi;
    assign id_alu_op[ 5] = inst_nor;
    assign id_alu_op[ 6] = inst_or | inst_ori;
    assign id_alu_op[ 7] = inst_xor | inst_xori;
    assign id_alu_op[ 8] = inst_slli_w | inst_sll_w;
    assign id_alu_op[ 9] = inst_srli_w | inst_srl_w;
    assign id_alu_op[10] = inst_srai_w | inst_sra_w;
    assign id_alu_op[11] = inst_lu12i_w;
    assign id_alu_op[12] = inst_mul_w ;
    assign id_alu_op[13] = inst_mulh_w;
    assign id_alu_op[14] = inst_mulh_wu;
    assign id_alu_op[15] = inst_div_w;
    assign id_alu_op[16] = inst_div_wu;
    assign id_alu_op[17] = inst_mod_w;
    assign id_alu_op[18] = inst_mod_wu;

    //各条指令需要的立即数格式
    assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui 
                        | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h;
    assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;     //添加blt等指令
    assign need_si20  =  inst_lu12i_w | inst_pcaddul2i;
    assign need_si26  =  inst_b | inst_bl;
    assign need_ui12  =  inst_andi   | inst_ori | inst_xori ;
    assign src2_is_4  =  inst_jirl | inst_bl;

    assign imm = src2_is_4 ? 32'h4                      :
                 need_si20 ? {i20[19:0], 12'b0}         :
                 (need_ui5 || need_si12) ? {{20{i12[11]}}, i12[11:0]} ://ui5立即数只需要5位，而且是截取的，所以不需要另外写
                {20'b0, i12[11:0]};


    //跳转地址建立
    assign rj_eq_rd = (rj_value == rkd_value);
    assign rj_ltu_rd = (rj_value < rkd_value);                                   //无符号数比较：GR[rj]小于GR[rd]
    assign rj_lt_rd = ($signed(rj_value) < $signed(rkd_value));       //有符号数比较：GR[rj]小于GR[rd]

    assign br_taken = (inst_beq  &&  rj_eq_rd
                    || inst_bne  && !rj_eq_rd
                    || inst_blt  &&  rj_lt_rd                                 //添加blt等指令的跳转条件
                    || inst_bge  && !rj_lt_rd
                    || inst_bltu &&  rj_ltu_rd
                    || inst_bgeu &&  !rj_ltu_rd
                    || inst_jirl
                    || inst_bl
                    || inst_b
                    ) && id_valid && ~stuck;
    assign br_target = (inst_beq || inst_bne || inst_blt || inst_bltu || inst_bge || inst_bgeu || inst_bl || inst_b) ? (id_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);        //添加blt等指令的跳转地址：与bne,beq相同
    assign br_stall =   (inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu| inst_bgeu| inst_jirl| inst_bl| inst_b) & stuck;        // 转移计算未完成

    assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                                {{14{i16[15]}}, i16[15:0], 2'b0} ;
    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

    //alu源操作数的选择
    assign id_src1_is_pc    = inst_jirl | inst_bl | inst_pcaddul2i;
    assign id_src2_is_imm   = inst_slli_w |
                              inst_srli_w |
                              inst_srai_w |
                              inst_addi_w |
                              inst_ld_w   |
                              inst_st_w   |
                              inst_lu12i_w|
                              inst_jirl   |
                              inst_bl     |
                              inst_pcaddul2i|
                              inst_andi   |
                              inst_ori    |
                              inst_xori   |
                              inst_slti   |
                              inst_sltui  |
                              inst_ld_b   |
                              inst_ld_h   |
                              inst_ld_bu  |
                              inst_ld_hu  |
                              inst_st_b   |
                              inst_st_h;
                    
    assign id_alu_src1 = id_src1_is_pc  ? id_pc[31:0] : rj_value;
    assign id_alu_src2 = id_src2_is_imm ? imm : rkd_value;

    //寄存器的读地址选择、寄存器的实例化
    assign src_reg_is_rd =      inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu 
                                | inst_st_w | inst_st_b | inst_st_h | inst_csrwr | inst_csxchg;     
    assign rf_raddr1 = rj;
    assign rf_raddr2 = src_reg_is_rd ? rd :rk;
     regfile u_regfile(
        .clk    (clk      ),
        .raddr1 (rf_raddr1),
        .rdata1 (rf_rdata1),
        .raddr2 (rf_raddr2),
        .rdata2 (rf_rdata2),
        .we     (wb_rf_we    ),
        .waddr  (wb_rf_waddr ),
        .wdata  (wb_rf_wdata )
    );

    //寄存器的写地址和写使能
    assign gr_we            =   ~inst_st_w & ~inst_st_b & ~inst_st_h 
                                & ~inst_beq & ~inst_bne & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu & ~inst_b 
                                & ~inst_syscall & ~inst_ertn & ~inst_break;
                                   
                                
    assign dst_is_r1        = inst_bl;
    assign dest             = dst_is_r1 ? 5'd1 : rd;
    assign id_rf_we         = gr_we  & id_valid & ~id_excep_en;
    assign id_rf_waddr      = id_read_TID ? rj : dest;              // rdcntid : write in rj

    //处理load、store指令的信号（向后面的流水级传递）
    assign id_res_from_mem  = (inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu) & id_valid;
    assign id_mem_we        = (inst_st_w | inst_st_b | inst_st_h) & id_valid;  

    assign id_op_st_ld_b      = inst_st_b | inst_ld_b |inst_ld_bu;
    assign id_op_st_ld_h      = inst_st_h | inst_ld_h |inst_ld_hu;
    assign id_op_st_ld_w      = inst_ld_w | inst_st_w;
    assign id_op_st_ld_u      = inst_ld_bu | inst_ld_hu;

//------------------------------------------------------------------------------------------------------------------------------------------------------
//处理冲突
    //冲突发生的条件为：1、寄存器非0 2、寄存器号相同 3、在EX、MEM、WB流水级上面的指令对寄存器进行写操作 4、ID流水级指令需要读对应的寄存器
    assign conflict_r1_wb  = (|rf_raddr1) & (rf_raddr1 == wb_rf_waddr)  & wb_rf_we & need_r1;
    assign conflict_r2_wb  = (|rf_raddr2) & (rf_raddr2 == wb_rf_waddr)  & wb_rf_we & need_r2;
    assign conflict_r1_mem = (|rf_raddr1) & (rf_raddr1 == mem_rf_waddr) & mem_rf_we & need_r1;
    assign conflict_r2_mem = (|rf_raddr2) & (rf_raddr2 == mem_rf_waddr) & mem_rf_we & need_r2;
    assign conflict_r1_ex  = (|rf_raddr1) & (rf_raddr1 == ex_rf_waddr)  & ex_rf_we & need_r1;
    assign conflict_r2_ex  = (|rf_raddr2) & (rf_raddr2 == ex_rf_waddr)  & ex_rf_we & need_r2;

    assign need_r1         = ~inst_b & ~inst_bl & ~inst_lu12i_w & ~inst_pcaddul2i & ~inst_csrrd & ~inst_csrwr;//需要使用（读）源寄存器1（rj）的指令
    assign need_r2         =  inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_and | inst_or | inst_nor | inst_xor
                              | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu                           //添加blt等指令
                              | inst_st_w | inst_sll_w| inst_srl_w | inst_sra_w | inst_mul_w 
                              | inst_mulh_w | inst_mulh_wu | inst_mod_w | inst_mod_wu | inst_div_w |inst_div_wu
                              | inst_st_b | inst_st_h | inst_csrrd | inst_csrwr | inst_csxchg;
                              //需要使用（读）源寄存器2（rk/rd）的指令

    //发生阻塞的条件：exe阶段为load指令并且与ID流水级指令发生冲突
    assign stuck           = ex_res_from_mem & (conflict_r1_ex|conflict_r2_ex)
                            |ex_res_from_wb & (conflict_r1_ex|conflict_r2_ex)
                            |mem_res_from_wb & (conflict_r1_mem|conflict_r2_mem);    

    //前递的数据在这里使用，发生conflict时代替寄存器中读出的值
    //由于优先级的原因，所以下面的顺序不能调换
    assign rj_value  =  conflict_r1_ex ? ex_rf_wdata:
                        conflict_r1_mem ? mem_rf_wdata:
                        conflict_r1_wb  ? wb_rf_wdata : rf_rdata1; 
    assign rkd_value =  conflict_r2_ex ? ex_rf_wdata:
                        conflict_r2_mem ? mem_rf_wdata:
                        conflict_r2_wb  ? wb_rf_wdata : rf_rdata2;

//------------------------------------------------------------------------------------------------------------------------------------------------------
// CSR读写
    assign id_csr_re  = inst_csrrd || inst_csrwr || inst_csxchg || inst_ertn || id_read_TID;
    assign id_csr_num = inst_ertn ?     14'h6           // CSR_ERA
                        :id_excep_en ?   14'hc           // CSR_EENTRY
                        :id_read_TID ?   14'h40          // CSR_TID
                                        :csr_num;

    assign id_csr_we  = inst_csrwr || inst_csxchg;
    assign id_csr_wmask = inst_csxchg ? rj_value: ~32'b0;

    assign id_ertn_flush = inst_ertn;

// 计数器读和TID读
    assign id_read_counter     = inst_rdcntvl_w | inst_rdcntvh_w;
    assign id_read_counter_low = inst_rdcntvl_w;
    assign id_read_TID         = inst_rdcntid; 

// 中断,系统调用,断点，指令不存在异常处理
    assign id_excep_INT     =   has_int;        // 记录中断信号
    assign id_excep_SYSCALL =   inst_syscall;   // 记录该条指令是否存在SYSCALL异常
    assign id_excep_BRK     =   inst_break;     // 记录该条指令是否存在BRK异常
    assign id_excep_INE     =   no_inst;        // 记录该条指令是否存在INE异常
    assign id_excep_en =        id_excep_INT | id_excep_SYSCALL | id_excep_BRK | id_excep_INE | if_excep_en;         //只要有一个异常就置1
    assign id_excep_esubcode =  9'h0;

endmodule

module IFreg(
    input  wire   clk,
    input  wire   resetn,
    //if模块与指令存储器的交互接�?
    output wire         inst_sram_req,
    output wire         inst_sram_wr,
    output wire [3:0]   inst_sram_wstrb,
    output wire [31:0]  inst_sram_addr,
    output wire [7:0]   inst_vindex,
    output wire [3:0]   inst_voffset,
    output wire [31:0]  inst_sram_wdata,
    
    input wire          inst_sram_addr_ok,
    input wire          inst_sram_data_ok,
    input wire  [31:0]  inst_sram_rdata,
    //if模块与id模块交互接口
    input  wire         id_allowin,
    input  wire [70:0]  id_to_if_bus,//{br_taken, br_target}
    output wire         if_to_id_valid,
    output wire [111:0]  if_to_id_bus,
    //etrn清空流水�?
    input  wire         flush,
    input  wire [31:0]  wb_flush_entry,
    // 虚实地址转换
    output wire [18:0] s0_vppn,
    output wire        s0_va_bit12,
    input wire          csr_crmd_pg,
    input wire  [1:0]   csr_crmd_plv,
    input wire          csr_dmw0_plv_met,
    input wire  [2:0]   csr_dmw0_pseg,
    input wire  [2:0]   csr_dmw0_vseg,
    input wire          csr_dmw1_plv_met,
    input wire  [2:0]   csr_dmw1_pseg,
    input wire  [2:0]   csr_dmw1_vseg,
    input  wire                        s0_found,
    input  wire [19:0]                 s0_ppn,
    input  wire [5:0]                  s0_ps,
    input  wire [1:0]                  s0_plv,
    input  wire                        s0_d,
    input  wire                        s0_v

);
// pre if reg 接受 inst_sram 数据
    reg         pre_if_reqed_reg;
    reg  [31:0] pre_if_ir;
    reg         pre_if_ir_valid;
// if reg接受从pre if 级的数据
    reg         if_valid;       //if流水级是否有效：正在等待或�?�已经接受到指令
    reg  [31:0] if_pc;
    reg  [31:0] if_ir;
    reg         if_ir_valid;
    reg         if_excep_en;
    reg  [ 5:0] if_ecode;
    reg  [ 8:0] if_esubcode;
    reg  [31:0] if_badv;
//流水控制信号
    wire        if_ready_go;
    wire        if_allowin;
    wire        pre_if_readygo;
    wire        to_if_valid;

    wire [31:0] seq_pc;
    wire [31:0] pre_pc;
    wire [31:0] pre_pc_pa;
    wire [31:0] if_inst;
//branch类指令的信号和目标地�?，来自ID模块
    reg          br_taken_reg;
    reg  [ 31:0] br_target_reg;

    wire         br_taken;
    wire [ 31:0] br_target;
    wire         br_stall;

// 异常相关
    wire [ 5:0] pre_if_ecode;
    wire [ 8:0] pre_if_esubcode;
    wire        pre_if_excep_en;
    wire        pre_if_excep_ADEF;
    wire        pre_if_excep_TLBR;
    wire        pre_if_excep_PIF;
    wire        pre_if_excep_PPI;


    wire       icacop;
    wire [4:0] cacop_code ;
    reg icacop_complete;

// if reg 接受从wb�? 的数�?
    reg          flush_reg;
    reg  [ 31:0] flush_entry_reg;

    reg          inst_cancel;
//----------------------------------------------------------------------------------------------------------------------------------------------
//===============================================流水线控制信号和数据交互
    /* if 级的握手信号*/
    always @(posedge clk) begin         // 表示if级当前正在等待指令返回，或�?�if级的指令缓存有效
        if(~resetn)
            if_valid <=         1'b0;
        else if(~(inst_sram_req & inst_sram_addr_ok) & (br_taken | flush)) // 排除跳转目的的pc值下�?个周期就返回
            if_valid <=         1'b0;
        else if(pre_if_readygo & if_allowin)
            if_valid <=         to_if_valid;
        else if(if_ready_go && id_allowin)
            if_valid <=         1'b0;
    end
    assign if_ready_go      =    if_ir_valid
                                |inst_sram_data_ok
                                |if_excep_en;
    assign if_to_id_valid   =   if_ready_go & ~inst_cancel & if_valid;

    assign if_allowin       =   ~if_valid 
                                | if_ready_go & id_allowin ;   

    /* 与id的数据和控制信号交互 */
    assign {br_taken, br_target, br_stall, icacop, cacop_code, icacop_addr} =        id_to_if_bus;
    assign if_to_id_bus =                           {if_inst,       // 32 bit
                                                    if_pc,          // 32 bit 
                                                    if_excep_en,    // 1 bit
                                                    if_ecode,       // 6 bit
                                                    if_esubcode,     // 9 bit
                                                    if_badv
                                                    };         

    /* 清空流水线时，第�?个指令需要丢�?*/
    always @(posedge clk) begin
        if(~resetn)
            inst_cancel <= 1'b0;
        else if (   (if_valid & ~if_ir_valid & ~inst_sram_data_ok & ~if_excep_en  // if正在等待指令返回
                    |pre_if_reqed_reg & ~pre_if_ir_valid & ~inst_sram_data_ok)// pre_if 级发出请求，但是数据没有返回，也还没有进入if�?
                & (flush | br_taken))
            inst_cancel <= 1'b1;
        else if(inst_sram_data_ok)      // 异常后第�?个需要被舍弃的指令返�?
            inst_cancel <= 1'b0;
    end


//=================================================pre_IF阶段发出指令请求
    // 与pre-if级的握手信号
    assign pre_if_readygo   =   pre_if_reqed_reg
                                |inst_sram_req & inst_sram_addr_ok
                                |pre_if_excep_en;

    assign to_if_valid      =   resetn;
    
    /* 与指令sram交互信号 */
    assign inst_sram_wstrb  =   4'b0;
    assign inst_sram_wr     =   1'b0;
    assign inst_sram_wdata  =   32'b0;

    assign inst_sram_req    =   resetn & ~pre_if_reqed_reg        // pre if 没有已经发出请求的指�? 
                                & ( inst_sram_data_ok  // 上一个请求恰好返�?  
                                    | if_ir_valid         // 上一个请求已经返回，且未进入id�?
                                    | if_allowin)     // 上一个请求已经返回，且已经进入id�?
                                & ~br_stall          //  转移计算已经完成
                                & ~pre_if_excep_en;      
    assign inst_sram_addr   =   pre_pc_pa;

    /* 控制信号和寄存器 */
    assign seq_pc           =   if_pc + 3'h4;  
    assign pre_pc           =   flush_reg ? flush_entry_reg
                                : flush ? wb_flush_entry
                                : br_taken_reg ? br_target_reg 
                                : br_taken ? br_target 
                                : seq_pc;
    always @(posedge clk) begin
        if(~resetn)begin
            br_taken_reg <= 1'b0;
            br_target_reg <= 32'b0;
        end
        else if((~inst_sram_req | ~inst_sram_addr_ok) & br_taken) begin// id级为跳转，但当前clk不能发出请求
            br_taken_reg <= 1'b1;
            br_target_reg <= br_target;
        end
        else if(inst_sram_req & inst_sram_addr_ok)begin
            br_taken_reg <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if(~resetn)begin
            flush_reg <= 1'b0;
            flush_entry_reg <= 32'b0;
        end
        else if((~inst_sram_req | ~inst_sram_addr_ok) & flush)begin
            flush_reg <= 1'b1;
            flush_entry_reg <= wb_flush_entry;
        end
        else if(inst_sram_req & inst_sram_addr_ok)
            flush_reg <= 1'b0;
    end
    
    always @(posedge clk) begin     // pre if 已经发出请求，且没有进入if�?
        if(~resetn)                 // 同时可以表明，当前inst_sram返回的指令是属于pre_if级的，�?�不是if级的
            pre_if_reqed_reg <= 1'b0;
        else if(pre_if_readygo && if_allowin)   // move forward to if
            pre_if_reqed_reg <= 1'b0;
        else if(inst_sram_req && inst_sram_addr_ok)
            pre_if_reqed_reg <= 1'b1;
    end

// pre-if级的指令暂存
    always @(posedge clk) begin
        if(~resetn)begin
            pre_if_ir_valid <= 1'b0;
            pre_if_ir <= 32'b0;
        end
        else if(    inst_sram_data_ok 
                    & pre_if_reqed_reg  // pre if 已经发出请求，且没有进入if�?
                    & ~if_allowin)     begin   
            pre_if_ir_valid <= 1'b1;
            pre_if_ir <= inst_sram_rdata;
        end
        else if(if_allowin & pre_if_readygo)begin
            pre_if_ir_valid <= 1'b0;
        end
    end
// ===============================================IF 阶段等待指令返回
    /* pc register */
    always @(posedge clk) begin
        if(~resetn)
            if_pc <= 32'h1bfffffc;
        else if(if_allowin & pre_if_readygo)
            if_pc <= pre_pc;
    end
    /* inst to id */
    assign if_inst    =     if_ir_valid ?  if_ir
                            :inst_sram_rdata;
    // if 级指令缓�?
    always @(posedge clk)begin
        if(~resetn) begin 
            if_ir_valid <=  1'b0;
            if_ir <=        32'b0;
        end
        else if(    (inst_sram_data_ok & ~pre_if_reqed_reg & ~if_ir_valid & ~id_allowin        // if级当前返回的指令不能进入id�?   
                    | pre_if_readygo & if_allowin & ~(flush | br_taken) & (pre_if_ir_valid        // pre_if缓存的指令必须先进入if级的缓存，不能直接进入id�?
                                                | inst_sram_data_ok & pre_if_reqed_reg)) ) begin// pre_if返回的指令必须先进入if级的缓存，不能直接进入id�?
            if_ir_valid <=  1'b1;
            if_ir <=        inst_sram_data_ok ? inst_sram_rdata
                                            :pre_if_ir;
        end
        else if(if_ready_go & id_allowin)
            if_ir_valid <= 1'b0;
    end
// =============================================虚实地址转换
    assign {s0_vppn, s0_va_bit12} = icacop_vaddr[31:12];// output to tlb

    assign inst_vindex = inst_sram_addr[11: 4] & {8{~icacop | cacop_code[4:3]==2'b10 | icacop_complete}}
                                | icacop_addr[11: 4] & {8{icacop & ~icacop_complete & cacop_code[4:3]!=2'b10}};

    assign inst_voffset =inst_sram_addr[ 3: 0] & {4{~icacop | cacop_code[4:3]==2'b10 | icacop_complete}}
                                | icacop_addr[ 3: 0] & {4{icacop & ~icacop_complete & cacop_code[4:3]!=2'b10}};

    //assign inst_vindex = pre_pc[11:4];
    //assign inst_voffset = pre_pc[3:0];

    wire [31:0]                 pre_pc_map;
    wire                        hit_dmw0;
    wire                        hit_dmw1;
    assign pre_pc_pa =          (!csr_crmd_pg | inst_cacop & cacop_code[4:3] == 2'b00 | inst_cacop & cacop_code[4:3] == 2'b01) ? pre_pc            // direct translate
                                :pre_pc_map;                    // enable mapping
                            
    assign hit_dmw0 =           csr_dmw0_plv_met & csr_dmw0_vseg == pre_pc[31:29];
    assign hit_dmw1 =           csr_dmw1_plv_met & csr_dmw1_vseg == pre_pc[31:29];

    assign pre_pc_map =         hit_dmw0 ? {csr_dmw0_pseg, pre_pc[28:0]}         // dierct map windows 0
                                :hit_dmw1? {csr_dmw1_pseg, pre_pc[28:0]}         // direct map windows 1
                                :(s0_ps == 6'b010101) ? {s0_ppn[19:9], icacop_vaddr[20:0]}   // tlb map: ps 4Mb
                                :{s0_ppn,icacop_vaddr[11:0]};                             // tlb map : ps 4kb

//====================================================取指地址错异常处�?
    assign pre_if_excep_ADEF   =        pre_pc[0] | pre_pc[1];   // 记录该条指令是否存在ADEF异常
    assign pre_if_excep_TLBR   =        csr_crmd_pg & ~hit_dmw0 & ~hit_dmw1 & ~s0_found;    // TLB refull
    assign pre_if_excep_PIF =           csr_crmd_pg & ~hit_dmw0 & ~hit_dmw1 & s0_found & ~s0_v;
    assign pre_if_excep_PPI =           csr_crmd_pg & ~hit_dmw0 & ~hit_dmw1 & s0_found & s0_v & (csr_crmd_plv > s0_plv);
    assign pre_if_ecode =               pre_if_excep_ADEF?  6'h08   // adef
                                        :pre_if_excep_TLBR?6'h3f  // tlbr
                                        :pre_if_excep_PIF? 6'h3 // pif
                                        :6'h7;   // ppi
    assign pre_if_esubcode =            9'b0;
    assign pre_if_excep_en =            pre_if_excep_ADEF| pre_if_excep_TLBR | pre_if_excep_PIF | pre_if_excep_PPI;
    always @(posedge clk)begin
        if(~resetn)begin
            if_excep_en  <=                 1'b0;
            if_ecode <=                     6'b0;
            if_esubcode <=                  9'b0;
            if_badv <=                      32'b0;            
        end
        else if(if_allowin & pre_if_readygo)begin
            if_excep_en  <=                 pre_if_excep_en;
            if_ecode <=                     pre_if_ecode;
            if_esubcode <=                  pre_if_esubcode;
            if_badv <=                      pre_pc;
        end
    end



////icacop
 wire [31:0]icacop_vaddr;
 wire [31:0]icacop_addr;
 wire inst_cacop;
 wire [4:0] cacop_code;
 
 assign icacop_vaddr = pre_pc & {32{~icacop| cacop_code[4:3]!=2'b10|icacop_complete}}
                    | icacop_addr&{32{icacop & ~icacop_complete &cacop_code[4:3]==2'b10}};

//的icacop_complete信号，用来标记ICache的cacop指令是否执行完毕
//为op�?10时，�?要两个周期才能完成，op不为10时需�?个周期完�?
always @(posedge clk) begin
    if (~resetn) begin
        icacop_complete <= 1'b1;
    end
    else if (icacop & cacop_code[4:3] != 2'b10) begin
        icacop_complete <= 1'b1;
    end
    else if (icacop_next & cacop_code[4:3] == 2'b10) begin
        icacop_complete <= 1'b1;
    end
    else  
        icacop_complete <= 1'b0;
end

reg icacop_next;
always @(posedge clk) begin
    if (~resetn) begin
        icacop_next <= 1'b0;
    end
    else
        icacop_next <= icacop;
end

endmodule
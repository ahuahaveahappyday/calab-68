module IFreg(
    input  wire   clk,
    input  wire   resetn,
    //if模块与指令存储器的交互接口
    output wire         inst_sram_req,
    output wire         inst_sram_wr,
    output wire [1:0]   inst_sram_size,
    output wire [3:0]   inst_sram_wstrb,
    output wire [31:0]  inst_sram_addr,
    output wire [31:0]  inst_sram_wdata,
    
    input wire          inst_sram_addr_ok,
    input wire          inst_sram_data_ok,
    input wire  [31:0]  inst_sram_rdata,
    //if模块与id模块交互接口
    input  wire         id_allowin,
    input  wire [33:0]  id_to_if_bus,//{br_taken, br_target}
    output wire         if_to_id_valid,
    output wire [65:0]  if_to_id_bus,//{if_inst, if_pc}
    //etrn清空流水线
    input  wire         flush,
    input  wire [31:0]  wb_csr_rvalue
);
//pre-if需要的寄存器
    // reg  [31:0] pre_if_ir;      // inst_reg
    // reg         pre_if_ir_valid;

    //reg         pre_if_reqed;
//if流水级需要的寄存器，根据clk不断更新
    reg         if_valid;       //if流水级是否有效：正在等待或者已经接受到指令

    reg  [31:0] if_pc;

    wire [31:0] if_inst;//wire信号，在ID被寄存

    reg  [31:0] if_ir;
    reg         if_ir_valid;
//流水控制信号
    wire        if_ready_go;
    wire        if_allowin;

    wire        pre_if_readygo;
    wire        to_if_valid;

//生成下一条指令的PC
    wire [31:0] seq_pc;
    wire [31:0] pre_pc; //预取指令（pre-IF）

//branch类指令的信号和目标地址，来自ID模块
    wire         br_taken;
    wire [ 31:0] br_target;
    wire         br_stall;

    reg          br_taken_reg;
    reg  [ 31:0] br_target_reg;

    reg          flush_reg;
    reg  [ 31:0] excep_entry_reg;

    reg          inst_cancel;
    

// 异常相关
    wire        pre_if_excep_en;
    wire        pre_if_excep_ADEF;
    reg         if_excep_en;
    reg         if_excep_ADEF;


//----------------------------------------------------------------------------------------------------------------------------------------------

//流水线控制信号
    // 与id级的握手信号
    always @(posedge clk) begin
        if(~resetn)
            if_valid <= 1'b0;
        else if(pre_if_readygo & if_allowin)
            if_valid <= to_if_valid;
        else if(if_ready_go && id_allowin)
            if_valid <= 1'b0;
    end
    assign if_ready_go      =    if_ir_valid
                                |inst_sram_data_ok;
                                //|if_allowin & pre_if_ir_valid;  
    assign if_to_id_valid   =   if_ready_go & ~inst_cancel;

    // 与pre-if级的握手信号
    // always @(posedge clk) begin     // pre if 已经发出请求，且没有进入if级
    //     if(~resetn)
    //         pre_if_reqed <= 1'b0;
    //     else if(pre_if_readygo && if_allowin)
    //         pre_if_reqed <= 1'b0;
    //     else if(inst_sram_req && inst_sram_addr_ok)
    //         pre_if_reqed <= 1'b1;
    // end
    assign pre_if_readygo   =   //pre_if_reqed
                                 inst_sram_req & inst_sram_addr_ok;
                                //| pre_if_ir_valid;
    assign if_allowin       =   ~if_valid 
                                | if_ready_go & id_allowin ;   
    assign to_if_valid      =    resetn;  
//pre_IF阶段提前生成下一条指令的PC
    assign seq_pc           =   if_pc + 3'h4;  
    assign pre_pc           =   flush_reg ? excep_entry_reg
                                : flush ? wb_csr_rvalue
                                : br_taken_reg ? br_target_reg 
                                : br_taken ? br_target 
                                : seq_pc;
    always @(posedge clk) begin
        if(~resetn)
            if_pc <= 32'h1bfffffc;
        else if(if_allowin & pre_if_readygo)
            if_pc <= pre_pc;
    end
    always @(posedge clk) begin
        if(~resetn)
            br_taken_reg <= 1'b0;
        else if((~inst_sram_req | ~inst_sram_addr_ok) & br_taken)// id级为跳转，但当前clk不能发出请求
            br_taken_reg <= 1'b1;
        else if(inst_sram_req & inst_sram_addr_ok)
            br_taken_reg <= 1'b0;
    end
    
    always @(posedge clk) begin
        if(~resetn)
            br_target_reg <= 32'b0;
        else if((~inst_sram_req | ~inst_sram_addr_ok) & br_taken)
            br_target_reg <= br_target;
    end

    always @(posedge clk) begin
        if(~resetn)
            flush_reg <= 1'b0;
        else if((~inst_sram_req | ~inst_sram_addr_ok) & flush)
            flush_reg <= 1'b1;
        else if(inst_sram_req & inst_sram_addr_ok)
            flush_reg <= 1'b0;
    end

    always @(posedge clk) begin
        if(~resetn)
            excep_entry_reg <= 32'b0;
        else if((~inst_sram_req | ~inst_sram_addr_ok) & flush)
            excep_entry_reg <= wb_csr_rvalue;
    end

//取指令
    assign inst_sram_wstrb  = 4'b0;
    assign inst_sram_wr     = 1'b0;
    assign inst_sram_size   = 2'h2;
    assign inst_sram_wdata  = 32'b0;

    assign inst_sram_req    = resetn //& ~pre_if_reqed        // pre if 没有已经发出请求的指令 
                            // & ( inst_sram_data_ok  // 上一个请求恰好返回  
                            //     | if_inst_valid         // 上一个请求已经返回，且未进入id级
                            //     | if_allowin)     // 上一个请求已经返回，且已经进入id级
                            & if_allowin
                            & ~br_stall;        // 转移计算未完成

    assign inst_sram_addr   = pre_pc;

// 指令暂存
    // pre-if
    // always @(posedge clk) begin
    //     if(~resetn)
    //         pre_if_ir <= 32'b0;
    //     else if(inst_sram_data_ok & if_ir_valid & pre_if_readygo & ~if_allowin)        // 在pre if级就接受到指令，但是if已有指令，且阻塞
    //         pre_if_ir <= inst_sram_rdata;
    // end
    // always @(posedge clk) begin
    //     if(~resetn)
    //         pre_if_ir_valid <= 1'b0;
    //     else if(inst_sram_data_ok & if_ir_valid & pre_if_readygo & ~if_allowin)
    //         pre_if_ir_valid <= 1'b1;
    //     else if(if_allowin & pre_if_ir_valid)
    //         pre_if_ir_valid <= 1'b0;
    // end

    // if
    always @(posedge clk)begin
        if(~resetn)
            if_ir <= 32'b0;
        else if(inst_sram_data_ok & ~id_allowin & ~inst_cancel)// & ~if_ir_valid)//| pre_if_readygo & if_allowin & pre_if_ir_valid))    // 接受到有效指令，但不能进入id级
            if_ir <= inst_sram_rdata;
                    //inst_sram_data_ok ? inst_sram_rdata
                    //:pre_if_ir;
    end
    always @(posedge clk)begin
        if(~resetn)
            if_ir_valid <= 1'b0;
        else if(inst_sram_data_ok & ~id_allowin & ~inst_cancel)// & ~if_inst_valid )| pre_if_readygo & if_allowin & pre_if_ir_valid))
            if_ir_valid <= 1'b1;
        else if(if_ready_go & if_allowin)
            if_ir_valid <= 1'b0;
    end

//清空流水线时，第一个指令需要丢弃
    always @(posedge clk) begin
        if(~resetn)
            inst_cancel <= 1'b0;
        else if ((if_valid & ~if_ir_valid & ~inst_sram_data_ok)  // if正在等待指令返回
                & (flush | br_taken))
            inst_cancel <= 1'b1;
        else if(inst_sram_data_ok)      // 异常后第一个需要被舍弃的指令返回
            inst_cancel <= 1'b0;
    end

//与id交互
    assign {br_taken, br_target, br_stall} =  id_to_if_bus;
    assign if_to_id_bus =           {if_inst, if_pc, if_excep_en, if_excep_ADEF};          
    assign if_inst    =             if_ir_valid ?  if_ir
                                    :inst_sram_rdata;

//取指地址错异常处理
    assign pre_if_excep_ADEF   =     pre_pc[0] | pre_pc[1];   // 记录该条指令是否存在ADEF异常
    assign pre_if_excep_en =        pre_if_excep_ADEF;
    always @(posedge clk)begin
        if_excep_en  <= pre_if_excep_en;
        if_excep_ADEF <= pre_if_excep_ADEF;
    end

endmodule
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
    input  wire [32:0]  id_to_if_bus,//{br_taken, br_target}
    output wire         if_to_id_valid,
    output wire [65:0]  if_to_id_bus,//{if_inst, if_pc}
    //etrn清空流水线
    input  wire         flush,
    input  wire [31:0]  excep_entry
);
//pre-if需要的寄存器
    reg  [31:0] pre_if_ir;      // inst_reg
    reg         pre_if_ir_valid;

    reg         pre_if_valid;
//if流水级需要的寄存器，根据clk不断更新
    reg         if_valid;//寄存if流水级是否有指令
    reg  [31:0] if_pc;//寄存if流水级的pc值

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
        else if(if_ready_go && id_allowin)
            if_valid <= 1'b0;
        else if(inst_sram_data_ok | if_allowin & pre_if_readygo & pre_if_ir_valid)
            if_valid <= 1'b1;
    end
    assign if_ready_go      =   if_valid
                                |inst_sram_data_ok
                                |if_allowin & pre_if_ir_valid;  
    assign if_to_id_valid   =   if_ready_go;

    // 与pre-if级的握手信号
    always @(posedge clk) begin
        if(~resetn)
            pre_if_valid <= 1'b0;
        else if(pre_if_readygo && if_allowin)
            pre_if_valid <= 1'b0;
        else if(inst_sram_req && inst_sram_addr_ok)
            pre_if_valid <= 1'b1;
    end
    assign pre_if_readygo   =   pre_if_valid
                                | inst_sram_req & inst_sram_addr_ok;
    assign if_allowin       =   ~if_valid 
                                | if_ready_go & id_allowin 
                                | flush;   

//pre_IF阶段提前生成下一条指令的PC
    assign seq_pc           =   if_pc + 3'h4;  
    assign pre_pc           =   flush ? excep_entry
                                : br_taken ? br_target 
                                : seq_pc;
    always @(posedge clk) begin
        if(~resetn)
            if_pc <= 32'h1bfffffc;
        else if(if_allowin & pre_if_readygo)
            if_pc <= pre_pc;
    end

//取指令
    assign inst_sram_wstrb  = 4'b0;
    assign inst_sram_wr     = 1'b0;
    assign inst_sram_size   = 2'h2;
    assign inst_sram_wdata  = 32'b0;

    assign inst_sram_req    = resetn & ~pre_if_valid;
    assign inst_sram_addr   = pre_pc;

// 指令暂存
    // pre-if
    always @(posedge clk) begin
        if(~resetn)
            pre_if_ir <= 32'b0;
        else if(inst_sram_data_ok & if_valid & pre_if_readygo)                  // 在pre if级就接受到指令，但是if阻塞
            pre_if_ir <= inst_sram_rdata;
    end
    always @(posedge clk) begin
        if(~resetn)
            pre_if_ir_valid <= 1'b0;
        else if(inst_sram_data_ok & if_valid & pre_if_readygo)
            pre_if_ir_valid <= 1'b1;
        else if(if_allowin & pre_if_ir_valid)
            pre_if_ir_valid <= 1'b0;
    end

    // if
    always @(posedge clk)begin
        if(~resetn)
            if_ir <= 32'b0;
        else if((inst_sram_data_ok| pre_if_readygo & if_allowin & pre_if_ir_valid) & ~id_allowin & ~if_valid)       // 接受到有效指令，但不能进入id级
            if_ir <= inst_sram_data_ok ? inst_sram_rdata
                    :pre_if_ir;
    end
    always @(posedge clk)begin
        if(~resetn)
            if_ir_valid <= 1'b0;
        else if((inst_sram_data_ok| pre_if_readygo & if_allowin & pre_if_ir_valid) & ~id_allowin & ~if_valid)
            if_ir_valid <= 1'b1;
        else if(if_ready_go & if_allowin)
            if_ir_valid <= 1'b0;
    end


//与id交互
    assign {br_taken, br_target} =  id_to_if_bus;
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
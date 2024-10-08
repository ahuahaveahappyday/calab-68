module IFreg(
    input  wire   clk,
    input  wire   resetn,
    //if模块与指令存储器的交互接口
    output wire         inst_sram_en,
    output wire [ 3:0]  inst_sram_we,
    output wire [31:0]  inst_sram_addr,
    output wire [31:0]  inst_sram_wdata,
    input  wire [31:0]  inst_sram_rdata,
    //if模块与id模块交互接口
    input  wire         id_allowin,
    input  wire [32:0]  id_to_if_bus,//{br_taken, br_target}
    output wire         if_to_id_valid,
    output wire [63:0]  if_to_id_bus//{if_inst, if_pc}
);
//if流水级需要的寄存器，根据clk不断更新
    reg         if_valid;//寄存if流水级是否有指令
    reg  [31:0] if_pc;//寄存if流水级的pc值

    wire [31:0] if_inst;//wire信号，在ID被寄存


//流水控制信号
    wire        if_ready_go;
    wire        if_allowin;

//生成下一条指令的PC
    wire [31:0] seq_pc;
    wire [31:0] pre_pc; //预取指令（pre-IF）

//branch类指令的信号和目标地址，来自ID模块
    wire         br_taken;
    wire [ 31:0] br_target;
    
    wire  to_if_valid;
    assign to_if_valid      = resetn;


//----------------------------------------------------------------------------------------------------------------------------------------------

//流水线控制信号
    assign if_ready_go      = 1'b1;
    assign if_allowin       = ~if_valid | if_ready_go & id_allowin;     
    assign if_to_id_valid   = if_valid & if_ready_go;

//pre_IF阶段提前生成下一条指令的PC
    assign seq_pc           = if_pc + 3'h4;  
    assign pre_pc           = br_taken ? br_target : seq_pc;

//更新if模块中的寄存器
    always @(posedge clk) begin
        if(~resetn)
            if_valid <= 1'b0;
        else if(if_allowin)
            if_valid <= to_if_valid; 
    end
    always @(posedge clk) begin
        if(~resetn)
            if_pc <= 32'h1bfffffc;
        else if(if_allowin)
            if_pc <= pre_pc;
    end

//模块间通信
    assign inst_sram_en     = if_allowin & resetn;//当if流水级允许流入的时候，片选信号置位1
    assign inst_sram_we     = 4'b0;
    assign inst_sram_addr   = pre_pc;//提前一个时钟周期向内存提交PC
    assign inst_sram_wdata  = 32'b0;

    assign {br_taken, br_target} = id_to_if_bus;
    assign if_to_id_bus = {if_inst, if_pc};
    assign if_inst    = inst_sram_rdata;//来自存储器的inst
endmodule
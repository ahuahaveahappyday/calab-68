module EXEreg(
    input  wire        clk,
    input  wire        resetn,
    //id与ex模块交互接口
    output  wire       ex_allowin,
    input wire         id_to_ex_valid,
    input wire [154:0] id_to_ex_bus,
    output wire [38:0] ex_to_id_bus, // {ex_res_from_mem, ex_rf_we, ex_rf_waddr, ex_alu_result}
    //ex与mem模块接口
    input  wire        mem_allowin,
    output wire        ex_to_mem_valid,
    output wire [102:0]ex_to_mem_bus,//{ex_pc,ex_res_from_mem, ex_rf_we, ex_rf_waddr, ex_alu_result,ex_rkd_value}
    //ex模块与数据存储器交互
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata
);
//ex模块需要的寄存器，寄存当前时钟周期的信号
    reg         ex_valid;
    reg  [31:0] ex_pc;//ex流水级的pc值
    reg  [18:0] ex_alu_op;
    reg  [31:0] ex_alu_src1;//alu操作数
    reg  [31:0] ex_alu_src2;
    reg  [31:0] ex_rkd_value;//源寄存器2读出的值
    reg         ex_res_from_mem;//load指令码
    reg         ex_mem_we;//store指令码
    reg         ex_rf_we;//寄存器写使能
    reg  [4 :0] ex_rf_waddr;//寄存器写地址

    wire        ex_ready_go;
    wire [31:0] ex_alu_result;
    wire        alu_complete;

//流水线控制信号
    assign ex_ready_go      = alu_complete;//等待alu完成运算
    assign ex_allowin       = ~ex_valid | ex_ready_go & mem_allowin;     
    assign ex_to_mem_valid  = ex_valid & ex_ready_go;

//EX流水级需要的寄存器，根据clk不断更新
    always @(posedge clk) begin
        if(~resetn)
            ex_valid <= 1'b0;
        else if(ex_allowin)
            ex_valid <= id_to_ex_valid; 
    end
    always @(posedge clk) begin
        if(~resetn)
            {ex_alu_op, ex_res_from_mem, ex_alu_src1, ex_alu_src2,
             ex_mem_we, ex_rf_we, ex_rf_waddr, ex_rkd_value, ex_pc} <= {148{1'b0}};
        else if(id_to_ex_valid & ex_allowin)
            {ex_alu_op, ex_res_from_mem, ex_alu_src1, ex_alu_src2,
             ex_mem_we, ex_rf_we, ex_rf_waddr, ex_rkd_value, ex_pc} <= id_to_ex_bus;    
    end

//alu的实例化
    alu u_alu(
        .clk            (clk       ),
        .resetn         (resetn    ),
        .alu_op         (ex_alu_op    ),
        .alu_src1       (ex_alu_src1  ),
        .alu_src2       (ex_alu_src2  ),
        .alu_result     (ex_alu_result),
        .complete       (alu_complete)
    );
//模块间通信
    //与内存交互接口定义
    assign data_sram_en     = (ex_res_from_mem || ex_mem_we) && ex_valid;//load 或者 store 指令有效的时候，启动sram片选信号
    assign data_sram_we     = {4{ex_mem_we & ex_valid}};//store 指令有效，内存写使能启动
    assign data_sram_addr   = ex_alu_result;//由于为同步ram，需要两个时钟周期才能读存储器，因此提前一拍将addr发送出去，这样mem阶段才能收到读dram的结果
    assign data_sram_wdata  = ex_rkd_value;

    //打包
    assign ex_to_id_bus     = {ex_res_from_mem & ex_valid , ex_rf_we & ex_valid, ex_rf_waddr, ex_alu_result};   
    assign ex_to_mem_bus    = {ex_pc,ex_res_from_mem & ex_valid, ex_rf_we & ex_valid, ex_rf_waddr, ex_alu_result, ex_rkd_value};

endmodule
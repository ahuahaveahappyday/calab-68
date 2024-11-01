module EXEreg(
    input  wire        clk,
    input  wire        resetn,
    //id与ex模块交互接口
    output  wire       ex_allowin,
    input wire         id_to_ex_valid,
    input wire [225:0] id_to_ex_bus,
    output wire [39:0] ex_to_id_bus, // {ex_res_from_mem, ex_rf_we, ex_rf_waddr, ex_alu_result}
    //ex与mem模块接口
    input  wire        mem_allowin,
    output wire        ex_to_mem_valid,
    output wire [239:0]ex_to_mem_bus,//{ex_pc,ex_res_from_mem, ex_rf_we, ex_rf_waddr, ex_alu_result,ex_rkd_value}
    input  wire [1:0]  mem_to_ex_bus,   // ex_en

    //ex模块与数据存储器交互
    output wire         data_sram_req,
    output wire         data_sram_wr,
    output wire [1:0]   data_sram_size,
    output wire [3:0]   data_sram_wstrb,
    output wire [31:0]  data_sram_addr,
    output wire [31:0]  data_sram_wdata,
    input wire          data_sram_addr_ok,
    
    input  wire         flush,

    input  wire [63:0]  counter
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
    reg         ex_op_st_ld_b;
    reg         ex_op_st_ld_h;
    reg         ex_op_st_ld_w;
    reg         ex_op_st_ld_u;
    reg         ex_read_counter;
    reg         ex_read_counter_low;
    reg         ex_read_TID;

    reg         ex_csr_re;
    reg         ex_csr_we;
    reg  [13:0] ex_csr_num;
    reg  [31:0] ex_csr_wmask;
    reg         ex_ertn_flush;
    wire        ex_excep_en;
    reg         ex_excep_ADEF;
    reg         ex_excep_SYSCALL;
    wire         ex_excep_ALE;
    reg         ex_excep_BRK;
    reg         ex_excep_INE;
    reg         ex_excep_INT;
    reg  [8:0]  ex_excep_esubcode;
    
    reg         id_excep_en;
    
    wire        ex_ready_go;
    wire [31:0] ex_alu_result;
    wire        alu_complete;
    wire [1:0]  ex_data_sram_addr;      // lowest 2 byte 
    wire        ex_cancel;
    wire        ex_mem_req;

    wire [31:0] ex_counter_result;

    wire        ex_res_from_wb;
    wire        mem_excep_en;
    //wire        wb_excep_en;
    wire        mem_ertn_flush;
    //wire        wb_ertn_flush;
    wire [31:0] ex_vaddr;
    // reg        ex_inst_st_b;               
    // reg        ex_inst_st_h;               
    // reg        ex_inst_st_w;                

//流水线控制信号
    assign ex_ready_go      = alu_complete & (~data_sram_req | data_sram_req & data_sram_addr_ok);//等待alu完成运算
    assign ex_allowin       = ~ex_valid | ex_ready_go & mem_allowin;     
    assign ex_to_mem_valid  = ex_valid & ex_ready_go;

//EX流水级需要的寄存器，根据clk不断更新
    always @(posedge clk) begin
        if(~resetn)
            ex_valid <= 1'b0;
        else if(flush)
            ex_valid <= 1'b0;
        else if(ex_allowin)
            ex_valid <= id_to_ex_valid; 
    end
    always @(posedge clk) begin
        if(~resetn)
            {ex_alu_op, ex_res_from_mem, ex_alu_src1, ex_alu_src2,
             ex_mem_we, ex_rf_we, ex_rf_waddr, ex_rkd_value, ex_pc,
              ex_op_st_ld_b, ex_op_st_ld_h, ex_op_st_ld_w, ex_op_st_ld_u, ex_read_counter, ex_read_counter_low, ex_read_TID, 
              ex_csr_re, ex_csr_we, ex_csr_num, ex_csr_wmask, ex_ertn_flush,
              id_excep_en, ex_excep_ADEF, ex_excep_SYSCALL, ex_excep_BRK, ex_excep_INE,ex_excep_INT,ex_excep_esubcode
              }       <= {226{1'b0}};
        else if(id_to_ex_valid & ex_allowin)
            {ex_alu_op, ex_res_from_mem, ex_alu_src1, ex_alu_src2,
             ex_mem_we, ex_rf_we, ex_rf_waddr, ex_rkd_value, ex_pc, 
             ex_op_st_ld_b, ex_op_st_ld_h, ex_op_st_ld_w, ex_op_st_ld_u, ex_read_counter, ex_read_counter_low, ex_read_TID, 
             ex_csr_re, ex_csr_we, ex_csr_num, ex_csr_wmask, ex_ertn_flush,
             id_excep_en, ex_excep_ADEF, ex_excep_SYSCALL, ex_excep_BRK, ex_excep_INE,ex_excep_INT, ex_excep_esubcode
             }     <= id_to_ex_bus;    
    end

//alu的实例化
    alu u_alu(
        .clk            (clk       ),
        .resetn         (resetn & ~flush & ~(id_to_ex_valid & ex_allowin)),
        .alu_op         (ex_alu_op    ),
        .alu_src1       (ex_alu_src1  ),
        .alu_src2       (ex_alu_src2  ),
        .alu_result     (ex_alu_result),
        .complete       (alu_complete)
    );
// 来自mem和wb的异常数据
    assign mem_excep_en = mem_to_ex_bus[1];
    assign mem_ertn_flush=mem_to_ex_bus[0];
    // assign wb_excep_en  = wb_to_ex_bus[1];
    // assign wb_ertn_flush= wb_to_ex_bus[0];
// 寄存器写回数据来自wb级
    assign ex_res_from_wb  = ex_csr_re;
//模块间通信

    //与内存交互接口定义
    assign data_sram_addr   =   ex_alu_result;//由于为同步ram，需要两个时钟周期才能读存储器，因此提前一拍将addr发送出去，这样mem阶段才能收到读dram的结果
    assign data_sram_wdata  =   {32{ex_op_st_ld_b}} & {4{ex_rkd_value[7:0]}}
                                |{32{ex_op_st_ld_h}} & {2{ex_rkd_value[15:0]}}
                                |{32{ex_op_st_ld_w}} & ex_rkd_value[31:0];
    assign data_sram_req    =   ex_mem_req & mem_allowin;
    assign data_sram_wr     =   ex_mem_we;
    assign data_sram_size   =     {2{ex_op_st_ld_b}} & 2'b0 
                                | {2{ex_op_st_ld_h}} & 2'b1 
                                | {2{ex_op_st_ld_w}} & 2'd2;
    
    assign data_sram_wstrb       =   {4{ex_op_st_ld_b}} & (4'b0001 << ex_data_sram_addr[1:0])          // st.b
                                    |{4{ex_op_st_ld_h}} & (ex_data_sram_addr[1] ? 4'b1100 : 4'b0011)    // st.h
                                    |{4{ex_op_st_ld_w}} & 4'b1111;// st.w

    assign ex_data_sram_addr= ex_alu_result[1:0];
    assign ex_mem_req       =   (ex_res_from_mem | ex_mem_we) & ex_valid 
                                & ~mem_excep_en & ~mem_ertn_flush         // mem级有异常
                                & ~ex_excep_en  & ~ex_ertn_flush          // ex级有异常
                                & ~flush;                                 // wb级报出异常

    //打包
    assign ex_to_id_bus     =   {ex_res_from_mem & ex_valid , 
                                ex_rf_we & ex_valid, 
                                ex_rf_waddr, 
                                ex_alu_result,
                                ex_res_from_wb & ex_valid};   
    assign ex_to_mem_bus    =   {ex_pc,                     // 32 bit
                                ex_res_from_mem & ex_valid, // 1 bit
                                ex_rf_we & ex_valid,        // 1 bit
                                ex_rf_waddr,                // 5 bit
                                ex_alu_result,              // 32 bit
                                ex_rkd_value,               // 32 bit
                                ex_data_sram_addr,          // 2 bit
                                ex_op_st_ld_b,              // 1 bit
                                ex_op_st_ld_h,              // 1 bit
                                ex_op_st_ld_u,              // 1 bit
                                ex_read_counter,            // 1 bit
                                ex_counter_result,          // 32 bit
                                ex_read_TID,                // 1 bit
                                ex_csr_re,                  // 1 bit
                                ex_csr_we,                  // 1 bit
                                ex_csr_num,                  // 14 bit        
                                ex_csr_wmask,                // 32 bit
                                ex_ertn_flush,               // 1 bit
                                ex_excep_en,                 // 1 bit
                                ex_excep_ADEF,               // 1 bit
                                ex_excep_SYSCALL,             // 1 bit
                                ex_excep_ALE,               // 1 bit
                                ex_excep_BRK,               // 1 bit
                                ex_excep_INE,               // 1 bit
                                ex_excep_INT,               //1 bit
                                ex_excep_esubcode,          // 9 bit
                                ex_vaddr,                     //32bit
                                ex_mem_req                  //1 bit 
                                };

// 读计数器
    assign ex_counter_result = ex_read_counter_low ? counter[31:0] : counter[63:32];            //处理rdcntvl.w rdcntvh.w指令

// 地址非对齐异常处理
    assign ex_excep_ALE = (ex_op_st_ld_h & ex_alu_result[0]) | (ex_op_st_ld_w & (ex_alu_result[1] | ex_alu_result[0]));     // 记录该条指令是否存在ALE异常
    assign ex_excep_en = ex_excep_ALE | id_excep_en;
    
    assign ex_vaddr = {32{ex_read_counter && ~ex_read_counter_low}} & counter[63:32] | 
                      {32{ex_read_counter && ex_read_counter_low}}  & counter[31: 0] |
                      {32{~ex_read_counter}} & ex_alu_result;


endmodule
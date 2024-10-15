module MEMreg(
    input  wire        clk,
    input  wire        resetn,
    //mem与ex模块交互接口
    output wire        mem_allowin,
    input  wire        ex_to_mem_valid,
    input  wire [238:0]ex_to_mem_bus, 
    //mem与wb模块交互接口
    input  wire        wb_allowin,
    output wire        mem_to_wb_valid,
    output wire [199:0] mem_to_wb_bus, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata, mem_pc}
    //mem与id模块交互接口
    output wire [38:0] mem_to_id_bus, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata}
    //mem与ex模块交互接口
    output wire  [1:0] mem_to_ex_bus,   // ex
    //mem与dram交互接口
    input  wire [31:0] data_sram_rdata,

    input  wire         flush

);
//MEM模块需要的寄存器，寄存当前时钟周期的信号
//定义方式与EX模块一致 此处不再赘述
    reg  [31:0] mem_pc;
    reg         mem_valid;
    reg  [31:0] mem_alu_result; //寄存的alu的运算结果
    reg         mem_res_from_mem;//load指令信号
    reg         mem_rf_we;
    reg  [4 :0] mem_rf_waddr;
    reg  [31:0] mem_rkd_value;//源寄存器2读出的值
    reg  [1:0]  mem_data_sram_addr;
    reg         mem_op_st_ld_b;
    reg         mem_op_st_ld_h;
    reg         mem_op_st_ld_u;
    reg         mem_read_counter;
    reg  [31:0] mem_counter_result;
    reg         mem_read_TID;

    reg         mem_csr_re;
    reg         mem_csr_we;
    reg  [13:0] mem_csr_num;
    reg  [31:0] mem_csr_wmask;
    reg         mem_ertn_flush;
    wire        mem_excep_en;
    reg         mem_excep_ADEF;
    reg         mem_excep_SYSCALL;
    reg         mem_excep_ALE;
    reg         mem_excep_BRK;
    reg         mem_excep_INE;
    reg         mem_excep_INT;
    reg [8:0]   mem_excep_esubcode;

    reg         ex_excep_en;
    reg [31:0]  mem_vaddr;

    wire        mem_ready_go;
    wire [31:0] mem_rf_wdata;
    wire [31:0] mem_result;//从dram读出的数据
    wire [31:0] mem_word_result;
    wire [15:0] mem_half_result;
    wire [8:0] mem_byte_result;

    wire [31:0] mem_csr_wvalue;
    wire        mem_res_from_wb;
// CSR 写数据
    assign mem_csr_wvalue = mem_rkd_value;
//流水线控制信号
    assign mem_ready_go      = 1'b1;
    assign mem_allowin       = ~mem_valid | mem_ready_go & wb_allowin;     
    assign mem_to_wb_valid   = mem_valid & mem_ready_go;

//MEM流水级需要的寄存器，根据clk不断更新
    always @(posedge clk) begin
        if(~resetn)
            mem_valid <= 1'b0;
        else if(flush)
            mem_valid <= 1'b0;
        else
            mem_valid <= ex_to_mem_valid & mem_allowin; 
    end
    always @(posedge clk) begin
        if(~resetn) begin
            {mem_pc,mem_res_from_mem, mem_rf_we, mem_rf_waddr, 
            mem_alu_result,mem_rkd_value, mem_data_sram_addr,
             mem_op_st_ld_b, mem_op_st_ld_h, mem_op_st_ld_u, mem_read_counter, mem_counter_result, mem_read_TID,
             mem_csr_re,mem_csr_we,mem_csr_num,mem_csr_wmask, mem_ertn_flush,
             ex_excep_en, mem_excep_ADEF, mem_excep_SYSCALL, mem_excep_ALE, mem_excep_BRK, mem_excep_INE, mem_excep_INT,mem_excep_esubcode,mem_vaddr} <= 239'b0;
        end
        if(ex_to_mem_valid & mem_allowin) begin
            {mem_pc,mem_res_from_mem, mem_rf_we, mem_rf_waddr, 
            mem_alu_result,mem_rkd_value, mem_data_sram_addr, 
            mem_op_st_ld_b, mem_op_st_ld_h, mem_op_st_ld_u, mem_read_counter, mem_counter_result, mem_read_TID,
            mem_csr_re,mem_csr_we,mem_csr_num,mem_csr_wmask, mem_ertn_flush,
             ex_excep_en, mem_excep_ADEF, mem_excep_SYSCALL, mem_excep_ALE, mem_excep_BRK, mem_excep_INE,mem_excep_INT, mem_excep_esubcode,mem_vaddr} <= ex_to_mem_bus;
        end
    end
// 寄存器写回数据来自wb级
    assign mem_res_from_wb  = mem_csr_re;
//模块间通信
    //与内存交互接口定义
    assign mem_word_result =    data_sram_rdata;
    assign mem_half_result =    mem_data_sram_addr[1] ? data_sram_rdata[31:16]
                                : data_sram_rdata[15:0];
    assign mem_byte_result =    ({8{mem_data_sram_addr[1:0] == 2'd0}} & data_sram_rdata[7:0])
                                |({8{mem_data_sram_addr[1:0] == 2'd1}} & data_sram_rdata[15:8])
                                |({8{mem_data_sram_addr[1:0] == 2'd2}} & data_sram_rdata[23:16])
                                |({8{mem_data_sram_addr[1:0] == 2'd3}} & data_sram_rdata[31:24]);

    assign mem_result =         mem_op_st_ld_b ? ({{24{~mem_op_st_ld_u & mem_byte_result[7]}}, mem_byte_result[7:0]}):       // mem_ld_st_type[3] identify if signed externed
                                mem_op_st_ld_h ? ({{16{~mem_op_st_ld_u & mem_half_result[15]}}, mem_half_result[15:0]}) :
                                mem_word_result;
    //assign data_sram_wdata= mem_rkd_value;
    //打包
    assign mem_rf_wdata = mem_read_counter ? mem_counter_result : 
                          mem_res_from_mem ? mem_result : mem_alu_result;//生成寄存器写回的值
    assign mem_to_id_bus  = {mem_rf_we & mem_valid, mem_rf_waddr, mem_rf_wdata, mem_res_from_wb & mem_valid};
    assign mem_to_wb_bus  = {mem_rf_we & mem_valid,     // 1 bit
                            mem_rf_waddr,               // 5 bit
                            mem_rf_wdata,               // 32 bit
                            mem_pc,                     // 32 bit
                            mem_read_TID,               // 1 bit
                            mem_csr_re,                 // 1 bit
                            mem_csr_we,                 // 1 bit
                            mem_csr_num,                 // 14 bit
                            mem_csr_wmask,               // 32 bit
                            mem_csr_wvalue,               // 32 bit
                            mem_ertn_flush,              // 1 bit
                            mem_excep_en,               // 1 bit
                            mem_excep_ADEF,             // 1 bit
                            mem_excep_SYSCALL,            // 1 bit
                            mem_excep_ALE,              // 1 bit
                            mem_excep_BRK,              // 1 bit
                            mem_excep_INE,              // 1 bit
                            mem_excep_INT,               // 1 bit
                            mem_excep_esubcode,          // 9 bit
                            mem_vaddr                   //32bit
                            };        
    assign mem_to_ex_bus  = {mem_excep_en & mem_valid , mem_ertn_flush};    

//异常处理
    assign mem_excep_en = ex_excep_en;

endmodule
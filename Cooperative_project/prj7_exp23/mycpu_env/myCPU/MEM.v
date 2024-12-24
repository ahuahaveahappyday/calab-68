module MEMreg(
    input  wire        clk,
    input  wire        resetn,
    //mem与ex模块交互接口
    output wire        mem_allowin,
    input  wire        ex_to_mem_valid,
    input  wire [256:0]ex_to_mem_bus, 
    //mem与wb模块交互接口
    input  wire        wb_allowin,
    output wire        mem_to_wb_valid,
    output wire [211:0] mem_to_wb_bus, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata, mem_pc}
    //mem与id模块交互接口
    output wire [39:0] mem_to_id_bus, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata}
    //mem与ex模块交互接口
    output wire  [2:0] mem_to_ex_bus,   // ex
    //mem与dram交互接口
    input wire          data_sram_data_ok,
    input wire  [31:0]  data_sram_rdata,

    input  wire         flush

);
//接受ex级传递来的数据的寄存器
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
    reg  [4:0]  mem_tlb_op;
    reg         mem_srch_conflict;
    reg         mem_csr_re;
    reg         mem_csr_we;
    reg  [13:0] mem_csr_num;
    reg  [31:0] mem_csr_wmask;
    reg         mem_ertn_flush;
    reg [8:0]   mem_esubcode;
    reg [5:0]   mem_ecode;
    reg         mem_excep_en;
    reg [31:0]  mem_badv;
    reg [4:0]   mem_tlbsrch_res;
    reg         mem_cacop;
    reg [4:0]   mem_cacop_code;

// 流水级控制信号
    wire        mem_ready_go;
// load or store
    wire [31:0] mem_rf_wdata;
    wire [31:0] mem_result;//从dram读出的数据
    wire [31:0] mem_word_result;
    wire [15:0] mem_half_result;
    wire [8:0]  mem_byte_result;

    wire        mem_res_from_wb;
    reg         mem_sram_requed;
// refetch 
    wire        mem_refetch;

//流水线控制信号----------------------------------------------------------------------------------------------------------------------------------------
    assign mem_ready_go      =      ~mem_sram_requed 
                                    | mem_sram_requed & data_sram_data_ok;
    assign mem_allowin       =      ~mem_valid 
                                    | mem_ready_go & wb_allowin;     
    assign mem_to_wb_valid   =      mem_valid & mem_ready_go;

//MEM流水级寄存器接受从ex级传递的数据----------------------------------------------------------------------------------------------------------------------------------------
    always @(posedge clk) begin
        if(~resetn)
            mem_valid <= 1'b0;
        else if(flush)
            mem_valid <= 1'b0;
        else if(mem_allowin)
            mem_valid <= ex_to_mem_valid; 
    end

    always @(posedge clk) begin
        if(~resetn) begin
            {mem_pc,mem_res_from_mem, mem_rf_we, mem_rf_waddr, 
            mem_alu_result,mem_rkd_value, mem_data_sram_addr,
             mem_op_st_ld_b, mem_op_st_ld_h, mem_op_st_ld_u, mem_read_counter, mem_counter_result, mem_read_TID,
             mem_csr_re,mem_csr_we,mem_csr_num,mem_csr_wmask, mem_ertn_flush,
             mem_excep_en, mem_esubcode, mem_ecode, mem_badv,mem_sram_requed,
             mem_tlb_op,mem_srch_conflict, mem_tlbsrch_res,mem_cacop,mem_cacop_code} <= 257'b0;
        end
        if(ex_to_mem_valid & mem_allowin) begin
            {mem_pc,mem_res_from_mem, mem_rf_we, mem_rf_waddr, 
            mem_alu_result,mem_rkd_value, mem_data_sram_addr, 
            mem_op_st_ld_b, mem_op_st_ld_h, mem_op_st_ld_u, mem_read_counter, mem_counter_result, mem_read_TID,
            mem_csr_re,mem_csr_we,mem_csr_num,mem_csr_wmask, mem_ertn_flush,
             mem_excep_en, mem_esubcode, mem_ecode, mem_badv,mem_sram_requed,
             mem_tlb_op,mem_srch_conflict, mem_tlbsrch_res,mem_cacop,mem_cacop_code} <= ex_to_mem_bus;
        end
    end

//load 与内存交互接口----------------------------------------------------------------------------------------------------------------------------------------
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

//模块间通信----------------------------------------------------------------------------------------------------------------------------------------
// 寄存器写回数据来自wb级
    assign mem_res_from_wb  = mem_csr_re;
     assign mem_rf_wdata = mem_read_counter ? mem_counter_result : 
                          mem_res_from_mem ? mem_result : mem_alu_result;//生成寄存器写回的值
//打包
    assign mem_to_id_bus  = {mem_rf_we & mem_valid, 
                            mem_rf_waddr, 
                            mem_rf_wdata,
                            mem_res_from_wb & mem_valid,
                            mem_res_from_mem & mem_valid
                            };
    assign mem_to_wb_bus  = {mem_rf_we & mem_valid,     // 1 bit
                            mem_rf_waddr,               // 5 bit
                            mem_rf_wdata,               // 32 bit
                            mem_pc,                     // 32 bit
                            mem_read_TID,               // 1 bit
                            mem_csr_re,                 // 1 bit
                            mem_csr_we,                 // 1 bit
                            mem_csr_num,                 // 14 bit
                            mem_csr_wmask,               // 32 bit
                            mem_rkd_value,               // 32 bit
                            mem_ertn_flush,              // 1 bit
                            mem_excep_en,               // 1 bit
                            mem_esubcode,          // 9 bit
                            mem_ecode,              // 6 bit
                            mem_badv,                   //32bit
                            mem_tlb_op,                  //5 bit
                            mem_srch_conflict,             //1bit
                            mem_tlbsrch_res,             // 5 bit
                            mem_cacop                  // 1 bit
                            };        
    assign mem_to_ex_bus  = {(mem_excep_en|| mem_refetch) & mem_valid ,
                             mem_ertn_flush & mem_valid, 
                             mem_srch_conflict & mem_valid};    


// refetch sign
    assign mem_refetch =    mem_tlb_op[3]   // inst_tlbwr
                            || mem_tlb_op[2]    // inst_tlbfill
                            || mem_tlb_op[1]    // inst_tlbrd
                            || mem_tlb_op[0]   // inst_invtlb
                            || (mem_csr_we && (mem_csr_num ==14'h18 // ASID
                                            || mem_csr_num ==14'h0 // CRMD
                                            || mem_csr_num ==14'h180// DMW0
                                            ||mem_csr_num ==14'h181)
                            || mem_cacop)// DMW1
                            ;

endmodule
module WBreg(
    input  wire        clk,
    input  wire        resetn,
    //mem与wb模块交互接口
    output wire        wb_allowin,
    input  wire        mem_to_wb_valid,
    input  wire [199:0] mem_to_wb_bus, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata，mem_pc}
    //debug信号
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    //mem与id模块交互接口
    output wire [37:0] wb_to_id_bus,  // {wb_rf_we, wb_rf_waddr, wb_rf_wdata}
    //mem与csr_file模块指令访问
    output wire        csr_re,
    output wire [13:0] csr_num,
    input  wire [31:0] csr_rvalue,
    output wire        csr_we,
    output wire [31:0] csr_wmask,
    output wire [31:0] csr_wvalue,
    //mem与csr_file模块异常
    output wire        wb_ex,
    output wire [5:0]  wb_ecode,
    output wire [8:0]  wb_esubcode,
    output wire [31:0] wb_ex_pc,
    output reg  [31:0] wb_vaddr,
    //  传给if级的跳转地址
    output wire [31:0] wb_csr_rvalue,

    output wire        ertn_flush
);
    
    wire        wb_ready_go;

//MEM模块需要的寄存器
    reg         wb_valid;
    reg  [31:0] wb_pc;
    reg  [31:0] wb_rf_wdata;
    reg  [4 :0] wb_rf_waddr;
    reg         wb_rf_we;
    reg         wb_read_TID;

    reg         wb_csr_re;
    reg         wb_csr_we;
    reg  [13:0] wb_csr_num;
    reg  [31:0] wb_csr_wmask;
    reg  [31:0] wb_csr_wvalue;
    reg         wb_ertn_flush;
    wire        wb_excep_en;
    reg         wb_excep_ADEF;
    reg         wb_excep_SYSCALL;
    reg         wb_excep_ALE;
    reg         wb_excep_BRK;
    reg         wb_excep_INE;
    reg         wb_excep_INT;
    reg  [8:0]  wb_excep_esubcode;

    reg        mem_excep_en;

    wire [31:0] final_rf_wdata;

//流水线控制信号
    assign wb_ready_go      = 1'b1;
    assign wb_allowin       = ~wb_valid | wb_ready_go ;     

//WB流水级需要的寄存器，根据clk不断更新
    always @(posedge clk) begin
        if(~resetn)
            wb_valid <= 1'b0;
        else if(wb_ex || ertn_flush)
            wb_valid <= 1'b0;
        else if(wb_allowin)
            wb_valid <= mem_to_wb_valid; 
    end
    always @(posedge clk) begin
        if(~resetn) begin
            {wb_rf_we, wb_rf_waddr, wb_rf_wdata,wb_pc, wb_read_TID,
            wb_csr_re,wb_csr_we,wb_csr_num, wb_csr_wmask,wb_csr_wvalue, wb_ertn_flush
            ,mem_excep_en, wb_excep_ADEF, wb_excep_SYSCALL, wb_excep_ALE, wb_excep_BRK, wb_excep_INE, wb_excep_INT,wb_excep_esubcode,wb_vaddr} <= 200'b0;
        end
        if(mem_to_wb_valid & wb_allowin) begin
            {wb_rf_we, wb_rf_waddr, wb_rf_wdata,wb_pc, wb_read_TID,
            wb_csr_re,wb_csr_we,wb_csr_num, wb_csr_wmask,wb_csr_wvalue, wb_ertn_flush,
            mem_excep_en, wb_excep_ADEF, wb_excep_SYSCALL, wb_excep_ALE, wb_excep_BRK, wb_excep_INE,wb_excep_INT, wb_excep_esubcode ,wb_vaddr} <= mem_to_wb_bus;
        end
    end

//模块间通信
    assign final_rf_wdata = wb_csr_re   ? csr_rvalue : 
                            wb_read_TID ? csr_rvalue : wb_rf_wdata;             //add csr_tid_rvalue for rdcntid.w
    assign wb_to_id_bus = {wb_rf_we & wb_valid & ~wb_ex & ~ertn_flush, wb_rf_waddr, final_rf_wdata};
    assign wb_csr_rvalue = csr_rvalue;
    //debug信号
    assign debug_wb_pc = wb_pc;
    assign debug_wb_rf_wdata = final_rf_wdata;
    assign debug_wb_rf_we = {4{wb_rf_we & wb_valid & ~wb_excep_en}};//注意，这里& wb_valid不能省略！必须保证wb流水级有指令才能进行trace比对
    assign debug_wb_rf_wnum = wb_rf_waddr;
//csr_file模块读写信号
    assign csr_re =     wb_csr_re | wb_ex;
    assign csr_num =    wb_ex ? 14'hc
                        : wb_csr_num;

    assign csr_we = wb_csr_we & wb_valid;
    assign csr_wmask = wb_csr_wmask;
    assign csr_wvalue = wb_csr_wvalue;
//清空流水线
    assign ertn_flush = wb_ertn_flush & wb_valid;
// 异常处理
    assign wb_excep_en = mem_excep_en;
    assign wb_ex =      wb_excep_en & wb_valid;
    assign wb_ecode =   wb_excep_INT     ? 6'h0 :       //INT 中断
                        wb_excep_ADEF    ? 6'h8 :       //ADEF
                        wb_excep_SYSCALL ? 6'hb :       //SYSCALL
                        wb_excep_BRK     ? 6'hc :       //BRK
                        wb_excep_INE     ? 6'hd :       //INE
                        6'h9;                           //ALE                           
    assign wb_esubcode= wb_excep_esubcode;
    assign wb_ex_pc =   wb_pc;

endmodule
module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
//cpu与指令存储器交互的接口
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
//cpu与数据存储器交互的接口
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
//debug信号
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

    wire id_allowin;
    wire ex_allowin;
    wire mem_allowin;
    wire wb_allowin;

    wire if_to_id_valid;
    wire id_to_ex_valid;
    wire ex_to_mem_valid;
    wire mem_to_wb_valid;

    wire [63:0]if_to_id_bus;
    wire [205:0]id_to_ex_bus;
    wire [123:0]ex_to_mem_bus;
    wire [117:0]mem_to_wb_bus;

    wire [32:0]id_to_if_bus;
    wire [38:0]ex_to_id_bus;
    wire [37:0]mem_to_id_bus;
    wire [37:0]wb_to_id_bus;

    wire            csr_re;
    wire [13:0]     csr_num;
    wire [31:0]     csr_rvalue;
    wire            csr_we;
    wire [31:0]     csr_wmask;
    wire [31:0]     csr_wvalue;

    wire            wb_ex;
    wire [5:0]      wb_ecode;
    wire [8:0]      wb_esubcode;
    wire [31:0]     wb_pc;
    wire [31:0]     wb_vaddr;

    wire            ertn_flush;
    wire [7:0]      hw_int_in;
    wire            ipi_int_in;
    IFreg my_ifReg(
        .clk(clk),
        .resetn(resetn),

        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata),
        
        .id_allowin(id_allowin),
        .id_to_if_bus(id_to_if_bus),
        .if_to_id_valid(if_to_id_valid),
        .if_to_id_bus(if_to_id_bus)
    );

    IDreg my_idReg(
        .clk(clk),
        .resetn(resetn),

        .if_to_id_valid(if_to_id_valid),
        .id_allowin(id_allowin),
        .id_to_if_bus(id_to_if_bus),
        .if_to_id_bus(if_to_id_bus),

        .ex_allowin(ex_allowin),
        .id_to_ex_valid(id_to_ex_valid),
        .id_to_ex_bus(id_to_ex_bus),

        .wb_to_id_bus(wb_to_id_bus),
        .mem_to_id_bus(mem_to_id_bus),
        .ex_to_id_bus(ex_to_id_bus)
    );

    EXEreg my_exeReg(
        .clk(clk),
        .resetn(resetn),
        
        .ex_allowin(ex_allowin),
        .id_to_ex_valid(id_to_ex_valid),
        .id_to_ex_bus(id_to_ex_bus),
        .ex_to_id_bus(ex_to_id_bus),

        .mem_allowin(mem_allowin),
        .ex_to_mem_valid(ex_to_mem_valid),
        .ex_to_mem_bus(ex_to_mem_bus),
        
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata)
    );

    MEMreg my_memReg(
        .clk(clk),
        .resetn(resetn),

        .mem_allowin(mem_allowin),
        .ex_to_mem_valid(ex_to_mem_valid),
        .ex_to_mem_bus(ex_to_mem_bus),

        .wb_allowin(wb_allowin),
        .mem_to_wb_valid(mem_to_wb_valid),
        .mem_to_wb_bus(mem_to_wb_bus),

        .mem_to_id_bus(mem_to_id_bus),

        .data_sram_rdata(data_sram_rdata)

    ) ;

    WBreg my_wbReg(
        .clk(clk),
        .resetn(resetn),

        .wb_allowin(wb_allowin),
        .mem_to_wb_valid(mem_to_wb_valid),
        .mem_to_wb_bus(mem_to_wb_bus),

        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata),

        .wb_to_id_bus(wb_to_id_bus),

        .csr_re(csr_re),
        .csr_num(csr_num),
        .csr_rvalue(csr_rvalue),
        .csr_we(csr_we),
        .csr_wmask(csr_wmask),
        .csr_wvalue(csr_wvalue)
    );

    CSRfile my_csrfild(
        .clk(clk),
        .resetn(resetn),

        .csr_re(csr_re),
        .csr_num(csr_num),
        .csr_rvalue(csr_rvalue),
        .csr_we(csr_we),
        .csr_wmask(csr_wmask),
        .csr_wvalue(csr_wvalue),

        .wb_ex(wb_ex),
        .wb_ecode(wb_ecode),
        .wb_esubcode(wb_esubcode),
        .wb_pc(wb_pc),
        .wb_vaddr(wb_vaddr),

        .ertn_flush(ertn_flush),

        .hw_int_in(),
        .ipi_int_in()

    );
endmodule
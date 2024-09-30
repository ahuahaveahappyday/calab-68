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
        .if_to_if_valid(if_to_id_valid),
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

        .wb_to_id_bus(wb_to_id_bus)
    );
endmodule
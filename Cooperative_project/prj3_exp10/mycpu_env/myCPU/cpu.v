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
//各个流水级是否允许指令进入
    wire        id_allowin;
    wire        ex_allowin;
    wire        mem_allowin;
    wire        wb_allowin;
//流水级到下一级的信号是否有效
    wire        if_to_id_valid;
    wire        id_to_ex_valid;
    wire        ex_to_mem_valid;
    wire        mem_to_wb_valid;
//各流水级的pc值
    wire [31:0] if_pc;
    wire [31:0] id_pc;
    wire [31:0] ex_pc;
    wire [31:0] mem_pc;
    wire [31:0] wb_pc;
//待删除
    wire [38:0] ex_rf_zip;
    wire [37:0] mem_rf_zip;
    wire [37:0] wb_rf_zip;

    wire [32:0] br_zip;
    wire [63:0] if_to_id_bus;
    wire [147:0] id_to_ex_bus;


    IFreg my_ifReg(
        .clk(clk),
        .resetn(resetn),

        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata),
        
        .ds_allowin(ds_allowin),
        .br_zip(br_zip),
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus)
    );

    IDreg my_idReg(
        .clk(clk),
        .resetn(resetn),

        .ds_allowin(ds_allowin),
        .br_zip(br_zip),
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),

        .es_allowin(es_allowin),
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),

        .ws_rf_zip(ws_rf_zip),
        .ms_rf_zip(ms_rf_zip),
        .es_rf_zip(es_rf_zip)
    );

    EXEreg my_exeReg(
        .clk(clk),
        .resetn(resetn),
        
        .es_allowin(es_allowin),
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),

        .ms_allowin(ms_allowin),
        .es_rf_zip(es_rf_zip),
        .es_to_ms_valid(es_to_ms_valid),
        .es_pc(es_pc),
        
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata)
    );

    MEMreg my_memReg(
        .clk(clk),
        .resetn(resetn),

        .ms_allowin(ms_allowin),
        .es_rf_zip(es_rf_zip),
        .es_to_ms_valid(es_to_ms_valid),
        .es_pc(es_pc),

        .ws_allowin(ws_allowin),
        .ms_rf_zip(ms_rf_zip),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_pc(ms_pc),

        .data_sram_rdata(data_sram_rdata)
    ) ;

    WBreg my_wbReg(
        .clk(clk),
        .resetn(resetn),

        .ws_allowin(ws_allowin),
        .ms_rf_zip(ms_rf_zip),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_pc(ms_pc),

        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata),

        .ws_rf_zip(ws_rf_zip)
    );
endmodule
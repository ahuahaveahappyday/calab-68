module WBreg(
    input  wire        clk,
    input  wire        resetn,
    //mem与wb模块交互接口
    output wire        wb_allowin,
    input  wire        mem_to_wb_valid,
    input  wire [69:0] mem_to_wb_bus, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata，mem_pc}
    //debug信号
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    //mem与id模块交互接口
    output wire [37:0] wb_to_id_bus  // {wb_rf_we, wb_rf_waddr, wb_rf_wdata}
);
    
    wire        wb_ready_go;

//MEM模块需要的寄存器
    reg         wb_valid;
    reg  [31:0] wb_pc;
    reg  [31:0] wb_rf_wdata;
    reg  [4 :0] wb_rf_waddr;
    reg         wb_rf_we;

//流水线控制信号
    assign wb_ready_go      = 1'b1;
    assign wb_allowin       = ~wb_valid | wb_ready_go ;     

//WB流水级需要的寄存器，根据clk不断更新
    always @(posedge clk) begin
        if(~resetn)
            wb_valid <= 1'b0;
        else if(wb_allowin)
            wb_valid <= mem_to_wb_valid; 
    end
    always @(posedge clk) begin
        if(~resetn) begin
            {wb_rf_we, wb_rf_waddr, wb_rf_wdata,wb_pc} <= 69'b0;
        end
        if(mem_to_wb_valid & wb_allowin) begin
            {wb_rf_we, wb_rf_waddr, wb_rf_wdata,wb_pc} <= mem_to_wb_bus;
        end
    end

//模块间通信
    assign wb_to_id_bus = {wb_rf_we & wb_valid, wb_rf_waddr, wb_rf_wdata};

    //debug信号
    assign debug_wb_pc = wb_pc;
    assign debug_wb_rf_wdata = wb_rf_wdata;
    assign debug_wb_rf_we = {4{wb_rf_we & wb_valid}};//注意，这里& wb_valid不能省略！必须保证wb流水级有指令才能进行trace比对
    assign debug_wb_rf_wnum = wb_rf_waddr;
endmodule
module MEMreg(
    input  wire        clk,
    input  wire        resetn,

    output wire        mem_allowin,
    input  wire [38:0] ex_rf_zip, 
    input  wire        ex_to_mem_valid,
    input  wire [31:0] ex_pc,    

    input  wire        wb_allowin,
    output wire [37:0] mem_rf_zip, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata}
    output wire        mem_to_wb_valid,
    output reg  [31:0] mem_pc,

    input  wire [31:0] data_sram_rdata    
);
    wire        mem_ready_go;
    reg         mem_valid;
    reg  [31:0] mem_alu_result ; 
    reg         mem_res_from_mem;
    reg         mem_rf_we      ;
    reg  [4 :0] mem_rf_waddr   ;
    wire [31:0] mem_rf_wdata   ;
    wire [31:0] mem_mem_result ;



    assign mem_ready_go      = 1'b1;
    assign mem_allowin       = ~mem_valid | mem_ready_go & wb_allowin;     
    assign mem_to_wb_valid      = mem_valid & mem_ready_go;
    always @(posedge clk) begin
        if(~resetn)
            mem_valid <= 1'b0;
        else
            mem_valid <= ex_to_mem_valid & mem_allowin; 
    end


    always @(posedge clk) begin
        if(~resetn) begin
            mem_pc <= 32'b0;
            {mem_res_from_mem, mem_rf_we, mem_rf_waddr, mem_alu_result} <= 38'b0;
        end
        if(ex_to_mem_valid & mem_allowin) begin
            mem_pc <= ex_pc;
            {mem_res_from_mem, mem_rf_we, mem_rf_waddr, mem_alu_result} <= ex_rf_zip;
        end
    end

    assign mem_mem_result = data_sram_rdata;
    assign mem_rf_wdata = mem_res_from_mem ? mem_mem_result : mem_alu_result;
    assign mem_rf_zip  = {mem_rf_we & mem_valid, mem_rf_waddr, mem_rf_wdata};

endmodule
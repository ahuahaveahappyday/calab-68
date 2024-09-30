module WBreg(
    input  wire        clk,
    input  wire        resetn,

    output wire        wb_allowin,
    input  wire [37:0] mem_rf_zip, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata}
    input  wire        mem_to_wb_valid,
    input  wire [31:0] mem_pc,    

    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,


    output wire [37:0] wb_rf_zip  // {wb_rf_we, wb_rf_waddr, wb_rf_wdata}
);
    
    wire        wb_ready_go;
    reg         wb_valid;
    reg  [31:0] wb_pc;
    reg  [31:0] wb_rf_wdata;
    reg  [4 :0] wb_rf_waddr;
    reg         wb_rf_we;



    assign wb_ready_go      = 1'b1;
    assign wb_allowin       = ~wb_valid | wb_ready_go ;     
    always @(posedge clk) begin
        if(~resetn)
            wb_valid <= 1'b0;
        else if(wb_allowin)
            wb_valid <= mem_to_wb_valid; 
    end


    always @(posedge clk) begin
        if(~resetn) begin
            wb_pc <= 32'b0;
            {wb_rf_we, wb_rf_waddr, wb_rf_wdata} <= 38'b0;
        end
        if(mem_to_wb_valid & wb_allowin) begin
            wb_pc <= mem_pc;
            {wb_rf_we, wb_rf_waddr, wb_rf_wdata} <= mem_rf_zip;
        end
    end


    assign wb_rf_zip = {wb_rf_we & wb_valid, wb_rf_waddr, wb_rf_wdata};


    assign debug_wb_pc = wb_pc;
    assign debug_wb_rf_wdata = wb_rf_wdata;
    assign debug_wb_rf_we = {4{wb_rf_we & wb_valid}};
    assign debug_wb_rf_wnum = wb_rf_waddr;
endmodule
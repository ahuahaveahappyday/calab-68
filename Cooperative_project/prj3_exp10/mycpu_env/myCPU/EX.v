module EXEreg(
    input  wire        clk,
    input  wire        resetn,

    input  wire        es_allowin,
    output wire        ds_to_es_valid,
    output wire [148 -1:0] ds_to_es_bus,
 

    input  wire        ms_allowin,
    output wire [38:0] es_rf_zip, // {es_res_from_mem, es_rf_we, es_rf_waddr, es_alu_result}
    output wire        es_to_ms_valid,
    output reg  [31:0] es_pc,    
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata
);

    wire        es_ready_go;
    reg         es_valid;

    reg  [11:0] es_alu_op     ;
    reg  [31:0] es_alu_src1   ;
    reg  [31:0] es_alu_src2   ;
    wire [31:0] es_alu_result ; 
    reg  [31:0] es_rkd_value  ;
    reg         es_res_from_mem;
    reg         es_mem_we     ;
    reg         es_rf_we      ;
    reg  [4 :0] es_rf_waddr   ;
    wire [31:0] es_mem_result ;




    assign es_ready_go      = 1'b1;
    assign es_allowin       = ~es_valid | es_ready_go & ms_allowin;     
    assign es_to_ms_valid  = es_valid & es_ready_go;
    always @(posedge clk) begin
        if(~resetn)
            es_valid <= 1'b0;
        else if(es_allowin)
            es_valid <= ds_to_es_valid; 
    end



    always @(posedge clk) begin
        if(~resetn)
            {es_alu_op, es_res_from_mem, es_alu_src1, es_alu_src2,
             es_mem_we, es_rf_we, es_rf_waddr, es_rkd_value, es_pc} <= {148{1'b0}};
        else if(ds_to_es_valid & es_allowin)
            {es_alu_op, es_res_from_mem, es_alu_src1, es_alu_src2,
             es_mem_we, es_rf_we, es_rf_waddr, es_rkd_value, es_pc} <= ds_to_es_bus;    
    end




    alu u_alu(
        .alu_op     (es_alu_op    ),
        .alu_src1   (es_alu_src1  ),
        .alu_src2   (es_alu_src2  ),
        .alu_result (es_alu_result)
    );


    assign data_sram_en     = (es_res_from_mem || es_mem_we) && es_valid;
    assign data_sram_we     = {4{es_mem_we & es_valid}};
    assign data_sram_addr   = es_alu_result;
    assign data_sram_wdata  = es_rkd_value;


    assign es_rf_zip       = {es_res_from_mem & es_valid, es_rf_we & es_valid, es_rf_waddr, es_alu_result};    

endmodule
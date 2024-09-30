module EXEreg(
    input  wire        clk,
    input  wire        resetn,

    input  wire        ex_allowin,
    output wire        id_to_ex_valid,
    output wire [147:0]id_to_ex_bus,
 

    input  wire        mem_allowin,
    output wire [38:0] ex_rf_zip, // {es_res_from_mem, es_rf_we, es_rf_waddr, es_alu_result}
    output wire        ex_to_mem_valid,
    output reg  [31:0] ex_pc,    
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata
);

    wire        ex_ready_go;
    reg         ex_valid;

    reg  [11:0] ex_alu_op     ;
    reg  [31:0] ex_alu_src1   ;
    reg  [31:0] ex_alu_src2   ;
    wire [31:0] ex_alu_result ; 
    reg  [31:0] ex_rkd_value  ;
    reg         ex_res_from_mem;
    reg         ex_mem_we     ;
    reg         ex_rf_we      ;
    reg  [4 :0] ex_rf_waddr   ;
    wire [31:0] ex_mem_result ;




    assign ex_ready_go      = 1'b1;
    assign ex_allowin       = ~ex_valid | ex_ready_go & mem_allowin;     
    assign ex_to_mem_valid  = ex_valid & ex_ready_go;
    always @(posedge clk) begin
        if(~resetn)
            ex_valid <= 1'b0;
        else if(es_allowin)
            ex_valid <= id_to_ex_valid; 
    end



    always @(posedge clk) begin
        if(~resetn)
            {ex_alu_op, ex_res_from_mem, ex_alu_src1, ex_alu_src2,
             ex_mem_we, ex_rf_we, ex_rf_waddr, ex_rkd_value, ex_pc} <= {148{1'b0}};
        else if(id_to_es_valid & ex_allowin)
            {ex_alu_op, ex_res_from_mem, ex_alu_src1, ex_alu_src2,
             ex_mem_we, ex_rf_we, ex_rf_waddr, ex_rkd_value, ex_pc} <= id_to_ex_bus;    
    end




    alu u_alu(
        .alu_op     (ex_alu_op    ),
        .alu_src1   (ex_alu_src1  ),
        .alu_src2   (ex_alu_src2  ),
        .alu_result (ex_alu_result)
    );


    assign data_sram_en     = (ex_res_from_mem || ex_mem_we) && ex_valid;
    assign data_sram_we     = {4{ex_mem_we & ex_valid}};
    assign data_sram_addr   = ex_alu_result;
    assign data_sram_wdata  = ex_rkd_value;


    assign ex_rf_zip       = {ex_res_from_mem & ex_valid, ex_rf_we & ex_valid, ex_rf_waddr, ex_alu_result};    

endmodule
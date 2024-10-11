`define CSR_CRMD 0




module csrfile(
    input  wire        clk,
    input  wire        reset,
    // inst access-------------------------
    // read port
    input wire          csr_re,         // read_enable
    input wire  [4:0]   csr_num,        // num of csr, address
    output wire [31:0]  csr_rvalue,
    // write port
    input wire          csr_we,
    input wire  [31:0]  csr_wmask,
    input wire  [31:0]  csr_wvalue,

    // hardware access------------------------
    // exception from wb
    input wire          wb_ex,
    input wire          wb_ecode,
    input wire          wb_esubcode,
    // inst (ertn) from wb
    input wire          ertn_flush
    //TODO

);
reg [1:0]   csr_crmd_plv;

reg [1:0]   csr_prmd_pplv;







/*---------------------------CSMD---------------------------------------------------*/
// PLV
always @(posedge clk)begin
    if(reset)
        csr_crmd_plv <=     2'b0;
    else if (wb_ex)             // exception 
        csr_crmd_plv <=     2'b0;
    else if(ertn_flush)           // restore to pplv
        csr_crmd_plv <=     csr_prmd_pplv;
    else if(csr_we && csr_num == `CSR_CRMD)     // inst access
        csr_crmd_plv <=     csr_wmask & csr_wvalue
                            | ~csr_wmask & csr_wvalue;
end












//TODO

endmodule

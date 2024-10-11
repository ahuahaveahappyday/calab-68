`define CSR_CRMD            0
`define CSR_CRMD_PLV        1:0
`define CSR_CRMD_PIE        2
`define CSR_CRMD_DA         3
`define CSR_CRMD_PG         4
`define CSR_CRMD_DATF       6:5
`define CSR_CRMD_DATM       8:7

`define CSR_PRMD            1
`define CSR_PRMD_PPLV       1:0
`define CSR_PRMD_PIE       1:0

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
reg         csr_crmd_ie;
wire        csr_crmd_da;
wire        csr_crmd_pg;
wire        csr_crmd_datf;
wire        csr_crmd_datm;

reg [1:0]   csr_prmd_pplv;
reg         csr_prmd_pie;






/*---------------------------CRMD---------------------------------------------------*/
// PLV
always @(posedge clk)begin
    if(reset)
        csr_crmd_plv <=     2'b0;
    else if (wb_ex)             // enter exception 
        csr_crmd_plv <=     2'b0;
    else if(ertn_flush)           // return from exception
        csr_crmd_plv <=     csr_prmd_pplv;
    else if(csr_we && csr_num == `CSR_CRMD)     // inst access
        csr_crmd_plv <=     csr_wmask[`CSR_CRMD_PLV] & csr_wvalue[`CSR_CRMD_PLV]
                            | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
end

// IE
always @(posedge clk)begin
    if(reset)
        csr_crmd_ie <=      1'b0;
    else if(wb_ex)          // enter exception
        csr_crmd_ie <=      1'b0;
    else if(ertn_flush)     // return from exception
        csr_crmd_ie <=      csr_prmd_pie;
    else if(csr_we && csr_num == `CSR_CRMD)     // inst access
        csr_crmd_ie <=      csr_wmask[`CSR_CRMD_PIE] & csr_wvalue[`CSR_CRMD_PIE]
                            | ~csr_wmask[`CSR_CRMD_PIE] & csr_crmd_ie;
end

// DA, PG, DATF, DATM
assign csr_crmd_da  =   1'b1;
assign csr_crmd_pg  =   1'b0;
assign csr_crmd_datf  = 2'b00;
assign csr_crmd_datm  = 2'b00;

/*---------------------------PRMD---------------------------------------------------*/
always @(posedge clk)begin
    if (wb_ex) begin             // enter exception 
        csr_prmd_pplv <=     csr_crmd_plv;
        csr_prmd_pie  <=     csr_crmd_ie;
    end
    else if(csr_we && csr_num == `CSR_CRMD)     // inst access
        csr_prmd_pplv <=     csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                            | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
        csr_prmd_pie  <=     csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE]
                            | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;  
end





//TODO

endmodule

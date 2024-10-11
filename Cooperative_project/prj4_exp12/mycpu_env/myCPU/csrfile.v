// CSR_NUM
`define CSR_CRMD            9'h0
`define CSR_PRMD            9'h1
`define CSR_ECFG            9'h4
`define CSR_ESTAT           9'h5
`define CSR_ERA             9'h6
`define CSR_BADV            9'h7
`define CSR_EENTRY          9'h12
`define CSR_SAVE0           9'h30
`define CSR_SAVE1           9'h31
`define CSR_SAVE2           9'h32
`define CSR_SAVE3           9'h33
`define CSR_TICLR           9'h44
// INDEX OF DOMAIN
`define CSR_CRMD_PLV        1:0
`define CSR_CRMD_PIE        2
`define CSR_CRMD_DA         3
`define CSR_CRMD_PG         4
`define CSR_CRMD_DATF       6:5
`define CSR_CRMD_DATM       8:7

`define CSR_PRMD_PPLV       1:0
`define CSR_PRMD_PIE       1:0

`define CSR_ECFG_LIE        12:0

`define CSR_ESTAT_IS10      1:0

`define CSR_ERA_PC          31:0

`define CSR_EENTRY_VA       31:6
`define CSR_SAVE_DATA       31:0
`define CSR_TICLR_CLR       0
// ECODE

`define ECODE_ADE           5'h8
`define ECODE_ALE           5'h9    


// ESUBCODE
`define ESUBCODE_ADEF       1
module csrfile(
    input  wire        clk,
    input  wire        reset,
    // inst access-------------------------
    // read port
    input wire          csr_re,         // read_enable
    input wire  [8:0]  csr_num,        // num of csr, address
    output wire [31:0]  csr_rvalue,
    // write port
    input wire          csr_we,
    input wire  [31:0]  csr_wmask,
    input wire  [31:0]  csr_wvalue,

    // hardware access------------------------
    // exception from wb
    input wire          wb_ex,
    input wire  [5:0]   wb_ecode,
    input wire  [8:0]   wb_esubcode,
    input wire  [31:0]  wb_pc,
    input wire  [31:0]  wb_vaddr,
    // inst (ertn) from wb
    input wire          ertn_flush,
    // Sampling each interrupt source each clk
    input wire [7:0]    hw_int_in,
    input wire          ipi_int_in      // Internuclear interrupt
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

reg [12:0]   csr_ecfg_lie;     

reg [12:0]   csr_estat_is;

reg          csr_tcfg_en;

reg  [5:0]     csr_estat_ecode;
reg  [8:0]     csr_estat_esubcode;

reg  [31:0]     csr_era_pc;

reg  [31:0]     csr_badv_vaddr;

reg [25:0]      csr_eentry_va;

reg [31:0]      csr_save0_data;
reg [31:0]      csr_save1_data;
reg [31:0]      csr_save2_data;
reg [31:0]      csr_save3_data;

reg  [31:0]  time_cnt;
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


/*---------------------------ECFG---------------------------------------------------*/
always @(posedge clk)begin
    if(reset)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_num == `CSR_ECFG)            // csr_ecfg_lie[10] == 0 
        csr_ecfg_lie <=     csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_wvalue[`CSR_ECFG_LIE]
                            | ~csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_ecfg_lie;
end

/*---------------------------ESTAT---------------------------------------------------*/
// is
always @(posedge clk)begin
    if(reset)
        csr_estat_is[1:0] <= 2'b0;
    else if(csr_we && csr_num == `CSR_ESTAT)
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]  & csr_wvalue[`CSR_ESTAT_IS10]
                            | ~csr_wmask[`CSR_ESTAT_IS10]  & csr_estat_is[1:0];

    csr_estat_is[9:2]   <= hw_int_in[7:0];          // come from hardware sampling
    csr_estat_is[10]    <= 1'b0;                    // reserved

    if(time_cnt[31:0] == 32'b0)                     // time counter interrupt
        csr_estat_is[11] <= 1'b1;
    else if(csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])
        csr_estat_is[11] <= 1'b0;

    csr_estat_is[12]    <= ipi_int_in;   

end

// ecode and esubcode
always @(posedge clk)begin
    if(wb_ex)   begin
        csr_estat_ecode    <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

/*---------------------------ERA---------------------------------------------------*/
always @(posedge clk)begin
    if(wb_ex)
        csr_era_pc <=       wb_pc;
    else if(csr_we && csr_num == `CSR_ERA)
        csr_era_pc <=       csr_wmask[`CSR_ERA_PC]  & csr_wvalue[`CSR_ERA_PC]
                            | ~csr_wmask[`CSR_ERA_PC]  & csr_era_pc;
end


/*---------------------------BADV---------------------------------------------------*/
wire wb_ex_addr_err = wb_ecode == `ECODE_ADE || wb_ecode == `ECODE_ALE;
always @(posedge clk)begin
    if(wb_ex && wb_ex_addr_err)
        csr_badv_vaddr <=       (wb_ecode == `ECODE_ADE && wb_esubcode == `ESUBCODE_ADEF) ?
                                wb_pc           //  inst fecth error
                                :wb_vaddr;      // mem access error and so on
end

/*---------------------------EENTRY---------------------------------------------------*/
always @(posedge clk)begin          // entry addr of all exception except tlb refill
    if(csr_we && csr_num == `CSR_EENTRY)
        csr_eentry_va <=    csr_wmask[`CSR_EENTRY_VA]  & csr_wvalue[`CSR_EENTRY_VA]
                            | ~csr_wmask[`CSR_EENTRY_VA]  & csr_eentry_va;
end

/*---------------------------SAVE0-3---------------------------------------------------*/
always @(posedge clk)begin
    if(csr_we && csr_num == `CSR_SAVE0)
        csr_save0_data <=    csr_wmask[`CSR_SAVE_DATA]  & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA]  & csr_save0_data;
    if(csr_we && csr_num == `CSR_SAVE1)
        csr_save1_data <=    csr_wmask[`CSR_SAVE_DATA]  & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA]  & csr_save1_data;
    if(csr_we && csr_num == `CSR_SAVE2)
        csr_save2_data <=    csr_wmask[`CSR_SAVE_DATA]  & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA]  & csr_save2_data;
    if(csr_we && csr_num == `CSR_SAVE3)
        csr_save3_data <=    csr_wmask[`CSR_SAVE_DATA]  & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA]  & csr_save3_data;
end




//TODO

endmodule

// CSR_NUM
`define CSR_CRMD 14'h0
`define CSR_PRMD 14'h1
`define CSR_ECFG 14'h4
`define CSR_ESTAT 14'h5
`define CSR_ERA 14'h6
`define CSR_BADV 14'h7
`define CSR_EENTRY 14'hc
`define CSR_TLBIDX 14'h10
`define CSR_TLBEHI 14'h11
`define CSR_TLBLO0 14'h12
`define CSR_TLBLO1 14'h13
`define CSR_ASID 14'h18
`define CSR_SAVE0 14'h30
`define CSR_SAVE1 14'h31
`define CSR_SAVE2 14'h32
`define CSR_SAVE3 14'h33
`define CSR_TID 14'h40     
`define CSR_TCFG 14'h41     
`define CSR_TVAL 14'h42     
`define CSR_TICLR 14'h44
`define CSR_TLBRENTRY 14'h88
// INDEX OF DOMAIN
`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_PIE 2
`define CSR_CRMD_DA 3
`define CSR_CRMD_PG 4
`define CSR_CRMD_DATF 6:5
`define CSR_CRMD_DATM 8:7
`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE 1:0
`define CSR_ECFG_LIE 12:0
`define CSR_ESTAT_IS10 1:0
`define CSR_ERA_PC 31:0
`define CSR_EENTRY_VA 31:6
`define CSR_SAVE_DATA 31:0
`define CSR_TID_TID 31:0
`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV 31:2
`define CSR_TICLR_CLR 0
// ECODE
`define ECODE_ADE 5'h8
`define ECODE_ALE 5'h9    
// ESUBCODE
`define ESUBCODE_ADEF 0
module CSRfile #(
    parameter TLBNUM = 16
) (
    input  wire        clk,
    input  wire        resetn,
    // inst access-------------------------
    // read port
    input  wire        csr_re,      // read_enable
    input  wire [13:0] csr_num,     // num of csr, address
    output wire [31:0] csr_rvalue,
    // write port
    input  wire        csr_we,
    input  wire [31:0] csr_wmask,
    input  wire [31:0] csr_wvalue,

    // hardware access------------------------
    // exception from wb
    input  wire                      wb_ex,
    input  wire [               5:0] wb_ecode,
    input  wire [               8:0] wb_esubcode,
    input  wire [              31:0] wb_pc,
    input  wire [              31:0] wb_vaddr,
    // inst (ertn) from wb
    input  wire                      ertn_flush,
    // Sampling each interrupt source each clk
    input  wire [               7:0] hw_int_in,
    input  wire                      ipi_int_in,     // Internuclear interrupt
    output wire                      has_int,
    // TLBSRCH
    input  wire                      tlbsrch_en,
    input  wire                      tlbsrch_found,
    input  wire [$clog2(TLBNUM)-1:0] tlbsrch_idx,
    // TLBRD
    output wire [$clog2(TLBNUM)-1:0] tlbrd_idx,
    input  wire                      tlbrd_en,
    input  wire                      tlbrd_valid,
    input  wire [               5:0] tlbrd_ps,
    input  wire [              18:0] tlbrd_vppn,
    input  wire                      tlbrd_g,
    input  wire [               9:0] tlbrd_asid,
    input  wire                      tlbrd_v0,
    input  wire                      tlbrd_d0,
    input  wire [               1:0] tlbrd_mat0,
    input  wire [               1:0] tlbrd_plv0,
    input  wire [              19:0] tlbrd_ppn0,
    input  wire                      tlbrd_v1,
    input  wire                      tlbrd_d1,
    input  wire [               1:0] tlbrd_mat1,
    input  wire [               1:0] tlbrd_plv1,
    input  wire [              19:0] tlbrd_ppn1,
    // TLBWR
    output wire                      tlbwr_ne,
    output wire                      tlbwr_index,
    output wire [               5:0] tlbwr_ps,
    output wire [              18:0] tlbwr_vppn,
    output wire                      tlbwr_g,
    output wire [               9:0] tlbwr_asid,
    output wire                      tlbwr_v0,
    output wire                      tlbwr_d0,
    output wire [               1:0] tlbwr_mat0,
    output wire [               1:0] tlbwr_plv0,
    output wire [              19:0] tlbwr_ppn0,
    output wire                      tlbwr_v1,
    output wire                      tlbwr_d1,
    output wire [               1:0] tlbwr_mat1,
    output wire [               1:0] tlbwr_plv1,
    output wire [              19:0] tlbwr_ppn1
);
    reg  [               1:0] csr_crmd_plv;
    reg                       csr_crmd_ie;
    wire                      csr_crmd_da;
    wire                      csr_crmd_pg;
    wire                      csr_crmd_datf;
    wire                      csr_crmd_datm;

    reg  [               1:0] csr_prmd_pplv;
    reg                       csr_prmd_pie;

    reg  [              12:0] csr_ecfg_lie;

    reg  [              12:0] csr_estat_is;

    reg  [               5:0] csr_estat_ecode;
    reg  [               8:0] csr_estat_esubcode;

    reg  [              31:0] csr_era_pc;

    reg  [              31:0] csr_badv_vaddr;

    reg  [              25:0] csr_eentry_va;

    reg  [              31:0] csr_save0_data;
    reg  [              31:0] csr_save1_data;
    reg  [              31:0] csr_save2_data;
    reg  [              31:0] csr_save3_data;

    reg  [              31:0] csr_tid_tid;

    reg                       csr_tcfg_en;
    reg                       csr_tcfg_periodic;
    reg  [              29:0] csr_tcfg_initval;

    wire [              31:0] tcfg_next_value;
    wire [              31:0] csr_tval;

    wire                      csr_ticlr_clr;

    reg  [              31:0] timer_cnt;

    reg  [$clog2(TLBNUM)-1:0] csr_tlbidx_index;
    reg  [               5:0] csr_tlbidx_ps;
    reg                       csr_tlbidx_ne;

    reg  [             18:0] csr_tlbehi_vppn;

    reg                      csr_tlbelo0_v;
    reg                      csr_tlbelo0_d;
    reg  [              1:0] csr_tlbelo0_plv;
    reg  [              1:0] csr_tlbelo0_mat;
    reg                      csr_tlbelo0_g;
    reg  [             19:0] csr_tlbelo0_ppn;

    reg                      csr_tlbelo1_v;
    reg                      csr_tlbelo1_d;
    reg  [              1:0] csr_tlbelo1_plv;
    reg  [              1:0] csr_tlbelo1_mat;
    reg                      csr_tlbelo1_g;
    reg  [             19:0] csr_tlbelo1_ppn;

    reg  [              9:0] csr_asid_asid;
    wire [              5:0] csr_asid_asidbits;

    //实现中断处理
    assign has_int = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && (csr_crmd_ie == 1'b1);

    /*---------------------------CRMD---------------------------------------------------*/
    // PLV
    always @(posedge clk)begin
        if(~resetn)
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
        if(~resetn)
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
        else if(csr_we && csr_num == `CSR_PRMD)  begin   // inst access
            csr_prmd_pplv <=     csr_wmask[`CSR_PRMD_PPLV] & csr_wvalue[`CSR_PRMD_PPLV]
                                | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
            csr_prmd_pie  <=     csr_wmask[`CSR_PRMD_PIE] & csr_wvalue[`CSR_PRMD_PIE]
                                | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie; 
        end 
    end


    /*---------------------------ECFG---------------------------------------------------*/
    always @(posedge clk)begin
        if(~resetn)
            csr_ecfg_lie <= 13'b0;
        else if (csr_we && csr_num == `CSR_ECFG)            // csr_ecfg_lie[10] == 0 
            csr_ecfg_lie <=     csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_wvalue[`CSR_ECFG_LIE]
                                | ~csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_ecfg_lie;
    end

    /*---------------------------ESTAT---------------------------------------------------*/
    // is
    always @(posedge clk)begin
        if(~resetn)
            csr_estat_is[1:0] <= 2'b0;
        else if(csr_we && csr_num == `CSR_ESTAT)
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]  & csr_wvalue[`CSR_ESTAT_IS10]
                                | ~csr_wmask[`CSR_ESTAT_IS10]  & csr_estat_is[1:0];

        csr_estat_is[9:2]   <= hw_int_in[7:0];          // come from hardware sampling
        csr_estat_is[10]    <= 1'b0;                    // reserved

        if(timer_cnt[31:0] == 32'b0)                     // time counter interrupt
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

    /*---------------------------TID-------------------------------------------------------*/           //add TID
    always @(posedge clk)begin
        if(~resetn)
            csr_tid_tid <= 32'b0;
        else if(csr_we && csr_num == `CSR_TID)
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                            | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
    end

    /*---------------------------TCFG------------------------------------------------------*/           //add TCFG
    always @(posedge clk)begin
        if(~resetn)
            csr_tcfg_en <= 1'b0;
        else if(csr_we && csr_num==`CSR_TCFG)
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN]
                            | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;

        if(csr_we && csr_num==`CSR_TCFG)begin
            csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wvalue[`CSR_TCFG_PERIOD]
                                | ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
            csr_tcfg_initval  <= csr_wmask[`CSR_TCFG_INITV] & csr_wvalue[`CSR_TCFG_INITV]
                                | ~csr_wmask[`CSR_TCFG_INITV] & csr_tcfg_initval;
        end
    end

    /*---------------------------TVAL------------------------------------------------------*/           //add TVAL
    assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0]
                            | ~csr_wmask[31:0] & {csr_tcfg_initval,csr_tcfg_periodic,csr_tcfg_en};      //value of TCFG in the next clk

    always @(posedge clk)begin
        if(~resetn)
            timer_cnt <= 32'hffffffff;
        else if(csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV],2'b0};
        else if(csr_tcfg_en && timer_cnt!=32'hffffffff) begin
            if(timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
                timer_cnt <= {csr_tcfg_initval,2'b0};
            else
                timer_cnt <= timer_cnt -1'b1;
        end
    end

    assign csr_tval = timer_cnt[31:0];

    /*---------------------------TICLR------------------------------------------------------*/  //add TICLR
    assign csr_ticlr_clr = 1'b0;

    /*------------------------------TLBIDX-------------------------------------------------*/
    always @(posedge clk) begin
        if (~resetn) 
            csr_tlbidx_index <= {($clog2(TLBNUM)) {1'b0}};
        else if (tlbsrch_en & tlbsrch_found) 
            csr_tlbidx_index <= tlbsrch_idx;
    end

    always @(posedge clk)begin
        if(~resetn)
            csr_tlbidx_ps <= 6'b0;
        else if(tlbrd_en)
            csr_tlbidx_ps <= {6{tlbrd_valid}} & tlbrd_ps;
    end

    always @(posedge clk) begin
        if(~resetn)
            csr_tlbidx_ne <= 1'b0;
        else if(tlbsrch_en)    // not found
            csr_tlbidx_ne <= ~tlbsrch_found;
        else if(tlbrd_en)
            csr_tlbidx_ne <= ~tlbrd_valid;
    end

    assign tlbrd_idx = csr_tlbidx_index;

/*--------------------------------TLBEHI------------------------------------------------------------*/
    always @(posedge clk)begin
        if(~resetn)
            csr_tlbehi_vppn <= 19'b0;
        else if(tlbrd_en)
            csr_tlbehi_vppn <= {19{tlbrd_valid}} & tlbrd_vppn;
    end
/*--------------------------------TLBELO--------------------------------------------------------*/
    always @(posedge clk)begin
        if(~resetn)begin
            {csr_tlbelo0_v,csr_tlbelo0_d,csr_tlbelo0_plv,csr_tlbelo0_mat,csr_tlbelo0_g,csr_tlbelo0_ppn} 
                <= 27'b0;
        end
        else if(tlbrd_en)begin
            {csr_tlbelo0_v,csr_tlbelo0_d,csr_tlbelo0_plv,csr_tlbelo0_mat,csr_tlbelo0_g,csr_tlbelo0_ppn} 
                <= {27{tlbrd_valid}} & {tlbrd_v0,tlbrd_d0,tlbrd_plv0,tlbrd_mat0,tlbrd_g,tlbrd_ppn0}; 
        end
    end

    always @(posedge clk) begin
        if(~resetn)begin
            {csr_tlbelo1_v,csr_tlbelo1_d,csr_tlbelo1_plv,csr_tlbelo1_mat,csr_tlbelo1_g,csr_tlbelo1_ppn} 
                <= 27'b0;
        end
        else if(tlbrd_en)begin
            {csr_tlbelo1_v,csr_tlbelo1_d,csr_tlbelo1_plv,csr_tlbelo1_mat,csr_tlbelo1_g,csr_tlbelo1_ppn} 
                <= {27{tlbrd_valid}} & {tlbrd_v1,tlbrd_d1,tlbrd_plv1,tlbrd_mat1,tlbrd_g,tlbrd_ppn1}; 
        end
    end
/*-------------------------------------ASI0-----------------------------------------------*/
    always @(posedge clk) begin
        if(~resetn)
            csr_asid_asid <= 10'b0;
        else if(tlbrd_en)
            csr_asid_asid <= {10{tlbrd_valid}} & tlbrd_asid;
    end

    assign csr_asid_asidbits = 6'h0a;   // 10 bit asid


    // tlbwr output
    assign tlbwr_ne = csr_tlbidx_ne;
    assign tlbwr_index = csr_tlbidx_index;





    // read csr value---------------------------------
    wire [31:0] csr_crmd_rvalue;
    wire [31:0] csr_prmd_rvalue;
    wire [31:0] csr_estat_rvalue;
    wire [31:0] csr_era_rvalue;
    wire [31:0] csr_eentry_rvalue;
    wire [31:0] csr_save0_rvalue;
    wire [31:0] csr_save1_rvalue;
    wire [31:0] csr_save2_rvalue;
    wire [31:0] csr_save3_rvalue;
    wire [31:0] csr_ecfg_rvalue;
    wire [31:0] csr_badv_rvalue;
    wire [31:0] csr_tid_rvalue;
    wire [31:0] csr_tcfg_rvalue;
    wire [31:0] csr_tval_rvalue;
    wire [31:0] csr_ticlr_rvalue;

    assign csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    assign csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    assign csr_estat_rvalue = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    assign csr_era_rvalue = csr_era_pc;
    assign csr_eentry_rvalue = {csr_eentry_va, 6'b0};
    assign csr_save0_rvalue = csr_save0_data;
    assign csr_save1_rvalue = csr_save1_data;
    assign csr_save2_rvalue = csr_save2_data;
    assign csr_save3_rvalue = csr_save3_data;
    assign csr_ecfg_rvalue = {19'b0, csr_ecfg_lie};
    assign csr_badv_rvalue = csr_badv_vaddr;
    assign csr_tid_rvalue = csr_tid_tid;
    assign csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    assign csr_tval_rvalue = csr_tval;
    assign csr_ticlr_rvalue = {31'b0, csr_ticlr_clr};


    // assign excep_entry = wb_ex ? csr_eentry_rvalue     //PC在flush时候取指的地址
    //                   /*ertn_flush*/:csr_era_pc;

    assign csr_rvalue =      {32{csr_num == `CSR_CRMD}} & csr_crmd_rvalue
                            |{32{csr_num == `CSR_PRMD}} & csr_prmd_rvalue
                            |{32{csr_num == `CSR_ESTAT}} & csr_estat_rvalue
                            |{32{csr_num == `CSR_ERA}} & csr_era_rvalue
                            |{32{csr_num == `CSR_EENTRY}} & csr_eentry_rvalue
                            |{32{csr_num == `CSR_SAVE0}} & csr_save0_rvalue
                            |{32{csr_num == `CSR_SAVE1}} & csr_save1_rvalue
                            |{32{csr_num == `CSR_SAVE2}} & csr_save2_rvalue
                            |{32{csr_num == `CSR_SAVE3}} & csr_save3_rvalue
                            |{32{csr_num == `CSR_ECFG}}  & csr_ecfg_rvalue
                            |{32{csr_num == `CSR_BADV}}  & csr_badv_rvalue
                            |{32{csr_num == `CSR_TID}}   & csr_tid_rvalue
                            |{32{csr_num == `CSR_TCFG}}  & csr_tcfg_rvalue
                            |{32{csr_num == `CSR_TVAL}}  & csr_tval_rvalue
                            |{32{csr_num == `CSR_TICLR}} & csr_ticlr_rvalue;

endmodule

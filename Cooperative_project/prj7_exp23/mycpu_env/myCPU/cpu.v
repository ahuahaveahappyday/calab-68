module mycpu_top
#(
    parameter TLBNUM = 16
)
(
    input  wire                 aclk,
    input  wire                 aresetn,
    // read request
    output wire  [3:0]          arid,
    output wire  [31:0]         araddr,
    output wire  [7:0]          arlen,
    output wire  [2:0]          arsize,
    output wire  [1:0]          arburst,
    output wire  [1:0]          arlock,
    output wire  [3:0]          arcache,
    output wire  [2:0]          arprot,
    output wire                 arvalid,
    input  wire                 arready,
    // read respond
    input  wire  [3:0]          rid,
    input  wire  [31:0]         rdata,
    input  wire  [1:0]          rresp,
    input  wire                 rlast,
    input  wire                 rvalid,
    output wire                 rready,
    // write request
    output wire [3:0]           awid,
    output wire [31:0]          awaddr,
    output wire [7:0]           awlen,
    output wire [2:0]           awsize,
    output wire [1:0]           awburst,
    output wire [1:0]           awlock,
    output wire [3:0]           awcache,
    output wire [2:0]           awprot,
    output wire                 awvalid,
    input  wire                 awready,
    // write data
    output wire [3:0]           wid,
    output wire [31:0]          wdata,
    output wire [3:0]           wstrb,
    output wire                 wlast,
    output wire                 wvalid,
    input  wire                 wready,
    // write respond
    input  wire [3:0]           bid,
    input  wire [1:0]           bresp,
    input  wire                 bvalid,
    output wire                 bready,
    // debug signals
    output wire [31:0]          debug_wb_pc,
    output wire [3:0]           debug_wb_rf_we,
    output wire [4:0]           debug_wb_rf_wnum,
    output wire [31:0]          debug_wb_rf_wdata
);
    wire id_allowin;
    wire ex_allowin;
    wire mem_allowin;
    wire wb_allowin;

    wire if_to_id_valid;
    wire id_to_ex_valid;
    wire ex_to_mem_valid;
    wire mem_to_wb_valid;

    wire [111:0] if_to_id_bus;
    wire [308:0] id_to_ex_bus;
    wire [256:0] ex_to_mem_bus;
    wire [211:0] mem_to_wb_bus;

    wire [71:0] id_to_if_bus;
    wire [39:0] ex_to_id_bus;
    wire [39:0] mem_to_id_bus;
    wire [37:0] wb_to_id_bus;
    wire        wb_to_ex_bus;
    wire [2:0]  mem_to_ex_bus;
    wire cacop_reqed;

    wire csr_re;
    wire [13:0] csr_num;
    wire [31:0] csr_rvalue;
    wire csr_we;
    wire [31:0] csr_wmask;
    wire [31:0] csr_wvalue;
    wire cacop_excep_en;
    wire [5:0]cacop_excep_code;
    wire [8:0]cacop_excep_subcode;

    wire wb_ex;
    wire [5:0] wb_ecode;
    wire [8:0] wb_esubcode;
    wire [31:0] wb_pc;
    wire [31:0] wb_badv;

    wire ertn_flush;
    wire [7:0] hw_int_in;
    wire ipi_int_in;
    wire has_int;
    wire [31:0] wb_flush_entry;

    wire [63:0] counter;
    // exp12 temporarily set to 0
    assign hw_int_in = 8'b0;
    assign ipi_int_in = 1'b0;

    wire         inst_sram_req;
    wire         inst_sram_wr;
    wire [3:0]   inst_sram_wstrb;
    wire [31:0]  inst_sram_addr;
    wire [31:0]  inst_sram_wdata;
    wire         inst_sram_addr_ok;
    wire         inst_sram_data_ok;
    wire [31:0]  inst_sram_rdata;
    wire         inst_type;

    wire         data_sram_req;
    wire         data_sram_wr;
    wire [1:0]   data_sram_size;
    wire [3:0]   data_sram_wstrb;
    wire [31:0]  data_sram_addr;
    wire [31:0]  data_sram_wdata;
    wire         data_sram_addr_ok;
    wire         data_sram_data_ok;
    wire [31:0]  data_sram_rdata;
    wire         data_type;
    //--------------------------------------------------output from if ------------------------------------------
    wire [18:0]                 if_s0_vppn;
    wire                        if_s0_va_bit12;   
    wire [7:0]                  inst_vindex;
    wire [3:0]                  inst_voffset;
    // ----------------------------------------------   output from ex -------------------------------------------------------------
    // search tlb port 1
    wire [18:0]                 ex_s1_vppn;
    wire                        ex_s1_va_bit12;
    wire [9:0]                  ex_s1_asid;
    // invtlb
    wire                        ex_invtlb_valid;
    wire [4:0]                  ex_invtlb_op;
    //dcache
    wire [7:0]                  data_vindex;
    wire [3:0]                  data_voffset;

    wire                        hit_dmw0;
    wire                        hit_dmw1;

    // -----------------------------------------------  output from wb ---------------------------------------------------------------
    // tlbsrch
    wire                        wb_tlbsrch_en;
    wire                        wb_tlbsrch_found;
    wire [$clog2(TLBNUM)-1:0]   wb_tlbsrch_idx; 
    // tlbrd
    wire                        wb_tlbrd_en;
    // tlbwr
    wire                        wb_tlbwr_en;
    // tlbfill
    wire                        wb_tlbfill_en;
    // refetch
    wire                        wb_refetch_flush;                        

    //------------------------------------------------  output from csrfile ---------------------------------------------------------
    wire                      csr_tlb_ne;
    wire [$clog2(TLBNUM)-1:0] csr_tlb_index;
    wire [               5:0] csr_tlb_ps;
    wire [              18:0] csr_tlb_vppn;
    wire                      csr_tlb_g;
    wire [               9:0] csr_tlb_asid;
    wire                      csr_tlb_v0;
    wire                      csr_tlb_d0;
    wire [               1:0] csr_tlb_mat0;
    wire [               1:0] csr_tlb_plv0;
    wire [              19:0] csr_tlb_ppn0;
    wire                      csr_tlb_v1;
    wire                      csr_tlb_d1;
    wire [               1:0] csr_tlb_mat1;
    wire [               1:0] csr_tlb_plv1;
    wire [              19:0] csr_tlb_ppn1;

    wire                      csr_output_pg;
    wire [               1:0] csr_output_plv;
    wire                      csr_dmw0_plv_met;
    wire [               2:0] csr_output_dmw0_pseg;
    wire [               2:0] csr_output_dmw0_vseg;
    wire                      csr_dmw1_plv_met;
    wire [               2:0] csr_output_dmw1_pseg;
    wire [               2:0] csr_output_dmw1_vseg;
    //----------------------------------------------------- output from tlb --------------------------------------------------------------
    // search port 0 (for fetch)
    wire                        s0_found;
    wire [$clog2(TLBNUM)-1:0]   s0_index;
    wire [19:0]                 s0_ppn;
    wire [5:0]                  s0_ps;
    wire [1:0]                  s0_plv;
    wire [1:0]                  s0_mat;
    wire                        s0_d;
    wire                        s0_v;
    // search port 1 (for load/store)
    wire                        s1_found;
    wire [$clog2(TLBNUM)-1:0]   s1_index;
    wire [19:0]                 s1_ppn;
    wire [5:0]                  s1_ps;
    wire [1:0]                  s1_plv;
    wire [1:0]                  s1_mat;
    wire                        s1_d;
    wire                        s1_v;
    // read port
    wire                        r_e;
    wire [18:0]                 r_vppn;
    wire [5:0]                  r_ps;
    wire [9:0]                  r_asid;
    wire                        r_g;
    wire [19:0]                 r_ppn0;
    wire [1:0]                  r_plv0;
    wire [1:0]                  r_mat0;
    wire                        r_d0;
    wire                        r_v0;
    wire [19:0]                 r_ppn1;
    wire [1:0]                  r_plv1;
    wire [1:0]                  r_mat1;
    wire                        r_d1;
    wire                        r_v1;
    // ----------------------------------------------------------------icache--------------------------------------------------------------
    wire                      icache_rd_req;
    wire [2:0]                icache_rd_type;
    wire [31:0]               icache_rd_addr;
    wire                      icache_rd_rdy;
    wire                      icache_ret_valid;
    wire [31:0]               icache_ret_data;
    wire                      icache_ret_last;

    // ----------------------------------------------------------------dcache--------------------------------------------------------------
    wire                      dcache_rd_req;
    wire [2:0]                dcache_rd_type;
    wire [31:0]               dcache_rd_addr;
    wire                      dcache_rd_rdy;
    wire                      dcache_ret_valid;
    wire [31:0]               dcache_ret_data;
    wire                      dcache_ret_last;
    wire                      dcache_wr_req;
    wire [2:0]                dcache_wr_type;
    wire [31:0]               dcache_wr_addr;
    wire [3:0]                dcache_wr_wsrb;
    wire [127:0]              dcache_wr_data;
    wire                      dcache_wr_rdy;
    wire                      dcache_wr_bvalid;  

    //--------------------------------------------------------------------------------------------------------------------------------
    wire icacop;
    wire [4:0] icacop_code;

    wire  dcacop;
    wire [4:0] dcacop_code;



    // ---------------------------------------------------------------------------------------------------------------------------
    IFreg my_ifReg(
        .clk                (aclk),
        .resetn             (aresetn),

        .inst_sram_req      (inst_sram_req),
        .inst_sram_wr       (inst_sram_wr),
        .inst_sram_wstrb    (inst_sram_wstrb),
        .inst_sram_addr     (inst_sram_addr),
        .inst_vindex        (inst_vindex),
        .inst_voffset       (inst_voffset),
        .inst_sram_wdata    (inst_sram_wdata),
        .inst_sram_addr_ok  (inst_sram_addr_ok),
        .inst_sram_data_ok  (inst_sram_data_ok),
        .inst_sram_rdata    (inst_sram_rdata),
        
        .id_allowin         (id_allowin),
        .id_to_if_bus       (id_to_if_bus),
        .if_to_id_valid     (if_to_id_valid),
        .if_to_id_bus       (if_to_id_bus),
        .flush              (ertn_flush || wb_ex || wb_refetch_flush),
        .wb_flush_entry     (wb_flush_entry),
        .s0_vppn            (if_s0_vppn),
        .s0_va_bit12        (if_s0_va_bit12),    
        .csr_crmd_pg        (csr_output_pg),
        .csr_crmd_plv       (csr_output_plv),
        .csr_dmw0_plv_met   (csr_dmw0_plv_met),
        .csr_dmw0_pseg      (csr_output_dmw0_pseg),
        .csr_dmw0_vseg      (csr_output_dmw0_vseg),
        .csr_dmw1_plv_met   (csr_dmw1_plv_met),
        .csr_dmw1_pseg      (csr_output_dmw1_pseg),
        .csr_dmw1_vseg      (csr_output_dmw1_vseg),
        .s0_found           (s0_found),
        .s0_ppn             (s0_ppn),
        .s0_ps              (s0_ps),
        .s0_plv             (s0_plv),
        .s0_d               (s0_d),
        .s0_v               (s0_v),

        .icacop            (icacop),
        .cacop_code       (icacop_code),
        .cacop_reqed        (cacop_reqed),
        .cacop_excep_en   (cacop_excep_en),
        .cacop_excep_code (cacop_excep_code),
        .cacop_excep_subcode (cacop_excep_subcode)
    
    );

    IDreg my_idReg(
        .clk                (aclk),
        .resetn             (aresetn),
        .if_to_id_valid     (if_to_id_valid),
        .id_allowin         (id_allowin),
        .id_to_if_bus       (id_to_if_bus),
        .if_to_id_bus       (if_to_id_bus),
        .ex_allowin         (ex_allowin),
        .id_to_ex_valid     (id_to_ex_valid),
        .id_to_ex_bus       (id_to_ex_bus),
        .wb_to_id_bus       (wb_to_id_bus),
        .mem_to_id_bus      (mem_to_id_bus),
        .ex_to_id_bus       (ex_to_id_bus),
        .flush              (ertn_flush || wb_ex || wb_refetch_flush),
        .has_int            (has_int),
        .cacop_reqed          (cacop_reqed),
        .cacop_excep_en     (cacop_excep_en),
        .cacop_excep_code   (cacop_excep_code),
        .cacop_excep_subcode(cacop_excep_subcode)
    );

    EXEreg my_exeReg(
        .clk                (aclk),
        .resetn             (aresetn),
        .ex_allowin         (ex_allowin),
        .id_to_ex_valid     (id_to_ex_valid),
        .id_to_ex_bus       (id_to_ex_bus),
        .ex_to_id_bus       (ex_to_id_bus),
        .mem_allowin        (mem_allowin),
        .ex_to_mem_valid    (ex_to_mem_valid),
        .ex_to_mem_bus      (ex_to_mem_bus),
        .wb_to_ex_bus       (wb_to_ex_bus),
        .mem_to_ex_bus      (mem_to_ex_bus),
        .data_sram_req      (data_sram_req),
        .data_sram_wr       (data_sram_wr),
        .data_sram_size     (data_sram_size),
        .data_sram_wstrb    (data_sram_wstrb),
        .data_sram_addr     (data_sram_addr),
        .data_sram_wdata    (data_sram_wdata),
        .data_vindex        (data_vindex),
        .data_voffset       (data_voffset),
        .data_sram_addr_ok  (data_sram_addr_ok),
        .flush              (ertn_flush || wb_ex || wb_refetch_flush),
        .counter            (counter),

        .ex_tlb_inv         (ex_invtlb_valid),
        .invtlb_op          (ex_invtlb_op),
        .s1_vppn            (ex_s1_vppn),
        .s1_va_bit12        (ex_s1_va_bit12),
        .s1_asid            (ex_s1_asid),

        .s1_found           (s1_found),
        .s1_index           (s1_index),
        .s1_ppn             (s1_ppn),
        .s1_ps              (s1_ps),
        .s1_plv             (s1_plv),
        .s1_mat             (s1_mat),
        .s1_d               (s1_d),
        .s1_v               (s1_v),

        .csr_tlbehi_vppn    (csr_tlb_vppn),
        .csr_asid           (csr_tlb_asid),

        .csr_crmd_pg        (csr_output_pg),
        .csr_crmd_plv       (csr_output_plv),
        .csr_dmw0_plv_met   (csr_dmw0_plv_met),
        .csr_dmw0_pseg      (csr_output_dmw0_pseg),
        .csr_dmw0_vseg      (csr_output_dmw0_vseg),
        .csr_dmw1_plv_met   (csr_dmw1_plv_met),
        .csr_dmw1_pseg      (csr_output_dmw1_pseg),
        .csr_dmw1_vseg      (csr_output_dmw1_vseg),

        .hit_dmw0           (hit_dmw0),
        .hit_dmw1           (hit_dmw1),

        .dcacop              (dcacop),
        .dcacop_code         (dcacop_code)
    );

    MEMreg my_memReg(
        .clk                (aclk),
        .resetn             (aresetn),
        .mem_allowin        (mem_allowin),
        .ex_to_mem_valid    (ex_to_mem_valid),
        .ex_to_mem_bus      (ex_to_mem_bus),
        .wb_allowin         (wb_allowin),
        .mem_to_wb_valid    (mem_to_wb_valid),
        .mem_to_wb_bus      (mem_to_wb_bus),
        .mem_to_id_bus      (mem_to_id_bus),
        .mem_to_ex_bus      (mem_to_ex_bus),
        .data_sram_data_ok  (data_sram_data_ok),
        .data_sram_rdata    (data_sram_rdata),
        .flush              (ertn_flush || wb_ex || wb_refetch_flush)
    );

    WBreg my_wbReg(
        .clk                (aclk),
        .resetn             (aresetn),
        .wb_allowin         (wb_allowin),
        .mem_to_wb_valid    (mem_to_wb_valid),
        .wb_to_ex_bus       (wb_to_ex_bus),
        .mem_to_wb_bus      (mem_to_wb_bus),
        .debug_wb_pc        (debug_wb_pc),
        .debug_wb_rf_we     (debug_wb_rf_we),
        .debug_wb_rf_wnum   (debug_wb_rf_wnum),
        .debug_wb_rf_wdata  (debug_wb_rf_wdata),
        .wb_to_id_bus       (wb_to_id_bus),
        .csr_re             (csr_re),
        .csr_num            (csr_num),
        .csr_rvalue         (csr_rvalue),
        .csr_we             (csr_we),
        .csr_wmask          (csr_wmask),
        .csr_wvalue         (csr_wvalue),
        .ertn_flush         (ertn_flush),
        .wb_ex              (wb_ex),
        .wb_ecode           (wb_ecode),
        .wb_esubcode        (wb_esubcode),
        .wb_ex_pc           (wb_pc),
        .wb_badv           (wb_badv),
        .wb_flush_entry      (wb_flush_entry),
        .wb_tlb_wr          (wb_tlbwr_en),
        .wb_tlb_fill        (wb_tlbfill_en),
        .wb_tlb_rd          (wb_tlbrd_en),
        .wb_tlbsrch_en      (wb_tlbsrch_en),
        .wb_tlbsrch_found   (wb_tlbsrch_found),
        .wb_tlbsrch_idx     (wb_tlbsrch_idx),
        .wb_refetch_flush   (wb_refetch_flush)
    );

    CSRfile my_csrfile(     // all operation to update csrfile is on wb
        .clk                (aclk),
        .resetn             (aresetn),
        .csr_re             (csr_re),
        .csr_num            (csr_num),
        .csr_rvalue         (csr_rvalue),
        .csr_we             (csr_we),
        .csr_wmask          (csr_wmask),
        .csr_wvalue         (csr_wvalue),
        .wb_ex              (wb_ex),
        .wb_ecode           (wb_ecode),
        .wb_esubcode        (wb_esubcode),
        .wb_pc              (wb_pc),
        .wb_badv           (wb_badv),
        .ertn_flush         (ertn_flush),
        .hw_int_in          (hw_int_in),
        .ipi_int_in         (ipi_int_in),
        .has_int            (has_int),

        .tlbsrch_en         (wb_tlbsrch_en),
        .tlbsrch_found      (wb_tlbsrch_found),
        .tlbsrch_idx        (wb_tlbsrch_idx),

        .tlbrd_en           (wb_tlbrd_en),
        .tlbrd_valid        (r_e),
        .tlbrd_ps           (r_ps),
        .tlbrd_vppn         (r_vppn),
        .tlbrd_g            (r_g),
        .tlbrd_asid         (r_asid),
        .tlbrd_v0           (r_v0),
        .tlbrd_d0           (r_d0),
        .tlbrd_mat0         (r_mat0),
        .tlbrd_plv0         (r_plv0),
        .tlbrd_ppn0         (r_ppn0),
        .tlbrd_v1           (r_v1),
        .tlbrd_d1           (r_d1),
        .tlbrd_mat1         (r_mat1),
        .tlbrd_plv1         (r_plv1),
        .tlbrd_ppn1         (r_ppn1),

        .csr_tlb_ne         (csr_tlb_ne),
        .csr_tlb_index      (csr_tlb_index),
        .csr_tlb_ps         (csr_tlb_ps),
        .csr_tlb_vppn       (csr_tlb_vppn),
        .csr_tlb_g          (csr_tlb_g),
        .csr_tlb_asid       (csr_tlb_asid),
        .csr_tlb_v0         (csr_tlb_v0),
        .csr_tlb_d0         (csr_tlb_d0),
        .csr_tlb_mat0       (csr_tlb_mat0),
        .csr_tlb_plv0       (csr_tlb_plv0),
        .csr_tlb_ppn0       (csr_tlb_ppn0),
        .csr_tlb_v1         (csr_tlb_v1),
        .csr_tlb_d1         (csr_tlb_d1),
        .csr_tlb_mat1       (csr_tlb_mat1),
        .csr_tlb_plv1       (csr_tlb_plv1),
        .csr_tlb_ppn1       (csr_tlb_ppn1),

        .csr_output_pg      (csr_output_pg),
        .csr_output_plv     (csr_output_plv),
        .csr_dmw0_plv_met   (csr_dmw0_plv_met),
        .csr_output_dmw0_pseg(csr_output_dmw0_pseg),
        .csr_output_dmw0_vseg(csr_output_dmw0_vseg),
        .csr_dmw1_plv_met   (csr_dmw1_plv_met),
        .csr_output_dmw1_pseg(csr_output_dmw1_pseg),
        .csr_output_dmw1_vseg(csr_output_dmw1_vseg),

        .hit_dmw0           (hit_dmw0),
        .hit_dmw1           (hit_dmw1),
        .s0_mat             (s0_mat),
        .s1_mat             (s1_mat),
        .inst_type          (inst_type),
        .data_type          (data_type)

    );

    //----------------------------- TLB ------------------------------------------------------------------------------------
    tlb u_tlb(
        .clk                (aclk),

        .s0_vppn            (if_s0_vppn),
        .s0_va_bit12        (if_s0_va_bit12),
        .s0_asid            (csr_tlb_asid),
        .s0_found           (s0_found),
        .s0_index           (s0_index),
        .s0_ppn             (s0_ppn),
        .s0_ps              (s0_ps),
        .s0_plv             (s0_plv),
        .s0_mat             (s0_mat),
        .s0_d               (s0_d),
        .s0_v               (s0_v),

        .s1_vppn            (ex_s1_vppn),
        .s1_va_bit12        (ex_s1_va_bit12),
        .s1_asid            (ex_s1_asid),
        .s1_found           (s1_found),
        .s1_index           (s1_index),
        .s1_ppn             (s1_ppn),
        .s1_ps              (s1_ps),
        .s1_plv             (s1_plv),
        .s1_mat             (s1_mat),
        .s1_d               (s1_d),
        .s1_v               (s1_v),

        .invtlb_valid       (ex_invtlb_valid),
        .invtlb_op          (ex_invtlb_op),

        .we                 (wb_tlbwr_en || wb_tlbfill_en),
        .w_index            (csr_tlb_index),
        .w_e                (~csr_tlb_ne),
        .w_vppn             (csr_tlb_vppn),
        .w_ps               (csr_tlb_ps),
        .w_asid             (csr_tlb_asid),
        .w_g                (csr_tlb_g),
        .w_ppn0             (csr_tlb_ppn0),
        .w_plv0             (csr_tlb_plv0),
        .w_mat0             (csr_tlb_mat0),
        .w_d0               (csr_tlb_d0),
        .w_v0               (csr_tlb_v0),
        .w_ppn1             (csr_tlb_ppn1),
        .w_plv1             (csr_tlb_plv1),
        .w_mat1             (csr_tlb_mat1),
        .w_d1               (csr_tlb_d1),
        .w_v1               (csr_tlb_v1),

        .r_index            (csr_tlb_index),
        .r_e                (r_e),
        .r_vppn             (r_vppn),
        .r_ps               (r_ps),
        .r_asid             (r_asid),
        .r_g                (r_g),
        .r_ppn0             (r_ppn0),
        .r_plv0             (r_plv0),
        .r_mat0             (r_mat0),
        .r_d0               (r_d0),
        .r_v0               (r_v0),
        .r_ppn1             (r_ppn1),
        .r_plv1             (r_plv1),
        .r_mat1             (r_mat1),
        .r_d1               (r_d1),
        .r_v1               (r_v1)
    );
    //----------------------------------------------------- TLB END -----------------------------------------------------------------------

    Stable_Counter my_counter(
        .clk        (aclk),
        .resetn     (aresetn),
        .counter    (counter)
    );

    sram_axi_bridge my_sram_axi_bridge(
        .clk                (aclk),
        .resetn             (aresetn),
        // req from icache
        .inst_sram_req      (icache_rd_req),
        .inst_sram_addr     (icache_rd_addr),
        .inst_sram_type     (icache_rd_type),
        .inst_sram_addr_ok  (icache_rd_rdy),
        // respond to icache
        .inst_sram_data_ok  (icache_ret_valid),
        .inst_sram_rdata    (icache_ret_data),
        .inst_sram_last     (icache_ret_last),
        // read req from dcache
        .data_sram_rd_req       (dcache_rd_req),
        .data_sram_rd_addr      (dcache_rd_addr),
        .data_sram_rd_type      (dcache_rd_type),
        .data_sram_rd_addr_ok   (dcache_rd_rdy),
        // wirte req from dcache
        .data_sram_wr_req       (dcache_wr_req),
        .data_sram_wr_addr      (dcache_wr_addr),
        .data_sram_wr_type      (dcache_wr_type),
        .data_sram_wr_data      (dcache_wr_data),
        .data_sram_wr_wstrb     (dcache_wr_wsrb),
        .data_sram_wr_addr_ok   (dcache_wr_rdy),
        //  read respond to dcache
        .data_sram_rd_data_ok      (dcache_ret_valid),
        .data_sram_rdata        (dcache_ret_data),
        .data_sram_last         (dcache_ret_last),
        // write respond to dcache
        .data_sram_wr_data_ok    (dcache_wr_bvalid),
    
        .arid               (arid),
        .araddr             (araddr),
        .arlen              (arlen),
        .arsize             (arsize),
        .arburst            (arburst),
        .arlock             (arlock),
        .arcache            (arcache),
        .arprot             (arprot),
        .arvalid            (arvalid),
        .arready            (arready),
        .rid                (rid),
        .rdata              (rdata),
        .rresp              (rresp),
        .rlast              (rlast),
        .rvalid             (rvalid),
        .rready             (rready),
        .awid               (awid),
        .awaddr             (awaddr),
        .awlen              (awlen),
        .awsize             (awsize),
        .awburst            (awburst),
        .awlock             (awlock),
        .awcache            (awcache),
        .awprot             (awprot),
        .awvalid            (awvalid),
        .awready            (awready),
        .wid                (wid),
        .wdata              (wdata),
        .wstrb              (wstrb),
        .wlast              (wlast),
        .wvalid             (wvalid),
        .wready             (wready),
        .bid                (bid),
        .bresp              (bresp),
        .bvalid             (bvalid),
        .bready             (bready)
    );

    cache icache(
        .clk                (aclk), 
        .resetn             (aresetn),
        // input from cpu
        .valid             (inst_sram_req),
        .op                (inst_sram_wr),
        .index             (inst_vindex),
        .tag               (inst_sram_addr[31:12]),
        .offset            (inst_voffset),
        .wstrb             (inst_sram_wstrb),
        .wdata             (inst_sram_wdata),
        .type              (inst_type),
        // output to cpu
        .addr_ok           (inst_sram_addr_ok),
        .data_ok           (inst_sram_data_ok),
        .rdata             (inst_sram_rdata),
        // axi read req
        .rd_req            (icache_rd_req),
        .rd_type           (icache_rd_type),
        .rd_addr           (icache_rd_addr),
        .rd_rdy            (icache_rd_rdy),
        // axi read ret
        .ret_valid        (icache_ret_valid),
        .ret_data         (icache_ret_data),
        .ret_last         (icache_ret_last),
        // axi write req
        .wr_req            (),
        .wr_type           (),
        .wr_addr           (),
        .wr_data           (),
        .wr_wstrb           (),
        .wr_rdy            (1'b1),
        // axi write ret
        .wr_bvalid          (1'b0),

        //cacop
        .way               (inst_sram_addr[0]),
        .cacop              (icacop),
        .cacop_code         (icacop_code)

    );
 
    cache dcache(
        .clk                (aclk), 
        .resetn             (aresetn),
        // input from cpu
        .valid             (data_sram_req),
        .op                (data_sram_wr),
        .index             (data_vindex),
        .tag               (data_sram_addr[31:12]),
        .offset            (data_voffset),
        .wstrb             (data_sram_wstrb),
        .wdata             (data_sram_wdata),
        .type              (data_type),
        // output to cpu
        .addr_ok           (data_sram_addr_ok),
        .data_ok           (data_sram_data_ok),
        .rdata             (data_sram_rdata),
        // axi read req
        .rd_req            (dcache_rd_req),
        .rd_type           (dcache_rd_type),
        .rd_addr           (dcache_rd_addr),
        .rd_rdy            (dcache_rd_rdy),
        // axi read ret
        .ret_valid        (dcache_ret_valid),
        .ret_data         (dcache_ret_data),
        .ret_last         (dcache_ret_last),
        // axi write req
        .wr_req            (dcache_wr_req),
        .wr_type           (dcache_wr_type),
        .wr_addr           (dcache_wr_addr),
        .wr_data           (dcache_wr_data),
        .wr_wstrb           (dcache_wr_wsrb),
        .wr_rdy            (dcache_wr_rdy),
        // axi write ret
        .wr_bvalid          (dcache_wr_bvalid),
        //cacop
        .way               (data_sram_addr[0]),
        .cacop              (dcacop),
        .cacop_code         (dcacop_code)
    );

endmodule
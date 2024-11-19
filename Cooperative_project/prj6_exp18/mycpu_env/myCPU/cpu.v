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
    input  wire                 bid,
    input  wire                 bresp,
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

    wire [65:0] if_to_id_bus;
    wire [237:0] id_to_ex_bus;
    wire [246:0] ex_to_mem_bus;
    wire [205:0] mem_to_wb_bus;

    wire [33:0] id_to_if_bus;
    wire [39:0] ex_to_id_bus;
    wire [39:0] mem_to_id_bus;
    wire [37:0] wb_to_id_bus;
    wire        wb_to_ex_bus;
    wire [1:0]  mem_to_ex_bus;

    wire csr_re;
    wire [13:0] csr_num;
    wire [31:0] csr_rvalue;
    wire csr_we;
    wire [31:0] csr_wmask;
    wire [31:0] csr_wvalue;

    wire wb_ex;
    wire [5:0] wb_ecode;
    wire [8:0] wb_esubcode;
    wire [31:0] wb_pc;
    wire [31:0] wb_vaddr;

    wire ertn_flush;
    wire [7:0] hw_int_in;
    wire ipi_int_in;
    wire has_int;
    wire [31:0] wb_csr_rvalue;

    wire [63:0] counter;
    // exp12 temporarily set to 0
    assign hw_int_in = 8'b0;
    assign ipi_int_in = 1'b0;

    wire         inst_sram_req;
    wire         inst_sram_wr;
    wire [1:0]   inst_sram_size;
    wire [3:0]   inst_sram_wstrb;
    wire [31:0]  inst_sram_addr;
    wire [31:0]  inst_sram_wdata;
    wire         inst_sram_addr_ok;
    wire         inst_sram_data_ok;
    wire [31:0]  inst_sram_rdata;

    wire         data_sram_req;
    wire         data_sram_wr;
    wire [1:0]   data_sram_size;
    wire [3:0]   data_sram_wstrb;
    wire [31:0]  data_sram_addr;
    wire [31:0]  data_sram_wdata;
    wire         data_sram_addr_ok;
    wire         data_sram_data_ok;
    wire [31:0]  data_sram_rdata;

    //------------------------------------------------  CSRfile中TLB相关 ---------------------------------------------------------

    // TLBSRCH
    wire                      tlbsrch_en;
    wire                      tlbsrch_found;
    wire [$clog2(TLBNUM)-1:0] tlbsrch_idx;
    // TLBRD
    wire [$clog2(TLBNUM)-1:0] tlbrd_idx;
    wire                      tlbrd_en;
    wire                      tlbrd_valid;
    wire [               5:0] tlbrd_ps;
    wire [              18:0] tlbrd_vppn;
    wire                      tlbrd_g;
    wire [               9:0] tlbrd_asid;
    wire                      tlbrd_v0;
    wire                      tlbrd_d0;
    wire [               1:0] tlbrd_mat0;
    wire [               1:0] tlbrd_plv0;
    wire [              19:0] tlbrd_ppn0;
    wire                      tlbrd_v1;
    wire                      tlbrd_d1;
    wire [               1:0] tlbrd_mat1;
    wire [               1:0] tlbrd_plv1;
    wire [              19:0] tlbrd_ppn1;
    // TLBWR or TLBFILL
    wire                      tlbwr_ne;
    wire                      tlbwr_index;
    wire [               5:0] tlbwr_ps;
    wire [              18:0] tlbwr_vppn;
    wire                      tlbwr_g;
    wire [               9:0] tlbwr_asid;
    wire                      tlbwr_v0;
    wire                      tlbwr_d0;
    wire [               1:0] tlbwr_mat0;
    wire [               1:0] tlbwr_plv0;
    wire [              19:0] tlbwr_ppn0;
    wire                      tlbwr_v1;
    wire                      tlbwr_d1;
    wire [               1:0] tlbwr_mat1;
    wire [               1:0] tlbwr_plv1;
    wire [              19:0] tlbwr_ppn1;


    //----------------------------------------------------- TLB相关 --------------------------------------------------------------
    wire          tlb_wr;
    wire          tlb_fill;

    // TLB ports
    wire                        clk;
    // search port 0 (for fetch)
    wire [18:0]                 s0_vppn;
    wire                        s0_va_bit12;
    wire [9:0]                  s0_asid;
    wire                        s0_found;
    wire [$clog2(TLBNUM)-1:0]   s0_index;
    wire [19:0]                 s0_ppn;
    wire [5:0]                  s0_ps;
    wire [1:0]                  s0_plv;
    wire [1:0]                  s0_mat;
    wire                        s0_d;
    wire                        s0_v;
    // search port 1 (for load/store)
    wire [18:0]                 s1_vppn;
    wire                        s1_va_bit12;
    wire [9:0]                  s1_asid;
    wire                        s1_found;
    wire [$clog2(TLBNUM)-1:0]   s1_index;
    wire [19:0]                 s1_ppn;
    wire [5:0]                  s1_ps;
    wire [1:0]                  s1_plv;
    wire [1:0]                  s1_mat;
    wire                        s1_d;
    wire                        s1_v;
    // invtlb opcode
    wire                        invtlb_valid;
    wire [4:0]                  invtlb_op;
    // write port
    wire [$clog2(TLBNUM)-1:0]   w_index;
    wire                        w_e;
    wire [18:0]                 w_vppn;
    wire [5:0]                  w_ps;
    wire [9:0]                  w_asid;
    wire                        w_g;
    wire [19:0]                 w_ppn0;
    wire [1:0]                  w_plv0;
    wire [1:0]                  w_mat0;
    wire                        w_d0;
    wire                        w_v0;
    wire [19:0]                 w_ppn1;
    wire [1:0]                  w_plv1;
    wire [1:0]                  w_mat1;
    wire                        w_d1;
    wire                        w_v1;
    // read port
    wire [$clog2(TLBNUM)-1:0]   r_index;
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


    wire [18:0]                 csr_tlbehi_vppn;
    wire [ 9:0]                 csr_asid;
    //--------------------------------------------------------------------------------------------------------------------------------

    IFreg my_ifReg(
        .clk                (aclk),
        .resetn             (aresetn),
        .inst_sram_req      (inst_sram_req),
        .inst_sram_wr       (inst_sram_wr),
        .inst_sram_size     (inst_sram_size),
        .inst_sram_wstrb    (inst_sram_wstrb),
        .inst_sram_addr     (inst_sram_addr),
        .inst_sram_wdata    (inst_sram_wdata),
        .inst_sram_addr_ok  (inst_sram_addr_ok),
        .inst_sram_data_ok  (inst_sram_data_ok),
        .inst_sram_rdata    (inst_sram_rdata),
        .id_allowin         (id_allowin),
        .id_to_if_bus       (id_to_if_bus),
        .if_to_id_valid     (if_to_id_valid),
        .if_to_id_bus       (if_to_id_bus),
        .flush              (ertn_flush || wb_ex),
        .wb_csr_rvalue      (wb_csr_rvalue)
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
        .flush              (ertn_flush || wb_ex),
        .has_int            (has_int)
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
        .data_sram_addr_ok  (data_sram_addr_ok),
        .flush              (ertn_flush || wb_ex),
        .counter            (counter),

        .ex_tlb_srch        (tlbsrch_en),
        .ex_tlb_inv         (invtlb_valid),
        .invtlb_op          (invtlb_op),
        .s1_vppn            (s1_vppn),
        .s1_va_bit12        (s1_va_bit12),
        .s1_asid            (s1_asid),

        .s1_found           (s1_found),
        .s1_index           (s1_index),
        .s1_ppn             (s1_ppn),
        .s1_ps              (s1_ps),
        .s1_plv             (s1_plv),
        .s1_mat             (s1_mat),
        .s1_d               (s1_d),
        .s1_v               (s1_v),

        .csr_tlbehi_vppn    (csr_tlbehi_vppn),
        .csr_asid           (csr_asid)
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
        .flush              (ertn_flush || wb_ex)
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
        .wb_vaddr           (wb_vaddr),
        .wb_csr_rvalue      (wb_csr_rvalue),
        .wb_tlb_wr          (tlb_wr),
        .wb_tlb_fill        (tlb_fill),
        .wb_tlb_rd          (tlbrd_en),
        /*.tlbrd_idx          (r_index),
        .tlbrd_en           (r_e),
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
        .tlbwr_ne           (tlbwr_ne),
        .tlbwr_index        (tlbwr_index),
        .tlbwr_ps           (tlbwr_ps),
        .tlbwr_vppn         (tlbwr_vppn),
        .tlbwr_g            (tlbwr_g),
        .tlbwr_asid         (tlbwr_asid),
        .tlbwr_v0           (tlbwr_v0),
        .tlbwr_d0           (tlbwr_d0),
        .tlbwr_mat0         (tlbwr_mat0),
        .tlbwr_plv0         (tlbwr_plv0),
        .tlbwr_ppn0         (tlbwr_ppn0),
        .tlbwr_v1           (tlbwr_v1),
        .tlbwr_d1           (tlbwr_d1),
        .tlbwr_mat1         (tlbwr_mat1),
        .tlbwr_plv1         (tlbwr_plv1),
        .tlbwr_ppn1         (tlbwr_ppn1)*/
    );

    CSRfile my_csrfild(
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
        .wb_vaddr           (wb_vaddr),
        .ertn_flush         (ertn_flush),
        .hw_int_in          (hw_int_in),
        .ipi_int_in         (ipi_int_in),
        .has_int            (has_int),
        //.excep_entry(excep_entry)

        .tlbsrch_en         (tlbsrch_en),
        .tlbsrch_found      (s1_found),
        .tlbsrch_idx        (s1_index),

        .tlbrd_valid        (r_e),
        .tlbrd_idx          (r_index),
        .tlbrd_en           (tlbrd_en),
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

        .tlbwr_ne           (tlbwr_ne),
        .tlbwr_index        (tlbwr_index),
        .tlbwr_ps           (tlbwr_ps),
        .tlbwr_vppn         (tlbwr_vppn),
        .tlbwr_g            (tlbwr_g),
        .tlbwr_asid         (tlbwr_asid),
        .tlbwr_v0           (tlbwr_v0),
        .tlbwr_d0           (tlbwr_d0),
        .tlbwr_mat0         (tlbwr_mat0),
        .tlbwr_plv0         (tlbwr_plv0),
        .tlbwr_ppn0         (tlbwr_ppn0),
        .tlbwr_v1           (tlbwr_v1),
        .tlbwr_d1           (tlbwr_d1),
        .tlbwr_mat1         (tlbwr_mat1),
        .tlbwr_plv1         (tlbwr_plv1),
        .tlbwr_ppn1         (tlbwr_ppn1),

        .wire_csr_tlbehi_vppn    (csr_tlbehi_vppn),
        .wire_csr_asid           (csr_asid)
    );

    //----------------------------- TLB ------------------------------------------------------------------------------------
    tlb u_tlb(
        .clk        (clk),

        .s0_vppn    (s0_vppn),
        .s0_va_bit12(s0_va_bit12),
        .s0_asid    (s0_asid),
        .s0_found   (s0_found),
        .s0_index   (s0_index),
        .s0_ppn     (s0_ppn),
        .s0_ps      (s0_ps),
        .s0_plv     (s0_plv),
        .s0_mat     (s0_mat),
        .s0_d       (s0_d),
        .s0_v       (s0_v),
        .s1_vppn    (s1_vppn),
        .s1_va_bit12(s1_va_bit12),
        .s1_asid    (s1_asid),
        .s1_found   (s1_found),
        .s1_index   (s1_index),
        .s1_ppn     (s1_ppn),
        .s1_ps      (s1_ps),
        .s1_plv     (s1_plv),
        .s1_mat     (s1_mat),
        .s1_d       (s1_d),
        .s1_v       (s1_v),

        .invtlb_valid(invtlb_valid),
        .invtlb_op  (invtlb_op),

        .we         (tlb_wr || tlb_fill),
        .w_index    (tlbwr_index),
        .w_e        (~tlbwr_ne),
        .w_vppn     (tlbwr_vppn),
        .w_ps       (tlbwr_ps),
        .w_asid     (tlbwr_asid),
        .w_g        (tlbwr_g),
        .w_ppn0     (tlbwr_ppn0),
        .w_plv0     (tlbwr_plv0),
        .w_mat0     (tlbwr_mat0),
        .w_d0       (tlbwr_d0),
        .w_v0       (tlbwr_v0),
        .w_ppn1     (tlbwr_ppn1),
        .w_plv1     (tlbwr_plv1),
        .w_mat1     (tlbwr_mat1),
        .w_d1       (tlbwr_d1),
        .w_v1       (tlbwr_v1),
        
        .r_index    (r_index),
        .r_e        (r_e),
        .r_vppn     (r_vppn),
        .r_ps       (r_ps),
        .r_asid     (r_asid),
        .r_g        (r_g),
        .r_ppn0     (r_ppn0),
        .r_plv0     (r_plv0),
        .r_mat0     (r_mat0),
        .r_d0       (r_d0),
        .r_v0       (r_v0),
        .r_ppn1     (r_ppn1),
        .r_plv1     (r_plv1),
        .r_mat1     (r_mat1),
        .r_d1       (r_d1),
        .r_v1       (r_v1)
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
        .inst_sram_req      (inst_sram_req),
        .inst_sram_wr       (inst_sram_wr),
        .inst_sram_size     (inst_sram_size),
        .inst_sram_wstrb    (inst_sram_wstrb),
        .inst_sram_addr     (inst_sram_addr),
        .inst_sram_wdata    (inst_sram_wdata),
        .inst_sram_addr_ok  (inst_sram_addr_ok),
        .inst_sram_data_ok  (inst_sram_data_ok),
        .inst_sram_rdata    (inst_sram_rdata),
        .data_sram_req      (data_sram_req),
        .data_sram_wr       (data_sram_wr),
        .data_sram_size     (data_sram_size),
        .data_sram_wstrb    (data_sram_wstrb),
        .data_sram_addr     (data_sram_addr),
        .data_sram_wdata    (data_sram_wdata),
        .data_sram_addr_ok  (data_sram_addr_ok),
        .data_sram_data_ok  (data_sram_data_ok),
        .data_sram_rdata    (data_sram_rdata),
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

endmodule
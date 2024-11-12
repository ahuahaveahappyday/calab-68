module mycpu_top(
    input  wire                 aclk,
    input  wire                 aresetn,
    // read request
    output wire  [3:0]          arid      ,
    output wire  [31:0]         araddr    ,
    output wire  [7:0]          arlen     ,
    output wire  [2:0]          arsize    ,
    output wire  [1:0]          arburst   ,
    output wire  [1:0]          arlock    ,
    output wire  [3:0]          arcache   ,
    output wire  [2:0]          arprot    ,
    output wire                 arvalid   ,
    input wire                  arready   ,
    // read respond
    input wire  [3:0]           rid       ,
    input wire  [31:0]          rdata     ,
    input wire  [1:0]           rresp     ,
    input wire                  rlast     ,
    input wire                  rvalid    ,
    output wire                 rready    ,
    // write request
    output wire [3:0]           awid      ,
    output wire [31:0]          awaddr    ,
    output wire [7:0]           awlen     ,
    output wire [2:0]           awsize    ,
    output wire [1:0]           awburst   ,
    output wire [1:0]           awlock    ,
    output wire [3:0]           awcache   ,
    output wire [2:0]           awprot    ,
    output wire                 awvalid   ,
    input wire                  awready   ,
    // write data
    output wire [3:0]           wid       ,
    output wire [31:0]          wdata     ,
    output wire [3:0]           wstrb     ,
    output wire                 wlast     ,
    output wire                 wvalid    ,
    input wire                  wready    ,
    // write respond
    input wire                  bid       ,
    input wire                  bresp     ,
    input wire                  bvalid    ,
    output wire                 bready    ,
//debug信号
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

    wire id_allowin;
    wire ex_allowin;
    wire mem_allowin;
    wire wb_allowin;

    wire if_to_id_valid;
    wire id_to_ex_valid;
    wire ex_to_mem_valid;
    wire mem_to_wb_valid;

    wire [65:0]if_to_id_bus;
    wire [225:0]id_to_ex_bus;
    wire [239:0]ex_to_mem_bus;
    wire [199:0]mem_to_wb_bus;

    wire [33:0]id_to_if_bus;
    wire [39:0]ex_to_id_bus;
    wire [39:0]mem_to_id_bus;
    wire [37:0]wb_to_id_bus;
    // wire [1:0] wb_to_ex_bus;
    wire [1:0] mem_to_ex_bus;

    wire            csr_re;
    wire [13:0]     csr_num;
    wire [31:0]     csr_rvalue;
    wire            csr_we;
    wire [31:0]     csr_wmask;
    wire [31:0]     csr_wvalue;

    wire            wb_ex;
    wire [5:0]      wb_ecode;
    wire [8:0]      wb_esubcode;
    wire [31:0]     wb_pc;
    wire [31:0]     wb_vaddr;

    wire            ertn_flush;
    wire [7:0]      hw_int_in;
    wire            ipi_int_in;
    wire            has_int;
    wire [31:0]     wb_csr_rvalue;

    wire [63:0]     counter;
    // exp12暂时设置为0
    assign hw_int_in = 8'b0;
    assign ipi_int_in = 1'b0;

    wire         inst_sram_req;
    wire         inst_sram_wr;
    wire [1:0]   inst_sram_size;
    wire [3:0]   inst_sram_wstrb;
    wire [31:0]  inst_sram_addr;
    wire [31:0]  inst_sram_wdata;
    wire          inst_sram_addr_ok;
    wire          inst_sram_data_ok;
    wire  [31:0]  inst_sram_rdata;

    wire         data_sram_req;
    wire         data_sram_wr;
    wire [1:0]   data_sram_size;
    wire [3:0]   data_sram_wstrb;
    wire [31:0]  data_sram_addr;
    wire [31:0]  data_sram_wdata;
    wire          data_sram_addr_ok;

    wire          data_sram_data_ok;
    wire  [31:0]  data_sram_rdata;
    
    IFreg my_ifReg(
        .clk                (aclk),
        .resetn             (aresetn),

        .inst_sram_req      (inst_sram_req    ),
        .inst_sram_wr       (inst_sram_wr     ),
        .inst_sram_size     (inst_sram_size   ),
        .inst_sram_wstrb    (inst_sram_wstrb  ),
        .inst_sram_addr     (inst_sram_addr   ),
        .inst_sram_wdata    (inst_sram_wdata  ),
        .inst_sram_addr_ok  (inst_sram_addr_ok),
        .inst_sram_data_ok  (inst_sram_data_ok),
        .inst_sram_rdata    (inst_sram_rdata  ),
        
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

        // .wb_to_ex_bus(wb_to_ex_bus),
        .mem_to_ex_bus      (mem_to_ex_bus),
        
        .data_sram_req      (data_sram_req    ),
        .data_sram_wr       (data_sram_wr     ),
        .data_sram_size     (data_sram_size   ),
        .data_sram_wstrb    (data_sram_wstrb  ),
        .data_sram_addr     (data_sram_addr   ),
        .data_sram_wdata    (data_sram_wdata  ),
        .data_sram_addr_ok  (data_sram_addr_ok),

        .flush              (ertn_flush || wb_ex),

        .counter            (counter)
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
        .data_sram_rdata    (data_sram_rdata  ),

        .flush              (ertn_flush || wb_ex)

    ) ;

    WBreg my_wbReg(
        .clk                (aclk),
        .resetn             (aresetn),

        .wb_allowin         (wb_allowin),
        .mem_to_wb_valid    (mem_to_wb_valid),
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

        .wb_csr_rvalue      (wb_csr_rvalue)
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
        .has_int            (has_int)
        //.excep_entry(excep_entry)

    );

    Stable_Counter my_counter(
        .clk                (aclk),
        .resetn             (aresetn),
        .counter            (counter)
    );

    sram_axi_bridge my_sram_axi_bridge(
        .clk                (aclk),
        .resetn             (aresetn),

        .inst_sram_req      (inst_sram_req    ),
        .inst_sram_wr       (inst_sram_wr     ),
        .inst_sram_size     (inst_sram_size   ),
        .inst_sram_wstrb    (inst_sram_wstrb  ),
        .inst_sram_addr     (inst_sram_addr   ),
        .inst_sram_wdata    (inst_sram_wdata  ),
        .inst_sram_addr_ok  (inst_sram_addr_ok),
        .inst_sram_data_ok  (inst_sram_data_ok),
        .inst_sram_rdata    (inst_sram_rdata  ),

        .data_sram_req      (data_sram_req    ),
        .data_sram_wr       (data_sram_wr     ),
        .data_sram_size     (data_sram_size   ),
        .data_sram_wstrb    (data_sram_wstrb  ),
        .data_sram_addr     (data_sram_addr   ),
        .data_sram_wdata    (data_sram_wdata  ),
        .data_sram_addr_ok  (data_sram_addr_ok),

        .data_sram_data_ok  (data_sram_data_ok),
        .data_sram_rdata    (data_sram_rdata  ),

        .arid               (arid      ),
        .araddr             (araddr    ),
        .arlen              (arlen     ),
        .arsize             (arsize    ),
        .arburst            (arburst   ),
        .arlock             (arlock    ),
        .arcache            (arcache   ),
        .arprot             (arprot    ),
        .arvalid            (arvalid   ),
        .arready            (arready   ),

        .rid                (rid       ),
        .rdata              (rdata     ),
        .rresp              (rresp     ),
        .rlast              (rlast     ),
        .rvalid             (rvalid    ),
        .rready             (rready    ),

        .awid               (awid      ),
        .awaddr             (awaddr    ),
        .awlen              (awlen     ),
        .awsize             (awsize    ),
        .awburst            (awburst   ),
        .awlock             (awlock    ),
        .awcache            (awcache   ),
        .awprot             (awprot    ),
        .awvalid            (awvalid   ),
        .awready            (awready   ),

        .wid                (wid       ),
        .wdata              (wdata     ),
        .wstrb              (wstrb     ),
        .wlast              (wlast     ),
        .wvalid             (wvalid    ),
        .wready             (wready    ),

        .bid                (bid       ),
        .bresp              (bresp     ),
        .bvalid             (bvalid    ),
        .bready             (bready    )

    );

endmodule
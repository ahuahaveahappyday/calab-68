module sram_axi_bridge(
    //if模块与指令存储器的交互接口
    input wire         inst_sram_req,
    input wire         inst_sram_wr,
    input wire [1:0]   inst_sram_size,
    input wire [3:0]   inst_sram_wstrb,
    input wire [31:0]  inst_sram_addr,
    input wire [31:0]  inst_sram_wdata,
    
    output wire          inst_sram_addr_ok,
    output wire          inst_sram_data_ok,
    output wire  [31:0]  inst_sram_rdata,
    
    //ex模块与数据存储器交互
    input wire         data_sram_req,
    input wire         data_sram_wr,
    input wire [1:0]   data_sram_size,
    input wire [3:0]   data_sram_wstrb,
    input wire [31:0]  data_sram_addr,
    input wire [31:0]  data_sram_wdata,
    output wire          data_sram_addr_ok,
    //mem与dram交互接口
    output wire          data_sram_data_ok,
    output wire  [31:0]  data_sram_rdata,

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
    output wire                 bready    
);



























endmodule
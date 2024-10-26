module sram_axi_bridge(
    input wire          clk,
    input wire          resetn,
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


/*--------------------------------------read request chanel---------------------------------------------------*/
assign arlen =      8'b0;
assign arburst =    2'b01;
assign arlock =     2'b0;
assign arache =     4'b0;
assign arprot =     3'b0;

reg [3:0]       arid_reg;
reg [31:0]      araddr_reg;
reg [2:0]       arsize_reg;
reg             arvalid_reg;


reg             ar_data_addr_valid;
//  ----------------one hot encoding
localparam      AR_WAIT =       3'b001,
                AR_INST_SEND=   3'b010,
                AR_DATA_SEND =  3'b100;

reg [2:0]   ar_current_state;
reg [2:0]   ar_next_state;
always @(posedge clk)begin
    if(~resetn)
        ar_current_state <= AR_WAIT;
    else 
        ar_current_state <= ar_next_state;
end
// ------------------next_state generate
always @( * )begin
    case (ar_current_state)
        AR_WAIT:begin
            if( inst_sram_req & ~inst_sram_wr)      // inst fetch, Higher priority
                ar_next_state   =       AR_INST_SEND;
            else if(data_sram_req & ~data_sram_wr)// data fetch
                ar_next_state =         AR_DATA_SEND;
            else 
                ar_next_state =         AR_WAIT;
        end
        AR_INST_SEND:begin
            if  (arready & ar_data_addr_valid)
                ar_next_state = AR_DATA_SEND;
            else if(arready)
                ar_next_state = AR_WAIT;
            else 
                ar_next_state = AR_WAIT;
        end
        AR_DATA_SEND: begin
            if  (arready)
                ar_next_state = AR_WAIT;
            else 
                ar_next_state = AR_DATA_SEND;
        end
    endcase
end

//---------------------------sram_like slave 
assign inst_sram_addr_ok = ar_current_state == AR_WAIT;
assign data_sram_addr_ok = ar_current_state == AR_WAIT;
// --------------------------axi master
assign arid = {2'b0,{ar_current_state == AR_DATA_SEND}};
always @(posedge clk)begin
    if(~resetn)
        araddr_reg <= 32'b0;
    else if(ar_current_state == AR_WAIT && inst_sram_req & ~inst_sram_wr)
        araddr_reg <= inst_sram_addr;
end





















endmodule
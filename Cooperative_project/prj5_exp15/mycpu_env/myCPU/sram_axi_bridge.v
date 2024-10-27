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
    output wire  [7:0]          arlen     ,     // 0
    output wire  [2:0]          arsize    ,     // 2
    output wire  [1:0]          arburst   ,     // 1
    output wire  [1:0]          arlock    ,     // 0
    output wire  [3:0]          arcache   ,     // 0
    output wire  [2:0]          arprot    ,     // 0
    output wire                 arvalid   ,
    input wire                  arready   ,
    // read respond
    input wire  [3:0]           rid       ,
    input wire  [31:0]          rdata     ,
    input wire  [1:0]           rresp     ,     // ignore
    input wire                  rlast     ,     // ignore
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
assign arsize =     3'b010; // 32 bit per time

reg [3:0]       arid_reg;
reg [31:0]      araddr_reg;
reg [2:0]       arsize_reg;
reg             arvalid_reg;


reg             ar_data_addr_valid;
reg [31:0]      ar_data_addr_reg;
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
// arid
assign arid = {2'b0,{ar_current_state == AR_DATA_SEND}};
// arvalid
assign arvalid = (ar_current_state == AR_DATA_SEND) || (ar_current_state == AR_INST_SEND);
// araddr
always @(posedge clk)begin
    if(resetn) begin
        ar_data_addr_reg<= 32'b0;
        ar_data_addr_valid <= 1'b0;
    end
    else if(ar_current_state == AR_WAIT && inst_sram_req && ~inst_sram_wr
                                        && data_sram_req && ~data_sram_wr )     // Inst fetch and data fetch request at the same time
    begin
        ar_data_addr_reg<= data_sram_addr;
        ar_data_addr_valid <= 1'b1;
    end
    else if(ar_current_state == AR_INST_SEND && arready)begin
        ar_data_addr_reg<= 32'b0;
        ar_data_addr_valid <= 1'b0; 
    end
end
always @(posedge clk)begin
    if(~resetn)
        araddr_reg <= 32'b0;
    else if(ar_current_state == AR_WAIT && inst_sram_req && ~inst_sram_wr)   // Inst fetch
        araddr_reg <= inst_sram_addr;
    else if(ar_current_state == AR_WAIT && data_sram_req && ~data_sram_wr)
        araddr_reg <= data_sram_addr;
    else if(ar_current_state == AR_INST_SEND && arready && ar_data_addr_valid)
        araddr_reg <= ar_data_addr_reg;
end
assign araddr = araddr_reg;
/*-------------------------------------------------read respond chanel------------------------------------------------------*/
reg [1:0]                r_current_state;
reg [1:0]               r_next_state;

reg [31:0]          rdata_reg;
reg                 rid_reg;
// ---------------------one hot encoding state
localparam      R_WAIT =        2'b00,
                R_RECIEVE =     2'b10;

always @(posedge clk)begin
    if(~resetn)
        r_current_state <= R_WAIT;
    else 
        r_current_state <= r_next_state;
end
// ---------------------next_state generate
always @(*)begin
    case(r_current_state)
        R_WAIT:begin
            if(rvalid)
                r_next_state = R_RECIEVE;
            else
                r_next_state = R_WAIT;
        end
        R_RECIEVE:begin
            r_next_state = R_WAIT;
        end
    endcase
end
// --------------------axi master
assign rready = r_current_state == R_WAIT;
// --------------------sram slave
always @(posedge clk)begin
    if(~resetn)begin
        rdata_reg <= 32'b0;
        rid_reg <= 1'b0;
    end
    else if(r_current_state == R_WAIT && rvalid)begin
        rdata_reg <= rdata;
        rid_reg  <= rid;
    end
    else if(r_current_state ==R_RECIEVE)begin
        rdata_reg <= 32'b0;
        rid_reg <= 1'b0;
    end
end
// inst_sram
assign inst_sram_data_ok = (r_current_state == R_RECIEVE && rid_reg == 4'b0);
assign inst_sram_rdata = rdata_reg;
// data_sram
assign data_sram_addr_ok = (r_current_state == R_RECIEVE && rid_reg == 4'b1);
assign data_sram_rdata = rdata_reg;




















endmodule
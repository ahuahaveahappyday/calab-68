module sram_axi_bridge(
    input wire          clk,
    input wire          resetn,
    // req from icache
    input wire              inst_sram_req,
    input wire [31:0]       inst_sram_addr,
    input wire [2:0]        inst_sram_type,
    output wire             inst_sram_addr_ok,
    // response to icache
    output wire             inst_sram_data_ok,
    output wire  [31:0]     inst_sram_rdata,
    output wire             inst_sram_last,
    
    //ex模块与数据存储器交互
    input wire              data_sram_req,
    input wire              data_sram_wr,
    input wire [1:0]        data_sram_size,
    input wire [3:0]        data_sram_wstrb,
    input wire [31:0]       data_sram_addr,
    input wire [31:0]       data_sram_wdata,
    output wire             data_sram_addr_ok,
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
    input wire                  rlast     ,
    input wire                  rvalid    ,
    output wire                 rready    ,
    // write request
    output wire [3:0]           awid      , // 1
    output wire [31:0]          awaddr    ,
    output wire [7:0]           awlen     , // 0
    output wire [2:0]           awsize    , // 1
    output wire [1:0]           awburst   , // 0
    output wire [1:0]           awlock    , // 0
    output wire [3:0]           awcache   , // 0
    output wire [2:0]           awprot    , // 0
    output wire                 awvalid   ,
    input wire                  awready   ,
    // write data
    output wire [3:0]           wid       , // 1
    output wire [31:0]          wdata     ,
    output wire [3:0]           wstrb     ,
    output wire                 wlast     , // 1
    output wire                 wvalid    ,
    input wire                  wready    ,
    // write respond
    input wire [3:0]            bid       , // ignore
    input wire [1:0]            bresp     , // ignore
    input wire                  bvalid    ,
    output wire                 bready    
);

//  ----------------one hot encoding: read request
localparam      AR_WAIT =       3'b001,
                AR_INST_SEND=   3'b010,
                AR_DATA_SEND =  3'b100;

reg [2:0]       ar_current_state;
reg [2:0]       ar_next_state;
// ----------------one hot encoding: read respond
localparam      R_WAIT =        2'b00,
                R_RECIEVE =     2'b10;

reg [1:0]                r_current_state;
reg [1:0]               r_next_state;
// ----------------one hot encoding: write request and data
localparam      AW_WAIT =       3'b001,
                AW_SEND_ADDR =   3'b010,
                AW_SEND_DATA =   3'b100;

reg [2:0]       aw_current_state;
reg [2:0]       aw_next_state;

// ----------------one hot encoding: write respond
localparam      B_WAIT =    2'b01,
                B_REC =     2'b10;
reg [2:0]       b_current_state;
reg [2:0]       b_next_state;

/*--------------------------------------read request chanel---------------------------------------------------*/
reg   [31:0]    inst_req_addr_reg;
reg   [2:0]     inst_req_type_reg;
reg             inst_req_valid_reg;
reg   [31:0]    data_req_addr_reg;
reg   [2:0]     data_req_type_reg;

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
            if(data_sram_req & data_sram_addr_ok & ~data_sram_wr)// data fetch, higher priority
                ar_next_state =         AR_DATA_SEND;
            else if( inst_sram_req & inst_sram_addr_ok)      // inst fetch
                ar_next_state   =       AR_INST_SEND;
            else 
                ar_next_state =         AR_WAIT;
        end
        AR_DATA_SEND: begin
            if  (arready & inst_req_valid_reg)
                ar_next_state = AR_INST_SEND;
            else if (arready)
                ar_next_state = AR_WAIT;
            else 
                ar_next_state = AR_DATA_SEND;
        end
        AR_INST_SEND:begin
            if  (arready )
                ar_next_state = AR_WAIT;
            else 
                ar_next_state = AR_INST_SEND;
        end
    endcase
end

//---------------------------sram_like slave 
assign inst_sram_addr_ok = ar_current_state == AR_WAIT && aw_current_state == AW_WAIT;
assign data_sram_addr_ok = ar_current_state == AR_WAIT && aw_current_state == AW_WAIT;
always @(posedge clk)begin
    if(~resetn)begin
        inst_req_addr_reg <= 32'b0;
        inst_req_type_reg <= 3'b0;
        inst_req_valid_reg <= 1'b0;
    end
    else if(ar_current_state == AR_WAIT && inst_sram_req && inst_sram_addr_ok)begin
        inst_req_addr_reg <= inst_sram_addr;
        inst_req_type_reg <= inst_sram_type;
        inst_req_valid_reg <= 1'b1;
    end
    else if(ar_current_state == AR_INST_SEND && arready)begin
        inst_req_valid_reg <= 1'b0;
    end
end
always @(posedge clk)begin
    if(~resetn)begin
        data_req_addr_reg <= 32'b0;
        data_req_type_reg <= 3'b0;
    end
    else if(ar_current_state == AR_WAIT && data_sram_req && data_sram_addr_ok && ~data_sram_wr)begin
        data_req_addr_reg <= data_sram_addr;
        data_req_type_reg <= 3'b0;
    end
end
// --------------------------axi master
assign arburst =    2'b01;
assign arlock =     2'b0;
assign arcache =    4'b0;
assign arprot =     3'b0;
assign arsize =     3'b010; // 32 bit per time

// arlen
assign arlen =      ar_current_state == AR_DATA_SEND ?  8'b0 
                                                        : inst_req_type_reg == 3'b100 ? 8'd3: 8'd0;
// arid
assign arid = {2'b0,{ar_current_state == AR_DATA_SEND}};
// arvalid
assign arvalid = (ar_current_state == AR_DATA_SEND) || (ar_current_state == AR_INST_SEND);
// araddr
assign araddr = ar_current_state == AR_DATA_SEND ? data_req_addr_reg
                                                : inst_req_addr_reg;
/*-------------------------------------------------read respond chanel------------------------------------------------------*/
// reg [31:0]          inst_rdata_reg[3:0];
// reg [1:0]           inst_rdata_cnt;
// reg                 rid_reg;

// always @(posedge clk)begin
//     if(~resetn)
//         r_current_state <= R_WAIT;
//     else 
//         r_current_state <= r_next_state;
// end
// ---------------------next_state generate
// always @(*)begin
//     case(r_current_state)
//         R_WAIT:begin
//             if(rvalid)
//                 r_next_state = R_RECIEVE;
//             else
//                 r_next_state = R_WAIT;
//         end
//         R_SEND:begin
//             if(rlast)
//                 r_next_state = R_WAIT;
//             else 
//                 r_next_state = R_RECIEVE;   
//         end
//     endcase
// end
// --------------------axi master
assign rready = 1'b1;
// always @(posedge clk)begin
//     if(~resetn)begin
//         inst_rdata_cnt <= 2'b0;
//     end
//     else if(rvalid & rid == 3'b0)begin
//         inst_rdata_reg[inst_rdata_cnt] <= rdata;
//         inst_rdata_cnt <= inst_rdata_cnt + 1;
//     end
// end





// --------------------sram slave
// always @(posedge clk)begin
//     if(~resetn)begin
//         rdata_reg <= 32'b0;
//         rid_reg <= 1'b0;
//     end
//     else if(r_current_state == R_WAIT && rvalid)begin
//         rdata_reg <= rdata;
//         rid_reg  <= rid;
//     end
//     else if(r_current_state ==R_RECIEVE)begin
//         rdata_reg <= 32'b0;
//         rid_reg <= 1'b0;
//     end
// end
// inst_sram
assign inst_sram_data_ok = (rvalid && rid == 4'b0);
assign inst_sram_rdata = rdata;
assign inst_sram_last = rlast;
// data_sram
assign data_sram_data_ok = (rvalid && rid == 4'b1)
                           |(b_current_state == B_REC);
assign data_sram_rdata = rdata;

/*----------------------------------------------------write data and request chanel----------------------------------------*/
reg [31:0]      awaddr_reg;
reg [3:0]       wstrb_reg;
reg [31:0]      wdata_reg;
always @(posedge clk)begin
    if(~resetn)
        aw_current_state <= AW_WAIT;
    else 
        aw_current_state <= aw_next_state;
end
// ------------------------------next state generate
always @(*)begin
    case(aw_current_state)
        AW_WAIT:begin
            if(data_sram_wr && data_sram_req && data_sram_addr_ok)   // data write request
                aw_next_state = AW_SEND_ADDR;
            else 
                aw_next_state = AW_WAIT;
        end
        AW_SEND_ADDR:begin
            if(awready)
                aw_next_state = AW_SEND_DATA;
            else
                aw_next_state = AW_SEND_ADDR;
        end
        AW_SEND_DATA:begin
            if(wready)
                aw_next_state = AW_WAIT;
            else
                aw_next_state = AW_SEND_DATA;
        end
    endcase
end
/*----------------------------------write request chanel------------------------*/
// ---------------------------sram_like slave
// data_sram_addr_ok is defined in read req chanel
always @(posedge clk)begin
    if(~resetn)begin
        awaddr_reg <= 32'b0;
        wstrb_reg <= 4'b0;
        wdata_reg <= 32'b0;
    end
    else if(aw_current_state == AW_WAIT && data_sram_addr_ok && data_sram_req && data_sram_wr)begin
        awaddr_reg <= data_sram_addr;
        wstrb_reg <= data_sram_wstrb;
        wdata_reg <= data_sram_wdata;
    end
end
// ---------------------------axi master
assign awlen =      8'b0;
assign awsize =     3'b010; // 32 bit per time
assign awburst =    2'b01;
assign awlock =     2'b0;
assign awcache =    4'b0;
assign awprot =     3'b0;
// awid 
assign awid =       4'b1;
// awaddr
assign awaddr = awaddr_reg;
// awvalid
assign awvalid = aw_current_state == AW_SEND_ADDR;
/*----------------------------------write data chanel------------------------*/
// -----------------------------axi master
assign wlast =  1'b1;
// wid
assign wid =    4'b1;
// wstrb
assign wstrb = wstrb_reg;
// wdata
assign wdata = wdata_reg;
// wvalid
assign wvalid = aw_current_state == AW_SEND_DATA;
/*----------------------------------------------------write respond chanel----------------------------------------*/
always @(posedge clk)begin
    if(~resetn)
        b_current_state <= B_WAIT;
    else 
        b_current_state <= b_next_state;
end
// ------------------next_state generate
always @(*)begin
    case (b_current_state)
        B_WAIT:begin
            if(bvalid)
                b_next_state = B_REC;
            else 
                b_next_state <= B_WAIT;
        end
        B_REC:begin
            b_next_state = B_WAIT;
        end
    endcase

end

// -------------------------------sram_like slave
// data_sram_data_ok is defined in read respond chanel
// -------------------------------axi master
// bready
assign bready = (b_current_state == B_WAIT);



endmodule
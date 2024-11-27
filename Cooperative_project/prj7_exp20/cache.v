module cache(
    input clk,
    input resetn,

    input         valid,
    input         op,
    input [ 7:0]  index, 
    input [19:0]  tag, 
    input [ 3:0]  offset,
    input [ 3:0]  wstrb,
    input [31:0]  wdata,
    output        addr_ok,
    output        data_ok,
    output[31:0]  rdata,

    output        rd_req,
    output[ 2:0]  rd_type,
    output[31:0]  rd_addr,
    input         rd_rdy,
    input         ret_valid,
    input         ret_last,
    input [31:0]  ret_data,
    output        wr_req,
    output[ 2:0]  wr_type,
    output[31:0]  wr_addr,
    output[ 3:0]  wr_wstrb,
    output[127:0] wr_data,       
    input         wr_rdy
);

endmodule
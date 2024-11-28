module cache(
    input wire          clk,
    input wire          resetn,
    // input from cpu
    input wire          valid,
    input wire          op,
    input wire [7:0]    index,
    input wire [19:0]   tag,
    input wire [3:0]    offset,
    input wire [3:0]    wstrb,
    input wire [31:0]   wdata,
    // output to cpu
    output wire         addr_ok,
    output wire         data_ok,
    output wire [31:0]  rdata,
    // axi read req
    output wire         rd_req,
    output wire [2:0]   rd_type,
    output wire [31:0]  rd_addr,
    input wire          rd_rdy,
    // axi read ret
    input wire          ret_valid,
    input wire [1:0]    ret_last,
    input wire [31:0]   ret_data,
    // asi write req
    output wire         wr_req,
    output wire [31:0]  wr_addr,
    output wire [127:0] wr_data,
    // axi write ret
    input wire          wr_rdy
);
    parameter IDLE 		= 5'b00001;
    parameter LOOKUP 	= 5'b00010;
    parameter MISS 		= 5'b00100;
    parameter REPLACE 	= 5'b01000;
    parameter REFILL 	= 5'b10000; 
    parameter WR_IDLE   = 2'b01;
    parameter WR_WRITE  = 2'b10;

    reg [4:0] main_current_state;
    reg [4:0] main_next_state;
    reg [1:0] wr_current_state;
    reg [1:0] wr_next_state;

    wire hit_write_conflict;//hit write 冲突信号，暂时先放着，还没实现

//main state machine
    always @(posedge clk) begin
        if(~resetn) begin
            main_current_state <= IDLE;
        end
        else begin
            main_current_state <= main_next_state;
        end
    end

    always @(*) begin
        case (main_current_state)
            IDLE: 
                if(valid & ~hit_write_conflict)
                    main_next_state = LOOKUP;
                else
                    main_next_state = IDLE;

            LOOKUP:
                if(cache_hit &  hit_write_conflict)
                    main_next_state = IDLE;
                else if(~cache_hit)
                    main_next_state = MISS;
                else
                    main_next_state = LOOKUP;

            MISS:
                if(~wr_rdy)
                    main_next_state = MISS;
                else
                    main_next_state = REPLACE;

            REPLACE:
                if(~rd_rdy)
                    main_next_state = REPLACE;
                else
                    main_next_state = REFILL;

            REFILL:
                if(ret_valid & ret_last[0])
                    main_next_state = IDLE;
                else
                    main_next_state = REFILL;

            default: 
                main_next_state = IDLE;
        endcase
    end

endmodule
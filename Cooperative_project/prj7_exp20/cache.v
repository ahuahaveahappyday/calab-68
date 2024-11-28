module d_regfile(
	input wire         clk,
	input wire [  7:0] addr,
	input wire         wen,
	input wire         wdata,
	output wire        rdata
);
	reg  [255 : 0] array;
	always @(posedge clk)
	begin
		if(wen)
			array[addr] <= wdata;
	end

assign rdata = array[addr];

endmodule
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
    wire cache_hit;

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
    /*--------------------------------------------INSTANTIATION table of reg and ram ----------------------------------------------*/
    genvar i;
    // data table
    wire [31:0] way0_data [3:0];
    generate
        for (i = 0; i < 4; i = i + 1)begin: data_way0
            data_bank_ram data_way0(
                .clka   (clk),    // input wire clka
                .wea    (),      // input wire [3 : 0] wea
                .addra  (index),  // input wire [7 : 0] addra
                .dina   (),    // input wire [31 : 0] dina
                .douta  (way0_data[i])  // output wire [31 : 0] douta
            );
        end
    endgenerate
    wire [31:0] way1_data [3:0];
    generate
        for (i = 0; i < 4; i = i + 1)begin: data_way1
            data_bank_ram data_way1(
                .clka   (clk),    // input wire clka
                .wea    (),      // input wire [3 : 0] wea
                .addra  (index),  // input wire [7 : 0] addra
                .dina   (),    // input wire [31 : 0] dina
                .douta  (way1_data[i])  // output wire [31 : 0] douta
            );
        end
    endgenerate
    // tag, v table
    wire            way0_v;
    wire [19:0]     way0_tag;
    tagv_ram tagv_ram_way0 (
        .clka   (clk),    // input wire clka
        .wea    (),      // input wire [2 : 0] wea
        .addra  (index),  // input wire [7 : 0] addra
        .dina   (),    // input wire [23 : 0] dina
        .douta  ({3'b0,way0_tag,way0_v})  // output wire [23 : 0] douta
    );
    wire            way1_v;
    wire [19:0]     way1_tag;
    tagv_ram tagv_ram_way1 (
        .clka   (clk),    // input wire clka
        .wea    (),      // input wire [2 : 0] wea
        .addra  (index),  // input wire [7 : 0] addra
        .dina   (),    // input wire [23 : 0] dina
        .douta  ({3'b0,way1_tag,way1_v})  // output wire [23 : 0] douta
    );
    // dtable
    d_regfile d_way0(
        .clk        (),
        .addr      (),
        .wen        (),
        .wdata      (),
        .rdata      ()
    );
    d_regfile d_way1(
        .clk        (),
        .addr      (),
        .wen        (),
        .wdata      (),
        .rdata      ()
    );
    /*------------------------------------------other data path -------------------------------------------------------------------*/
    // requeset buffer
    reg         req_op;
    reg [7:0]   req_index;
    reg [19:0]  req_tag;
    reg [3:0]   req_offset;
    reg [3:0]   req_wstrb;
    reg [31:0]  req_wdata;

    always @(posedge clk)begin
        if(~resetn) begin
            req_op <=       1'b0;
            req_index <=    8'b0;
            req_tag <=      20'b0;
            req_offset <=   4'b0;
            req_wstrb <=    4'b0;
            req_wdata <=    32'b0;
        end
        else if(valid)begin
            req_op <=       op;
            req_index <=    index;
            req_tag <=      tag;
            req_offset <=   offset;
            req_wstrb <=    wstrb;
            req_wdata <=    wdata;       
        end
    end
    // tag compare
    wire        way0_hit;
    wire        way1_hit;
    assign way0_hit = way0_v && (way0_tag == req_tag);
    assign way1_hit = way1_v && (way1_tag == req_tag);
    assign cache_hit = way0_hit || way1_hit;
    // data select
    wire [31:0]     way0_load_word;
    wire [31:0]     way1_load_word;
    wire [31:0]     load_res;
    wire [255:0]    replace_data;
    wire            replace_way;

    assign way0_load_word = way0_data[offset[3:2]];
    assign way1_load_word = way1_data[offset[3:2]];

    assign load_res =   {32{way0_hit}} & way0_load_word
                        |{32{way1_hit}} & way1_load_word;
    assign replace_data =   replace_way ? {way0_data[3], way0_data[2], way0_data[1], way0_data[0]} 
                            :{way1_data[3], way1_data[2], way1_data[1], way1_data[0]}  ;
    // miss buffer

    // LFSR
    reg [7:0]   lfsr;
    wire feedback;
    assign feedback = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];

    always @(posedge clk)begin
        if(~resetn)
            lfsr <= 8'b00000001;
        else
            lfsr <= {lfsr[6:0], feedback};
    end
    // write buffer




endmodule


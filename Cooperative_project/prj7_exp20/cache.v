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
    output wire [2:0]   wr_type,
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
// requeset buffer
    reg         req_buffer_op;
    reg [7:0]   req_buffer_index;
    reg [19:0]  req_buffer_tag;
    reg [3:0]   req_buffer_offset;
    reg [3:0]   req_buffer_wstrb;
    reg [31:0]  req_buffer_wdata;
// write buffer
    reg  [7:0]  w_buffer_index;
    reg         w_buffer_way;
    reg  [3:0]  w_buffer_wstrb;
    reg  [31:0] w_buffer_wdata;
    reg  [1:0]  w_buffer_bank;















    wire hit_write_conflict;//hit write 冲突信号，暂时先放着，还没实现
    wire cache_hit;

    assign hit_write_conflict =     (main_current_state == LOOKUP & ~op
                                        & {tag, index, offset[3:2]} == {req_buffer_tag, req_buffer_index, req_buffer_offset[3:2]})
                                    |(wr_current_state == WR_WRITE & ~op
                                        & offset[3:2] == req_buffer_offset[3:2]);


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
                if(cache_hit & (~valid | hit_write_conflict))
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
// wirte buffer state machine
    always @(posedge clk) begin
        if(~resetn) begin
            wr_current_state <= IDLE;
        end
        else begin
            wr_current_state <= wr_next_state;
        end
    end
    always @(*)begin
        case (wr_current_state)
            WR_IDLE:
                if(main_current_state == LOOKUP && req_buffer_op && cache_hit)
                    wr_next_state <= WR_WRITE;
                else
                    wr_next_state <= wr_current_state;
            WR_WRITE:
                if(main_current_state == LOOKUP && req_buffer_op && cache_hit)
                    wr_next_state <= WR_WRITE;
                else
                    wr_next_state <= wr_current_state;
            default: 
                main_next_state = WR_IDLE;
        endcase
    end

    /*--------------------------------------------INSTANTIATION table of reg and ram ----------------------------------------------*/
    genvar i;
    // data table
    wire [3:0]  data_way0_wen;
    wire [31:0] data_way0_wdata;
    wire [31:0] way0_data [3:0];
    wire [7:0]  data_way0_index;

    assign data_way0_wen = (wr_current_state == WR_WRITE && w_buffer_way == 0) ? (4'b1 << w_buffer_bank) : 4'b0;
    assign data_way0_wdata =  w_buffer_wdata;
    assign data_way0_index = (wr_current_state == WR_WRITE) ? w_buffer_index : index;
    generate
        for (i = 0; i < 4; i = i + 1)begin: data_way0
            data_bank_ram data_way0(
                .clka   (clk),
                .wea    (data_way0_wen[i]),   
                .addra  (index),
                .dina   (data_way0_wdata),
                .douta  (way0_data[i])  // output when lookup
            );
        end
    endgenerate
    wire [3:0]  data_way1_wen;
    wire [31:0] data_way1_wdata;
    wire [31:0] way1_data [3:0];

    assign data_way1_wen = (wr_current_state == WR_WRITE && w_buffer_way == 1) ? (4'b1 << w_buffer_bank) : 4'b0;
    assign data_way1_wdata =  w_buffer_wdata;
    generate
        for (i = 0; i < 4; i = i + 1)begin: data_way1
            data_bank_ram data_way1(
                .clka   (clk),
                .wea    (data_way1_wen[i]),
                .addra  (index),
                .dina   (data_way1_wdata),
                .douta  (way1_data[i])  // output when lookup
            );
        end
    endgenerate
    // tag, v table
    wire            tagv_way0_wen;
    wire            way0_v;
    wire [19:0]     way0_tag;
    wire [20:0]     tagv_way0_wdata;

    assign tagv_way0_wen = 0;
    tagv_ram tagv_ram_way0 (
        .clka   (clk), 
        .wea    (tagv_way0_wen),
        .addra  (index),
        .dina   (),
        .douta  ({3'b0,way0_tag,way0_v})// output when lookup
    );
    wire            tagv_way1_wen;
    wire            way1_v;

    assign           tagv_way1_wen = 0;
    wire [19:0]     way1_tag;
    tagv_ram tagv_ram_way1 (
        .clka   (clk),
        .wea    (tagv_way1_wen),  
        .addra  (index), 
        .dina   (),
        .douta  ({3'b0,way1_tag,way1_v})// output when lookup
    );
    // dtable
    wire d_way0_wen;
    wire d_way0_wdata;
    wire way0_d;

    assign d_way0_wen = wr_current_state == WR_WRITE && w_buffer_way == 0;
    assign d_way0_wdata =  wr_current_state == WR_WRITE;
    d_regfile d_way0(
        .clk        (clk),
        .addr       (),
        .wen        (d_way0_wen),
        .wdata      (d_way0_wdata),
        .rdata      (way0_d)
    );
    wire d_way1_wen;
    wire d_way1_wdata;
    wire way1_d;

    assign d_way1_wen = wr_current_state == WR_WRITE && w_buffer_way == 1;
    assign d_way1_wdata =  wr_current_state == WR_WRITE;
    d_regfile d_way1(
        .clk        (clk),
        .addr       (),
        .wen        (d_way1_wen),
        .wdata      (d_way1_wdata),
        .rdata      (way1_d)
    );
    /*------------------------------------------other data path -------------------------------------------------------------------*/
    // requeset buffer
    always @(posedge clk)begin
        if(~resetn) begin
            req_buffer_op <=       1'b0;
            req_buffer_index <=    8'b0;
            req_buffer_tag <=      20'b0;
            req_buffer_offset <=   4'b0;
            req_buffer_wstrb <=    4'b0;
            req_buffer_wdata <=    32'b0;
        end
        else if(main_current_state == IDLE & valid & ~hit_write_conflict 
                | main_current_state == LOOKUP & cache_hit & valid & ~hit_write_conflict)begin      // next_state == LOOKUP
            req_buffer_op <=       op;
            req_buffer_index <=    index;
            req_buffer_tag <=      tag;
            req_buffer_offset <=   offset;
            req_buffer_wstrb <=    wstrb;
            req_buffer_wdata <=    wdata;       
        end
    end
    // tag compare
    wire        way0_hit;
    wire        way1_hit;
    assign way0_hit = way0_v && (way0_tag == req_buffer_tag);
    assign way1_hit = way1_v && (way1_tag == req_buffer_tag);
    assign cache_hit = way0_hit || way1_hit;
    // data select
    wire [31:0]     way0_load_word;
    wire [31:0]     way1_load_word;
    wire [31:0]     load_res;
    wire [255:0]    replace_data;
    wire            replace_way;
    wire            replace_d;

    assign way0_load_word = way0_data[offset[3:2]];
    assign way1_load_word = way1_data[offset[3:2]];

    assign load_res =   {32{way0_hit}} & way0_load_word
                        |{32{way1_hit}} & way1_load_word;
    assign replace_data =   replace_way ? {way1_data[3], way1_data[2], way1_data[1], way1_data[0]} 
                            :{way0_data[3], way0_data[2], way0_data[1], way0_data[0]}  ;
    assign replace_d =  replace_data ? way1_d: way0_d;
    // miss buffer
    reg [31:0]   miss_buffer_data [3:0];
    reg [1:0]    miss_buffer_cnt;
    always @(posedge clk)begin
        if(~resetn)begin
            miss_buffer_cnt <= 2'b0;
            miss_buffer_data[0] <= 32'b0;
            miss_buffer_data[1] <= 32'b0;
            miss_buffer_data[2] <= 32'b0;
            miss_buffer_data[3] <= 32'b0;
        end
        else if(main_current_state == MISS)
            ;
    
    end
    assign wr_req =     (main_current_state == MISS) & replace_d & wr_rdy;
    assign wr_data =    replace_data;
    assign wr_addr =    {req_buffer_tag, req_buffer_index, 4'b0};
    

    assign rd_req =     main_current_state == MISS & wr_rdy;    // next_state == replace
    assign rd_type =    3'b100;

    // LFSR
    reg [7:0]   lfsr;
    wire feedback;
    assign feedback = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];

    always @(posedge clk)begin
        if(~resetn)
            lfsr <= 8'b00000001;
        else if(main_current_state == REFILL & ret_valid & ret_last[0] )
            lfsr <= {lfsr[6:0], feedback};
    end
    assign replace_way =    lfsr[0];
    // write buffer
    always @(posedge clk)begin
        if(~resetn) begin
            w_buffer_index <= 8'b0;
            w_buffer_way <= 1'b0;
            w_buffer_wstrb <= 4'b0;
            w_buffer_wdata <= 32'b0;
        end else if(main_current_state == LOOKUP && req_buffer_op && cache_hit) begin
            w_buffer_index <= req_buffer_index;
            w_buffer_way <= way0_hit ? 0 : 1;
            w_buffer_wstrb <= req_buffer_wstrb;
            w_buffer_wdata <= req_buffer_wdata;
            w_buffer_bank <= req_buffer_offset[3:2];
        end
    end




endmodule


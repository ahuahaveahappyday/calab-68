module d_regfile(
	input wire         clk,
    input wire         resetn,
	input wire [  7:0] addr,
	input wire         wen,
	input wire         wdata,
	output wire        rdata
);
	reg  [255 : 0] array;
	always @(posedge clk)
	begin
        if(~resetn)
            array <= 256'b0;
		else if(wen)
			array[addr] <= wdata;
	end

assign rdata = array[addr];

endmodule
module tagv_regfile(
    input wire         clka,
    input wire         resetn,
	input wire [  7:0] addra,
	input wire         wea,
	input wire [20:0]  dina,
	output reg [20:0]  douta
);
	reg  [20 : 0] array [255:0];
    integer i;
    always @(posedge clka) begin
        if (~resetn) begin
            // 复位时清零整个数组
            for (i = 0; i < 256; i = i + 1) begin
                array[i] <= 21'b0;
            end
        end else if (wea) begin
            // 写操作
            array[addra] <= dina;
        end
    end
    always @(posedge clka)begin
        if(~resetn)
            douta <= 21'b0;
        else
            douta <= array[addra];
    end

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
    input wire          ret_last,
    input wire [31:0]   ret_data,
    // asi write req
    output wire         wr_req,
    output wire [2:0]   wr_type,
    output wire [31:0]  wr_addr,
    output wire [3:0]   wr_wstrb,
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

// data select
    wire [31:0]     way0_load_word;
    wire [31:0]     way1_load_word;
    wire [31:0]     load_hit_res;
    wire [255:0]    replace_data;
    wire            replace_way;
    wire            replace_d;
    wire            replace_v;
// miss buffer
    // reg          miss_buffer_d;
    // reg [7:0]    miss_buffer_tag;
    // reg [255:0]  miss_buffer_data;
    reg [31:0]   load_miss_res;
    reg [1:0]    miss_buffer_cnt;
    reg          first_clk_of_replace;

// data table
    wire [3:0]  data_way0_wen[3:0];
    wire [31:0] data_way0_wdata;
    wire [31:0] way0_data [3:0];
    wire [7:0]  data_way0_index [3:0];
    wire [3:0]  data_way1_wen[3:0];
    wire [31:0] data_way1_wdata;
    wire [31:0] way1_data [3:0];
    wire [7:0]  data_way1_index [3:0];
// tag, v table
    wire [7:0]      tagv_way0_index;
    wire            tagv_way0_wen;
    wire            way0_v;
    wire [19:0]     way0_tag;
    wire [20:0]     tagv_way0_wdata;
    wire [7:0]      tagv_way1_index;
    wire            tagv_way1_wen;
    wire            way1_v;
    wire [19:0]     way1_tag;
    wire [20:0]     tagv_way1_wdata;
// dtable
    wire [7:0]      d_way0_index;
    wire            d_way0_wen;
    wire            d_way0_wdata;
    wire            way0_d;
    wire [7:0]      d_way1_index;
    wire            d_way1_wen;
    wire            d_way1_wdata;
    wire            way1_d;

    wire hit_write_conflict;
    wire cache_hit;

    assign hit_write_conflict =     (main_current_state == LOOKUP & ~op
                                        & {tag, index, offset[3:2]} == {req_buffer_tag, req_buffer_index, req_buffer_offset[3:2]})
                                    |(wr_current_state == WR_WRITE & ~op
                                        & offset[3:2] == req_buffer_offset[3:2]);

    assign addr_ok =    main_current_state == LOOKUP & cache_hit & ~hit_write_conflict
                        |main_current_state == IDLE & ~hit_write_conflict;
    assign data_ok =    (main_current_state == REFILL & ret_valid & miss_buffer_cnt == req_buffer_offset[3:2] & ~req_buffer_op)         // read miss
                        |(main_current_state == LOOKUP & (cache_hit | req_buffer_op));             // hit or write
    assign rdata =      main_current_state == LOOKUP & cache_hit ? load_hit_res     // read hit
                        : ret_data;       // read miss

    
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
                if(ret_valid & ret_last)
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
                    wr_next_state <= WR_IDLE;
            WR_WRITE:
                if(main_current_state == LOOKUP && req_buffer_op && cache_hit)
                    wr_next_state <= WR_WRITE;
                else
                    wr_next_state <= WR_IDLE;
            default: 
                wr_next_state = WR_IDLE;
        endcase
    end

    /*--------------------------------------------INSTANTIATION table of reg and ram ----------------------------------------------*/
    genvar i;
    // data table
    wire [31:0] store_res;
    wire [31:0] store_mask;
    assign store_mask = {{8{req_buffer_wstrb[3]}}, {8{req_buffer_wstrb[2]}}, {8{req_buffer_wstrb[1]}}, {8{req_buffer_wstrb[0]}}};
    assign store_res =      store_mask & req_buffer_wdata
                            | ~store_mask & ret_data; 


    assign data_way0_wdata =        wr_current_state == WR_WRITE ? w_buffer_wdata
                                    : (miss_buffer_cnt == req_buffer_offset[3:2] & req_buffer_op) ? store_res 
                                    : ret_data;

    generate
        for (i = 0; i < 4; i = i + 1)begin: data_way0
            assign data_way0_index[i] = (wr_current_state == WR_WRITE && w_buffer_bank == i) ? w_buffer_index //hit write 
                                        :(main_current_state == LOOKUP || main_current_state == IDLE) ? index   // look up
                                        :req_buffer_index;      // replace and refill
            assign data_way0_wen[i] =    (wr_current_state == WR_WRITE & w_buffer_way == 0 & w_buffer_bank == i)? w_buffer_wstrb
                                        :(main_current_state == REFILL & replace_way ==0 & ret_valid & miss_buffer_cnt == i) ? 4'b1111
                                        :4'b0000;
            data_bank_ram data_way0(
                .clka   (clk),
                .wea    (data_way0_wen[i]),   
                .addra  (data_way0_index[i]),
                .dina   (data_way0_wdata),
                .douta  (way0_data[i])  
            );
        end
    endgenerate

    assign data_way1_wdata =        wr_current_state == WR_WRITE ? w_buffer_wdata
                                    : (miss_buffer_cnt == req_buffer_offset[3:2] & req_buffer_op) ? store_res 
                                    : ret_data;
    generate
        for (i = 0; i < 4; i = i + 1)begin: data_way1
            assign data_way1_index[i] = (wr_current_state == WR_WRITE && w_buffer_bank == i) ? w_buffer_index //hit write 
                                        :(main_current_state == LOOKUP || main_current_state == IDLE) ? index   // look up
                                        :req_buffer_index;      // replace and refill
            assign data_way1_wen[i] =    (wr_current_state == WR_WRITE & w_buffer_way == 1 & w_buffer_bank == i) ? w_buffer_wstrb
                                        :(main_current_state == REFILL & replace_way ==1 & ret_valid & miss_buffer_cnt == i) ? 4'b1111
                                        :4'b0000;
            data_bank_ram data_way1(
                .clka   (clk),
                .wea    (data_way1_wen[i]),
                .addra  (data_way1_index[i]),
                .dina   (data_way1_wdata),
                .douta  (way1_data[i])  
            );
        end
    endgenerate
    // tag, v table
    assign tagv_way0_index =    (main_current_state == LOOKUP || main_current_state == IDLE) ? index   // look up
                                :req_buffer_index;      // replace and refill;
    assign tagv_way0_wen =  main_current_state == REFILL & replace_way == 0 & ret_valid & ret_last;
    assign tagv_way0_wdata = {req_buffer_tag, 1'b1};
    tagv_regfile tagv_ram_way0 (
        .clka   (clk),
        .resetn  (resetn),
        .wea    (tagv_way0_wen),
        .addra  (tagv_way0_index),
        .dina   ({tagv_way0_wdata}),
        .douta  ({way0_tag,way0_v})// output when lookup
    );

    assign tagv_way1_index =    (main_current_state == LOOKUP || main_current_state == IDLE) ? index   // look up
                                :req_buffer_index;      // replace and refill;
    assign tagv_way1_wen =      main_current_state == REFILL & replace_way == 1 & ret_valid & ret_last;
    assign tagv_way1_wdata =    {req_buffer_tag, 1'b1};
    tagv_regfile tagv_ram_way1 (
        .clka   (clk),
        .resetn (resetn),
        .wea    (tagv_way1_wen),  
        .addra  (tagv_way1_index), 
        .dina   ({tagv_way1_wdata}),
        .douta  ({way1_tag,way1_v})// output when lookup
    );
    // dtable
    assign d_way0_index =   (wr_current_state == WR_WRITE) ? w_buffer_index // hit write
                            : req_buffer_index;     // replace and refill
    assign d_way0_wen =     wr_current_state == WR_WRITE & w_buffer_way == 0
                            |main_current_state == REFILL & replace_way == 0 & ret_valid & ret_last;
    assign d_way0_wdata =   wr_current_state == WR_WRITE;
    d_regfile d_way0(
        .clk        (clk),
        .resetn     (resetn),
        .addr       (d_way0_index),
        .wen        (d_way0_wen),
        .wdata      (d_way0_wdata),
        .rdata      (way0_d)
    );
    assign d_way1_index =   (wr_current_state == WR_WRITE) ? w_buffer_index // hit write
                            : req_buffer_index;         // replace and refill
    assign d_way1_wen =     wr_current_state == WR_WRITE & w_buffer_way == 1
                            |main_current_state == REFILL & replace_way == 1 & ret_valid & ret_last;
    assign d_way1_wdata =   wr_current_state == WR_WRITE;
    d_regfile d_way1(
        .clk        (clk),
        .resetn     (resetn),
        .addr       (d_way1_index),
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
    wire [19:0] replace_tag;

    assign way0_hit = way0_v && (way0_tag == req_buffer_tag);
    assign way1_hit = way1_v && (way1_tag == req_buffer_tag);
    assign cache_hit = way0_hit || way1_hit;
    // data select
    assign way0_load_word = way0_data[req_buffer_offset[3:2]];
    assign way1_load_word = way1_data[req_buffer_offset[3:2]];

    assign load_hit_res =   {32{way0_hit}} & way0_load_word
                            |{32{way1_hit}} & way1_load_word;
    assign replace_data =   replace_way ? {way1_data[3], way1_data[2], way1_data[1], way1_data[0]} 
                            :{way0_data[3], way0_data[2], way0_data[1], way0_data[0]}  ;
    assign replace_d =  replace_data ? way1_d: way0_d;
    assign replace_tag = replace_way ? way1_tag : way0_tag;
    assign replace_v =  replace_way ? way1_v : way0_v;
    // miss buffer
    // always @(posedge clk)begin
    //     if(~resetn)begin
    //         miss_buffer_d <= 1'b0;
    //         miss_buffer_tag <= 8'b0;
    //         miss_buffer_data <= 256'b0;
    //     end
    //     else if(first_clk_of_replace)begin   // next state == replace
    //         miss_buffer_d <=    replace_d;
    //         miss_buffer_tag <=  replace_tag;
    //         miss_buffer_data <= replace_data;
    //     end
    // end
    always@(posedge clk)begin
        if(~resetn)begin
            load_miss_res <= 32'b0;
        end
        else if(main_current_state == REFILL & ret_valid & miss_buffer_cnt == req_buffer_offset[3:2])begin
            load_miss_res <= ret_data;
        end
    end
    always @(posedge clk)begin
        if(~resetn)begin
            miss_buffer_cnt <= 2'b0;
        end
        else if(main_current_state == REFILL & ret_valid)begin
            miss_buffer_cnt <= miss_buffer_cnt + 1;
        end
        else if(main_current_state == REFILL & ret_valid & ret_last)begin
            miss_buffer_cnt <= 2'b0;
        end
    end
    always @(posedge clk)begin
        if(~resetn)begin
            first_clk_of_replace <= 1'b0;
        end
        else if(main_current_state == MISS & wr_rdy)begin
            first_clk_of_replace <= 1'b1;
        end
        else begin
            first_clk_of_replace <= 1'b0;
        end
    end

    assign wr_req =     first_clk_of_replace & replace_d & replace_v;
    assign wr_data =    replace_data;
    assign wr_addr =    {replace_tag, req_buffer_index, 4'b0};
    assign wr_type =    3'b100;
    assign wr_wstrb =    4'b1111;
    

    assign rd_req =     main_current_state == REPLACE;    // next_state == replace
    assign rd_addr =    {req_buffer_tag, req_buffer_index, 4'b0};
    assign rd_type =    3'b100;

    // LFSR
    reg [7:0]   lfsr;
    wire feedback;
    assign feedback = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];

    always @(posedge clk)begin
        if(~resetn)
            lfsr <= 8'b00000001;
        else if(main_current_state == REFILL & ret_valid & ret_last)
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
            w_buffer_bank <= 2'b0;
        end else if(main_current_state == LOOKUP && req_buffer_op && cache_hit) begin
            w_buffer_index <= req_buffer_index;
            w_buffer_way <= way0_hit ? 0 : 1;
            w_buffer_wstrb <= req_buffer_wstrb;
            w_buffer_wdata <= req_buffer_wdata;
            w_buffer_bank <= req_buffer_offset[3:2];
        end
    end




endmodule
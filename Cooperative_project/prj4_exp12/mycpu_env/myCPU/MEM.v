module MEMreg(
    input  wire        clk,
    input  wire        resetn,
    //mem与ex模块交互接口
    output wire        mem_allowin,
    input  wire        ex_to_mem_valid,
    input  wire [107:0]ex_to_mem_bus, 
    //mem与wb模块交互接口
    input  wire        wb_allowin,
    output wire        mem_to_wb_valid,
    output wire [69:0] mem_to_wb_bus, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata, mem_pc}
    //mem与id模块交互接口
    output wire [37:0] mem_to_id_bus, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata}
    //mem与dram交互接口
    input  wire [31:0] data_sram_rdata

);
//MEM模块需要的寄存器，寄存当前时钟周期的信号
//定义方式与EX模块一致 此处不再赘述
    reg  [31:0] mem_pc;
    reg         mem_valid;
    reg  [31:0] mem_alu_result; //寄存的alu的运算结果
    reg         mem_res_from_mem;//load指令信号
    reg         mem_rf_we;
    reg  [4 :0] mem_rf_waddr;
    reg  [31:0] mem_rkd_value;//源寄存器2读出的值
    reg  [1:0]  mem_data_sram_addr;
    // reg  [3:0]  mem_ld_st_type;     // ld.b: 0x0000 ; ld.h: 0x0001; ld.w: 0010; ld.bu: 0x1000; ld.hu: 0x1001; 
                                    // st.b: 0x01000; st.h: 0x0101; st.w: 0x0110
    reg         mem_op_st_ld_b;
    reg         mem_op_st_ld_h;
    reg         mem_op_st_ld_u;


    wire        mem_ready_go;
    wire [31:0] mem_rf_wdata;
    wire [31:0] mem_result;//从dram读出的数据
    wire [31:0] mem_word_result;
    wire [15:0] mem_half_result;
    wire [8:0] mem_byte_result;

//流水线控制信号
    assign mem_ready_go      = 1'b1;
    assign mem_allowin       = ~mem_valid | mem_ready_go & wb_allowin;     
    assign mem_to_wb_valid   = mem_valid & mem_ready_go;

//MEM流水级需要的寄存器，根据clk不断更新
    always @(posedge clk) begin
        if(~resetn)
            mem_valid <= 1'b0;
        else
            mem_valid <= ex_to_mem_valid & mem_allowin; 
    end
    always @(posedge clk) begin
        if(~resetn) begin
            {mem_pc,mem_res_from_mem, mem_rf_we, mem_rf_waddr, 
            mem_alu_result,mem_rkd_value, mem_data_sram_addr, mem_op_st_ld_b, mem_op_st_ld_h, mem_op_st_ld_u} <= 137'b0;
        end
        if(ex_to_mem_valid & mem_allowin) begin
            {mem_pc,mem_res_from_mem, mem_rf_we, mem_rf_waddr, 
            mem_alu_result,mem_rkd_value, mem_data_sram_addr, mem_op_st_ld_b, mem_op_st_ld_h, mem_op_st_ld_u} <= ex_to_mem_bus;
        end
    end

//模块间通信
    //与内存交互接口定义
    assign mem_word_result =    data_sram_rdata;
    assign mem_half_result =    mem_data_sram_addr[1] ? data_sram_rdata[31:16]
                                : data_sram_rdata[15:0];
    assign mem_byte_result =    ({8{mem_data_sram_addr[1:0] == 2'd0}} & data_sram_rdata[7:0])
                                |({8{mem_data_sram_addr[1:0] == 2'd1}} & data_sram_rdata[15:8])
                                |({8{mem_data_sram_addr[1:0] == 2'd2}} & data_sram_rdata[23:16])
                                |({8{mem_data_sram_addr[1:0] == 2'd3}} & data_sram_rdata[31:24]);

    assign mem_result =         mem_op_st_ld_b ? ({{24{~mem_op_st_ld_u & mem_byte_result[7]}}, mem_byte_result[7:0]}):       // mem_ld_st_type[3] identify if signed externed
                                mem_op_st_ld_h ? ({{16{~mem_op_st_ld_u & mem_half_result[15]}}, mem_half_result[15:0]}) :
                                mem_word_result;
    //assign data_sram_wdata= mem_rkd_value;
    //打包
    assign mem_rf_wdata = mem_res_from_mem ? mem_result : mem_alu_result;//生成寄存器写回的值
    assign mem_to_id_bus  = {mem_rf_we & mem_valid, mem_rf_waddr, mem_rf_wdata};
    assign mem_to_wb_bus  = {mem_rf_we & mem_valid, mem_rf_waddr, mem_rf_wdata, mem_pc};
endmodule
module csrfile(
    input  wire        clk,
    // inst port
    input wire          csr_re,         // read_enable
    input wire  [4:0]   csr_num,        // num of csr, address
    output wire [31:0]  csr_rvalue,

    input wire          csr_we,
    input wire  [31:0]  csr_wmask,
    input wire  [31:0]  csr_wvalue

    // hardware port
    //TODO

);
//TODO

endmodule

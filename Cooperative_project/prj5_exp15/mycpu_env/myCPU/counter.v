module Stable_Counter(
    input  wire        clk,
    input  wire        resetn,
    
    output wire [63:0] counter
);

reg [63:0] time_counter;

always @(posedge clk)begin
    if(~resetn)
        time_counter <= 64'b0;
    else
        time_counter <= time_counter + 1'b1;
end

assign counter = time_counter;

endmodule

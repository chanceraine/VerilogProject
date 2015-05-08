module prefetcher(input clk,
	input [15:0]pc,
	input memAccess,
	input [15:0]memAddress,

	output memRequest,
	output [15:0]requestAddress
	);
	
	//look-ahead pc
	reg [15:0]laPC = 0;

	//32 entry reference predictor table
	//[1:0] = state
	//[15:2] = stride (lots of stride space)
	//[31:16] = prev address accessed
	//[37:32] = tag (lower bits of pc)
	reg [37:0]rpt[31:0];

	//initialize all entries
	integer i;
	initial begin
		for(i=0;i<32;i = i+1) begin
			rpt[i] <= 0;
		end
	end


endmodule
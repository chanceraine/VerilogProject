module bPredictor(input clk,
	input [15:0]laPC,
	output [15:0]address,

	input branch,
	input [15:0]branchPC,
	input [15:0]branchAddr,
	output firstHit
	);

	//reading
	wire [4:0]index = laPC[4:0];
	wire [10:0]tag = laPC[15:5];
	wire [1:0]state = pTable[index][1:0];

	wire [15:0]address = (state > 0) ? pTable[index][17:2] : 16'hFFFF;

	//writing
	wire [4:0]wIndex = branchPC[4:0];

	wire [15:0]ptable6 = pTable[6];
	wire firstHit = (pTable[wIndex] == 0) && branch;

	wire [28:0]writeValue;
	assign writeValue[28:18] = brachPC[15:5];
	assign writeValue[17:2] = branchAddr;
	assign writeValue[1:0] = 1;

	//32 entry table
	// [28:18] = tag
	// [17:2] = addr
	// [1:0] = state
	reg [28:0]pTable[31:0];

	integer i;
	initial begin
		for(i = 0; i < 32; i = i+1) begin
			pTable[i] <= 0;
		end
	end

	always @(posedge clk) begin
		if(branch) begin
			pTable[wIndex] <= writeValue;
		end
	end

endmodule
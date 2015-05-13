module bPredictor(input clk,
	input request,
	input [15:0]pc,
	output [15:0]address,

	input branch,
	input [15:0]brachPC,
	input [15:0]branchAddr
	);

	//reading
	wire [4:0]index = address[4:0];
	wire [10:0]tag = address[15:5];

	wire [1:0]state = wIndex[index][1:0];
	wire [15:0]address = (state > 0)  ? wIndex[index][17:2] : 16'hFFFF;

	//writing
	wire [4:0]wIndex = address[4:0];

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
			pTable[i] = 0;
		end
	end

	always @(posedge clk) begin
		if(branch) begin
			pTable[wIndex] <= writeValue;
		end
	end

endmodule
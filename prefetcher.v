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
	//[43:32] = tag (lower bits of pc)
	//[43:43] = valid
	reg [43:0]rpt[31:0];

	wire memRequest = 0;
	wire [15:0]requestAddress = 0;

	pcTag = pc[15:5];
	pcIndex = pc[4:0];

	wire [43:0]pcEntry = orl[pc];
	wire pcEntryV = pcEntry[43:43];
	wire pcEntryTag = pcEntry[42:32];
	wire pcEntryAddr = pcEntry[31:16];
	wire pcEntryStride = pcEntry[15:2];
	wire pcEntryState = pcEntry[1:0];

	wire [43:0]init;
	assign init[43:43] = 1;
	assign init[42:32] = pcEntryTag;
	assign init[31:16] = memAddress;
	assign init[15:2] = 0;
	assign init[1:0] = 0;

	wire [43:0]transient;
	assign transient[43:43] = 1;
	assign transient[42:32] = pcEntryTag;
	assign transient[31:16] = memAddress;
	assign transient[15:2] = memAddress - pcEntryAddr;
	assign transient[1:0] = 1;

	wire [43:0]stable;
	assign stable[43:43] = 1;
	assign stable[42:32] = pcEntryTag;
	assign stable[31:16] = memAddress;
	assign stable[15:2] = memAddress - pcEntryAddr;
	assign stable[1:0] = 2;
	
	wire [43:0]none;
	assign none[43:43] = 1;
	assign none[42:32] = pcEntryTag;
	assign none[31:16] = memAddress;
	assign none[15:2] = memAddress - pcEntryAddr;
	assign none[1:0] = 2;
	wire [43:0]laPCEntry = orl[laPC];
	wire laPCEntryV = laPCEntry[43:43];

    always @(posedge clk) begin
    	if(memAccess) begin
    		if(pcTag == pcEntryTag)) begin
    			//seen this address before
    			if(pcEntryState == 1) begin
    				//no judgement can be made yet
    				//
    				rpt[pcIndex] <= stateChange;
    			end
    			else if(pcEntryState == 2) begin
    				//
    				
    			end
    			else if(pcEntryState == 3) begin
    				
    			end
    			//initiate prefetch
    		end
    		//haven't seen before, make new entry
    		rpt[pcIndex] <= stateChange;
    	end
    	else if(laPCEntryV) begin
    		//initiate prefetch 
    	end
    end

    //Manage currently in progress requests

	reg[15:0]orl[99:0];

	integer i;
    always @(posedge clk) begin
        //move each item up by one in queue
        for(i = 1; i < 100; i = i + 1) begin
            orl[i] <= orl[i-1];
        end

        //handle new values
        if(loadEnable) begin
            orl[0] <= loadAddr;
        end
        else begin
           orl[0] <= 16'hFFFF;
        end
    end


	//initialize all entries
	initial begin
		for(i=0;i<32;i = i+1) begin
			rpt[i] <= 0;
		end
	end



endmodule
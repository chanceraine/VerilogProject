module prefetcher(input clk,
	input [15:0]pc,
	input memAccess,
	input [15:0]memAddress,

	output memRequest,
	output [15:0]requestAddress,

	output [15:0]orlOutput
	);

	initial begin
		$dumpfile("cpu.vcd");
        $dumpvars(1,prefetcher);
	end
	
	//look-ahead pc
	reg [15:0]laPC = 0;

	//32 entry reference predictor table
	//[1:0] = state
	//[15:2] = stride (lots of stride space)
	//[31:16] = prev address accessed
	//[43:32] = tag (lower bits of pc)
	//[43:43] = valid
	reg [43:0]rpt[31:0];

	//initialize all entries
	initial begin
		for(i=0;i<32;i = i+1) begin
			rpt[i] <= 0;
		end
	end

	reg memRequest = 0;
	reg [15:0]requestAddress = 0;

	wire [15:0]nextAddress = memAddress + (memAddress - pcEntryAddr);

	//PC
	wire [10:0]pcTag = pc[15:5];
	wire [4:0]pcIndex = pc[4:0];

	wire pcEntryHit = memAccess && pcEntryV && pcTag == pcEntryTag;

	wire [43:0]pcEntry = rpt[pc];
	wire pcEntryV = pcEntry[43:43];
	wire [10:0]pcEntryTag = pcEntry[42:32];
	wire [15:0]pcEntryAddr = pcEntry[31:16];
	wire [13:0]pcEntryStride = pcEntry[15:2];
	wire [1:0]pcEntryState = pcEntry[1:0];

	//STATE TRANSITIONS
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
	assign none[1:0] = 3;

	//Lookahead PC

	wire [43:0]laPCEntry = rpt[laPC];
	wire laPCEntryV = laPCEntry[43:43];

    always @(posedge clk) begin
    	if(memAccess) begin
    		//give priority to immediate memory accesses
		    //Rules: 
		    //a. no entry -> initial
		    //b. initial -> transient
		    //c. transient + same stride -> stable
		    //d. transient + wrong stride -> no prediction
		    //e. stable + same stride -> stable
		    //f. stable + wrong stride -> initial
		    //g. no prediction + wrong stride -> no prediction
		    //h. no prediction + correct stride -> transient
    		if(pcEntryHit) begin 
    			//seen this address before
    			if(pcEntryState == 0) begin
    				//no judgement can be made yet (b)
    			    rpt[pcIndex] <= transient;
    			end
    			else if(pcEntryStride == (memAddress - pcEntryAddr) && (pcEntryState != 3)) begin
    				//stride is stable (c) (e)
    				rpt[pcIndex] <= stable;
    			end
    			else if(pcEntryStride == (memAddress - pcEntryAddr) && (pcEntryState == 3)) begin
    			    //no longer unstable (h)
    			    rpt[pcIndex] <= transient;
    			end
    			else if(pcEntryStride != (memAddress - pcEntryAddr) && (pcEntryState == 2)) begin
    				//not stable anymore (f)
    				rpt[pcIndex] <= init;
    			end
    			else if(pcEntryStride != (memAddress - pcEntryAddr) && (pcEntryState == 1) || (pcEntryState == 3)) begin
    				//irregular (d) (g)
    				rpt[pcIndex] <= none;
    			end

    			if(pcEntryState != 3 && !orlCheck) begin
    				//we do a prefetch if not in the no prediction state
    				//also if address was not already requested
    				//initiate prefetch (done in next cycle)
    				memRequest <= 1;
    				requestAddress <= nextAddress;
    			end
    		end
    		else begin
    			//haven't seen before, make new entry (a) (or we are evicting old entry)
    			rpt[pcIndex] <= init;
    		end
    	end
    	else if(laPCEntryV) begin
    		//if no other memory prefetch is needed, we will initiate another fetch if we can
    	end
    	else begin
			memRequest <= 0;
			requestAddress <= 0;    		
    	end
    end

    //Manage currently in progress requests

	reg[15:0]orl[99:0];

	wire [15:0]orlOutput = orl[99];

	reg orlCheck = 0;

	integer i;
    always @(posedge clk) begin
        //move each item up by one in queue
        for(i = 1; i < 100; i = i + 1) begin
            orl[i] <= orl[i-1];

            if(memAccess) begin
	            //weird way to check if address already in orl
	            //gets set to 1 if address is there, 0 otherwise
	            if(orl[i] == nextAddress) begin
	            	orlCheck <= 1;
	            end
	        end
        end
        //handle new values
        if(memAccess) begin
        	orl[0] <= memAddress;
        end
        else if(memRequest) begin
            orl[0] <= requestAddress;
        end
        else if(0) begin
        	orl[0] <= 1; //LAPC request
        end
        else begin
           orl[0] <= 16'hFFFF;
        end
    end

endmodule
module loader(input clk,
	input writeEnabled,
	input [50:0]line,

	input floatOutReady,
	input [15:0]floatOut,
	input [3:0]floatOutSrc,

    input memReady,
    output loadMem,
    output [15:0]memAddr,
    input [15:0]memOut,

	output [3:0]nextRA,
	output [1:0]RAFilled,
	output loadOutReady,
	output [15:0]loadOut,
	output [3:0]loadOutSrc,
	output [3:0]loadOutReg);

    //[50:47] = reg
    //[46:46] = busy
    //[45:42] = opcode
    //[41:26] = value0
    //[25:25] = ready0
    //[24:21] = src0
    //[20:5] = value1
    //[4:4] = ready1
    //[3:0] = src1

	//Adding module
	wire [3:0]nextRA = (rs0 == 0) ? 2 :
				  (rs1 == 0) ? 3 :
				  16'hF;

    wire [1:0]RAFilled = rs0[46:46] + rs1[46:46]; //load stations open
    reg [50:0]rs0 = 0;
    reg [50:0]rs1 = 0; 

    //connecting to memory

    wire loadMem = (load0Ready || load1Ready) && !fetching;
    wire memAddr = (load0Ready) ? rs0Addr :
                   (load1Ready) ? rs1Addr :
                    16'hF;

    reg fetching = 0;

    //output from module
    wire [15:0]loadOut = memOut;
    wire [3:0]loadOutSrc = (load0Ready) ? 2 :
                        (load1Ready) ? 3 :
                        16'hF;

    wire [3:0]loadOutReg = (load0Ready) ? rs0Reg :
                        (load1Ready) ? rs1Reg :
                        16'hF;

    wire loadOutReady = memReady;


    //inputs to module
    wire load0Ready = rs0[46:46] && rs0[25:25] && rs0[4:4]; //ready to handle rs0 (priority)
    wire [3:0]rs0Opcode = rs0[45:42];
    wire [3:0]rs0src0 = rs0[24:21];
    wire [3:0]rs0Reg = rs0[50:47];
    wire [15:0]rs0Addr = rs0[41:26];
    
    wire load1Ready = !load0Ready && rs1[46:46] && rs1[25:25] && rs1[4:4]; //ready to do rs1
    wire [3:0]rs1Opcode = rs1[45:42];
    wire [3:0]rs1src0 = rs1[24:21];
    wire [3:0]rs1Reg = rs1[50:47];
    wire [15:0]rs1Addr = rs1[41:26];

    always @(posedge clk) begin
        //writing to RA
        if(writeEnabled) begin
        	if(nextRA == 2) begin
        		rs0 <= line;
        	end
        	else begin
        		rs1 <= line;
        	end
        end

        if(memReady) begin
            fetching <= 0;
        end
        else if(loadMem) begin
            fetching <= 1;
        end

        //once load is complete
        if(memReady) begin
            //update other station if there are dependencies
            if(load0Ready) begin
                rs0 <= 0;    
                if((rs1src0 == loadOutSrc) && (rs1 != 0)) begin
                    rs1[41:26] <= loadOut;
                    rs1[25:25] <= 1;
                end
            end
            else if(load1Ready) begin
                rs1 <= 0;
                if((rs0src0 == loadOutSrc) && (rs0 != 0)) begin
                    rs0[41:26] <= loadOut;
                    rs0[25:25] <= 1;
                end
            end
        end

        if(floatOutReady) begin
            //rs0
            if((rs0src0 == floatOutSrc) && (rs0 != 0)) begin
                rs0[41:26] <= floatOut;
                rs0[25:25] <= 1;
            end
  
            //rs1
            if((rs1src0 == floatOutSrc) && (rs1 != 0)) begin
                rs1[41:26] <= floatOut;
                rs1[25:25] <= 1;
            end
        end
    end

endmodule
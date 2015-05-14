module adder(input clk,
	input writeEnabled,
	input [50:0]line,

	input loadOutReady,
	input [15:0]loadOut,
	input [3:0]loadOutSrc,

	output [3:0]nextRA,
	output [1:0]RAFilled,
	output floatOutReady,
	output [15:0]floatOut,
	output [3:0]floatOutSrc,
	output [3:0]floatOutReg,
	output isJeq,
	output jeqTaken);

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
	wire [3:0]nextRA = (rs0 == 0) ? 0 :
				  (rs1 == 0) ? 1 :
				  16'hF;

    wire [1:0]RAFilled = rs0[46:46] + rs1[46:46]; //float stations open
    reg [50:0]rs0 = 0;
    reg [50:0]rs1 = 0; 
    
    //output from module
    wire [15:0]floatOut = (float0Ready && (rs0Opcode == 1 || rs0Opcode == 5)) ? rs0Add :
                        (float1Ready && (rs1Opcode == 1 || rs1Opcode == 5)) ? rs1Add :
                        (float0Ready && (rs0Opcode == 6)) ? rs0Reg :
                        (float1Ready && (rs1Opcode == 6)) ? rs1Reg :
                        16'hF;
    wire [3:0]floatOutSrc = (float0Ready) ? 0 :
                        (float1Ready) ? 1 :
                        16'hF;

    wire [3:0]floatOutReg = (float0Ready && (rs0Opcode == 1 || rs0Opcode == 5)) ? rs0Reg :
                        (float1Ready && (rs1Opcode == 1)) ? rs1Reg :
                        16'hF;

    wire floatOutReady = float0Ready || float1Ready;
    wire isJeq = (float0Ready && (rs0Opcode == 6)) || (float1Ready && (rs1Opcode == 6));
    wire jeqTaken = isJeq && ((float0Ready && rs0Jeq) || (float1Ready && rs1Jeq));

    //inputs to module
    wire float0Ready = rs0[46:46] && rs0[25:25] && rs0[4:4]; //ready to handle rs0 (priority)
    wire [3:0]rs0Opcode = rs0[45:42];
    wire [3:0]rs0src0 = rs0[24:21];
    wire [3:0]rs0src1 = rs0[3:0];
    wire [3:0]rs0Reg = rs0[50:47];
    wire [15:0]rs0v0 = rs0[41:26];
    wire [15:0]rs0v1 = rs0[20:5];   
    wire [15:0]rs0Add = rs0v0 + rs0v1;
    wire [15:0]rs0Jeq = (rs0v0 == rs0v1);
    
    wire float1Ready = !float0Ready && rs1[46:46] && rs1[25:25] && rs1[4:4]; //ready to do rs1
    wire [3:0]rs1Opcode = rs1[45:42];
    wire [3:0]rs1src0 = rs1[24:21];
    wire [3:0]rs1src1 = rs1[3:0];
    wire [3:0]rs1Reg = rs1[50:47];
    wire [15:0]rs1v0 = rs1[41:26];
    wire [15:0]rs1v1 = rs1[20:5];
    wire [15:0]rs1Add = rs1v0 + rs1v1;
    wire [15:0]rs1Jeq = (rs1v0 == rs1v1);

    always @(posedge clk) begin
        if(writeEnabled) begin
        	if(nextRA == 0) begin
        		rs0 <= line;
        	end
        	if(nextRA == 1) begin
        		rs1 <= line;
        	end
        end

        //update based on floatOut
        if(float0Ready) begin
            rs0 <= 0;
            if((rs1src0 == floatOutSrc) && (rs1 != 0)) begin
                rs1[41:26] <= floatOut;
                rs1[25:25] <= 1;
    			rs1[24:21] <= 16'hF;
            end
            if((rs1src1 == floatOutSrc) && (rs1 != 0)) begin
                rs1[20:5] <= floatOut;
                rs1[4:4] <= 1;
                rs1[3:0] <= 16'hF;
            end
        end
        else if(float1Ready) begin
        	rs1 <= 0;
            if((rs0src0 == floatOutSrc) && (rs0 != 0)) begin
                rs0[41:26] <= floatOut;
                rs0[25:25] <= 1;

            end
            if((rs0src1 == floatOutSrc) && (rs0 != 0)) begin
                rs0[20:5] <= floatOut;
                rs0[4:4] <= 1;
            end
        end

        //read in from load bus
        if(loadOutReady) begin
            //rs0
            if((rs0src0 == loadOutSrc) && !rs0[25:25]) begin
                rs0[41:26] <= loadOut;
                rs0[25:25] <= 1;
            end
            if((rs0src1 == loadOutSrc) && !rs0[4:4]) begin
                rs0[20:5] <= loadOut;
                rs0[4:4] <= 1;
            end   
            //rs1
            if((rs1src0 == loadOutSrc) && !rs1[25:25]) begin
                rs1[41:26] <= loadOut;
                rs1[25:25] <= 1;
                rs1[24:21] <= 16'hF;
            end
            if((rs1src1 == loadOutSrc) && !rs1[4:4]) begin
                rs1[20:5] <= loadOut;
                rs1[4:4] <= 1;
                rs1[3:0] <= 16'hF;
            end     
        end
    end

endmodule
//queue

module isb(input clk,
	input pause,
    input outEnable, //if true, give next queue value
    output outReady,
    output [15:0]dataOut, //output for queue
    input inEnable, //if true, should read value in
    output inReady,
    input [15:0]dataIn); //input for data, 4 instructions

//32 entry buffer
reg [15:0]buffer[0:31];

reg [4:0]head = 0;
reg [4:0]tail = 0;
reg [4:0]count = 0;

wire inReady = (count < 32);
wire pause;

wire [15:0]dataOut = (outReady && outEnable && (count > 0)) ? buffer[head] :
					 (outReady && outEnable) ? dataIn :
					 16'hxxxx;	
wire empty = (count == 0);
wire outReady = !empty || inEnable;

always @(posedge clk) begin
	if(!empty) begin
		//assume count > 0
		if(outEnable && !pause) begin
			count <= count - 1;
			if(head == 32) begin
				head <= 0;
			end
			else begin
				head <= head + 1;
			end
		end
	end	
	else begin
		if(outEnable && pause) begin
			count <= count + 1;
			buffer[tail] <= dataIn;
			if(tail == 32) begin
				tail <= 0;
			end
			else begin
				tail <= tail + 1;
			end
		end
	end
	if(inEnable) begin
		//assume count < 32, therefore, inReady = true
		if(!(count == 0 && outEnable)) begin //
			count <= count + 1;
			buffer[tail] <= dataIn;
			if(tail == 32) begin
				tail <= 0;
			end
			else begin
				tail <= tail + 1;
			end
		end
	end
end

endmodule
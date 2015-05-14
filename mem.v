/* memory */

`timescale 1ps/1ps

// Protocol:
//  set fetchEnable = 1
//      fetchAddr = read address
//
//  A few cycles later:
//      fetchReady = 1
//      fetchData = data
//
// Returns 64 bit block with 4 instructions/values
//
module mem(input clk,
    // fetch port
    input fetchEnable,
    input [15:0]fetchAddr,
    output fetchReady,
    output [63:0]fetchData,

    // load port
    input loadEnable,
    input [15:0]loadAddr,
    output loadReady,
    output [63:0]loadData
);

    reg [63:0]data[1023:0];

    /* Simulation -- read initial content from file */
    initial begin
        $readmemh("mem.hex",data);
    end

    reg [15:0]fetchPtr = 16'hxxxx;
    reg [15:0]fetchCounter = 0;

    assign fetchReady = (fetchCounter == 1);
    assign fetchData = (fetchCounter == 1) ? data[fetchPtr/4] : 16'hxxxx;

    always @(posedge clk) begin
        if (fetchEnable) begin
            fetchPtr <= fetchAddr;
            fetchCounter <= 1; 
        end else begin
            if (fetchCounter > 0) begin
                fetchCounter <= fetchCounter - 1;
            end else begin
                fetchPtr <= 16'hxxxx;
            end
        end
    end
    
    //data memory is weird
    //it's a size 100 queue, where you have to go through all the steps
    //you can make one request per cycle, and then expect to get it back 100 cycles later
    //by doing this, requests are pipelined essentially
    //this mimics a memory that can handle multiple requests at a time, but takes a long time to get results
    reg [15:0]queue[99:0];

    integer i;
    initial begin
    queue[99] <= 16'hFFFF;
        for(i = 0; i < 100; i = i + 1) begin
            queue[i] <= 16'hFFFF;
        end        
    end

    assign loadReady = (queue[99] != 16'hFFFF);
    assign loadData = (loadReady) ? data[queue[99]/4] : 16'hxxxx;

    always @(posedge clk) begin
        //move each item up by one in queue
        for(i = 1; i < 100; i = i + 1) begin
            queue[i] <= queue[i-1];
        end

        //handle new values
        if(loadEnable) begin
            queue[0] <= loadAddr;
        end
        else begin
           queue[0] <= 16'hFFFF;
        end
    end

endmodule

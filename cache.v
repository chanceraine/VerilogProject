//two way set associative cache

module cache(input clk,
    input iReadEnable,
    input [15:0]iAddress,
    output iMemReady,
    output [15:0]iDataOut,

    input dReadEnable,
    input [15:0]dAddress,
    output dMemReady,
    output [15:0]dDataOut,

    input [15:0]pc,
    input loadOutReady);
    
    //initialize cache
    integer i;
    initial begin
        for(i = 0;i<16;i = i+1) begin
            iLRU[i] <= 0;
            iLRU[i+16] <= 1;
            iCacheV[i] <= 0;
            iCacheV[i+16] <= 0;

            dLRU[i] <= 0;
            dLRU[i+16] <= 1;
            dCacheV[i] <= 0;
            dCacheV[i+16] <= 0;            
        end
    end

    //Memory
    wire [63:0]iData;
    wire iReady;

    wire [63:0]dData;
    wire dReady;

    mem i0(clk,
       /* fetch port */
       (!icacheHit && iReadEnable),
        iAddress,
        iReady,
        iData,

       /* load port */
       (!dcacheHit && dReadEnable),
        dAddress,
        dReady,
        dData
    );


    //INSTRUCTION CACHE
    // cache
    reg [79:0]iCache[31:0];
    reg iCacheV[31:0];
    reg iLRU[31:0];

    //prefetcher

    wire memRequest;
    wire [15:0]requestAddress;

    prefetcher pre(clk,
        pc,
        loadOutReady,
        dAddress,

        memRequest,
        requestAddress);

    //Control
    wire iMemReady = (icacheHit) ? 1 :
                    iReady;
    wire [15:0]iDataOut = (blockIndex == 3) ? iBlockOut[15:0] :
                          (blockIndex == 2) ? iBlockOut[31:16] :
                          (blockIndex == 1) ? iBlockOut[47:32] :
                          iBlockOut[63:48];
    
    wire [63:0]iBlockOut = (icacheHit) ? icacheVal :
                         iData;                     
    
    //Indexing
    wire [15:0]iAddressReal = iReadEnable ? iAddress : raddr;
    wire [3:0]index = iAddressReal[5:2]; 
    wire [15:0]iTag = iAddressReal[15:6];
    wire [1:0]blockIndex = iAddressReal[1:0];

    //setting cache values
    wire [79:0]iCacheAssign;
    assign iCacheAssign[79:64] = iTag; //tag
    assign iCacheAssign[63:0] = iData; //data to store

    //first way
    wire [79:0]value1 = iCache[index];
    wire value1V = iCacheV[index];
    wire [15:0]value1Tag = value1[79:64];
    wire [63:0]value1Val = value1[63:0];

    //second way
    wire [79:0]value2 = iCache[index+16];
    wire value2V = iCacheV[index+16];
    wire [15:0]value2Tag = value2[79:64];
    wire [63:0]value2Val = value2[63:0];    

    //analyzing values
    wire icachev1Hit = (value1V && (value1Tag == iTag));
    wire icachev2Hit = (value2V && (value2Tag == iTag));
    wire icacheHit = icachev1Hit || icachev2Hit;

    wire [63:0]icacheVal = icachev1Hit ? value1 :
                        icachev2Hit ? value2 :
                        16'hxxxx;

    //store  iAddress
    reg [15:0]raddr;
    always @(posedge clk) begin
        if(iReadEnable) begin
            raddr <= iAddress;
        end 
    end
    //handle insertions/evictions
    always @(posedge clk) begin
        if(iReady) begin
            //store instruction value in cache
            if(!value1V) begin
                //nothing in 1st way -> store there
                iCache[index] <= iCacheAssign;
                iCacheV[index] <= 1;
                iLRU[index] <= 0;
                iLRU[index+16] <= 1;
            end
            else if(!value2V) begin
                //nothing in 2nd way -> store there
                iCache[index+16] <= iCacheAssign;
                iCacheV[index+16] <= 1;
                iLRU[index] <= 1;
                iLRU[index+16] <= 0;
            end
            else if(iLRU[index]) begin
                //both occupied, and first way is LRU
                iCache[index] <= iCacheAssign;
                iCacheV[index] <= 1;
                iLRU[index] <= 0;
                iLRU[index+16] <= 1;              
            end
            else begin
                //both occupied, second way is LRU
                iCache[index+16] <= iCacheAssign;
                iCacheV[index+16] <= 1;
                iLRU[index] <= 1;
                iLRU[index+16] <= 0;              
            end
        end
    end

    //DATA CACHE ////////////////

    //Cache
    reg [79:0]dCache[31:0];
    reg dCacheV[31:0];
    reg dLRU[31:0];

    //Control
    wire dMemReady = (dcacheHit) ? 1 :
                    dReady;
    wire [15:0]dDataOut = (dBlockIndex == 3) ? dBlockOut[15:0] :
                          (dBlockIndex == 2) ? dBlockOut[31:16] :
                          (dBlockIndex == 1) ? dBlockOut[47:32] :
                          dBlockOut[63:48];
    
    wire [63:0]dBlockOut = (dcacheHit) ? dcacheVal :
                         dData;  

    //Index
    wire [15:0]dAddressReal = dReadEnable ? dAddress : daddr;
    wire [3:0]dIndex = dAddressReal[5:2]; 
    wire [15:0]dTag = dAddressReal[15:6];
    wire [1:0]dBlockIndex = dAddressReal[1:0];

    //setting cache values
    wire [79:0]dCacheAssign;
    assign dCacheAssign[79:64] = dTag; //tag
    assign dCacheAssign[63:0] = dData; //data to store  

    //first way
    wire [79:0]dvalue1 = dCache[dIndex];
    wire dvalue1V = dCacheV[dIndex];
    wire [15:0]dvalue1Tag = dvalue1[79:64];
    wire [63:0]dvalue1Val = dvalue1[63:0];

    //second way
    wire [79:0]dvalue2 = dCache[dIndex+16];
    wire dvalue2V = dCacheV[dIndex+16];
    wire [15:0]dvalue2Tag = dvalue2[79:64];
    wire [63:0]dvalue2Val = dvalue2[63:0];  

    //analyzing values
    wire dcachev1Hit = (dvalue1V && (dvalue1Tag == dTag));
    wire dcachev2Hit = (dvalue2V && (dvalue2Tag == dTag));
    wire dcacheHit = dcachev1Hit || dcachev2Hit;

    wire [63:0]dcacheVal = dcachev1Hit ? dvalue1 :
                        dcachev2Hit ? dvalue2 :
                        16'hxxxx;

    //store  dAddress
    reg [15:0]daddr;
    always @(posedge clk) begin
        if(dReadEnable) begin
            daddr <= dAddress;
        end 
    end
    //handle cache insertions/evictions
    always @(posedge clk) begin
        if(dReady) begin
            //store instruction value in cache
            if(!dvalue1V) begin
                //nothing in 1st way -> store there
                dCache[dIndex] <= dCacheAssign;
                dCacheV[dIndex] <= 1;
                dLRU[dIndex] <= 0;
                dLRU[dIndex+16] <= 1;
            end
            else if(!dvalue2V) begin
                //nothing in 2nd way -> store there
                dCache[dIndex+16] <= dCacheAssign;
                dCacheV[dIndex+16] <= 1;
                dLRU[dIndex] <= 1;
                dLRU[dIndex+16] <= 0;
            end
            else if(dLRU[dIndex]) begin
                //both occupied, and first way is LRU
                dCache[dIndex] <= dCacheAssign;
                dCacheV[dIndex] <= 1;
                dLRU[dIndex] <= 0;
                dLRU[dIndex+16] <= 1;              
            end
            else begin
                //both occupied, second way is LRU
                dCache[dIndex+16] <= dCacheAssign;
                dCacheV[dIndex+16] <= 1;
                dLRU[dIndex] <= 1;
                dLRU[dIndex+16] <= 0;              
            end   
        end      
    end


endmodule
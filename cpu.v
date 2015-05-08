`timescale 1ps/1ps


module main();
    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(1,main);
        $dumpvars(1,i0);
        $dumpvars(1,ib);
        $dumpvars(1,add);
        $dumpvars(1,load);
    end

    // clock
    wire clk;
    clock c0(clk);

    counter ctr(finish,clk,finishedInst,cycle);

    wire finishedInst = (floatOutReady || loadOutReady || finish || (opcode == 0));
    
    // MEMORY ////////////////////// 
    cache i0(clk,
       iRead, 
       imemIn, 
       imemReady,
       imemOut,

       dData,
       dmemIn,
       dmemReady,
       dmemOut,

       pc,
       loadOutReady
    );

    //state
    reg fetching = 0;
    reg stallFetch = 0; //if true, last instruction received was jeq, so don't fetch more until set to 0. 
    reg [15:0]pc = 16'h0000;
    
    //instructions
    wire iRead = !fetching && inReady && !stallFetch;
    wire [15:0]imemIn = pc;
    wire imemReady;
    wire [15:0]imemOut;

    //control
    wire fastFetch = (imemReady && iRead);
    wire earlyJump = imemReady && (imemOut[15:12] == 2) && (fetching || fastFetch);
    wire [11:0]jmpDest = imemOut[11:0];
    wire jeq = imemReady && (imemOut[15:12] == 6) && (fetching || fastFetch);

    //data
    wire dData;
    wire [15:0]dmemIn;
    wire dmemReady;
    wire [15:0]dmemOut;
    
    always @(posedge clk) begin
        //if trying to read, don't try to read next cycle
        if(iRead && !fastFetch) begin
            fetching <= 1;
        end
        //if memory is ready, update pc or do nothing
        else if(imemReady) begin
            //jump early
            if(stallFetch && !isJeq) begin
                pc <= pc;
            end
            else if(jeqTaken) begin
                pc <= pc + floatOut;
            end
            else if(earlyJump) begin
                pc <= jmpDest;
            end
            //waiting to hear back, don't do anything
            else if(jeq) begin
                pc <= pc;
            end 
            //normal inst, just keep truckin
            else begin
                pc <= pc + 1;
            end
            fetching <= 0;
        end

        //if jeq, stall fetching
        if(jeq) begin
            stallFetch <= 1;
        end
        //if jeq inst has finished, unstall 
        if(isJeq) begin
            stallFetch <= 0;
        end
    end

    // Instruction buffer /////////////////
    wire pause = stallDispatch || willStall;
    wire outReady;
    wire outEnable = outReady; 
    wire [15:0]isbOut;
    wire inEnable = imemReady && inReady && !earlyJump && !stallFetch;
    wire inReady;
    wire [15:0]isbIn = imemOut;

    isb ib(clk,
        pause,
        outEnable, //if true, give next queue value
        outReady, //true if queue has value to present
        isbOut, //output for queue
        inEnable, //if true, queue reads value in
        inReady, //true if queue can add another value
        isbIn); //input to queue

    // REGISTERS ///////////////////////
    reg [15:0]regs[0:15];
    reg [3:0]regsSource[0:15];
    reg regsValid[0:15];
    
    //initialize regs to valid
    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            regsValid[i] <= 1;
        end
    end   
    //listen to bus for changes

    wire writingFloat = (floatOutReady && !isJeq) && ((regsSource[floatOutReg] == floatOutSrc) && (regsValid[floatOutReg] == 0));
    wire [3:0]regsSourceAdd = regsSource[floatOutReg];
    wire regsValidAdd = regsValid[floatOutReg];

    //don't bother writing/changing valid status if register will be overwritten by write
    //only for add? Need this for load too?
    wire overwrite = (floatWE && floatOutReady && floatOutReg == addRS[50:47] && addRS[45:42] == 1);

    always @(posedge clk) begin
        if(floatOutReady && !isJeq) begin
            if((regsSource[floatOutReg] == floatOutSrc) && (regsValid[floatOutReg] == 0) && !overwrite) begin
                regs[floatOutReg] <= floatOut;
                regsValid[floatOutReg] <= 1;
            end     
        end
        if(loadOutReady) begin
            if((regsSource[loadOutReg] == loadOutSrc) && (regsValid[loadOutReg] == 0)) begin
                regs[loadOutReg] <= loadOut;
                regsValid[loadOutReg] <= 1;
            end     
        end
    end

    //Dispatch
    
    //mov -> immediately put in register
    //add -> add module
    //jmp -> covered before dispatch between i0 and ib
    //halt -> add module??? or just stall til stations empty?
    //ld -> load module
    //ldr -> 2 inst, one in add and dependent one in load
    //jeq -> add module

    // decode
    wire [15:0]inst = isbOut;

    wire [3:0]opcode = inst[15:12];
    wire [3:0]ra = inst[11:8];
    wire [3:0]rb = inst[7:4];
    wire [3:0]rt = inst[3:0];
    wire [15:0]ii = inst[11:4]; // zero-extended

    wire needsFloat = (opcode == 1) || (opcode == 5) || (opcode == 6);
    wire needsLoad = (opcode == 4) || (opcode == 5);

    reg stallDispatch = 0;
    wire willStall = (outEnable) && 
        ((needsFloat && (floatFilled == 2)) || 
        (needsLoad && (loadFilled == 2)) || 
        ((opcode == 3) && (floatFilled > 0 || loadFilled > 0)));

    reg finish = 0;

    always @(posedge clk) begin
        stallDispatch <= (outEnable) && //getting new instruction or already stalling
                         ((needsFloat && (floatFilled == 2)) || //all float stations used
                         (needsLoad && (loadFilled == 2)) || //all load stations used
                         ((opcode == 3) && (floatFilled > 0 || loadFilled > 0))); //waiting to end program 
                         //jeq???

        //set register sources before sending to module
        if(stallDispatch) begin
            //???
        end
        if(isJeq) begin
            //also just wait?
        end
        if(outEnable && !finish && !pause) begin

            if(opcode == 0) begin
                //mov
                //can do immediately, need to update other parts of regs?
                regs[rt] <= ii;
                regsSource[rt] <= 16'hF; //make sure src isn't necessary
                regsValid[rt] <= 1; //this register is now valid
            end
            else if(opcode == 1) begin
                //add
                regsValid[rt] <= 0;
                if(nextFloatRA == 0) begin
                    //put it in rs0
                    regsSource[rt] <= 0;
                end
                else begin
                    //put it in rs1
                    regsSource[rt] <= 1;
                end
            end
            else if(opcode == 2) begin
                //shouldn't happen
                //jmp handled earlier
                $display("jmp error");
            end
            else if(opcode == 3) begin
                //do this before halting
                if(floatFilled == 0 && loadFilled == 0) begin
                    $display("#0:%x",regs[0]);
                    $display("#1:%x",regs[1]);
                    $display("#2:%x",regs[2]);
                    $display("#3:%x",regs[3]);
                    $display("#4:%x",regs[4]);
                    $display("#5:%x",regs[5]);
                    $display("#6:%x",regs[6]);
                    $display("#7:%x",regs[7]);
                    $display("#8:%x",regs[8]);
                    $display("#9:%x",regs[9]);
                    $display("#10:%x",regs[10]);
                    $display("#11:%x",regs[11]);
                    $display("#12:%x",regs[12]);
                    $display("#13:%x",regs[13]);
                    $display("#14:%x",regs[14]);
                    $display("#15:%x",regs[15]);    
                    finish <= 1;    
                end  
                //otherwise just wait
            end
            else if(opcode == 4) begin
                //ld
                regsValid[rt] <= 0;
                if(nextLoadRA == 2) begin
                    //put it in rs0
                    regsSource[rt] <= 2;
                end
                else begin
                    //put it in rs1
                    regsSource[rt] <= 3;
                end
            end
            else if(opcode == 5) begin
                //ldr
                regsValid[rt] <= 0;
                if(nextLoadRA == 2) begin
                    //put it in rs0
                    regsSource[rt] <= 2;
                end
                else begin
                    //put it in rs1
                    regsSource[rt] <= 3;
                end
            end
            else if(opcode == 6) begin
                //jeq
            end
        end
    end


    //Modules

    //4 total stations, 0 and 1 for non-float, 2 and 3 for loading
    
    //Reservation Stations
    //[50:47] = reg
    //[46:46] = busy
    //[45:42] = opcode
    //[41:26] = value0
    //[25:25] = ready0
    //[24:21] = src0
    //[20:5] = value1
    //[4:4] = ready1
    //[3:0] = src1

    wire [15:0]reg0Src = regsSource[0];
    wire [15:0]reg0V = regsValid[0];

    wire [15:0]addRSv0 = addRS[41:26];
    wire [15:0]addRSv1 = addRS[20:5];    

    wire [50:0]addRS; //use same one for jeq, add, and ldr
    assign addRS[50:47] = rt;
    assign addRS[46:46] = 1;
    assign addRS[45:42] = opcode;
    //r0
    assign addRS[41:26] = (regsValid[ra]) ? regs[ra] : //reg value if valid
                          (floatOutReady && floatOutSrc == regsSource[ra]) ? floatOut : //float out if same
                          (loadOutReady && loadOutSrc == regsSource[ra]) ? loadOut : //load out if same
                           regsSource[ra]; //source otherwise
    assign addRS[25:25] = (regsValid[ra]) ? 1 : 
                          (floatOutReady && floatOutSrc == regsSource[ra]) ? 1 : 
                          (loadOutReady && loadOutSrc == regsSource[ra]) ? 1 : 
                           0; 
    assign addRS[24:21] = (regsSource[ra]); //r0 src
    //r1
    assign addRS[20:5] = (regsValid[rb]) ? regs[rb] : //reg value if valid
                         (floatOutReady && floatOutSrc == regsSource[rb]) ? floatOut : //float out if same
                         (loadOutReady && loadOutSrc == regsSource[rb]) ? loadOut : //load out if same
                          regsSource[rb]; //source otherwise
    assign addRS[4:4] = (regsValid[rb]) ? 1 : 
                        (floatOutReady && floatOutSrc == regsSource[rb]) ? 1 : 
                        (loadOutReady && loadOutSrc == regsSource[rb]) ? 1 : 
                         0; 
    assign addRS[3:0] = (regsSource[rb]); //r1 src

    wire floatWE = !pause && outEnable && needsFloat;

    wire [3:0]nextFloatRA;
    wire [1:0]floatFilled;
    wire floatOutReady;
    wire [15:0]floatOut;
    wire [3:0]floatOutSrc;
    wire [3:0]floatOutReg;
    wire isJeq;
    wire jeqTaken;

    adder add(clk,
        floatWE, addRS,
        loadOutReady,loadOut,loadOutSrc,
        nextFloatRA,floatFilled,floatOutReady,
        floatOut,floatOutSrc,floatOutReg,
        isJeq,jeqTaken);
    
    //Load
    wire [50:0]loadRS;
    assign loadRS[50:47] = rt;
    assign loadRS[46:46] = 1;
    assign loadRS[45:42] = opcode;
    assign loadRS[41:26] = (opcode == 4) ? ii : 0; //contains address/add ra if ldr
    assign loadRS[25:25] = (opcode == 4) ? 1 : 0; //1 if ld, 0 if ldr
    assign loadRS[24:21] = (opcode == 5) ? nextFloatRA : 16'hF;
    assign loadRS[20:5] = 16'hFFFF; //contains nothing
    assign loadRS[4:4] = 1; 
    assign loadRS[3:0] = 16'hF; 

    wire loadWE = !pause && outEnable && needsLoad;

    wire [3:0]nextLoadRA;
    wire [1:0]loadFilled;
    wire loadOutReady;
    wire [15:0]loadOut;
    wire [3:0]loadOutSrc;
    wire [3:0]loadOutReg;

    loader load(clk,
        loadWE, loadRS, //line input
        !isJeq ? floatOutReady : 0,floatOut,floatOutSrc, //bus access
        dmemReady,dData,dmemIn,dmemOut, //memory access
        nextLoadRA,loadFilled,loadOutReady, //logistics
        loadOut,loadOutSrc,loadOutReg); //bus out

endmodule

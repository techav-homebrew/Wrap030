/******************************************************************************
 * Wrap030 Memory Glue
 * techav
 * 2025-02-27
 ******************************************************************************
 * Wrap030 DRAM Glue Logic 
 *****************************************************************************/

module wrap030_dram_glue (
    input   wire            busClk,     // bus clock                    83
    input   wire            busReset_n, // bus reset                    1
    input   wire [1:0]      busFC,      // bus function code            16/12
    input   wire            busRW_n,    // bus read/write               21
    inout   wire [1:0]      busDsack_nz,// bus data strobe acknowledge  31/29
    input   wire [1:0]      busSiz,     // bus transfer size            30/28
    input   wire            busAS_n,    // bus address strobe           15
    input   wire            busDS_n,    // bus data strobe              17
    input   wire            busAddr31,  // bus address bit 31           18
    input   wire            busBerr_n,  // bus error                    25
    input   wire [23:0]     busAddr,    // bus address  20/22/24/ 4/81/79/11/75
                                        //              80/74/76/73/70/68/69/67
                                        //              64/65/63/60/61/58/56/27
    output  wire [11:0]     memAddr,    // dram address 45/41/48/46/44/40/39/37
                                        //              36/35/34/33
    output  wire [3:0]      memCas_n,   // dram col strobe          55/52/54/51
    output  wire [1:0]      memRas_n,   // dram row strobe              49/50
    output  wire            memWe_n,    // dram write enable            57
    output  wire            memBufE_n,  // dram buffer enable           5

//  output  wire            timeIrq_nz, // timer interrupt  (io5)       11
// spare I/O
//    inout   wire            oe1,        //                              84
//    inout   wire            oe2,        //                              2
//    inout   wire            io6,        //                              10
//    inout   wire            io8,        //                              9
//    inout   wire            io11,       //                              8
//    inout   wire            io13,       //                              6
    output  wire [3:0]      stateDebug
);


assign stateDebug = timingState;
/*always @(negedge busClk, negedge busReset_n) begin
    if(!busReset_n) stateDebug <= sIDL;
    else stateDebug <= nextState;
end*/


// data bus byte & word select signals
wire UUDn, UMDn, LMDn, LLDn;
always_comb begin
    UUDn = ~(
        busRW_n | (~busAddr[0] & ~busAddr[1])
    );
    UMDn = ~(
        busRW_n | (~busSiz[0] & ~busAddr[1]) | (~busAddr[1] & busAddr[0]) |
        (busSiz[1] & !busAddr[1])
    );
    LMDn = ~(
        busRW_n | (~busAddr[0] & busAddr[1]) |
        (~busAddr[1] & ~busSiz[0] & ~busSiz[1]) | 
        (busSiz[1] & busSiz[0] & ~busAddr[1]) |
        (~busSiz[0] & ~busAddr[1] & busAddr[0])
    );
    LLDn = ~(
        busRW_n | (busAddr[0] & busSiz[0] & busSiz[1]) | (~busSiz[0] & ~busSiz[1]) | 
        (busAddr[0] & busAddr[1]) | (busAddr[1] & busSiz[1])
    );
    //UDn = ~(~busAddr[0] | busRW_n);
    //LDn = ~(~busSiz[0] | busSiz[1] | busAddr[0] | busRW_n);
end
/*
assign byteSELn[0] = LLDn;
assign byteSELn[1] = LMDn;
assign byteSELn[2] = UMDn;
assign byteSELn[3] = UUDn;
*/



// initialization timer
reg [3:0] initCount;
always @(posedge busClk, negedge busReset_n) begin
    if(!busReset_n) begin
        //initCount <= 13'h1388;          // 5000 cycles @ 25MHz = 200us
        initCount <= 4'b0111;             // 7 cycles @ 25MHz = 280ns
    end else begin
        if(initCount > 0) initCount <= initCount - 13'd1;
        else initCount <= 4'd0;
    end
end


// refresh timing counter
reg [8:0] refreshTimer;
reg refreshCall, refreshAck;
reg [3:0] initRfshCount;
always @(posedge busClk, negedge busReset_n) begin
    if(!busReset_n) begin
        refreshTimer <= 0;
        refreshCall <= 0;
    end else if(refreshTimer >= 9'h186) begin   // 390 cycles @ 25MHz = 15.6us
        refreshCall <= 1;
        refreshTimer <= 0;
    end else if(initRfshCount >= 4'h8) begin
        refreshTimer <= refreshTimer + 9'h001;
        if(refreshAck) refreshCall <= 0;
        else refreshCall <= refreshCall;
    end
end

always @(negedge busClk, negedge busReset_n) begin
    if(!busReset_n) begin
        refreshAck <= 0;
    end else begin
        if(nextState == sRC0) begin
            refreshAck <= 1;
        end else begin
            refreshAck <= 0;
        end
    end
end

// initRfshCount counts 8 refresh cycles immediately following the reset
// initialization hold sequence. It is incremented when the state machine
// is in the middle of the refresh sequence, and held there until reset
always @(negedge busClk, negedge busReset_n) begin
    if(!busReset_n) begin
        initRfshCount <= 0;
    end else begin
        if(initRfshCount < 4'h8) begin
            if(timingState == sRR2) begin
                initRfshCount <= initRfshCount + 4'd1;
            end
        end
    end
end



// primary DRAM controller state machine
parameter
    sIDL    =   0,  //  Idle state
    sCR0    =   1,  //  Cycle RAS state 0
    sCC0    =   2,  //  Cycle CAS state 0
    sCC1    =   3,  //  Cycle CAS state 1
    sBST    =   4,  //  Burst Cycle state
    sBND    =   5,  //  Burst End state
    sRC0    =   6,  //  Refresh CAS state 0
    sRR0    =   7,  //  Refresh RAS state 0
    sRR1    =   8,  //  Refresh RAS state 1
    sRR2    =   9,  //  Refresh RAS state 2
    sINIT   =  10,  //  Startup initialization state
    sREG    =  11;  //  Write configuration registers state
reg [3:0] timingState, nextState;

always @(negedge busClk, negedge busReset_n) begin
    if(!busReset_n) begin
        timingState <= sINIT;
    end else begin
        timingState <= nextState;
    end
end

//always @(timingState, ramCEn, cpuCBREQn, refreshCall, initRfshCount, initCount, cpuAddr, cpuRWn) begin
always @(*) begin
    nextState = timingState;
    case(timingState)
        sINIT: begin
            // Startup initialization state
            // hold here until initCount is 0
            // then move on to sRC0 to start a series of 8 refresh cycles
            if(initCount > 0) begin
                nextState = sINIT;
            end else begin
                nextState = sRC0;
            end
        end
        sIDL: begin
            // Idle state
            // if time for refresh, then move to sRC0
            // else if time for CPU cycle then move to sCR0
            // else state at Idle
            if(refreshCall) begin
                nextState = sRC0;
            end else if(!busAS_n && !busAddr31 && (busFC[0] ^ busFC[1])) begin
                // this looks like a RAM access cycle ...
                if(!busRW_n) begin
                    // always handle writes to RAM
                    nextState = sCR0;
                end else if(rOverlay && busAddr >= 24'h00080000) begin
                    // always read RAM above $0080,0000
                    nextState = sCR0;
                end else if(!rOverlay) begin
                    // overlay is disabled, read RAM
                    nextState = sCR0;
                end else begin
                    // we'll let ROM handle this one
                    nextState = sIDL;
                end
            end else begin
                // we're not currently being addressed
                nextState = sIDL;
            end
        end

        // normal access cycle sequence
        sCR0: nextState = sCC0;
        sCC0: nextState = sCC1;
        sCC1: begin
            // Cycle CAS state 1
            // if cache burst, then proceed to sBST
            // else progress to sIDL to end cycle
            
            /*
            if(!busCbReq_n) begin
                nextState = sBST;
            end else begin
                nextState = sIDL;
            end
            */

            // we don't have burst request here, so just go to idle
            nextState = sIDL;
        end
        sBST: begin
            // Cycle burst state
            // if cpu cache burst request still asserted then proceed to sCC1
            // else proceed to sBND to end cycle

            /*
            if(!cpuCbReq_n) begin
                nextState = sCC1;
            end else begin
                nextState = sBND;
            end
            */

            // we don't have burst request here, so just go to idle
            nextState = sIDL;
        end

        // Cylce burst end; always proceed to sIDL to end cycle
        sBND: nextState = sIDL;

        // CBR Refresh sequence
        sRC0: nextState = sRR0;
        sRR0: nextState = sRR1;
        sRR1: nextState = sRR2;
        sRR2: begin
            // Refresh cycle RAS state 2
            // if initialization is not complete, then start another refresh cycle
            // else proceed to sIDL
            if(initRfshCount < 4'h8) begin
                nextState = sINIT;
            end else begin
                nextState = sIDL;
            end
        end

        // Register write state (not implemented here either)
        sREG: nextState = sIDL;

        default: nextState = sIDL;
    endcase
end


// memory address output
always @(negedge busClk, negedge busReset_n) begin
    if(!busReset_n) begin
        memAddr <= 0;
    end else begin
        case(nextState)
            sCR0: begin
                // output row address
                memAddr[11] <= 0;
                memAddr[10:0] <= busAddr[23:13];
            end
            sCC0, sBST: begin
                // output column address
                memAddr[11] <= 0;
                memAddr[10:0] <= busAddr[12:2];
            end
        endcase
    end
end


// row & column strobe outputs
// these are double-buffered to ensure timing, given everything that goes into
// calculating each signal (expecially CAS)
reg[3:0] nextMemCASn;
reg nextMemRASn;

// calculate nextMemRASn
always @(posedge busClk, negedge busReset_n) begin
    if(!busReset_n) begin
        nextMemRASn <= 1;
    end else begin
        case(nextState)
            sCR0, sCC0, sCC1, sBST, sBND: begin
                // cpu access cycle
                nextMemRASn <= 0;
            end
            sRR0, sRR1, sRR2: begin
                // refresh cycle
                nextMemRASn <= 0;
            end
            default: begin
                nextMemRASn <= 1;
            end
        endcase
    end
end

// calculate nextMemCASn
always @(posedge busClk, negedge busReset_n) begin
    if(!busReset_n) begin
        nextMemCASn <= 4'b1111;
    end else begin
        case(nextState)
            sCC0, sCC1, sBND: begin
                // cpu access cycle
                nextMemCASn[0] <= LLDn;
                nextMemCASn[1] <= LMDn;
                nextMemCASn[2] <= UMDn;
                nextMemCASn[3] <= UUDn;
            end
            sRC0, sRR0, sRR1: begin
                // refresh cycle
                nextMemCASn <= 4'b0000;
            end 
            sINIT: begin
                // this is to catch a special case at the end of the initialization cycle
                if(initCount == 1) nextMemCASn <= 4'b0000;
                else nextMemCASn <= 4'b1111;
            end
            default: begin
                nextMemCASn <= 4'b1111;
            end
        endcase
    end
end

// not actually output RAS/CAS signals
always @(negedge busClk, negedge busReset_n) begin
    if(!busReset_n) begin
        memRas_n <= 2'b11;
        memCas_n <= 4'b1111;
    end else begin
        memRas_n[1] <= 1;
        memRas_n[0] <= nextMemRASn;
        memCas_n <= nextMemCASn;
    end
end



// misc other control signals output
always_comb begin
    case(timingState)
        sCR0, sCC0: begin
            busDsack_nz <= 2'bZZ;
            memWe_n <= busRW_n;
        end
        sCC1: begin
            busDsack_nz <= 2'b00;
            memWe_n <= busRW_n;
        end
        sBST: begin
            busDsack_nz <= 2'bZZ;
            memWe_n <= busRW_n;
        end
        sBND: begin
            busDsack_nz <= 2'b00;
            memWe_n <= busRW_n;
        end
        sREG: begin
            busDsack_nz <= 2'b10;
            memWe_n <= busRW_n;
        end
        default: begin
            busDsack_nz <= 2'bZZ;
            memWe_n <= busRW_n;
        end
    endcase
end


// ROM overlay enable/disable
reg rOverlay;
always @(negedge busClk, negedge busReset_n) begin
    if(!busReset_n) begin
        rOverlay <= 1;
    end else begin
        if(!busAS_n && busAddr31 && (busFC[0] ^ busFC[1]) && busAddr[21:19] == 3) begin
            rOverlay <= 0;
        end else begin
            rOverlay <= rOverlay;
        end
    end
end


// Data bus buffers enable
/*
    sCR0    =   1,  //  Cycle RAS state 0
    sCC0    =   2,  //  Cycle CAS state 0
    sCC1    =   3,  //  Cycle CAS state 1
    sBST    =   4,  //  Burst Cycle state
    sBND    =   5,  //  Burst End state
*/
always @(negedge busClk, negedge busReset_n) begin
    if(!busReset_n) begin
        memBufE_n <= 1;
    end else begin
        case(nextState)
            sCR0, sCC0, sCC1, sBST, sBND: begin
                memBufE_n <= 0;
            end
            default: begin
                memBufE_n <= 1;
            end
        endcase
    end
end


endmodule

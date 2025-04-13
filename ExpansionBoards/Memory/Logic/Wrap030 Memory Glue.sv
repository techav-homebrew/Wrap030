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
    output  wire            memBufE_n   // dram buffer enable           5

//  output  wire            timeIrq_nz, // timer interrupt  (io5)       11
// spare I/O
//    inout   wire            oe1,        //                              84
//    inout   wire            oe2,        //                              2
//    inout   wire            io6,        //                              10
//    inout   wire            io8,        //                              9
//    inout   wire            io11,       //                              8
//    inout   wire            io13,       //                              6
);

// internal registers
reg [3:0] timingState;          // state machine current state
reg [3:0] initCount;            // startup initialization sequence
reg [6:0] refreshTimer;         // counter until time to run refresh cycle
reg refreshCall;                // set when time to run refresh cycle
reg refreshAck;                 // set when starting refresh cycle
reg rOverlay;                   // startup ROM overlay

// internal wires
wire [3:0] nextState;           // state machine next state
wire UUDn, UMDn, LMDn, LLDn;    // data bus byte select signals
wire memCE_n;                   // bus is trying to address RAM

/******************************************************************************
 * bus decoding
 *****************************************************************************/
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
end

always_comb begin
    if(!busAS_n && !busAddr31 && (busFC[0] ^ busFC[1])) begin
        // this looks like a RAM access cycle
        if(!busRW_n) memCE_n = 0;
        else if(rOverlay && busAddr >= 24'h080000) memCE_n = 0;
        else if(!rOverlay) memCE_n = 0;
        else memCE_n = 1;
    end else memCE_n = 1;
end

/******************************************************************************
 * primary DRAM controller state machine
 *****************************************************************************/
parameter
    sIDL    =   0,  //  Idle state
    sCR0    =   1,  //  Cycle RAS state 0
    sCC0    =   2,  //  Cycle CAS state 0
    sCC1    =   3,  //  Cycle CAS state 1
    sEND    =   4,  //  Cycle end state
    sRC0    =   5,  //  Refresh CAS state 0
    sRR0    =   6,  //  Refresh RAS state 0
    sRR1    =   7,  //  Refresh RAS state 1
    sRR2    =   8,  //  Refresh RAS state 2
    sINIT   =   9;  //  Startup initialization state

always_comb begin
    case(timingState)
        // handle startup initialization
        sINIT: begin
            nextState = sRC0;
        end

        // idle state is the launching point for other cycles
        sIDL: begin
            if(refreshCall) nextState = sRC0;
            else if(!memCE_n) nextState = sCR0;
            else nextState = sIDL;
        end

        // main memory cycle sequence
        sCR0: nextState = sCC0;
        sCC0: nextState = sCC1;
        sCC1: nextState = sEND;
        sEND: begin
            if(refreshCall) nextState = sRC0;
            else if(!busAS_n) nextState = sEND;
            else nextState = sIDL;
        end

        // refresh cycle sequence
        sRC0: nextState = sRR0;
        sRR0: nextState = sRR1;
        sRR1: nextState = sRR2;
        sRR2: begin
            if(initCount > 0) nextState = sRC0;
            else nextState = sIDL;
        end

        default: nextState = sIDL;
    endcase
end

always @(posedge busClk, negedge busReset_n) begin
    if(!busReset_n) timingState <= sINIT;
    else timingState <= nextState;
end

/******************************************************************************
 * startup initialization
 *****************************************************************************/

// run 8 refresh cycles at startup before operation
always @(negedge busClk, negedge busReset_n) begin
    if(!busReset_n) initCount <= 4'h8;
    else if(initCount > 0 && timingState == sRR2) initCount <= initCount - 4'h1;
    else initCount <= initCount;
end

/******************************************************************************
 * DRAM refresh
 *****************************************************************************/

// refresh cycle acknowledge
always @(posedge busClk, negedge busReset_n) begin
    if(!busReset_n) refreshAck <= 0;
    else begin
        if(nextState == sRC0) refreshAck <= 1;
        else refreshAck <= 0;
    end
end

// refresh timing counter
always @(negedge busClk, negedge busReset_n) begin
    if(!busReset_n) begin
        refreshTimer <= 0;
        refreshCall <= 0;
    end
    else if(refreshTimer >= 7'h7E) begin
        refreshTimer <= 0;
        refreshCall <= 1;
    end else begin
        refreshTimer <= refreshTimer + 7'h1;
        if(refreshAck) refreshCall <= 0;
        else refreshCall <= refreshCall;
    end
end

/******************************************************************************
 * DRAM control signals
 *****************************************************************************/

// Memory Address
always @(negedge busClk, negedge busReset_n) begin
    if(!busReset_n) memAddr <= 0;
    else begin
        case(timingState)
            sCR0, sCC0, sCC1, sEND: begin
                // latch column address
                memAddr[11] <= 0;
                memAddr[10:0] <= busAddr[12:2];
            end
            default: begin
                // continually latch row address
                memAddr[11] <= 0;
                memAddr[10:0] <= busAddr[23:13];
            end
        endcase
    end
end

// Write Enable
always @(posedge busClk, negedge busReset_n) begin
    if(!busReset_n) memWe_n <= 1;
    else begin
        case(nextState)
            sCR0, sCC0, sCC1, sEND: memWe_n <= busRW_n;
            default: memWe_n <= 1;
        endcase
    end
end

// Row Address Strobe
always @(posedge busClk, negedge busReset_n) begin
    if(!busReset_n) memRas_n <= 2'b11;
    else begin
        case(nextState)
            sCR0, sCC0, sCC1: memRas_n <= 2'b10;
            sRR0, sRR1, sRR2: memRas_n <= 2'b00;
            default: memRas_n <= 2'b11;
        endcase
    end
end

// Column Address Strobe
always @(posedge busClk, posedge busAS_n) begin
    if(busAS_n) memCas_n <= 4'b1111;
    else begin
        case(nextState)
            sCC0, sCC1: begin
                memCas_n[0] <= LLDn;
                memCas_n[1] <= LMDn;
                memCas_n[2] <= UMDn;
                memCas_n[3] <= UUDn;
            end
            sRC0, sRR0, sRR1, sRR2: memCas_n <= 4'b0000;
            default: memCas_n <= 4'b1111;
        endcase
    end
end

/******************************************************************************
 * Bus control signals
 *****************************************************************************/

// data bus buffers
always @(posedge busClk, negedge busReset_n) begin
    if(!busReset_n) memBufE_n <= 1;
    else begin
        case(nextState)
            sCR0, sCC0, sCC1: memBufE_n <= 0;
            sEND: begin
                // hold buffer open until end of write cycles
                if(!busRW_n) memBufE_n <= 0;
                else memBufE_n <= 1;
            end
            default memBufE_n <= 1;
        endcase
    end
end

// Data Strobe Acknowledge
always @(negedge busClk, posedge busAS_n) begin
    if(busAS_n) busDsack_nz <= 2'bZZ;
    else begin
        case(timingState)
            sCC0: busDsack_nz <= 2'b00;
            sEND: busDsack_nz <= 2'b11;
            default: busDsack_nz <= 2'bZZ;
        endcase
    end
end

/******************************************************************************
 * Startup ROM overlay
 *****************************************************************************/

always @(negedge busClk, negedge busReset_n) begin
    if(!busReset_n) rOverlay <= 1;
    else begin
        if(     !busAS_n 
                && busAddr31 
                && (busFC[0] ^ busFC[1]) 
                && busAddr[21:19] == 3
        ) begin
            rOverlay <= 0;
        end else begin
            rOverlay <= rOverlay;
        end
    end
end


endmodule

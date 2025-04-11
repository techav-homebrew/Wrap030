/******************************************************************************
 * Memory Cycle
 * techav
 * 2021-12-25
 *      - initial
 * 2025-04-03
 *      - rework memory map for contiguous 16MB RAM at address 0
 *      - remove synchronous SRAM cycles
 *      - reduce ROM wait states for 55ns ROM at 50MHz
 *      - add interrupt autovector cycle
 ******************************************************************************
 * Timing and control signals for memory devices (ROM/RAM)
 *****************************************************************************/

module memcycle (
    input   wire                sysClk,     // primary system clock
    input   wire                nReset,     // primary system reset
    input   wire                nAS,        // address strobe
    input   wire                addr31,     // address bit 31
    input   wire                RnW,        // Read/Write select
    input   logic [2:0]         addrSel,    // address select bits (21:19)
    input   logic [1:0]         addrSiz,    // address size bits
    input   logic [1:0]         siz,        // transfer size bits
    input   wire  [1:0]         cpuFC,      // cpu function code
    output  wire                nRomCE,     // rom chip select
    output  logic [1:0]         nDsack,     // DS acknowledge
    output  wire                nSterm,     // synchronous termination
    output  wire                nMemRd,     // memory Read strobe
    output  wire                nMemWr,     // memory Write strobe
    output  logic [3:0]         nRamCE,     // ram chip select
    output  wire                nBerr,      // CPU bus error signal
    output  wire                nAvec       // CPU autovector signal
);

// define state machine states
parameter 
    sIDLE   =    0, // Idle state
    sAACTV  =    1, // Async active state
    sAWAT1  =    2, // Async wait 1 state
    sAWAT2  =    3, // Async wait 2 state
    sAWAT3  =    4, // Async wait 3 state
    sATERM  =    5, // Async term state
    sBERR   =    6, // Bus error state
    sMODE   =    7, // Mode switch state
    sAVEC   =    8, // Autovector state
    sEND    =    9; // Cycle end state
logic [4:0] timingState;

reg nRomCEinternal,
    nMemRDinternal,
    nMemWRinternal,
    nDSACKinternal,
    nBERRinternal,
    nAVECinternal,
    memOverlay;     // 0 on reset; 1 enables read RAM page 0

wire    romSel,
        berrSel,
        modeSel;

assign nRomCE = nRomCEinternal;
assign nMemRd = nMemRDinternal;
assign nMemWr = nMemWRinternal;
assign nSterm = 1;
assign nBerr = nBERRinternal;
assign nAvec = nAVECinternal;

//assign nDsack[1] = 1;
assign nDsack[1] = 1;
assign nDsack[0] = nDSACKinternal;

// RAM chip enable signals
assign nRamCE = 4'hF;

// CPU is driving an address that should map to ROM 
//      overlay: $0000,0000 - $0007,ffff
//      runtime: $8000,0000 - $8000,0000
always_comb begin
    if(!nAS && (cpuFC[0] ^ cpuFC[1])) begin
        if(!memOverlay && RnW && !addr31 && addrSel == 0) begin
            // on reset, reads to page 0 go to ROM
            romSel <= 1;
        end else if(addr31 & addrSel == 0) begin
            // normal ROM access address range
            romSel <= 1;
        end else begin
            romSel <= 0;
        end
    end else begin
        romSel <= 0;
    end
end

// CPU is driving an address for toggling memory overlay
//      address: $8018,0000
always_comb begin
    if(!nAS && addr31 && addrSel == 3 && !RnW && (cpuFC[0] ^ cpuFC[1])) begin
        // writes to page 6 toggle the reset overlay
        modeSel = 1;
    end else begin
        modeSel = 0;
    end
end

// CPU is driving an address that doesn't map to anything
always_comb begin
    if(nAS) begin
        // no cycle, don't do BERR
        berrSel = 0;
    end else if(!addr31) begin
        // addressing RAM space, don't do BERR
        berrSel = 0;
    end else if(addr31 
            && (cpuFC[0] ^ cpuFC[1]) 
            && (addrSel == 1 || addrSel == 3)) begin
        // cycle handled by this chip, don't do BERR
        berrSel = 0;
    end else begin
        // some other cycle is happening. go do BERR
        berrSel = 1;
    end
end


// Primary timing state machine
always @(posedge sysClk or posedge nAS or negedge nReset) begin
    if(!nReset) begin
        memOverlay <= 0;            // 0 on reset, 1 enables read RAM page 0
    end else if(nAS) begin
        timingState <= sIDLE;
        nRomCEinternal <= 1;
        nMemRDinternal <= 1;
        nMemWRinternal <= 1;
        nDSACKinternal <= 1;
        nBERRinternal <= 1;
        nAVECinternal <= 1;
    end else begin
        case(timingState)
            sIDLE : begin
                // Idle state.
                // Wait for memory cycle to begin
                if(cpuFC == 3 && addrSel == 7) timingState <= sAVEC;
                else if(romSel) timingState <= sAACTV;
                else if(berrSel) timingState <= sBERR;
                else if(modeSel) timingState <= sMODE;
                else timingState <= sIDLE;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nBERRinternal <= 1;
                nAVECinternal <= 1;
            end
            sAACTV: begin
                // Async Active state
                // Always move to sAWAIT1
                timingState <= sAWAT1;
                nRomCEinternal <= 0;
                nMemRDinternal <= ~RnW;
                nMemWRinternal <= RnW;
                nDSACKinternal <= 1;
                nBERRinternal <= 1;
                nAVECinternal <= 1;
            end
            sAWAT1: begin
                // Async wait 1 state
                // Always move to sAWAT2
                timingState <= sAWAT2;
                nRomCEinternal <= 0;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nBERRinternal <= 1;
                nAVECinternal <= 1;
            end
            sAWAT2: begin
                // Async wait 2 state
                // Always move to sAWAT3
                timingState <= sAWAT3;
                nRomCEinternal <= 0;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nBERRinternal <= 1;
                nAVECinternal <= 1;
            end
            sAWAT3: begin
                // Async wait 3 state
                // Always move to sATERM
                timingState <= sATERM;
                nRomCEinternal <= 0;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 1;
                nBERRinternal <= 1;
                nAVECinternal <= 1;
            end
            sATERM: begin
                // Async Term state
                // Always move to sEND
                timingState <= sEND;
                nRomCEinternal <= 0;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= 0;
                nBERRinternal <= 1;
                nAVECinternal <= 1;
            end
            sBERR : begin
                // Bus Error state
                // Always move to sEND
                timingState <= sEND;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nBERRinternal <= 0;
                nAVECinternal <= 1;
            end
            sMODE : begin
                // Mode Switch state
                // Always move to sEND
                timingState <= sEND;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 0;
                nBERRinternal <= 1;
                memOverlay <= ~memOverlay;
                nAVECinternal <= 1;
            end
            sAVEC : begin
                // Autovector interrupt state
                // Always move to sEND
                timingState <= sEND;
                nRomCEinternal <= 1;
                nMemRDinternal <= 1;
                nMemWRinternal <= 1;
                nDSACKinternal <= 1;
                nBERRinternal <= 1;
                nAVECinternal <= 0;
            end
            sEND  : begin
                // Cycle End state
                // Wait for CPU to deassert nAS
                if(nAS) timingState <= sIDLE;
                else timingState <= sEND;
                // hold all signals at previous level except Memory Write
                nRomCEinternal <= nRomCEinternal;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= 1;    // force high early
                nDSACKinternal <= nDSACKinternal;
                nBERRinternal <= nBERRinternal;
                nAVECinternal <= nAVECinternal;
            end
            default: begin
                // How did we end up here?
                timingState <= sIDLE;
                // hold all signals at previous level
                nRomCEinternal <= nRomCEinternal;
                nMemRDinternal <= nMemRDinternal;
                nMemWRinternal <= nMemWRinternal;
                nDSACKinternal <= nDSACKinternal;
                nBERRinternal <= nBERRinternal;
                nAVECinternal <= nAVECinternal;
            end
        endcase
    end
end

endmodule
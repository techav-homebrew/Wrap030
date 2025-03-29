/******************************************************************************
 * DRAM Controller
 * techav
 * 2021-05-31
 ******************************************************************************
 * Timing and control signals for DRAM
 *****************************************************************************/

module dramctrl (
    input   wire [21:0]     cpuAddr,
    input   wire            addrBank,
    input   wire            nMemCE,
    output  logic [9:0]     memAddr,
    output  logic [1:0]     nMemRAS,
    output  logic [3:0]     nMemCAS32,
    output  logic [1:0]     nMemCAS16,
    output  logic           nMemCAS8,
    output  wire            nMemWE,
    input   wire            nCpuAS,
    input   logic [1:0]     cpuSiz,
    inout   wire            nCpuDsack,
    input   wire            cpuRnW,
    input   wire            nReset,
    input   wire            clock
);

// refresh cycle counter
logic [8:0] rCount;
always @(posedge clock or negedge nReset) begin
    if(!nReset) rCount <= 0;
    if(rCount>=511) rCount <= 0;
    else rCount <= rCount + 1;
end

// primary state machine
parameter
    S0  =   0,  // Idle state
    S1  =   1,  // Cycle row state
    S2  =   2,  // Cycle column state
    S3  =   3,  // Cycle end state
    S4  =   4,  // Refresh CAS state
    S5  =   5,  // Refresh RAS state
    S6  =   6;  // Refresh end state
logic [2:0] timingState;

always @(negedge clock or negedge nReset) begin
    if(!nReset) timingState <= S0;
    else begin
        case(timingState)
            S0  :   begin
                if(rCount==511) timingState <= S4;
                else if(!nCpuAS && !nMemCE) timingState <= S1;
                else timingState <= S0;
            end
            S1  :   begin
                timingState <= S2;
            end
            S2  :   begin
                timingState <= S3;
            end
            S3  :   begin
                if(!nCpuAS) timingState <= S3;
                else timingState <= S0;
            end
            S4  :   begin
                timingState <= S5;
            end
            S5  :   begin
                timingState <= S6;
            end
            S6  :   begin
                timingState <= S0;
            end
            default: begin
                timingState <= S0;
            end
        endcase
    end
end

endmodule
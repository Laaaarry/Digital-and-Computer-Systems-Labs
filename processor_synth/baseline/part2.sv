`timescale 1ns /1 ns
/************************** Control path **************************************************/
module control_path(
    input logic clk,
    input logic reset, 
    input logic run, 
    input logic [15:0] INSTRin,
    output logic R0in, R1in, Ain, Rin, IRin, 
    output logic [1:0] select, ALUOP,
    output logic done
); 

// Given information:
/* OPCODE format: II M X DDDDDDDDDDDD, where 
    *     II = instruction, M = Immediate, X = rX; X = (rX==0) ? r0:r1
    *     If M = 0, DDDDDDDDDDDD = 00000000000Y = rY; Y = (rY==0) r0:r1
    *     If M = 1, DDDDDDDDDDDD = #D is the immediate operand 
    *
    *  II M  Instruction   Description
    *  -- -  -----------   -----------
    *  00 0: mv    rX,rY    rX <- rY
    *  00 1: mv    rX,#D    rX <- D (sign extended)
    *  01 0: add   rX,rY    rX <- rX + rY
    *  01 1: add   rX,#D    rX <- rX + D
    *  10 0: sub   rX,rY    rX <- rX - rY
    *  10 1: sub   rX,#D    rX <- rX - D
    *  11 0: mult  rX,rY    rX <- rX * rY
    *  11 1: mult  rX,#D    rX <- rX * D 
*/

// Defining ALU operations
parameter mv = 2'b00, add = 2'b01, sub = 2'b10, mult = 2'b11;

// Parsing instruction into its components
logic [1:0] II;
logic M, rX, rY;
assign II = INSTRin[15:14];
assign M =  INSTRin[13];
assign rX = INSTRin[12];
assign rY = INSTRin[0];

// control FSM states
typedef enum logic[1:0]
{
    C0 = 2'd0,
    C1 = 2'd1, 
    C2 = 2'd2, 
    C3 = 2'd3
} statetype;

statetype current_state, next_state;


// control FSM state table
always_comb begin
    case(current_state)
	    C0: next_state = run? C1:C0;
        C1: next_state = done? C0:C2;
        C2: next_state = C3;
        C3: next_state = C0;
    endcase
end

// output logic i.e: datapath control signals
always_comb begin
    // by default, make all our signals 0
    R0in = 1'b0; R1in = 1'b0;
    Ain = 1'b0; Rin = 1'b0; IRin = 1'b0;
    select = 2'bxx; 
    ALUOP = 2'bxx;
    done = 1'b0;
    case(current_state)
        C0: begin
            // Instructions
            IRin = 1'b1;
        end
        C1: begin
            case(II)
                mv: begin
                    // Source
                    if(M) select = 2'b11;
                    else begin
                        if(rY) select = 2'b10;
                        else select = 2'b01;
                    end
                    // Destination
                    if(rX) R1in = 1'b1; else R0in = 1'b1;
                    // Indicate done
                    done = 1'b1;
                end
                default begin
                    // since this step is the same for add, sub, and mult, can be combined into default
                    // asserting temp ALU input register
                    Ain = 1'b1;
                    // selecting first ALU input based on rX
                    if (rX == 1'b0)
                        select = 2'b01;
                    else 
                        select = 2'b10;
                end
            endcase
        end
        C2: begin
            // These steps are the same regardless of add, sub, or mult. mv will never reach C2
            Rin = 1'b1; // assert result register
            // select second ALU input
            if(M) select = 2'b11;
            else begin
                if(rY) select = 2'b10;
                else select = 2'b01;
            end

            // choose ALU operation
            case(II)
                add: ALUOP = 2'b00;
                sub: ALUOP = 2'b01;
                mult: ALUOP = 2'b10;
            endcase
        end
        C3: begin
            // These steps are the same regardless of add, sub, or mult. mv will never reach C3
            select = 2'b00;
            if(rX) R1in = 1'b1; else R0in = 1'b1;
            done = 1'b1;
        end
    endcase 
end
// control FSM FlipFlop
always_ff @(posedge clk) begin
    if(reset)
        current_state <= C0;
    else
       current_state <= next_state;
end
endmodule


/************************** Datapath **************************************************/
module datapath(
    input logic clk, 
    input logic reset,
    input logic [15:0] INSTRin,
    input logic IRin, R0in, R1in, Ain, Rin,
    input logic [1:0] select, ALUOP,
    output logic [15:0] r0, r1, a, r // for testing purposes these are outputs
);
    logic [15:0] Instr, reg0, reg1, regA, regR, immediate, MUXout, ALUout;
    assign immediate = {{4{INSTRin[11]}}, INSTRin[11:0]};

    always_comb begin
        MUXout = 16'b0;
        ALUout = 16'b0;
        case(select)
            2'b00: MUXout = regR;
            2'b01: MUXout = reg0;
            2'b10: MUXout = reg1;
            2'b11: MUXout = immediate;
            default: MUXout = 16'b0;
        endcase
        case(ALUOP)
            2'b00: ALUout = regA + MUXout;
            2'b01: ALUout = regA - MUXout;
            2'b10: ALUout = regA * MUXout;
            default: ALUout = 16'b0;
        endcase
    end
    always_ff @(posedge clk) begin
        // Assuming active-high synchronous reset
        if(reset) begin
            Instr <= 16'b0;
            regA <= 16'b0;
            regR <= 16'b0;
            reg0 <= 16'b0;
            reg1 <= 16'b0;
        end
        else begin
            if(IRin) Instr <= INSTRin;
            if(Ain) regA <= MUXout;
            if(Rin) regR <= ALUout;
            if(R0in) reg0 <= MUXout;
            if(R1in) reg1 <= MUXout;
        end
        
    end
    assign r0 = reg0;
    assign r1 = reg1;
    assign a = regA;
    assign r = regR;
endmodule



/************************** processor  **************************************************/
module part2(
    input logic [15:0] INSTRin,
    input logic reset, 
    input logic clk,
    input logic run,
    output logic done,
    output logic[15:0] r0_out,r1_out, a_out, r_out
);

// intermediate logic 
logic r0in, r1in, ain, rin, irin;
logic[1:0] select, aluop;

control_path control(
   .clk(clk),
   .reset(reset), 
   .run(run), 
   .INSTRin(INSTRin),
   .R0in(r0in), 
   .R1in(r1in), 
   .Ain(ain), 
   .Rin(rin), 
   .IRin(irin), 
   .select(select), 
   .ALUOP(aluop),
   .done(done)
);

datapath data(
    .clk(clk), 
    .reset(reset),
    .INSTRin(INSTRin),
    .IRin(irin), 
    .R0in(r0in),
    .R1in(r1in), 
    .Ain(ain),
    .Rin(rin),
    .select(select), 
    .ALUOP(aluop),
    .r0(r0_out), 
    .r1(r1_out),
    .a(a_out),
    .r(r_out)
);

endmodule

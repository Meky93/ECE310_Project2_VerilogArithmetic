`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NCSU
// Engineer: Jake Lewis
// 
// Create Date: 10/12/2026 11:14:18 PM
// Design Name: project2
// Module Name: project2
// Project Name: project2
// Target Devices: 
// Tool Versions: Vivado 2026.1
// Description: A small system that accepts 8-bit 2's complement signed numbers 
//              as inputs,performs the operation (𝐴 − 𝐵) + (𝐶 − 𝐷), and provides the result as an output.// 
// Dependencies: // 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// Top level module
module Project2(

    // Input d_in has packed dimensions [7:0} therefore [7:0] preceeds the variable name.
    input signed [7:0] d_in,        // 8-bit signed input (will be A, B, C, or D depending on 'op')
    input [1:0] op,                 // 2-bit operand selector
    input reset_n,                  // Active-low synchronous reset
    input capture,                  // 1-bit capture indicator
    input clock,
    
    // Dimensions for output 'result' is also packed.
    output signed [9:0] result,     // 10-bit signed result
    output valid                    // 1-bit valid indicator
);    

// Register variables (8-bit) that will store their relative inpugts
wire signed [7:0] regA;
wire signed [7:0] regB;
wire signed [7:0] regC;
wire signed [7:0] regD;
wire Ain, Bin, Cin, Din;

    datapath datapath (
        .clock(clock),
        .reset_n(reset_n),
        .d_in(d_in),
        .Ain(Ain),
        .Bin(Bin),
        .Cin(Cin),
        .Din(Din),
        .regA(regA),
        .regB(regB),
        .regC(regC),
        .regD(regD),
        .result(result)
    );
    
    controller controller (
        .clock(clock),
        .reset_n(reset_n),
        .op(op),
        .capture(capture),
        .Ain(Ain),
        .Bin(Bin),
        .Cin(Cin),
        .Din(Din),
        .valid(valid)
    );

endmodule

// Controller module - mostly keeps track of what has been seen or not etc and handles the 'valid' signal.
module controller(  input clock,
                    input reset_n,
                    input [1:0] op,
                    input capture,
                    output Ain,
                    output Bin,
                    output Cin,
                    output Din,
                    output valid
);

wire givenA, givenB, givenC, givenD, newGivenA, newGivenB, newGivenC, newGivenD, newValid, done, nextDone, allGiven;            // indicates when all inputs have been recieved.

    // Sets signal high indicating capture = 1 and op = corresponding input
    assign Ain = (op == 2'b00) && capture;
    assign Bin = (op == 2'b01) && capture;
    assign Cin = (op == 2'b10) && capture;
    assign Din = (op == 2'b11) && capture;    
    
    assign newGivenA = givenA | Ain;
    assign newGivenB = givenB | Bin;
    assign newGivenC = givenC | Cin;
    assign newGivenD = givenD | Din;
   
    assign allGiven = givenA && givenB && givenC && givenD;

    // Produce one valid pulse after all four operands are stored.
    assign newValid = allGiven && ~done;

    // Prevent valid from repeating every other clock.
    assign nextDone = done | allGiven;
    
    // signal/flag registers  
    dff1bit valid_signal(
        .Clk(clock),
        .reset_n(reset_n),
        .D(newValid),
        .Q(valid)
    );
    
    dff1bit givenAornot(
        .Clk(clock),
        .reset_n(reset_n),
        .D(newGivenA),
        .Q(givenA)
    );
    
    dff1bit givenBornot(
        .Clk(clock),
        .reset_n(reset_n),
        .D(newGivenB),
        .Q(givenB)
    );
    
    dff1bit givenCornot(
        .Clk(clock),
        .reset_n(reset_n),
        .D(newGivenC),
        .Q(givenC)
    );
    
    dff1bit givenDornot(
        .Clk(clock),
        .reset_n(reset_n),
        .D(newGivenD),
        .Q(givenD)
     );
     
     dff1bit doneregister(
    .Clk(clock),
    .reset_n(reset_n),
    .D(nextDone),
    .Q(done)
);

endmodule

// datapath module - performs the arithmetic and handles register memory and the result.
module datapath(
input clock,
                input reset_n,
                input signed [7:0] d_in,
                input Ain,
                input Bin,
                input Cin,
                input Din,
                output signed [7:0] regA,
                output signed [7:0] regB,
                output signed [7:0] regC,
                output signed [7:0] regD,
                output signed [9:0] result
);    

// MUX output variables (register input)
wire signed [7:0] futureA;
wire signed [7:0] futureB;
wire signed [7:0] futureC;
wire signed [7:0] futureD;

// Arithmegtic variables
wire signed [9:0] A;
wire signed [9:0] B;
wire signed [9:0] C;
wire signed [9:0] D;
wire signed [9:0] notB;
wire signed [9:0] notD;
wire signed [9:0] AminusB;
wire signed [9:0] CminusD;
wire signed [9:0] calculation;

// not super important
wire notBcarry, notDcarry, sub1overflow, sub2overflow, resultoverflow;

    // MUX to organize inputs into their correct registers as the next value to be stored at pos clock edge
    assign futureA = Ain ? d_in : regA;
    assign futureB = Bin ? d_in : regB;
    assign futureC = Cin ? d_in : regC;
    assign futureD = Din ? d_in : regD;

    // sign extend stored values to 10 bits for simplified arithmetic using concatenation.
    assign A = { { 2{regA[7]} }, regA};
    assign B = { { 2{regB[7]} }, regB};
    assign C = { { 2{regC[7]} }, regC};
    assign D = { { 2{regD[7]} }, regD}; 

    // (A - B) + (C - D)
    // coonvert B to -B (negate and add 1 for n2's complement)
    ksa_10bit_adder negateB(
            .A(~B),
            .B(10'd1),
            .S(notB),
            .Cout(notBcarry)
    );   
     
    // convert D to -D (negate and add 1 for 2's complement)
    ksa_10bit_adder negateD(
            .A(~D),
            .B(10'd1),
            .S(notD),
            .Cout(notDcarry)
    );    
    
    // perform operation A - B
    ksa_10bit_adder subtractor1(
            .A(A),
            .B(notB),
            .S(AminusB),
            .Cout(sub1overflow)
    );  
    
    // perform operation C - D
    ksa_10bit_adder subtractor2(
            .A(C),
            .B(notD),
            .S(CminusD),
            .Cout(sub2overflow)
    );  
    
    // Add previous 2 results to complete (A - B) + (C - D) and asssign it to result.
    ksa_10bit_adder letsAdd(
            .A(AminusB),
            .B(CminusD),
            .S(calculation),
            .Cout(resultoverflow)
    );  
    
    // Declaring each dff register to store their relative inputs. (@ rising edge of clock wave)
    dff8bit registerA(
        .Clk(clock),
        .reset_n(reset_n),
        .D(futureA),
        .Q(regA)
    );
    
    dff8bit registerB(
        .Clk(clock),
        .reset_n(reset_n),
        .D(futureB),
        .Q(regB)
    );
    
    dff8bit registerC(
        .Clk(clock),
        .reset_n(reset_n),
        .D(futureC),
        .Q(regC)
    );
    
    dff8bit registerD(
        .Clk(clock),
        .reset_n(reset_n),    
        .D(futureD),
        .Q(regD)
    );

    dff10bit registerresult(
        .Clk(clock),
        .reset_n(reset_n),    
        .D(calculation),
        .Q(result)
    );
    
endmodule

module ksa_10bit_adder(input [9:0] A,
                       input [9:0] B,
                       output [9:0] S,
                       output Cout
);
                    
wire [9:0] P0, G0, P1, G1, P2, G2, P3, G3, P4, G4;  
                                          
    
// Nomenclature is Px[y] and Gx[y] where x is ROW and Y is COLUMN

// ROW 0

    // Column 0
    assign P0[0] = A[0] ^ B[0];
    assign G0[0] = A[0] & B[0];
    
    // Column 1
    assign P0[1] = A[1] ^ B[1];
    assign G0[1] = A[1] & B[1];       
    
    // Column 2
    assign P0[2] = A[2] ^ B[2];
    assign G0[2] = A[2] & B[2];
    
    // Column 3
    assign P0[3] = A[3] ^ B[3];
    assign G0[3] = A[3] & B[3];
 
     // Column 4
    assign P0[4] = A[4] ^ B[4];
    assign G0[4] = A[4] & B[4];
    
    // Column 5
    assign P0[5] = A[5] ^ B[5];
    assign G0[5] = A[5] & B[5];       
    
    // Column 6
    assign P0[6] = A[6] ^ B[6];
    assign G0[6] = A[6] & B[6];
    
    // Column 7
    assign P0[7] = A[7] ^ B[7];
    assign G0[7] = A[7] & B[7];
    
    // Column 8
    assign P0[8] = A[8] ^ B[8];
    assign G0[8] = A[8] & B[8];
    
    // Column 9
    assign P0[9] = A[9] ^ B[9];
    assign G0[9] = A[9] & B[9]; 
 
// ROW 1

    // Column 0
    assign P1[0] = P0[0];
    assign G1[0] = G0[0];
    
    // Column 1
    assign P1[1] = P0[1] & P0[0];
    assign G1[1] = ( P0[1] & G0[0] ) | G0[1];
    
    // Column 2
    assign P1[2] = P0[2] & P0[1];
    assign G1[2] = ( P0[2] & G0[1] ) | G0[2];
    
    // Column 3
    assign P1[3] = P0[3] & P0[2];
    assign G1[3] = ( P0[3] & G0[2] ) | G0[3];
    
    // Column 4
    assign P1[4] = P0[4] & P0[3];
    assign G1[4] = ( P0[4] & G0[3] ) | G0[4];
    
    // Column 5
    assign P1[5] = P0[5] & P0[4];
    assign G1[5] = ( P0[5] & G0[4] ) | G0[5];
    
    // Column 6
    assign P1[6] = P0[6] & P0[5];
    assign G1[6] = ( P0[6] & G0[5] ) | G0[6];
    
    // Column 7
    assign P1[7] = P0[7] & P0[6];
    assign G1[7] = ( P0[7] & G0[6] ) | G0[7];
    
    // Column 8
    assign P1[8] = P0[8] & P0[7];
    assign G1[8] = ( P0[8] & G0[7] ) | G0[8];
    
    // Column 9
    assign P1[9] = P0[9] & P0[8];
    assign G1[9] = ( P0[9] & G0[8] ) | G0[9];

// Row 2

    // Column 0
    assign P2[0] = P1[0];
    assign G2[0] = G1[0];
    
    // Column 1
    assign P2[1] = P1[1];
    assign G2[1] = G1[1];
    
    // Column 2
    assign P2[2] = P1[2] & P1[0];
    assign G2[2] = ( P1[2] & G1[0] ) | G1[2];
    
    // Column 3
    assign P2[3] = P1[3] & P1[1];
    assign G2[3] = ( P1[3] & G1[1] ) | G1[3];
    
    // Column 4
    assign P2[4] = P1[4] & P1[2];
    assign G2[4] = ( P1[4] & G1[2] ) | G1[4];
    
    // Column 5
    assign P2[5] = P1[5] & P1[3];
    assign G2[5] = ( P1[5] & G1[3] ) | G1[5];
    
    // Column 6
    assign P2[6] = P1[6] & P1[4];
    assign G2[6] = ( P1[6] & G1[4] ) | G1[6];
    
    // Column 7
    assign P2[7] = P1[7] & P1[5];
    assign G2[7] = ( P1[7] & G1[5] ) | G1[7];
    
    // Column 8
    assign P2[8] = P1[8] & P1[6];
    assign G2[8] = ( P1[8] & G1[6] ) | G1[8];
    
    // Column 9
    assign P2[9] = P1[9] & P1[7];
    assign G2[9] = ( P1[9] & G1[7] ) | G1[9];

// Row 3 - distance of 4

    // Column 0
    assign P3[0] = P2[0];
    assign G3[0] = G2[0];

    // Column 1    
    assign P3[1] = P2[1];
    assign G3[1] = G2[1];
    
    // Column 2 
    assign P3[2] = P2[2];
    assign G3[2] = G2[2];
    
    // Column 3 
    assign P3[3] = P2[3];
    assign G3[3] = G2[3];
    
    // Column 4     
    assign P3[4] = P2[4] & P2[0];
    assign G3[4] = (P2[4] & G2[0]) | G2[4];
    
    // Column 5 
    assign P3[5] = P2[5] & P2[1];
    assign G3[5] = (P2[5] & G2[1]) | G2[5];
    
    // Column 6 
    assign P3[6] = P2[6] & P2[2];
    assign G3[6] = (P2[6] & G2[2]) | G2[6];
    
    // Column 7 
    assign P3[7] = P2[7] & P2[3];
    assign G3[7] = (P2[7] & G2[3]) | G2[7];
    
    // Column 8 
    assign P3[8] = P2[8] & P2[4];
    assign G3[8] = (P2[8] & G2[4]) | G2[8];
    
    // Column 9 
    assign P3[9] = P2[9] & P2[5];
    assign G3[9] = (P2[9] & G2[5]) | G2[9];
    
// Row 4 - distance of 8                

    // Column 0
    assign P4[0] = P3[0];
    assign G4[0] = G3[0];
    
    // Column 1
    assign P4[1] = P3[1];
    assign G4[1] = G3[1];
    
    // Column 2
    assign P4[2] = P3[2];
    assign G4[2] = G3[2];
    
    // Column 3
    assign P4[3] = P3[3];
    assign G4[3] = G3[3];
    
    // Column 4
    assign P4[4] = P3[4];
    assign G4[4] = G3[4];
    
    // Column 5
    assign P4[5] = P3[5];
    assign G4[5] = G3[5];
    
    // Column 6
    assign P4[6] = P3[6];
    assign G4[6] = G3[6];
    
    // Column 7
    assign P4[7] = P3[7];
    assign G4[7] = G3[7];
    
    // Column 8
    assign P4[8] = P3[8] & P3[0];
    assign G4[8] = (P3[8] & G3[0]) | G3[8];
    
    // Column 9
    assign P4[9] = P3[9] & P3[1];
    assign G4[9] = (P3[9] & G3[1]) | G3[9];
    
    // Final Output assignment to S and Cout from previous calculations.
    assign S[0] = P0[0];
    assign S[1] = P0[1] ^ G4[0];
    assign S[2] = P0[2] ^ G4[1];
    assign S[3] = P0[3] ^ G4[2];
    assign S[4] = P0[4] ^ G4[3];
    assign S[5] = P0[5] ^ G4[4];
    assign S[6] = P0[6] ^ G4[5];
    assign S[7] = P0[7] ^ G4[6];
    assign S[8] = P0[8] ^ G4[7];
    assign S[9] = P0[9] ^ G4[8];
    assign Cout = G4[9];

endmodule

// These D Flip-Flop modules are for register storage and were obtained from Professor Cutitaru's lecture slides (with reset added).
module dff8bit(output reg [7:0] Q,
               input [7:0] D,
               input Clk, reset_n
);

    always @(posedge Clk) begin
        if (!reset_n)
            Q <= 8'b0;
        else
            Q <= D;
    end
        
endmodule

module dff1bit(output reg Q,
               input D,
               input Clk, reset_n
);

    always @(posedge Clk) begin
        if (!reset_n)
            Q <= 1'b0;
        else
            Q <= D;
    end
        
endmodule

module dff10bit(output reg  [9:0] Q,
               input [9:0] D,
               input Clk, reset_n
);

    always @(posedge Clk) begin
        if (!reset_n)
            Q <= 10'b0;
        else
            Q <= D;
    end
        
endmodule














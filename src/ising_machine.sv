module ising_machine #(
    parameter N = 16,
    parameter fractionalBits = 16,
    parameter dataWidth = 32
)(
    input   logic clk,
    input   logic n_rst,
    input   logic start,  // a 2D coupling matrix, couplingMatrix[i][j] describes relationships between oscillators i and j
    input   logic signed [dataWidth-1:0] couplingMatrix [N-1:0][N-1:0],  // final states of N oscillators, now in a 1D array
    input   logic signed [dataWidth-1:0] stopTime,  
    input   logic signed [dataWidth-1:0] deltaT,
    output  logic signed [dataWidth-1:0] finalPhases [N-1:0]
    output  logic done
);

typedef enum logic [2:0] {
    IDLE,
    INIT,
    COMPUTE,
    UPDATE,
    FINISH
};
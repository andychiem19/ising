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
} state_t;

state_t state;

always_ff (@posedge clk or negedge n_rst) begin
    if !(n_rst) begin
        state <= IDLE;
        done <= 0;
    end
    // initialize inputs to zero, etc. here later
    else begin
        case (state)
            IDLE: begin
                done <= 0;
                // state transition hinges on start flag
                // reinitializes values to starting values
            end
            INIT: begin
                // initialize values to a random phase in a certain interval
                // once this process is complete, transition to computation phase
            end
            COMPUTE: begin
                // compute coupling forces 
            end
            UPDATE: begin
                // update all phases based upon these coupling forces
                // if stop threshold has been met, could be temp, or just simulation time, transition to finish, else loop back to compute
            end
            FINISH: begin
                // return done <= 1
                // return to IDLE
            end
end
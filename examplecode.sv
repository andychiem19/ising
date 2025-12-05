// Simplified Working Ising Machine
// Uses basic Kuramoto model with fixed-point Q16.16

// example written by Claude

module ising_machine #(
    parameter N = 16,
    parameter FRAC_BITS = 16,
    parameter DATA_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic signed [DATA_WIDTH-1:0] J [N-1:0][N-1:0],
    input  logic signed [DATA_WIDTH-1:0] T_stop,
    input  logic signed [DATA_WIDTH-1:0] delta_T,
    output logic signed [DATA_WIDTH-1:0] phi_out [N-1:0],
    output logic done
);

    typedef enum logic [2:0] {
        IDLE,
        INIT,
        COMPUTE,
        UPDATE,
        FINISH
    } state_t;
    
    state_t state;
    
    // Registers
    logic signed [DATA_WIDTH-1:0] phi [N-1:0];
    logic signed [63:0] force_accum [N-1:0];  // Wide accumulator
    logic signed [DATA_WIDTH-1:0] temperature;
    logic [15:0] iter_count;
    logic [7:0] i, j;
    
    // Constants
    localparam signed [DATA_WIDTH-1:0] PI = 32'h0003243F;      // π ≈ 3.14159
    localparam signed [DATA_WIDTH-1:0] TWO_PI = 32'h0006487E;  // 2π
    localparam signed [DATA_WIDTH-1:0] T_INIT = 32'h000A0000;  // 10.0
    
    // 16-bit LFSR for random init
    logic [15:0] lfsr;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            temperature <= T_INIT;
            iter_count <= 0;
            i <= 0;
            j <= 0;
            lfsr <= 16'hACE1;
            
            for (int k = 0; k < N; k++) begin
                phi[k] <= 0;
                force_accum[k] <= 0;
                phi_out[k] <= 0;
            end
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        temperature <= T_INIT;
                        iter_count <= 0;
                        i <= 0;
                        lfsr <= 16'hACE1;
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize phases with LFSR random values
                    if (i < N) begin
                        // Generate random phase between -π/4 and +π/4
                        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
                        phi[i] <= {{18{lfsr[15]}}, lfsr[13:0]};  // Small random value
                        i <= i + 1;
                    end
                    else begin
                        i <= 0;
                        j <= 0;
                        // Clear force accumulators
                        for (int k = 0; k < N; k++) begin
                            force_accum[k] <= 0;
                        end
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Compute coupling forces for all oscillator pairs
                    if (i < N) begin
                        if (j < N) begin
                            if (i != j) begin
                                // Force from j on i: J[i][j] * (phi[j] - phi[i])
                                logic signed [DATA_WIDTH-1:0] phase_diff;
                                logic signed [63:0] coupling_term;
                                
                                phase_diff = phi[j] - phi[i];
                                
                                // J[i][j] * phase_diff (using sin(x) ≈ x approximation)
                                coupling_term = J[i][j] * phase_diff;
                                force_accum[i] <= force_accum[i] + coupling_term;
                            end
                            j <= j + 1;
                        end
                        else begin
                            j <= 0;
                            i <= i + 1;
                        end
                    end
                    else begin
                        i <= 0;
                        state <= UPDATE;
                    end
                end
                
                UPDATE: begin
                    // Update all phases
                    if (i < N) begin
                        logic signed [DATA_WIDTH-1:0] delta;
                        logic signed [DATA_WIDTH-1:0] new_phi;
                        
                        // Scale force and apply time step
                        // delta = (delta_T * force) / (2^FRAC_BITS)^2
                        delta = (delta_T * force_accum[i][63:32]) >>> FRAC_BITS;
                        
                        new_phi = phi[i] + delta;
                        
                        // Wrap to [-π, π]
                        if (new_phi > PI)
                            new_phi = new_phi - TWO_PI;
                        if (new_phi < -PI)
                            new_phi = new_phi + TWO_PI;
                        
                        phi[i] <= new_phi;
                        force_accum[i] <= 0;  // Reset for next iteration
                        i <= i + 1;
                    end
                    else begin
                        // Cool down
                        temperature <= temperature - delta_T;
                        iter_count <= iter_count + 1;
                        i <= 0;
                        j <= 0;
                        
                        // Check stopping condition
                        if (temperature <= T_stop || iter_count >= 500) begin
                            state <= FINISH;
                        end
                        else begin
                            state <= COMPUTE;
                        end
                    end
                end
                
                FINISH: begin
                    // Output final phases
                    for (int k = 0; k < N; k++) begin
                        phi_out[k] <= phi[k];
                    end
                    done <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
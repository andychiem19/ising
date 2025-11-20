// Oscillator-based Ising Machine in SystemVerilog
// Fixed-point arithmetic: Q16.16 format (16 integer bits, 16 fractional bits)

// example written by Claude

module ising_machine #(
    parameter N = 16,              // Number of oscillators
    parameter FRAC_BITS = 16,      // Fractional bits for fixed-point
    parameter DATA_WIDTH = 32      // Total data width
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic signed [DATA_WIDTH-1:0] J [N-1:0][N-1:0],  // Coupling matrix
    input  logic signed [DATA_WIDTH-1:0] T_stop,
    input  logic signed [DATA_WIDTH-1:0] delta_T,
    output logic signed [DATA_WIDTH-1:0] phi_out [N-1:0],   // Final phases
    output logic done
);

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        COMPUTE_K,
        COMPUTE_FORCES,
        UPDATE_PHASE,
        FINISH
    } state_t;
    
    state_t state, next_state;
    
    // Internal registers
    logic signed [DATA_WIDTH-1:0] phi [N-1:0];          // Current phases
    logic signed [DATA_WIDTH-1:0] phi_next [N-1:0];     // Next phases
    logic signed [DATA_WIDTH-1:0] delta_phi [N-1:0];    // Phase derivatives
    logic signed [DATA_WIDTH-1:0] K, Ks;
    logic signed [DATA_WIDTH-1:0] q_counter;
    logic signed [DATA_WIDTH-1:0] max_iterations;
    logic [7:0] osc_idx;                                 // Oscillator index
    
    // Fixed-point constants
    localparam signed [DATA_WIDTH-1:0] ONE = 32'h00010000;     // 1.0 in Q16.16
    localparam signed [DATA_WIDTH-1:0] TWO = 32'h00020000;     // 2.0 in Q16.16
    localparam signed [DATA_WIDTH-1:0] TWENTY = 32'h00140000;  // 20.0 in Q16.16
    localparam signed [DATA_WIDTH-1:0] PI = 32'h0003243F;      // π in Q16.16
    
    // Compute max iterations
    always_comb begin
        max_iterations = (T_stop * ONE) / delta_T;
    end
    
    // State machine - sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // State machine - combinational
    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT;
            INIT: next_state = COMPUTE_K;
            COMPUTE_K: next_state = COMPUTE_FORCES;
            COMPUTE_FORCES: 
                if (osc_idx == N-1) next_state = UPDATE_PHASE;
            UPDATE_PHASE: 
                if (q_counter >= max_iterations) next_state = FINISH;
                else next_state = COMPUTE_K;
            FINISH: next_state = IDLE;
        endcase
    end
    
    // Main computation logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < N; i++) begin
                phi[i] <= 32'sd0;
                phi_next[i] <= 32'sd0;
                delta_phi[i] <= 32'sd0;
            end
            q_counter <= 32'sd0;
            osc_idx <= 8'd0;
            K <= ONE;
            Ks <= ONE;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    q_counter <= 32'sd0;
                end
                
                INIT: begin
                    // Initialize phases (random or zero)
                    for (int i = 0; i < N; i++) begin
                        phi[i] <= 32'sd0;  // Start at zero phase
                    end
                    q_counter <= 32'sd1;
                    osc_idx <= 8'd0;
                end
                
                COMPUTE_K: begin
                    // K = 1 + q*delta_T/20
                    K <= ONE + ((q_counter * delta_T) / TWENTY);
                    // Ks = 1 + 2*M(q*delta_T)
                    // Simplified: M(t) approximated as tanh-like function
                    Ks <= ONE + (TWO * modulation_func(q_counter * delta_T));
                    osc_idx <= 8'd0;
                end
                
                COMPUTE_FORCES: begin
                    if (osc_idx < N) begin
                        // Compute forces for oscillator osc_idx
                        logic signed [DATA_WIDTH-1:0] lf, ss;
                        logic signed [DATA_WIDTH-1:0] coupling_sum;
                        
                        // Compute locking force (simplified)
                        coupling_sum = 32'sd0;
                        for (int j = 0; j < N; j++) begin
                            logic signed [DATA_WIDTH-1:0] pd;
                            pd = phi[osc_idx] - phi[j];
                            // C(pd) approximated as cos(pd) using CORDIC or LUT
                            coupling_sum += (J[osc_idx][j] * cos_approx(pd)) >>> FRAC_BITS;
                        end
                        lf = -(K * coupling_sum) >>> FRAC_BITS;
                        
                        // Compute self-stabilization force
                        ss = -(Ks * sin_approx(TWO * phi[osc_idx])) >>> FRAC_BITS;
                        
                        delta_phi[osc_idx] <= lf + ss;
                        osc_idx <= osc_idx + 1;
                    end
                end
                
                UPDATE_PHASE: begin
                    // Update all phases: phi = B(phi + delta_T * delta_phi)
                    for (int i = 0; i < N; i++) begin
                        phi_next[i] = phi[i] + ((delta_T * delta_phi[i]) >>> FRAC_BITS);
                        // Boundary function: wrap to [-π, π]
                        phi[i] <= wrap_phase(phi_next[i]);
                    end
                    q_counter <= q_counter + 1;
                end
                
                FINISH: begin
                    for (int i = 0; i < N; i++) begin
                        phi_out[i] <= phi[i];
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Helper function: cosine approximation (first-order)
    function automatic logic signed [DATA_WIDTH-1:0] cos_approx(
        input logic signed [DATA_WIDTH-1:0] x
    );
        // Simple approximation: cos(x) ≈ 1 - x²/2 for small x
        logic signed [DATA_WIDTH-1:0] x_sq;
        x_sq = (x * x) >>> FRAC_BITS;
        return ONE - (x_sq >>> 1);
    endfunction
    
    // Helper function: sine approximation (first-order)
    function automatic logic signed [DATA_WIDTH-1:0] sin_approx(
        input logic signed [DATA_WIDTH-1:0] x
    );
        // Simple approximation: sin(x) ≈ x for small x
        return x;
    endfunction
    
    // Helper function: modulation (sigmoid-like)
    function automatic logic signed [DATA_WIDTH-1:0] modulation_func(
        input logic signed [DATA_WIDTH-1:0] t
    );
        // Simplified: returns value between 0 and 1
        // Can implement tanh or sigmoid lookup table
        if (t > (10 << FRAC_BITS)) return ONE;
        else if (t < 0) return 32'sd0;
        else return t >>> 4;  // Linear approximation
    endfunction
    
    // Helper function: wrap phase to [-π, π]
    function automatic logic signed [DATA_WIDTH-1:0] wrap_phase(
        input logic signed [DATA_WIDTH-1:0] phase
    );
        logic signed [DATA_WIDTH-1:0] wrapped;
        wrapped = phase;
        while (wrapped > PI) wrapped = wrapped - (TWO * PI);
        while (wrapped < -PI) wrapped = wrapped + (TWO * PI);
        return wrapped;
    endfunction

endmodule
// Testbench for Oscillator-based Ising Machine
// MAX-CUT Problem: 6-node graph (2x3 grid)
// 
// Graph layout:
// 0 -- 1 -- 2
// |    |    |
// 3 -- 4 -- 5
//
// Optimal solution: checkerboard pattern
// Set A {0,2,4}: +1, Set B {1,3,5}: -1 (or vice versa)
// This cuts 6 out of 7 edges total

// example written by Claude

`timescale 1ns/1ps

module tb_ising_maxcut;

    // Parameters
    localparam N = 6;
    localparam DATA_WIDTH = 32;
    localparam FRAC_BITS = 16;
    localparam CLK_PERIOD = 10;
    
    // Fixed-point constants
    localparam signed [DATA_WIDTH-1:0] ONE = 32'h00010000;      // 1.0
    localparam signed [DATA_WIDTH-1:0] NEG_ONE = 32'hFFFF0000;  // -1.0
    localparam signed [DATA_WIDTH-1:0] HALF = 32'h00008000;     // 0.5
    
    // DUT signals
    logic clk;
    logic rst_n;
    logic start;
    logic signed [DATA_WIDTH-1:0] J [N-1:0][N-1:0];
    logic signed [DATA_WIDTH-1:0] T_stop;
    logic signed [DATA_WIDTH-1:0] delta_T;
    logic signed [DATA_WIDTH-1:0] phi_out [N-1:0];
    logic done;
    
    // Testbench variables
    integer i, j;
    integer cut_edges;
    logic [N-1:0] spin_state;  // Binary representation of spins
    
    // Instantiate DUT
    ising_machine #(
        .N(N),
        .FRAC_BITS(FRAC_BITS),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .J(J),
        .T_stop(T_stop),
        .delta_T(delta_T),
        .phi_out(phi_out),
        .done(done)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Initialize coupling matrix J for MAX-CUT
    // For MAX-CUT: J[i][j] = -1 if edge exists (we want anti-alignment)
    // J[i][j] = 0 if no edge
    task setup_maxcut_graph();
        // Initialize all to zero
        for (i = 0; i < N; i++) begin
            for (j = 0; j < N; j++) begin
                J[i][j] = 32'sd0;
            end
        end
        
        // Define edges for 2x3 grid
        // Horizontal edges
        J[0][1] = NEG_ONE; J[1][0] = NEG_ONE;  // 0--1
        J[1][2] = NEG_ONE; J[2][1] = NEG_ONE;  // 1--2
        J[3][4] = NEG_ONE; J[4][3] = NEG_ONE;  // 3--4
        J[4][5] = NEG_ONE; J[5][4] = NEG_ONE;  // 4--5
        
        // Vertical edges
        J[0][3] = NEG_ONE; J[3][0] = NEG_ONE;  // 0--3
        J[1][4] = NEG_ONE; J[4][1] = NEG_ONE;  // 1--4
        J[2][5] = NEG_ONE; J[5][2] = NEG_ONE;  // 2--5
        
        $display("========================================");
        $display("MAX-CUT Problem Setup: 2x3 Grid");
        $display("========================================");
        $display("Graph structure:");
        $display("  0 -- 1 -- 2");
        $display("  |    |    |");
        $display("  3 -- 4 -- 5");
        $display("");
        $display("Total edges: 7");
        $display("Optimal MAX-CUT: 6 edges (checkerboard)");
        $display("Expected solution:");
        $display("  Set A {0,2,4}: one spin");
        $display("  Set B {1,3,5}: opposite spin");
        $display("========================================");
    endtask
    
    // Convert phase to spin (-1 or +1)
    function automatic logic signed [DATA_WIDTH-1:0] phase_to_spin(
        input logic signed [DATA_WIDTH-1:0] phase
    );
        // If phase is closer to 0, spin = +1
        // If phase is closer to π or -π, spin = -1
        if ((phase > -HALF) && (phase < HALF))
            return ONE;
        else
            return NEG_ONE;
    endfunction
    
    // Count cut edges
    task count_cut_edges();
        cut_edges = 0;
        
        // Check each edge
        // Horizontal edges
        if (spin_state[0] != spin_state[1]) cut_edges++;  // 0--1
        if (spin_state[1] != spin_state[2]) cut_edges++;  // 1--2
        if (spin_state[3] != spin_state[4]) cut_edges++;  // 3--4
        if (spin_state[4] != spin_state[5]) cut_edges++;  // 4--5
        
        // Vertical edges
        if (spin_state[0] != spin_state[3]) cut_edges++;  // 0--3
        if (spin_state[1] != spin_state[4]) cut_edges++;  // 1--4
        if (spin_state[2] != spin_state[5]) cut_edges++;  // 2--5
    endtask
    
    // Display results
    task display_results();
        $display("\n========================================");
        $display("Simulation Results");
        $display("========================================");
        $display("Final phases (in Q16.16 fixed-point):");
        for (i = 0; i < N; i++) begin
            $display("  Node %0d: phi = 0x%08h (%.4f rad)", 
                     i, phi_out[i], $itor(phi_out[i])/65536.0);
        end
        
        $display("\nSpin configuration:");
        $display("  %s -- %s -- %s", 
                 spin_state[0] ? "+1" : "-1",
                 spin_state[1] ? "+1" : "-1",
                 spin_state[2] ? "+1" : "-1");
        $display("  |    |    |");
        $display("  %s -- %s -- %s", 
                 spin_state[3] ? "+1" : "-1",
                 spin_state[4] ? "+1" : "-1",
                 spin_state[5] ? "+1" : "-1");
        
        $display("\nCut edges: %0d / 7 total edges", cut_edges);
        
        // List which edges are cut
        $display("\nEdges cut:");
        if (spin_state[0] != spin_state[1]) $display("  ✓ 0--1");
        if (spin_state[1] != spin_state[2]) $display("  ✓ 1--2");
        if (spin_state[3] != spin_state[4]) $display("  ✓ 3--4");
        if (spin_state[4] != spin_state[5]) $display("  ✓ 4--5");
        if (spin_state[0] != spin_state[3]) $display("  ✓ 0--3");
        if (spin_state[1] != spin_state[4]) $display("  ✓ 1--4");
        if (spin_state[2] != spin_state[5]) $display("  ✓ 2--5");
        
        if (cut_edges == 6) begin
            $display("\n*** SUCCESS: Optimal MAX-CUT found! ***");
        end else if (cut_edges >= 5) begin
            $display("\n*** GOOD: Found a near-optimal cut ***");
        end else if (cut_edges >= 4) begin
            $display("\n*** FAIR: Found a reasonable cut (not optimal) ***");
        end else begin
            $display("\n*** POOR: Suboptimal solution ***");
        end
        $display("========================================\n");
    endtask
    
    // Main test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        start = 0;
        T_stop = 32'h000A0000;     // 10.0 time units
        delta_T = 32'h00000CCD;    // 0.05 time units (1/20)
        
        // Setup MAX-CUT problem
        setup_maxcut_graph();
        
        // Reset
        #(CLK_PERIOD*5);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        // Start simulation
        $display("Starting Ising machine simulation...");
        $display("T_stop = 10.0, delta_T = 0.05");
        $display("Expected iterations: %0d\n", 10.0/0.05);
        
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        
        // Wait for completion
        wait(done);
        #(CLK_PERIOD*5);
        
        // Convert phases to spins
        for (i = 0; i < N; i++) begin
            spin_state[i] = (phase_to_spin(phi_out[i]) == ONE) ? 1'b1 : 1'b0;
        end
        
        // Count cut edges
        count_cut_edges();
        
        // Display results
        display_results();
        
        // Additional verification - check for checkerboard pattern
        $display("Verification:");
        $display("  Checking for optimal checkerboard pattern...");
        
        // Check pattern: {0,2,4} vs {1,3,5}
        if ((spin_state[0] == spin_state[2]) && 
            (spin_state[2] == spin_state[4]) &&
            (spin_state[1] == spin_state[3]) && 
            (spin_state[3] == spin_state[5]) &&
            (spin_state[0] != spin_state[1])) begin
            $display("  ✓ Found checkerboard pattern!");
            $display("  Set A: {0,2,4} = %s", spin_state[0] ? "+1" : "-1");
            $display("  Set B: {1,3,5} = %s", spin_state[1] ? "+1" : "-1");
        end else begin
            $display("  ✗ Did not find expected checkerboard pattern");
            $display("  This might still be a valid solution if 6 edges are cut");
        end
        
        // Finish simulation
        #(CLK_PERIOD*10);
        $display("\nSimulation completed at time %0t ns", $time);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD * 100000);  // 1ms timeout
        $display("\n*** ERROR: Simulation timeout! ***");
        $finish;
    end
    
    // Optional: Waveform dump for viewing
    initial begin
        $dumpfile("ising_maxcut.vcd");
        $dumpvars(0, tb_ising_maxcut);
    end

endmodule
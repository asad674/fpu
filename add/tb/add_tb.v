`timescale 1ns / 1ps

module add_tb;
    // Inputs
    reg [31:0] in1, in2;
    reg RDN, RUP, RTZ, RNE, RMM;
    reg [8*8:1] mode_str;
    reg [8*16:1] test_status;
    reg [31:0] exp_res;
    // Outputs
    wire [1:0] unused;
    wire out_sign, out_sign_round;
    wire [7:0] out_exp, out_exp_round;
    wire [25:0] out_mant;
    wire [22:0] out_mant_round;
    wire [31:0] out;
    wire overflow, underflow, inexact;
    wire in1_is_norm;
    wire in1_is_subnorm;
    wire in1_is_zero;
    wire in1_is_inf;
    wire in1_is_snan;
    wire in1_is_qnan;
    wire in2_is_norm;
    wire in2_is_subnorm;
    wire in2_is_zero;
    wire in2_is_inf;
    wire in2_is_snan;
    wire in2_is_qnan;

    integer infile, outfile, err_cnt, test_cnt, ok1, ok2, n; 


    reg [1023:0] in_path;
    reg [1023:0] out_path;

    fp_type type(
        .in1 (in1),
        .in2 (in2),
        .in1_is_norm    (in1_is_norm),
        .in1_is_subnorm(in1_is_subnorm),
        .in1_is_zero      (in1_is_zero),
        .in1_is_inf       (in1_is_inf),
        .in1_is_snan(in1_is_snan),
        .in1_is_qnan     (in1_is_qnan),
        .in2_is_norm    (in2_is_norm),
        .in2_is_subnorm(in2_is_subnorm),
        .in2_is_zero      (in2_is_zero),
        .in2_is_inf       (in2_is_inf),
        .in2_is_snan(in2_is_snan),
        .in2_is_qnan(in2_is_qnan)
    );
    // Instantiate the Unit Under Test (UUT)
    add adder (
        .in1 (in1),
        .in2 (in2),
        .is_sub1(in1_is_subnorm),
        .is_sub2(in2_is_subnorm),
        .is_zero1(in1_is_zero),
        .is_zero2(in2_is_zero),
        .is_snan1(in1_is_snan),
        .is_snan2(in2_is_snan),
        .is_qnan1(in1_is_qnan),
        .is_qnan2(in2_is_qnan),
        .is_inf1 (in1_is_inf),
        .is_inf2(in2_is_inf),
        .out_sign(out_sign),
        .out_exp(out_exp),
        .out_mant(out_mant),
        .overflow (overflow),
        .underflow (underflow),
        .inexact (inexact)
    );


    rounding rounding (
        .result_mant(out_mant),
        .result_sign(out_sign),
        .result_exp (out_exp),
        .in1_sign (in1[31]),
        .in2_sign (in2[31]),
        .RTZ(RTZ),
        .RUP(RUP),
        .RDN(RDN),
        .RNE(RNE),
        .RMM(RMM),
        .is_add (1'b1),
        .is_zero1(in1_is_zero),
        .is_zero2(in2_is_zero),
        .overflow (overflow),
        .out_sign (out_sign_round),
        .out_exp (out_exp_round),
        .out_mant(out_mant_round)
    );

    assign out = {out_sign_round, out_exp_round, out_mant_round};


    initial begin
        in_path = "adder/vectors/test_rne.txt";
        out_path = "adder/vectors/test_rne_result.txt";
        if ($value$plusargs("IN=%s", in_path)) begin
            $display("IN = %s", in_path);
        end
        else begin
          $display("No user entered infile path found. Using default infile path");
        end

        if ($value$plusargs("OUT=%s", out_path)) begin
            $display("OUT = %s", out_path);
        end
        else begin
          $display("No user entered outfile path found. Using default outfile path");
        end
        

        infile = $fopen(in_path, "r");
        if (infile == 0) begin
        $display("ERROR: Cannot open input file: %s", in_path);
        $finish;
        end


        outfile = $fopen(out_path, "w");
        if (outfile == 0) begin
        $display("ERROR: Cannot open output file: %s", out_path);
        $finish;
        end
        err_cnt = 0;
        test_cnt = 0;
        mode_str = "RNE";
        if ($value$plusargs("MODE=%s", mode_str)) begin
            $display("MODE = %s", mode_str);
        end
        else begin
            $display("No user entered MODE found. Using default %s MODE", mode_str);
        end
        
        
            
        RTZ=0; RUP=0; RDN=0; RNE=0; RMM=0;
        if (mode_str == "RTZ") RTZ=1;
        else if (mode_str == "RUP") RUP=1;
        else if (mode_str == "RDN") RDN=1;
        else if (mode_str == "RMM") RMM=1;
        else RNE=1;
        
        while (! $feof(infile)) begin
            n = $fscanf(infile,"%h %h %h %h\n",in1,in2, exp_res, unused);
             #10;
            test_cnt = test_cnt + 1;
                if(exp_res != out)
                begin
                    $display("in1=%h in2=%h Expected=%h Actual=%h \t", in1, in2, exp_res, out);
            
                    $fwrite(outfile, "in1=%b in2=%b Expected=%b Actual=%b GRS=%b\n", in1, in2, exp_res, out, out_mant);

                end
                if (exp_res != out) begin
                    err_cnt = err_cnt + 1;
                end
                // end
        end
        if (err_cnt == 0)begin
            test_status="\033[32mPASSED\033[0m";
        end
        else begin
            test_status="\033[31mFAILED\033[0m";
        end
        $display("MODE: %s | TOTAL ERRORS: %d/%d\t(%0.2f%%) | \033[32m%s\033[0m ", mode_str, err_cnt, test_cnt, err_cnt*100.0/test_cnt, test_status);
        $fclose(infile);
        $stop();
    end


endmodule

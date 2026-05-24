module add (
    input [31:0] in1,
    input [31:0] in2,
    input is_sub1,
    input is_sub2,
    input is_zero1,
    input is_zero2,
    input is_snan1,
    input is_snan2,
    input is_qnan1,
    input is_qnan2,
    input is_inf1,
    input is_inf2,
    output reg out_sign,
    output reg [7:0] out_exp,
    output reg [25:0] out_mant,
    output inexact,
    output overflow,
    output underflow
);

// Input Signal parts
wire        in1_sign, in2_sign;
wire [7:0]  in1_exp, in2_exp;
wire [23:0] in1_mant, in2_mant;

// Intermediate Control Signals
reg         large_num_sign, small_num_sign,  large_is_subnorm, small_is_subnorm, in1_mag_is_large;
wire        is_subtract, sticky_bit, both_subnorm, out_sign_temp, sticky_bit_sum_result;

// Exponent Signals
reg  [8:0]  large_exp, small_exp, exp_adj, exp_diff_subnorm, sum_mant_adj;
wire [8:0] exp_diff, out_exp_temp;
wire [25:0] exp_diff_to_ones;

// Mantissa Signals
reg  [26:0] large_num_mant, small_num_mant, sub_neg_in, sub_pos_in;
wire [26:0] sub_neg_in_comp, op1, op2, small_num_mant_subnorm, small_num_mant_subnorm_grs;

// Summation and Normalization
wire [27:0] sum_mant;
reg  [27:0] sum_mant_comp, sum_mant_norm, sum_mant_denorm;

// zero count
wire [4:0]  zero_count;
wire all_zeroes_flag;

assign in1_sign = in1[31];
assign in2_sign = in2[31];

assign in1_exp = in1[30:23];
assign in2_exp = in2[30:23];

assign in1_mant = {!is_sub1, in1[22:0]};
assign in2_mant = {!is_sub2, in2[22:0]};

//classifies the larger and smaller number by magnitude
always @(*) begin

    if (in1_exp != in2_exp)
        in1_mag_is_large = (in1_exp > in2_exp);
    else
        in1_mag_is_large = (in1_mant >= in2_mant);

    large_exp = {1'b0, (in1_mag_is_large ? in1_exp : in2_exp)};
    large_num_sign = (in1_mag_is_large ? in1_sign : in2_sign);
    large_num_mant = { (in1_mag_is_large ? in1_mant : in2_mant), 3'd0};
    large_is_subnorm = (in1_mag_is_large ? is_sub1 : is_sub2);


    small_exp = {1'b0, (in1_mag_is_large ? in2_exp : in1_exp)};
    small_num_sign = (in1_mag_is_large ? in2_sign : in1_sign);
    small_num_mant = { (in1_mag_is_large ? in2_mant : in1_mant), 3'd0};
    small_is_subnorm = (in1_mag_is_large ? is_sub2 : is_sub1);
end

assign both_subnorm = is_sub1 & is_sub2;
assign exp_diff = large_exp - small_exp;


//subnormal correction
always @ (*) begin
    if (!(large_is_subnorm ^ small_is_subnorm)) begin
        exp_diff_subnorm = exp_diff;
    end
    else if (small_is_subnorm)begin
        exp_diff_subnorm = exp_diff - 9'd1;
    end
    else begin
        exp_diff_subnorm = exp_diff + 9'b1;
    end
end

assign small_num_mant_subnorm = small_num_mant >> exp_diff_subnorm;


//sticky bit calculation
assign exp_diff_to_ones = (26'd1 << exp_diff_subnorm) - 1;
assign sticky_bit = |(small_num_mant & {exp_diff_to_ones,1'b1});
assign small_num_mant_subnorm_grs = {small_num_mant_subnorm[26:1], sticky_bit};

assign inexact = small_num_mant_subnorm[2] | small_num_mant_subnorm[1] | sticky_bit; 

assign is_subtract  = (in1_sign ^ in2_sign);


always @(*)begin
    if (large_num_sign)begin
        sub_neg_in = large_num_mant;
        sub_pos_in = small_num_mant_subnorm_grs;
    end
    else begin
        sub_neg_in = small_num_mant_subnorm_grs;
        sub_pos_in = large_num_mant;      
    end
end

assign sub_neg_in_comp = -sub_neg_in;

assign op1 = (is_subtract) ? sub_neg_in_comp : large_num_mant;
assign op2= (is_subtract) ? sub_pos_in : small_num_mant_subnorm_grs;

assign sum_mant = op1 + op2;

always @(*) begin
    if (~is_subtract || ((is_subtract && sum_mant[27])) || (is_subtract && small_num_sign))begin
        sum_mant_comp = sum_mant;
    end
    else begin
        sum_mant_comp = ~sum_mant + 1'b1;
    end

end

lzc #(27) lcz1({sum_mant_comp[26:0]}, zero_count, all_zeroes_flag);


//resulting mantissa normalization
always @(*)begin

    exp_adj = 8'd0;
    sum_mant_adj = 9'd0;
    sum_mant_denorm = sum_mant_comp;
    sum_mant_norm = sum_mant_denorm;

    if (!both_subnorm)begin
        if (~is_subtract && sum_mant_comp[27])begin
            exp_adj = 8'd1;
            sum_mant_adj = 9'd1;
            sum_mant_denorm = sum_mant_comp >> sum_mant_adj;
            sum_mant_norm = {sum_mant_denorm[27:1], |sum_mant_comp[1:0]};
            
        end
        else begin 
            if (is_subtract && (in1_exp == in2_exp) && (in1_mant == in2_mant)) begin
                exp_adj = -large_exp;
                sum_mant_adj = zero_count;
                sum_mant_norm = sum_mant_denorm << sum_mant_adj;
            end         
            else if (zero_count < large_exp) begin
                exp_adj = -{3'd0,zero_count};
                sum_mant_adj = zero_count;
                sum_mant_norm = sum_mant_denorm << sum_mant_adj;
                  
            end 
            else begin
                exp_adj = -large_exp;
                sum_mant_adj = large_exp - 1;
                sum_mant_norm = sum_mant_comp << sum_mant_adj;
            end                  
        end
    end
    else if (sum_mant_comp[26]) begin
         exp_adj = 8'd1;
    end
end


assign out_exp_temp = large_exp + exp_adj;
assign out_sign_temp = (~is_subtract & (in1_sign & in2_sign)) | (is_subtract & large_num_sign);

//final output decision
always@(*)begin
    if (is_snan1 || is_qnan1)begin
        out_mant = {1'b1, in1_mant[21:0], 3'd0};
        out_exp = 8'b11111111;
        out_sign = in1_sign;
    end
    else if (is_snan2 || is_qnan2)begin
        out_mant = {1'b1, in2_mant[21:0], 3'd0};
        out_exp = 8'b11111111;
        out_sign = in2_sign;
    end
    else if (is_inf1) begin
        if (is_inf2 && (in1_sign ^ in2_sign))begin
            out_mant = {1'b1, 25'd0};
            out_exp = 8'b11111111;
            out_sign = 1'b1;
        end
        else begin
            out_mant = {in1_mant[22:0], 3'd0};
            out_exp = in1_exp;
            out_sign = in1_sign;
        end
    end
    else if (is_inf2) begin
        out_mant = {in2_mant[22:0], 3'd0};
        out_exp = in2_exp;
        out_sign = in2_sign;
    end
    else if (is_zero1)begin
        if (is_zero2) begin
            out_mant = {in2_mant[22:0], 3'd0};
            out_exp = in2_exp;
            if (in1_sign && in2_sign) begin
                out_sign = 1'b1;
            end
            else begin
                out_sign = 1'b0;
            end
        end
        else begin
            out_mant = {in2_mant[22:0], 3'd0};
            out_exp = in2_exp;
            out_sign = in2_sign;
        end
    end
    else if (is_zero2)begin
        out_mant = {in1_mant[22:0], 3'd0};
        out_exp = in1_exp;
        out_sign = in1_sign;
    end
    else begin
        out_sign = out_sign_temp;
        if (out_exp_temp == 9'b011111111) begin
            out_exp = 8'b11111110;
            out_mant = 26'b11111111111111111111111111;
        end
        else begin
            out_mant = sum_mant_norm[25:0];
            out_exp = out_exp_temp;
        end
    end
end


assign overflow = large_exp[8];
assign underflow = is_sub1 & is_sub2;

endmodule

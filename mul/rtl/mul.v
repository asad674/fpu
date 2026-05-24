module mul (
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


wire all_zeroes_flag;
reg [7:0] bias;
reg exp_sum_is_zero;

//Input operand fiels
wire        in1_sign, in2_sign;
wire [7:0]  in1_exp, in2_exp;
wire [23:0] in1_mant, in2_mant;


reg large_num_sign, small_num_sign;

//Exponent signals
reg [8:0] exp_sum, exp_adj,  exp_sum_corrected, exp_sum_corrected_temp, out_exp_temp;

//Mantiss signals
reg [26:0] in1_mant_extend, in2_mant_extend;
wire [52:0] mult_mant_to_ones;
wire [53:0] mult_mant;
reg [53:0] mult_mant_norm, mult_mant_norm_temp;
reg [27:0] mult_mant_trunc;
wire [5:0] zero_count;
reg [8:0] mult_mant_adj;
wire is_sub,  sticky_bit;

wire out_sign_temp;

always @(*)begin
    if (is_sub1 || is_sub2)begin
        bias = 8'd126;
    end
    else begin
        bias = 8'd127;
    end
end

assign in1_sign = in1[31];
assign in2_sign = in2[31];

assign in1_exp = in1[30:23];
assign in2_exp = in2[30:23];

assign in1_mant = {!is_sub1, in1[22:0]};
assign in2_mant = {!is_sub2, in2[22:0]};


assign in1_mant_extend = {in1_mant, 3'd0};
assign in2_mant_extend = {in2_mant, 3'd0};
assign exp_sum = in1_exp + in2_exp;

assign exp_sum_corrected_temp = exp_sum - bias;



always @(*)begin
    if (bias >= exp_sum)begin
        exp_sum_corrected = 9'd0;
        exp_sum_is_zero = 1'b1;
    end
    else begin
        exp_sum_corrected = exp_sum_corrected_temp;
        exp_sum_is_zero = 1'b0;
    end
end

assign mult_mant = in1_mant_extend * in2_mant_extend;

lzc #(32) lcz1({mult_mant[52:21]}, zero_count);

assign mult_mant_to_ones = (53'd1 << mult_mant_adj) - 1;
assign sticky_bit = |(mult_mant & {mult_mant_to_ones,1'b1});

always @(*)begin

    if (!exp_sum_is_zero) begin
        if (mult_mant[53])begin
            mult_mant_adj = 1;
            mult_mant_norm_temp = mult_mant >> mult_mant_adj;
            mult_mant_norm = {mult_mant_norm_temp[53:1], sticky_bit}; 
            exp_adj = 9'd1;
        end
        else begin
            if (zero_count < exp_sum_corrected) begin
                exp_adj = -{4'd0,zero_count};
                mult_mant_adj = {4'd0, zero_count};
                mult_mant_norm = mult_mant << mult_mant_adj;               
            end
            else begin
                exp_adj = -exp_sum_corrected;
                mult_mant_adj = exp_sum_corrected - 1;
                mult_mant_norm = mult_mant << mult_mant_adj; 
            end                   
        end
    end
    else begin

        mult_mant_adj = ~exp_sum_corrected_temp + 2;
        mult_mant_norm_temp = mult_mant >> mult_mant_adj;
        mult_mant_norm = {mult_mant_norm_temp[53:1], sticky_bit}; 
        if (mult_mant[53] && exp_sum_corrected_temp == 0)begin 
            exp_adj = 8'd1; 
        end
        else begin
            exp_adj = 8'd0;
        end
    end
end

assign mult_mant_trunc = {mult_mant_norm[53: 27], |mult_mant_norm[26:0]};
assign out_exp_temp = exp_sum_corrected + exp_adj;
assign out_sign_temp = in1_sign ^ in2_sign;

always@(*)begin
    if (is_snan1 || is_qnan1)begin
        out_mant = {1'b1, in1_mant[21:0], 3'd0};
        out_exp = 9'b011111111;
        out_sign = in1_sign;
    end
    else if (is_snan2 || is_qnan2)begin
        out_mant = {1'b1, in2_mant[21:0], 3'd0};
        out_exp = 9'b011111111;
        out_sign = in2_sign;
    end
    else if (is_inf1) begin
        if (is_zero2) begin
            out_mant = {1'b1, in2_mant[21:0], 3'd0};
            out_exp = 9'b011111111;
            out_sign = 1'b1;
        end
        else begin
            out_mant = {in1_mant[22:0], 3'd0};
            out_exp = {1'b0, in1_exp};
            out_sign = in1_sign ^ in2_sign;
        end
    end
    else if (is_inf2) begin
        if (is_zero1) begin
            out_mant = {1'b1, in1_mant[21:0], 3'd0};
            out_exp = 9'b011111111;
            out_sign = 1'b1;
        end
        else begin
            out_mant = {in2_mant[22:0], 3'd0};
            out_exp = {1'b0, in2_exp};
            out_sign = in1_sign ^ in2_sign;
        end
    end
    else if (is_zero1 || is_zero2)begin
        out_mant = 26'd0;
        out_exp = 9'd0;
        out_sign = in1_sign ^ in2_sign;

    end
    else begin
        out_sign = out_sign_temp;
        if (out_exp_temp == 9'b011111111) begin
            out_mant = 26'b11111111111111111111111111;
            out_exp = 8'b11111110;
        end
        else begin
            out_mant = mult_mant_trunc[25:0];
            out_exp = out_exp_temp;
        end
    end
end


assign overflow = (is_snan1 || is_snan2 || is_qnan1 || is_qnan2 || is_inf1 || is_inf2) ? 1'b0 : out_exp_temp[8];
assign underflow = is_sub1 & is_sub2;

endmodule

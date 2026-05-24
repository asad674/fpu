module lzc #(
    parameter WIDTH = 128
) (
    input  wire [WIDTH-1:0]           in,
    output wire [$clog2(WIDTH+1)-1:0] count,
    output wire                       all_zero
);

    localparam CNT_W = $clog2(WIDTH + 1);

    generate
        if (WIDTH == 1) begin : g_base
            // Base case: single bit
            assign all_zero = ~in[0];
            assign count    = ~in[0];

        end else begin : g_tree
            // Split into upper (MSB) and lower (LSB) halves.
            // UPPER_W = ceil(WIDTH/2), LOWER_W = floor(WIDTH/2)
            localparam UPPER_W = WIDTH - (WIDTH / 2);
            localparam LOWER_W = WIDTH / 2;
            localparam U_CNT_W = $clog2(UPPER_W + 1);
            localparam L_CNT_W = $clog2(LOWER_W + 1);

            wire               u_all_zero, l_all_zero;
            wire [U_CNT_W-1:0] u_count;
            wire [L_CNT_W-1:0] l_count;

            lzc #(.WIDTH(UPPER_W)) u_upper (
                .in      (in[WIDTH-1 : LOWER_W]),
                .count   (u_count),
                .all_zero(u_all_zero)
            );

            lzc #(.WIDTH(LOWER_W)) u_lower (
                .in      (in[LOWER_W-1 : 0]),
                .count   (l_count),
                .all_zero(l_all_zero)
            );

            // Widen sub-results to CNT_W bits (Verilog zero-extends on assignment)
            wire [CNT_W-1:0] w_u_count = u_count;
            wire [CNT_W-1:0] w_l_count = l_count;

            // If upper half is all-zero: leading zeros = UPPER_W + lower leading zeros
            // Otherwise            : leading zeros = upper leading zeros only
            wire [CNT_W-1:0] w_l_total = UPPER_W + w_l_count;

            assign all_zero = u_all_zero & l_all_zero;
            assign count    = u_all_zero ? w_l_total : w_u_count;
        end
    endgenerate

endmodule

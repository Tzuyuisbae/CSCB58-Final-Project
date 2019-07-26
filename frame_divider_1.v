// clocks every 1 second - uses frame_divider_1_60
module frame_divider_1 (
    input CLOCK_1_60_S,
    output reg CLOCK_1
);

	reg [5:0] counter;
	
	always @(posedge CLOCK_1_60_S) begin
		if (counter == 6'd0) begin
			counter <= 6'd60;
			CLOCK_1 <= 1'b1;
		end
		
		else begin
			counter <= counter - 1'b1;
			CLOCK_1 <= 1'b0;
		end
	end
endmodule
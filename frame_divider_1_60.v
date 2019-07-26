// clocks every 1/60 of second
module frame_divider_1_60 (
    input CLOCK_50,
    output reg CLOCK_1_60_S
);

	reg [19:0] counter;
	
	always @(posedge CLOCK_50) begin
		if (counter == 20'b00000000000000000000) begin
			counter <= 20'b11001011011100110100;
			CLOCK_1_60_S <= 1'b1;
		end
		
		else begin
			counter <= counter - 1'b1;
			CLOCK_1_60_S <= 1'b0;
		end
	end
endmodule
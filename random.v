// 'generates' a random number from 0 to a number
// basically just a really fast counter
module random (
    input CLOCK_50, 
    input [15:0] limit,
    output reg [15:0] result
);
	
	always @(posedge CLOCK_50) begin
		if (result == limit) begin
            result <= 16'd0;
		end
		
		else begin
            result <= result + 1;
		end
	end
endmodule
// Module converts a binary number to binary-coded decimal
module bin2bcd(
	bin,
	bcd
);

    //input ports and their sizes
    input [15:0] bin;
    //output ports and, their size
    output [15:0] bcd;
    //Internal variables
    reg [15:0] 	bcd; 
    reg [4:0] 	i;   
     
     //Always block - implement the Double Dabble algorithm
     always @(bin)
        begin
            bcd = 0; //initialize bcd to zero.
            for (i = 0; i < 16; i = i+1) //run for 8 iterations
            begin
                bcd = {bcd[14:0],bin[15-i]}; //concatenation
                    
                //if a hex digit of 'bcd' is more than 4, add 3 to it.  
                if(i < 15 && bcd[3:0] > 4) 
                    bcd[3:0] = bcd[3:0] + 3;
                if(i < 15 && bcd[7:4] > 4)
                    bcd[7:4] = bcd[7:4] + 3;
                if(i < 15 && bcd[11:8] > 4)
                    bcd[11:8] = bcd[11:8] + 3;
                if(i < 15 && bcd[15:12] > 4)
                    bcd[15:12] = bcd[15:12] + 3;
            end
		end
endmodule
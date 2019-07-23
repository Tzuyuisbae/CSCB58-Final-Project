module block_catcher(
		//	On Board 50 MHz
		CLOCK_50,						

		// Your inputs and outputs here
        	KEY,
        	SW,
	  	LEDR,

		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B,   						//	VGA Blue[9:0]

		HEX0,
		HEX1,
		HEX2,
		HEX3,
		HEX4,
		HEX5
);

	input 		CLOCK_50;
	input [17:0] 	SW;
	input [3:0] 	KEY;

	output [9:0] 	LEDR;
	
	// Declare your inputs and outputs here
	// Do not change the following outputs
	output		VGA_CLK;   				//	VGA Clock
	output		VGA_HS;					//	VGA H_SYNC
	output		VGA_VS;					//	VGA V_SYNC
	output		VGA_BLANK_N;				//	VGA BLANK
	output		VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]

	output [6:0] HEX0;
	output [6:0] HEX1;
	output [6:0] HEX2;
	output [6:0] HEX3;
	output [6:0] HEX4;
	output [6:0] HEX5;

	wire resetn;
	assign resetn = KEY[0];

	wire [2:0] colour;
	wire [7:0] x;
	wire [7:0] y;
	wire writeEn;

	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";

	game_module(
		.left(SW[1]), //~KEY[3]),
		.right(SW[0]), // KEY[2]),
		.clk(CLOCK_50),
		.begin_game(~KEY[1]),
		.resetn(resetn),
		.writeEn(writeEn),
		.x_out(x),
		.y_out(y),
		.colour_out(colour),
		.LEDR(LEDR),
		.HEX0(HEX0),
		.HEX1(HEX1),
		.HEX2(HEX2),
		.HEX3(HEX3),
		.HEX4(HEX4),
		.HEX5(HEX5),
	);
endmodule

module game_module(
	// TODO:
	// Clean up code
	//		- maybe use ram idk ?????
	// RNG when falling / don't make balls fall at same time
	// Powerups / Uhh the reverse of powerups
	// 		- Diff colours for powerups
	// Diff colour balls
	// diff game modes
	// 		- timed (current one we making)
	//		- survival (have 3 lives)
	input left, right, clk, begin_game, resetn, 

	output reg writeEn,

	output [7:0] x_out, 
	output [7:0] y_out, 
	output [2:0] colour_out,
	output [9:0] LEDR, // for testing state

	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	output [6:0] HEX4,
	output [6:0] HEX5
	);

	reg [4:0] current_state, next_state;

	// assign LEDR[0] = current_state[0];
	// assign LEDR[1] = current_state[1];
	// assign LEDR[2] = current_state[2];
	// assign LEDR[3] = current_state[3];
	// assign LEDR[4] = current_state[4];

	// reg to keep track of x counter
	reg [8:0] count_xy;
	reg [7:0] x;
	reg [7:0] y;
	reg [2:0] colour;
	
	// start w/ 0
	reg [16:0] draw_counter;
	reg [15:0] score;
	reg [7:0] timer;
	integer count_to_60 = 0;

	wire [7:0]  timer_convert_to_bcd;

	wire [15:0] score_convert_to_bcd;

	bin2bcd digit0_1 (.bin(score[15:0]),
					.bcd(score_convert_to_bcd[15:0]));

	bin2bcd timer_display (.bin(timer[7:0]),
					.bcd(timer_convert_to_bcd[7:0]));

	hex_display H0 (
		.IN(score_convert_to_bcd[3:0]),
		.OUT(HEX0)
	);	

	hex_display H1 (
		.IN(score_convert_to_bcd[7:4]),
		.OUT(HEX1)
	);	

	hex_display H2 (
		.IN(score_convert_to_bcd[11:8]),
		.OUT(HEX2)
	);	

	hex_display H3 (
		.IN(score_convert_to_bcd[15:12]),
		.OUT(HEX3)
	);	

	hex_display H4 (
		.IN(timer_convert_to_bcd[3:0]),
		.OUT(HEX4)
	);	

	hex_display H5 (
		.IN(timer_convert_to_bcd[7:4]),
		.OUT(HEX5)
	);	

    wire [3:0] rng;

    random r(.o(rng), .clk(fps_60));

	// start pos of paddle
	integer paddle_x = 8'd72; // try 6 pixel wide
	integer paddle_x_old = 8'd72; // the previous location
	integer paddle_y = 8'd110; // at bottom

	// integer location of col 1
	integer col_1_x = 8'd0; 
	integer col_1_y = 8'd0;
	reg [3:0] count_col_1; // 2x2 by now
	reg [2:0] col_1_colour;

	// integer location of col 2
	integer col_2_x = 8'd40; 
	integer col_2_y = 8'd0;
	reg [3:0] count_col_2; // 2x2 by now
	reg [2:0] col_2_colour;

	// integer location of col 3
	integer col_3_x = 8'd80; 
	integer col_3_y = 8'd0;
	reg [3:0] count_col_3; // 2x2 by now
	reg [2:0] col_3_colour;

	// integer location of col 4
	integer col_4_x = 8'd120; 
	integer col_4_y = 8'd0;
	reg [3:0] count_col_4; // 2x2 by now
	reg [2:0] col_4_colour;

	// 60 fps counter

	wire fps_60;

	frame_divider f0 (
			.CLOCK_50(clk),
			.clk_60fps(fps_60)
				);

	// GAME STATES
	localparam 	
			DRAW_BLACK = 5'd0,
			GAME_INITIALIZE = 5'd1,
			GAME_STOP	= 5'd2,
		  	GAME_START	= 5'd3,
			MOVE_LEFT 	= 5'd4,
			MOVE_RIGHT	= 5'd5,
			ERASE_PADDLE	= 5'd6,
			ERASE_PADDLE_2	= 5'd7,
			DRAW_PADDLE	= 5'd8,

			ERASE_COL_ONE = 5'd9, // update ball
			DRAW_COL_ONE = 5'd10, // update ball

			ERASE_COL_2 = 5'd11, // update ball
			DRAW_COL_2= 5'd12, // update ball

			ERASE_COL_3 = 5'd13, // update ball
			DRAW_COL_3 = 5'd14, // update ball

			ERASE_COL_4 = 5'd15, // update ball
			DRAW_COL_4 = 5'd16; // update ball

	// STATE TABLE
	always@(posedge clk)
	begin: game_control
		case (current_state)
			DRAW_BLACK: begin
				if (draw_counter < 17'b10000000000000000) begin
						if (x >= 17'd120)
							colour = 3'b010;
						else
							colour = 3'b000;
						writeEn = 1'b1;
						x = draw_counter[7:0];
						y = draw_counter[16:8];
						draw_counter = draw_counter + 1'b1;
						end
					else begin
						draw_counter = 8'b00000000;
						next_state = GAME_INITIALIZE;
					end
				paddle_x = 8'd72;
			end
			GAME_INITIALIZE: begin
				if (count_xy <= 6'b011111) begin
					colour = 3'b111;
					writeEn = 1'd1;
					x = paddle_x + count_xy[3:0];	// the paddle is 15 pixel wide
					y = paddle_y + count_xy[4]; // the paddle is 2 pixel high
					count_xy = count_xy + 1'b1;
				end
				else begin
					count_xy = 9'b00000;
					next_state = GAME_STOP;
				end
			end
			GAME_STOP: begin
				next_state = begin_game ? GAME_START : GAME_STOP;
				col_1_y = 8'd0;
				col_1_colour = 3'b111;
				col_2_y = 8'd0;
				col_2_colour = 3'b111;
				col_3_y = 8'd0;
				col_3_colour = 3'b111;
				col_4_y = 8'd0;
				col_4_colour = 3'b111;
	 			paddle_x = 8'd72; // at middle
				paddle_y = 8'd110; // at bottom
				score <= 16'd000; // check for top score later
				timer = 8'd60;
			end
			GAME_START: begin
				if (left && fps_60) begin
					next_state = MOVE_LEFT;
				end
				else if (right && fps_60) begin
					next_state = MOVE_RIGHT;
				end
				else if (fps_60) begin
					next_state = ERASE_COL_ONE;
				end
				else
					writeEn = 1'd0;
				if (count_to_60 == 60) begin
					count_to_60 = 0;
					timer = timer - 1;
					if (timer == 0)
						next_state = DRAW_BLACK;
				end
				else if (fps_60) 
					count_to_60 = count_to_60 + 1;
			end
			MOVE_LEFT: begin
				if (paddle_x > 0) begin 
					paddle_x_old = paddle_x;
					paddle_x = paddle_x - 1'b1;
				end
				next_state = ERASE_PADDLE;
			end
			MOVE_RIGHT: begin
				if (paddle_x < 146) begin 
					paddle_x_old = paddle_x;
					paddle_x = paddle_x + 1'b1;
				end
				next_state = ERASE_PADDLE;
			end
			ERASE_PADDLE: begin
				if (count_xy <= 9'd160) begin
					colour = 3'b000;
					writeEn = 1'd1;
					x = count_xy;	// the paddle is 15 pixel wide
					y = paddle_y; // the paddle is 2 pixel high
					count_xy = count_xy + 1'b1;
				end

				else begin
					count_xy = 9'b00000;
					next_state = ERASE_PADDLE_2;
				end
			end
			ERASE_PADDLE_2: begin
				if (count_xy <= 9'd160) begin
					colour = 3'b000;
					writeEn = 1'd1;
					x = count_xy;	// the paddle is 15 pixel wide
					y = paddle_y + 1; // the paddle is 2 pixel high
					count_xy = count_xy + 1'b1;
				end

				else begin
					count_xy = 9'b00000;
					next_state = DRAW_PADDLE;
				end
			end
			DRAW_PADDLE: begin
				if (count_xy <= 6'b011111) begin
					colour = 3'b100;
					writeEn = 1'd1;
					x = paddle_x + count_xy[3:0];	// the paddle is 15 pixel wide
					y = paddle_y + count_xy[4]; // the paddle is 2 pixel high
					count_xy = count_xy + 1'b1;
				end
				else begin
					count_xy = 9'b00000;
					next_state = ERASE_COL_ONE;
				end
			end
			ERASE_COL_ONE: begin
				if (col_1_y >= 8'd109) begin // check if paddle in same x pos
					col_1_colour = rng[2:0];
					if (col_1_colour == 3'b000) begin
						col_1_colour = 3'b010;
					end
	                col_1_x = 8'd0 + rng[3:0]; 
					col_1_y = 8'd0; // reset to top
					if ((col_1_x >= paddle_x) && (col_1_x + 1 <= paddle_x + 16)) begin
						if (col_1_colour == 3'b100 && score >= 3'b100)
							score = score - 3'b100;
						else
							score = score + col_1_colour[2:0];
					end
				end
				if (count_col_1 <= 3'd4) begin
					colour = 3'b000;
					writeEn = 1'd1;
					x = col_1_x + count_col_1[0];
					y = col_1_y + count_col_1[1];
					count_col_1 = count_col_1 + 1;
				end
				else begin
					count_col_1 = 3'd0;
					col_1_y = col_1_y + 1;
					next_state = DRAW_COL_ONE;
				end
			end
			DRAW_COL_ONE: begin
				if (count_col_1 <= 3'd4) begin
					colour = col_1_colour[2:0];
					writeEn = 1'd1;
					x = col_1_x + count_col_1[0];
					y = col_1_y + count_col_1[1];
					count_col_1 = count_col_1 + 1;
				end
				else begin
					count_col_1 = 3'd0;
					next_state = ERASE_COL_2;
				end
			end


			ERASE_COL_2: begin
				if (col_2_y >= 8'd109) begin // check if paddle in same x pos
					col_2_colour = {rng[0], rng[1], rng[2]};
					if (col_2_colour == 3'b000) begin
						col_2_colour = 3'b010;
					end
	                col_2_x = 8'd40 + {rng[0], rng[1], rng[2]}; 
					col_2_y = 8'd0; // reset to top
					if ((col_2_x >= paddle_x) && (col_2_x + 1 <= paddle_x + 16)) begin
						if (col_2_colour == 3'b100 && score >= 3'b100)
							score = score - 3'b100;
						else
							score = score + col_2_colour[2:0];
					end
				end
				if (count_col_2 <= 3'd4) begin
					colour = 3'b000;
					writeEn = 1'd1;
					x = col_2_x + count_col_2[0];
					y = col_2_y + count_col_2[1];
					count_col_2 = count_col_2 + 1;
				end
				else begin
					count_col_2 = 3'd0;
					col_2_y = col_2_y + 1;
					next_state = DRAW_COL_2;
				end
			end
			DRAW_COL_2: begin
				if (count_col_2 <= 3'd4) begin
					colour = col_2_colour[2:0];
					writeEn = 1'd1;
					x = col_2_x + count_col_2[0];
					y = col_2_y + count_col_2[1];
					count_col_2 = count_col_2 + 1;
				end
				else begin
					count_col_2 = 3'd0;
					next_state = ERASE_COL_3;
				end
			end


			ERASE_COL_3: begin
				if (col_3_y >= 8'd109) begin // check if paddle in same x pos
					col_3_colour = {rng[0], rng[2], rng[1]};
					if (col_3_colour == 3'b000) begin
						col_3_colour = 3'b010;
					end
	                col_3_x = 8'd80 + {rng[0], rng[2], rng[1]}; 
					col_3_y = 8'd0; // reset to top
					if ((col_3_x >= paddle_x) && (col_3_x + 1 <= paddle_x + 16)) begin
						if (col_3_colour == 3'b100 && score >= 3'b100)
							score = score - 3'b100;
						else
							score = score + col_3_colour[2:0];
					end
				end
				if (count_col_3 <= 3'd4) begin
					colour = 3'b000;
					writeEn = 1'd1;
					x = col_3_x + count_col_3[0];
					y = col_3_y + count_col_3[1];
					count_col_3 = count_col_3 + 1;
				end
				else begin
					count_col_3 = 3'd0;
					col_3_y = col_3_y + 1;
					next_state = DRAW_COL_3;
				end
			end
			DRAW_COL_3: begin
				if (count_col_3 <= 3'd4) begin
					colour = col_3_colour[2:0];
					writeEn = 1'd1;
					x = col_3_x + count_col_3[0];
					y = col_3_y + count_col_3[1];
					count_col_3 = count_col_3 + 1;
				end
				else begin
					count_col_3 = 3'd0;
					next_state = ERASE_COL_4;
				end
			end


			ERASE_COL_4: begin
				if (col_4_y >= 8'd109) begin // check if paddle in same x pos
					col_4_colour = {rng[1], rng[2], rng[0]};
					if (col_4_colour == 3'b000) begin
						col_4_colour = 3'b010;
					end
	                col_4_x = 8'd120 + {rng[1], rng[2], rng[0]}; 
					col_4_y = 8'd0; // reset to top
					if ((col_4_x >= paddle_x) && (col_4_x + 1 <= paddle_x + 16)) begin
						if (col_4_colour == 3'b100 && score >= 3'b100)
							score = score - 3'b100;
						else
							score = score + col_4_colour[2:0];
					end
				end
				if (count_col_4 <= 3'd4) begin
					colour = 3'b000;
					writeEn = 1'd1;
					x = col_4_x + count_col_4[0];
					y = col_4_y + count_col_4[1];
					count_col_4 = count_col_4 + 1;
				end
				else begin
					count_col_4 = 3'd0;
					col_4_y = col_4_y + 1;
					next_state = DRAW_COL_4;
				end
			end
			DRAW_COL_4: begin
				if (count_col_4 <= 3'd4) begin
					colour = col_4_colour[2:0];
					writeEn = 1'd1;
					x = col_4_x + count_col_4[0];
					y = col_4_y + count_col_4[1];
					count_col_4 = count_col_4 + 1;
				end
				else begin
					count_col_4 = 3'd0;
					next_state = GAME_START;
				end
			end
		endcase
	end

	// current_state registers
    	always@(posedge clk)
    	begin: state_FFs
        	if(!resetn)
        	    current_state <= DRAW_BLACK;
        	else
        	    current_state <= next_state;
	end // state_FFS

	assign x_out = x;
	assign y_out = y;
	assign colour_out = colour; // colour is wh
endmodule

module frame_divider (
		input CLOCK_50,
		output reg clk_60fps
);

	reg [19:0] curr_frame;
	
	always @(posedge CLOCK_50) begin
		if (curr_frame == 20'b00000000000000000000) begin
			curr_frame = 20'b11001011011100110100;
			clk_60fps = 1'b1;
		end
		
		else begin
			curr_frame = curr_frame - 1'b1;
			clk_60fps = 1'b0;
		end
	end
endmodule

module hex_display(IN, OUT);
    input [3:0] IN;
	 output reg [7:0] OUT;
	 
	 always @(*)
	 begin
		case(IN[3:0])
			4'b0000: OUT = 7'b1000000;
			4'b0001: OUT = 7'b1111001;
			4'b0010: OUT = 7'b0100100;
			4'b0011: OUT = 7'b0110000;
			4'b0100: OUT = 7'b0011001;
			4'b0101: OUT = 7'b0010010;
			4'b0110: OUT = 7'b0000010;
			4'b0111: OUT = 7'b1111000;
			4'b1000: OUT = 7'b0000000;
			4'b1001: OUT = 7'b0011000;
			4'b1010: OUT = 7'b0001000;
			4'b1011: OUT = 7'b0000011;
			4'b1100: OUT = 7'b1000110;
			4'b1101: OUT = 7'b0100001;
			4'b1110: OUT = 7'b0000110;
			4'b1111: OUT = 7'b0001110;
			
			default: OUT = 7'b0111111;
		endcase

	end
endmodule


module bin2bcd(
     bin,
     bcd
    );

    
    //input ports and their sizes
    input [15:0] bin;
    //output ports and, their size
    output [15:0] bcd;
    //Internal variables
    reg [15 : 0] bcd; 
     reg [4:0] i;   
     
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

module tff_p(q,t,c);
    output q;
    input t,c;
    reg q;
    initial 
     begin 
      q=1'b1;
     end
    always @ (posedge c)
    begin
        if (t==1'b0) begin q=q; end
        else begin q=~q;  end
    end
endmodule
 
module tff1_p(q,t,c);
    output q;
    input t,c;
    reg q;
    initial 
     begin 
      q=1'b0;
     end
    always @ (posedge c)
    begin
        if (t==1'b0) begin q=q; end
        else begin q=~q;  end
    end
endmodule
 
module random(o,clk);
    output [3:0]o;      input clk;
    xor (t0,o[3],o[2]);
    assign t1=o[0];
    assign t2=o[1];
    assign t3=o[2];
    tff_p u1(o[0],t0,clk);
    tff1_p u2(o[1],t1,clk);
    tff1_p u3(o[2],t2,clk);
    tff1_p u4(o[3],t3,clk);
endmodule
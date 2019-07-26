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

	input 		    CLOCK_50;
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
		.left(SW[1]), // ~KEY[3]),
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
    input left, right, clk, begin_game, resetn,

    output reg writeEn,

	output [7:0] x_out, 
	output [7:0] y_out, 
	output [2:0] colour_out,
	output [9:0] LEDR, // for testing

	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	output [6:0] HEX4,
	output [6:0] HEX5
);

	reg [7:0] current_state, next_state;

	// reg for output to vga
	reg [16:0] draw_counter;
	reg [7:0] x;
	reg [7:0] y;
	reg [2:0] colour;

	// output to VGA
	assign x_out = x;
	assign y_out = y;
	assign colour_out = colour;

	// reg for holding the score, time, lives
	reg [15:0] score;
	reg [7:0] timer;

	// converting time/score in hex to decimal
	wire [7:0] timer_convert_to_bcd;
	wire [15:0] score_convert_to_bcd;

	// paddle position
	integer paddle_x; // start at middle
	integer paddle_y; // 10 pixels from bottom
	integer paddle_size; // 16 pixel wide paddle
	integer direction; // 0 = left, 1 = right

	// clock for 1/60 sec and 1 sec
	wire CLOCK_1_60_S;
	wire CLOCK_1;

	// wire for rng number
	wire [15:0] rng;

	// init ram for each ball
	reg [4:0] address;
	reg clock_ram;
	reg [31:0] input_ram;
	reg write_ram;
	wire [31:0] output_ram;

	// address = which ball eg. 0000 = ball 0...
	// [7:0] x value of ball
	// [15:8] y value of ball
	// [18:16] colour of ball
	// [21:19] size of ball
	// [24:22] speed of ball
	ram32x32 ram(
		.address(address),
		.clock(clock_ram),
		.data(input_ram),
		.wren(write_ram),
		.q(output_ram)
	);

	// init random number generator
	random r0 (
		.CLOCK_50(clk),
		.limit(15'd100),
		.result(rng)
	);

	// initializing clocks
	frame_divider_1_60 f0 (
		.CLOCK_50(clk),
		.CLOCK_1_60_S(CLOCK_1_60_S)
	);

	frame_divider_1 f1 (
		.CLOCK_1_60_S(CLOCK_1_60_S),
		.CLOCK_1(CLOCK_1)
	);

	// converting score/time to bcd
	bin2bcd score_display (
		.bin(score[15:0]),
		.bcd(score_convert_to_bcd[15:0])
	);

	bin2bcd timer_display (
		.bin(timer[7:0]),
		.bcd(timer_convert_to_bcd[7:0])
	);

	// HEX3 - HEX0 = current score
	// HEX5, HEX4 = timer
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

	// current_state registers
	always@(posedge clk)
    	begin: state_FFs
        	if(!resetn)
        	    current_state <= GAME_INIT;
        	else
        	    current_state <= next_state;
	end

	// GAME STATES
	localparam 	
			GAME_INIT		= 5'd0, // init the game vars
			DRAW_BG 		= 5'd1, // draw background
			INIT_PADDLE		= 5'd2, // draw paddle at start position
			GAME_STOP		= 5'd3, // wait for player to start
		  	GAME_START		= 5'd4, // when game is in play

			ERASE_PADDLE 	= 5'd5, // erase and move paddle pos
			DRAW_PADDLE		= 5'd6; // draw paddle at new position

	// STATE TABLE
	always @(posedge clk)
	begin: game_control
		case (current_state)
			GAME_INIT: begin
				// reset all var to default
				writeEn = 1'b0; 
				paddle_x = 72; // middle of screen
				paddle_y = 110; // 10 px from bottom
				paddle_size = 4;// 12 px size paddle

				next_state = DRAW_BG;
			end

			DRAW_BG: begin
				// colour all pixels black
				if (draw_counter < 17'b10000000000000000) begin
					writeEn = 1'b1;
					colour = 3'b000;
					x = draw_counter[7:0];
					y = draw_counter[16:8];
					draw_counter = draw_counter + 1'b1;
				end
				else begin
					writeEn = 1'b0;
					draw_counter = 17'b00000000;
					next_state = INIT_PADDLE;
				end
			end

			INIT_PADDLE: begin
				if (draw_counter < (6'b100000 + paddle_size)) begin
					writeEn = 1'b1;
					if (draw_counter[2:0] == 3'b000)
						colour = 3'b111;
					else
						colour = draw_counter[2:0];

					x = paddle_x + draw_counter[4:0];
					y = paddle_y + draw_counter[5]; 
					
					if (draw_counter == (paddle_size - 1))
						draw_counter = 6'b100000;
					else
						draw_counter = draw_counter + 1'b1;
				end

				else begin
					writeEn = 1'b0;
					draw_counter = 9'b00000;
					next_state = GAME_STOP;
				end
			end

			// wait for player to start
			GAME_STOP: next_state = begin_game ? GAME_START : GAME_STOP;

			GAME_START: begin
				if (left && CLOCK_1_60_S) begin
					direction = 0;
					next_state = ERASE_PADDLE;
				end

				else if (right && CLOCK_1_60_S) begin
					direction = 1;
					next_state = ERASE_PADDLE;
				end
			end

			ERASE_PADDLE: begin
				if (draw_counter < (6'b100001 + paddle_size)) begin
					writeEn = 1'b1;
					colour = 3'b000;

					x = paddle_x + draw_counter[4:0];
					y = paddle_y + draw_counter[5]; 
					
					if (draw_counter == (paddle_size - 1))
						draw_counter = 6'b100000;
					else
						draw_counter = draw_counter + 1'b1;
				end

				else begin
					// idk why i have to do this but i do
					writeEn = 1'b1;
					colour = 3'b000;
					x = paddle_x;
					y = paddle_y;
					draw_counter = 9'b00000;

					if (direction == 0)
						paddle_x = paddle_x - 1;
					else 
						paddle_x = paddle_x + 1;

					next_state = DRAW_PADDLE;
				end
			end

			DRAW_PADDLE: begin
				if (draw_counter < (6'b100000 + paddle_size)) begin
					writeEn = 1'b1;
					if (draw_counter[2:0] == 3'b000)
						colour = 3'b111;
					else
						colour = draw_counter[2:0];

					x = paddle_x + draw_counter[4:0];
					y = paddle_y + draw_counter[5]; 
					
					if (draw_counter == (paddle_size - 1))
						draw_counter = 6'b100000;
					else
						draw_counter = draw_counter + 1'b1;
				end

				else begin
					writeEn = 1'b0;
					draw_counter = 9'b00000;
					next_state = GAME_START;
				end
			end
		endcase
	end
endmodule
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
		HEX5,
		HEX6,
		HEX7
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
	output [6:0] HEX6;
	output [6:0] HEX7;

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
		.left(~KEY[3] || SW[1]),
		.right(~KEY[2] || SW[0]),
		.clk(CLOCK_50),
		.begin_game(~KEY[1]),
		.resetn(resetn),
		.mode(SW[17]), // choose game mode
		.writeEn(writeEn),
		.x_out(x),
		.y_out(y),
		.colour_out(colour),

		// for testing
		.LEDR(LEDR),
		.HEX0(HEX0),
		.HEX1(HEX1),
		.HEX2(HEX2),
		.HEX3(HEX3),
		.HEX4(HEX4),
		.HEX5(HEX5),
		.HEX6(HEX6),
		.HEX7(HEX7),

		// for testing
		.SW(SW[16:2])
	);
endmodule

module game_module(
    input left, right, clk, begin_game, resetn, mode,

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
	output [6:0] HEX5,
	output [6:0] HEX6,
	output [6:0] HEX7,


	// for testing
	input [16:3] SW
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
	// 2d array for high score for both game modes
	reg [15:0] high_score [1:0];
	reg [15:0] high_score_2 [1:0];
	reg [15:0] high_score_3 [1:0];
	reg [15:0] high_score_4 [1:0];
	reg [15:0] high_score_5 [1:0];
	// note this holds lives as well lol
	reg [7:0] timer;

	// converting time/score in hex to decimal
	wire [7:0] timer_convert_to_bcd;
	wire [7:0] power_timer_convert_to_bcd;
	wire [15:0] score_convert_to_bcd;

	// paddle position
	integer paddle_x;
	integer paddle_y;
	integer paddle_size; 
	integer direction; // 0 = left, 1 = right
	reg [2:0] paddle_colour; 

	// clock for 1/60 sec and 1 sec
	wire CLOCK_1_60_S;
	integer count_to_60;

	// wire for rng number
	wire [15:0] rng;

	// 2d reg for ball info
	reg [7:0] ball_x [10:0];
	reg [7:0] ball_y [10:0];
	reg [2:0] ball_colour [10:0];
	reg [2:0] ball_size [10:0];
	reg [2:0] ball_speed [10:0];
	reg [10:0] ball_active;
	integer curr_ball;
	integer ball_amount;
	integer time_since_last_ball;
	integer var_ball; // variation in ball spawn
	integer curr_ball_size;
	integer curr_ball_speed;
	integer base_score; // base score of a ball collected
	reg [7:0] power_up_timer; // controls time of paddle size change
	integer paddle_power; // holds whether if paddle has increase or decrease or neither
	reg [3:0] rng_goal; // to introduce more rng to spawning
	// draw bg does different things if prev state is in game or not
	reg from_game;  // init value of 0
	reg game_mode; // current game mode 0 or 1

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

	// converting score/time to bcd
	bin2bcd score_display (
		.bin(score[15:0]),
		.bcd(score_convert_to_bcd[15:0])
	);

	bin2bcd timer_display (
		.bin(timer[7:0]),
		.bcd(timer_convert_to_bcd[7:0])
	);

	bin2bcd power_timer_display (
		.bin(power_up_timer[7:0]),
		.bcd(power_timer_convert_to_bcd[7:0])
	);

	// HEX3 - HEX0 = current score
	// HEX5, HEX4 = timer
	// HEX7, HEX6 = power up timer
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

	hex_display H6 (
		.IN(power_timer_convert_to_bcd[3:0]),
		.OUT(HEX6)
	);	

	hex_display H7 (
		.IN(power_timer_convert_to_bcd[7:4]),
		.OUT(HEX7)
	);	

	// current_state registers
	always@(posedge clk)
    	begin: state_FFs
			// removed resetn will only have effect during game
			current_state <= next_state;
	end

	// GAME STATES
	localparam 	
			GAME_INIT		= 5'd0, // init the game vars
			RESET_BALLS		= 5'd1, // reset ball stats
			DRAW_BG 		= 5'd2, // draw background
			INIT_PADDLE		= 5'd3, // draw paddle at start position
			GAME_STOP		= 5'd4, // wait for player to start
		  	GAME_START		= 5'd5, // when game is in play

			ERASE_PADDLE 	= 5'd6, // erase and move paddle pos
			ERASE_PADDLE_2 	= 5'd7,
			DRAW_PADDLE		= 5'd8, // draw paddle at new position

			SPAWN_BALLS		= 5'd9, // decide whether to spawn a ball
			ERASE_BALLS		= 5'd10, // erase and move balls
			DRAW_BALLS		= 5'd11, // draw balls at new position

			// check if balls are in contact w/ bottom or paddle
			COLLISION_CHECK = 5'd12; 

	// STATE TABLE
	always @(posedge clk)
	begin: game_control
		case (current_state)
			GAME_INIT: begin
				// reset all var to default
				writeEn = 1'b0; 
				paddle_x = 44; // middle of screen
				paddle_y = 110; // 10 px from bottom
				paddle_size = 12; // 12 px size paddle
				paddle_colour = 3'b111; // white paddle
				curr_ball = 0;
				// update high scores here
				// will not update if you quit
				// FOR TESTING need to edit bakc this if statement
				if (from_game == 1) begin
					if (score > high_score[mode]) begin
						high_score[mode] = score;
						high_score_2[mode] = high_score[mode];
						high_score_3[mode] = high_score_2[mode];
						high_score_4[mode] = high_score_3[mode];
						high_score_5[mode] = high_score_4[mode];
					end

					else if (score > high_score_2[mode]) begin
						high_score_2[mode] = score;
						high_score_3[mode] = high_score_2[mode];
						high_score_4[mode] = high_score_3[mode];
						high_score_5[mode] = high_score_4[mode];
					end

					else if (score > high_score_3[mode]) begin
						high_score_3[mode] = score;
						high_score_4[mode] = high_score_3[mode];
						high_score_5[mode] = high_score_4[mode];
					end

					else if (score > high_score_4[mode]) begin
						high_score_4[mode] = score;
						high_score_5[mode] = high_score_4[mode];
					end

					else if (score > high_score_5[mode]) begin
						high_score_5[mode] = score;
					end
				end

				// display high score on hex
				score = high_score[mode];

				// FOR TESTING
				// ball_amount = 1;

				ball_amount = 9; // 9 balls on screen

				count_to_60 = 0; // reset count_to_60 to 0
				// timer will be set in game_start
				time_since_last_ball = 0; // reset ball timer
				curr_ball_size = 4; // start at biggest size
				curr_ball_speed = 1; // start at slowest speed
				power_up_timer = 8'd0; // reset power up timer

				from_game = 0;
				next_state = RESET_BALLS;
			end

			// this state is to make balls inactive
			RESET_BALLS: begin
				if (curr_ball < ball_amount + 1) begin
					ball_active[curr_ball] = 1'b0;
					curr_ball = curr_ball + 1;
				end

				else begin
					curr_ball = 0;
					next_state = DRAW_BG;
				end
			end

			DRAW_BG: begin
				// colour all pixels black
				if (draw_counter < 17'b10000000000000000) begin
					// do not draw in 100x100 if from game
					// bc of flickering
					if (from_game == 1 && x < 99)
						writeEn = 1'b0;
					else
						writeEn = 1'b1;

					x = draw_counter[7:0];
					y = draw_counter[16:8];

					// draw bg for side 'menu' blue if timer game mode
					// red if survival
					// need scores and text
					if (x >= 100)
						colour = game_mode ? 3'b100 : 3'b001;
					else
						colour = 3'b000;

					draw_counter = draw_counter + 1'b1;
				end
				else begin
					writeEn = 1'b0;
					draw_counter = 17'b00000000;
					// erase paddle or init paddle depending from where called
					next_state = from_game ? ERASE_PADDLE : INIT_PADDLE;
				end
			end

			// draw initial paddle location
			INIT_PADDLE: begin
				if (draw_counter < (6'b100000 + paddle_size)) begin
					writeEn = 1'b1;
					colour = paddle_colour;

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
			GAME_STOP: begin
				// set game mode here, cannot change during
				game_mode = mode;
				var_ball = 20 * (game_mode + 1); // ball variation speed double if gamemode 2
				next_state = begin_game ? GAME_START : GAME_STOP;
			end

			GAME_START: begin
				// reset the game when reset n is pressed
				if (!resetn) begin
					from_game = 0;
					next_state = GAME_INIT;
				end

				// set begin score and timer
				else if (from_game == 0) begin
					if (game_mode == 0)
						timer = 8'd60; // reset timer to 60
					else
						timer = 8'd5; // if survival set lives to 5
					from_game = 1;
					score = 9'd0;
				end

				// idk why using the 1 sec clock does not work
				// need to use count_to_60 lol
				// end game here when timer is 0
				else if (timer == 8'd0)
					next_state = GAME_INIT;

				// every 1/60th of second
				else if (CLOCK_1_60_S) begin
					// update screen
					next_state = DRAW_BG;

					// move left
					if (left && paddle_x > 0)
						direction = 0;

					// move right
					else if (right && paddle_x + paddle_size + 1 < 100)
						direction = 1;

					// do nothing
					else
						direction = -1;

					count_to_60 = count_to_60 + 1;
					time_since_last_ball = time_since_last_ball + 1;

					// this is every one second
					if (count_to_60 == 60) begin
						// decrement timer if in game mode 0
						if (game_mode == 0)
							timer = timer - 1;
						count_to_60 = 0;

						if (power_up_timer > 0)
							power_up_timer = power_up_timer - 1;
						else begin
							// reset paddle stats when power up ends
							paddle_power = -1;
							paddle_size = 12;
						end

						// increase diff every 15 seconds for timed game
						// every 100 score in surival increase diff
						if ((timer <= 8'd15 && game_mode == 0) || (game_mode == 1 && score >= 300))
							curr_ball_size = 1;
						else if ((timer <= 8'd30 && game_mode == 0) || (game_mode == 1 && score >= 150))
							curr_ball_speed = 2;
						else if ((timer <= 8'd45 && game_mode == 0) || (game_mode == 1 && score >= 50))
							curr_ball_size = 2;
					end
				end
			end

			// Erase the entire bottom two rows yolo
			ERASE_PADDLE: begin
				if (draw_counter < 9'd100) begin
					colour = 3'b000;
					writeEn = 1'd1;
					x = draw_counter;
					y = paddle_y;
					draw_counter = draw_counter + 1'b1;
				end

				else begin
					draw_counter = 9'b00000;
					next_state = ERASE_PADDLE_2;
				end
			end

			ERASE_PADDLE_2: begin
				if (draw_counter < 9'd100) begin
					colour = 3'b000;
					writeEn = 1'd1;
					x = draw_counter;
					y = paddle_y + 1;
					draw_counter = draw_counter + 1'b1;
				end

				else begin
					writeEn = 1'b0;
					draw_counter = 9'b00000;

					// move left or right depending on prev state
					if (direction == 0)
						paddle_x = paddle_x - 1;
					else if (direction == 1)
						paddle_x = paddle_x + 1;

					next_state = DRAW_PADDLE;
				end
			end

			// just draw the thing 
			DRAW_PADDLE: begin
				if (draw_counter < (6'b100000 + paddle_size)) begin
					writeEn = 1'b1;
					colour = paddle_colour;

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
					next_state = SPAWN_BALLS;
				end
			end

			SPAWN_BALLS: begin
				if (curr_ball < ball_amount + 1) begin
					// try to introduce rng in the thing
					if (ball_active[curr_ball] == 1'b0 && rng[3:0] == rng_goal && time_since_last_ball >= var_ball) begin
						// set ball active and reset time since last ball
						ball_active[curr_ball] = 1'b1;
						time_since_last_ball = 0;
						// set ball to top
						ball_y[curr_ball] = 1'b0;

						// rng_goal just keeps incrementing by one to introduce more 'rng'
						rng_goal = rng_goal + 1'b1;

						// set the ball size only when spawning
						// we don't want ball to change size while it is active
						ball_size[curr_ball] = curr_ball_size;

						// just introducing more "rng" lol
						if (var_ball < 30 * (game_mode + 1))
							var_ball = var_ball + 1;
						else
							var_ball = 20 * (game_mode + 1);

						// set ball colour w/ rng, make sure it isn't black tho
						if (rng[2:0] == 3'b000)
							ball_colour[curr_ball] = 3'b111;
						else
							ball_colour[curr_ball] = rng[2:0];

						// FOR TESTING
						// ball_colour[curr_ball] = SW[16:14];

						// set ball location across the play area w/ randomness
						ball_x[curr_ball] = (10 * (curr_ball - 1)) + rng[3:0];

						// FOR TESTING
						// ball_x[curr_ball] = paddle_x;
					end

					curr_ball = curr_ball + 1;
				end

				else begin
					curr_ball = 0;
					next_state = ERASE_BALLS;
				end
			end

			ERASE_BALLS: begin
				if (curr_ball < ball_amount + 1) begin
					// for some reason i need a dummy ball
					// the first has issues rendering
					if (curr_ball == 0)
						curr_ball = 1;

					// balls are squares 1x1 or 2x2 or 4x4
					else if (draw_counter <= (ball_size[curr_ball] * ball_size[curr_ball]) && ball_active[curr_ball] == 1'b1) begin
						writeEn = 1'b1;
						colour = 3'b000;

						x = ball_x[curr_ball];
						y = ball_y[curr_ball]; 

						if (ball_size[curr_ball] == 4'd4) begin
							x = x + draw_counter[1:0];
							y = y + draw_counter[3:2]; 
						end
						else if (ball_size[curr_ball] == 4'd2) begin
							x = x + draw_counter[0];
							y = y + draw_counter[1]; 
						end

						draw_counter = draw_counter + 1'b1;
					end

					else begin
						writeEn = 1'b0;
						draw_counter = 9'b00000;

						// only move ball if its active
						// looks weird when balls move in diff speeds
						// so all balls will start moving the same speed
						if (ball_active[curr_ball] == 1'b1)
							ball_y[curr_ball] = ball_y[curr_ball] + curr_ball_speed;

						curr_ball = curr_ball + 1;
					end
				end

				else begin
					curr_ball = 0;
					next_state = COLLISION_CHECK;
				end
			end

			COLLISION_CHECK: begin
				if (curr_ball < ball_amount + 1) begin

					// check if ball is at paddle depth (110 px)
					if ((ball_y[curr_ball] + ball_size[curr_ball] - 1) >= 110 && ball_active[curr_ball]) begin
						// make ball inactive
						ball_active[curr_ball] = 1'b0;

						// check if ball is within the paddle dimensions
						if (ball_x[curr_ball] + ball_size[curr_ball] - 1 >= paddle_x && ball_x[curr_ball] <= paddle_x + paddle_size - 1) begin
							// ball size = 4 -> 1, 2 -> 3, 1 -> 4 multiplication
							base_score = (5 - ball_size[curr_ball]);
							
							// blue == 001 just double score
							// green == 010 increase paddle size to 24 for 5 seconds
							// red == 100 lower timer by 5 / lose life and lose point
							// yellow == 110 decrease paddle size for 5 seconds to 6
							// magenta - cyan - white just add the colour value to score

							// power down gets priority
							// red no effect if green in effect
							// paddle power = 1 = power up 0 = power down
							if (ball_colour[curr_ball] == 3'b100 && paddle_power != 1) begin
								// if survival remove 1 life
								if (game_mode == 1) begin
									timer = timer - 1'b1;
								end

								// otherwise remove 5 secs from timer
								else if (timer > 3'b101) begin
									timer = timer - 3'b101;
								end

								// to ensure that timer is not messed up lool
								else 
									timer = 3'b000; 

								// less score given bit shift right div by 2
								base_score = base_score >> 1;
							end

							// yellow no effect if green in effect allow 'stack'
							else if (ball_colour[curr_ball] == 3'b110 && paddle_power != 1) begin
								paddle_size = 6;
								power_up_timer = 5;
								paddle_power = 0;
							end

							// blue no effect if yellow in effect
							else if (ball_colour[curr_ball] == 3'b001 && paddle_power != 0)
								base_score = base_score * 2;

							// green nothing happens if paddle is decreased do not stack as well
							else if (ball_colour[curr_ball] == 3'b010 && paddle_power == -1) begin
								paddle_size = 24;

								// ensure ball does not overlap with menu
								if (paddle_x + paddle_size + 1 >= 100)
									paddle_x = 99 - paddle_size;

								power_up_timer = 5;
								paddle_power = 1;
							end

							score = score + base_score;
						end

						// if not within bounds and game mode is 1 and not red or yellow remove life
						else if (game_mode == 1) begin
							if (ball_colour[curr_ball] == 3'b001 || ball_colour[curr_ball] == 3'b010 || ball_colour[curr_ball] == 3'b011 || ball_colour[curr_ball] == 3'b101 || ball_colour[curr_ball] == 3'b111)
								timer = timer - 1'b1;
						end

					end

					curr_ball = curr_ball + 1;
				end

				else begin
					curr_ball = 0;
					next_state = DRAW_BALLS;
				end
			end

			// p much the same as erase ball
			DRAW_BALLS: begin
				if (curr_ball < ball_amount + 1) begin
					if (curr_ball == 0)
						curr_ball = 1;

					else if (draw_counter <= (ball_size[curr_ball] * ball_size[curr_ball]) && ball_active[curr_ball] == 1'b1) begin
						writeEn = 1'b1;
						colour = ball_colour[curr_ball];

						x = ball_x[curr_ball];
						y = ball_y[curr_ball]; 

						if (ball_size[curr_ball] == 4'd4) begin
							x = x + draw_counter[1:0];
							y = y + draw_counter[3:2]; 
						end

						else if (ball_size[curr_ball] == 4'd2) begin
							x = x + draw_counter[0];
							y = y + draw_counter[1]; 
						end

						draw_counter = draw_counter + 1'b1;
					end

					else begin
						writeEn = 1'b0;
						draw_counter = 9'b00000;

						curr_ball = curr_ball + 1;
					end
				end

				else begin
					curr_ball = 0;
					next_state = GAME_START;
				end
			end
		endcase
	end
endmodule
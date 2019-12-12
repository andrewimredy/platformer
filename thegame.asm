# api5
# Andrew Imredy

.include "convenience.asm"
.include "game_settings.asm"


#	Defines the number of frames per second: 16ms -> 60fps
.eqv	GAME_TICK_MS		16
#offsets to access data from enemy array
.eqv	ENEMY_GET_X	1
.eqv	ENEMY_GET_Y	2
.eqv 	ENEMY_GET_DIR	3

.data
# don't get rid of these, they're used by wait_for_next_frame.
last_frame_time:  .word 0
frame_counter:    .word 0

#my game data here
blit_heart: 	.byte 0 1 0 1 0  1 1 1 1 1  1 1 1 1 1  0 1 1 1 0  0 0 1 0 0 
blit_player:	.byte 0xFF 5 5 5 0xFF  0xFF 3 3 3 0xFF  5 5 3 5 5  0xFF 5 5 5 0xFF  0xFF 5 0xFF 5 0xFF
blit_enemy:	.byte 0xFF 4 4 4 0xFF  0xFF 4 1 4 0xFF  4 4 4 4 4  0xFF 4 4 4 0xFF  0xFF 4 0xFF 4 0xFF 
arena_tiles:	.byte 0 0 0 0 0 0 0 0 0 0 0 0 #1 means platform
		      0 0 0 0 0 0 0 0 0 0 0 0
		      0 1 1 1 1 1 1 0 0 0 0 0  
		      0 0 0 0 0 0 0 0 0 0 0 0 
		      0 0 0 0 0 0 0 0 1 1 1 1 
		      1 1 1 1 0 0 0 0 0 0 0 0
		      0 0 0 0 0 0 1 1 0 0 0 0 
		      0 0 0 0 0 0 0 0 0 0 0 0 
		      0 0 1 1 1 1 1 1 1 1 0 0 
		      0 0 0 0 0 0 0 0 0 0 0 0
		      1 1 1 1 1 1 1 1 1 1 1 1
enemy_array:	.byte 1 50 15 1 #alive? x, y, dir
		      1 40 45 1
		      1 30 35 -1
		      1 30 5 1 
		      1 35 25 -1		 
player_hearts:	.word 3
player_x:	.word 2 #top left of model
player_y:	.word 0
inv_frames:	.word 0
player_dir:	.word 1
jump_frames:	.word 11
bullet_dir:	.word 0 #-1 left. 1 right. 0 DNE
bullet_x:	.word 0
bullet_y:	.word 0
lose_msg:	.asciiz "YOU LOSE!"
win_msg:	.asciiz "VICTORY!"
win_score:	.asciiz "SCORE:"

.text
# --------------------------------------------------------------------------------------------------

.globl game
game:
	# set up anything you need to here,
	# and wait for the user to press a key to start.

	# Wait for a key input
_game_wait:
	jal	input_get_keys
	beqz	v0, _game_wait
	
	#TEST SPACE

_game_loop:
	# check for input,
	jal     handle_input

	#master control function checks for game end
	jal game_control
	# update everything,
	jal move_player_LR
	jal move_player_UD
	jal player_shoot
	jal bullet_move
	jal enemies_move

	# draw everything
	jal	draw_player_hearts
	jal 	draw_arena_borders
	jal 	draw_platforms
	jal 	draw_bullet
	jal 	draw_enemies
	jal	draw_player

	jal	display_update_and_clear

	## This function will block waiting for the next frame!
	jal	wait_for_next_frame
	b	_game_loop

_game_over: 
	exit

#checks for win/lose conditions. displays win or lose message
game_control:
	enter s0, s1, s2
	win:
	#loop around, check if enemies are dead
	move a0, s0
	jal get_enemy_address
	move s1, v0
	lb t0, (s1)
	bnez t0, lose #if enemy alive, check lose
	blt s0, 4, win_loop #keep iterating
		#player wins here
		jal display_update_and_clear
		la a2, win_msg
		li a0, 10
		li a1, 20 
		jal display_draw_text
		la a2, win_score
		li a0, 15
		li a1, 28
		jal display_draw_text
		#calculate score
		#1000 pts for each life left
		lw t0, player_hearts
		mul s2, t0, 1000
		#1 pt for every frame left before 1min
		lw t0, frame_counter
		bgt t0, 3600, no_time_pts
		li t2, 3600
		sub t1, t2, t0
		add s2, s2, t1
		no_time_pts:
		li a0, 20
		li a1, 36
		move a2, s2
		jal display_draw_int
		jal display_update
		b _game_over
	win_loop:
	inc s0
	b win
	
	lose:
	lw t0, player_hearts
	bgtz t0, exit_game_control
		jal display_update_and_clear
		la a2, lose_msg
		li a0, 7
		li a1, 20
		jal display_draw_text
		jal display_update
		b _game_over
	exit_game_control:
	leave s0, s1, s2

#Draws number of player hearts remaining in bottom of screen
draw_player_hearts:
	enter a0, a1, a2, s0, s1, s2
	lw s0, player_hearts 
	#for (i = hearts, i<0, i--)
draw_player_hearts_loop:
	beqz s0, draw_player_hearts_end
		li a0, 62
		li s1, 6
		mul s1, s1, s0
		li a1, 57
		sub a0, a0, s1
		la a2, blit_heart
      		jal display_blit_5x5
      		dec s0
      	b draw_player_hearts_loop
draw_player_hearts_end: 	
      	leave a0, a1, a2, s0, s1, s2
      	
#draws the borders of the arena
draw_arena_borders:
	enter s0, s1, s2
	#left border
	li a0, 0
	li a1, 0
	li a2, 2
	li a3, 64
	li v1, 5
	jal display_fill_rect
	#right border
	li a0, 62
	li a1, 0
	li a2, 2
	li a3, 64
	li v1, 5
	jal display_fill_rect
	#bottom border
	li a0, 0
	li a1, 63
	li a2, 64
	li a3, 1
	li v1, 5
	jal display_fill_rect
	#divider
	li a0, 0
	li a1, 55
	li a2, 64
	li a3, 1
	li v1, 5
	jal display_fill_rect
	leave s0, s1, s2
	
#draws the platforms
draw_platforms:
	enter
	#floor
	li a0, 2
	li a1, 50
	li a2, 60
	li a3, 5
	li v1, 2
	jal display_fill_rect
	#lower big platform
	li a0, 12
	li a1, 40
	li a2, 40
	li a3, 5
	li v1, 2
	jal display_fill_rect
	#middle block
	li a0, 32
	li a1, 30
	li a2, 10
	li a3, 5
	li v1, 2
	jal display_fill_rect
	#side platform left
	li a0, 2
	li a1, 25
	li a2, 20
	li a3, 5
	li v1, 2
	jal display_fill_rect
	#side platform right
	li a0, 42
	li a1, 20
	li a2, 20
	li a3, 5
	li v1, 2
	jal display_fill_rect
	#top platform
	li a0, 7
	li a1, 10
	li a2, 30
	li a3, 5
	li v1, 2
	jal display_fill_rect
	leave

#draws player at his x, y
draw_player:
	enter a0, a1, a2
	lw a0, player_x
	lw a1, player_y
	la a2, blit_player
	#check player invuln
	lw t0, inv_frames
	bgtz t0, draw_player_inv
	jal display_blit_5x5_trans
	leave a0, a1, a2
	draw_player_inv:
	dec t0 #lose an invincibility frame
	sw t0, inv_frames
	li t1, 3
	lw t2, frame_counter
	rem t1, t2, t1
	bnez t1, draw_player_exit
	jal display_blit_5x5_trans
	draw_player_exit:
	leave a0, a1, a2

#draws bullet if it exists
draw_bullet:
	enter 
	lw t0, bullet_dir
	beqz t0, draw_bullet_exit
		lw a0, bullet_x
		lw a1, bullet_y
		li a2, 3
		jal display_set_pixel
	draw_bullet_exit:
	leave
	
#draws the enemies 
draw_enemies:
	enter s0, s1, s2
	li s0, 0 #s0 is the iterator
	#for all enemies
draw_enemies_loop:
	li t0, 5
	beq s0, t0, draw_enemies_exit
		move a0, s0
		jal get_enemy_address
		move s1, v0
		lb t1, (s1)
		beqz t1, draw_enemies_next
		lb a0, ENEMY_GET_X(s1)
		lb a1, ENEMY_GET_Y(s1)
		la a2, blit_enemy
		jal display_blit_5x5_trans
		draw_enemies_next:
		inc s0
	b draw_enemies_loop
draw_enemies_exit:	
	leave s0, s1, s2

#moves the player one step L/R based on what's pushed
#includes wall protection
move_player_LR:
	enter s0, s1, s2, s3
	jal handle_input
move_left:
	lw s0, left_pressed
	beqz s0, move_right
		lw s0, player_x
		#wall protection here
		li t0, 2
		ble s0, t0, move_right
		#platform protection here - left head
		subi s2, s0, 1
		move a0, s2
		lw a1, player_y
		jal pixel_to_tile
		move a0, v0
		move a1, v1
		jal is_tile_platform #returned in v0
		move s3, v0
		bgtz s3, move_right
		####check left foot
		subi s2, s0, 1
		move a0, s2
		lw a1, player_y
		addi a1, a1, 4
		jal pixel_to_tile
		move a0, v0
		move a1, v1
		jal is_tile_platform #returned in v0
		move s3, v0
		bgtz s3, move_right
		dec s0 #move
		sw s0, player_x
		#store player direction
		li t0, -1
		sw t0, player_dir
move_right:
	lw s1, right_pressed
	beqz s1, exit_move_player_LR
		lw s1, player_x
		#wall protection here
		li t0, 57
		bge s1, t0, exit_move_player_LR
		#platform protection here
		#right head
		lw a0, player_x
		addi a0, a0, 5
		lw a1, player_y
		jal pixel_to_tile
		move a0, v0
		move a1, v1
		jal is_tile_platform
		bgtz v0, exit_move_player_LR
		#right foot
		lw a0, player_x
		addi a0, a0, 5
		lw a1, player_y
		addi a1, a1, 4
		jal pixel_to_tile
		move a0, v0
		move a1, v1
		jal is_tile_platform
		bgtz v0, exit_move_player_LR
		#ONCE CHECKS DONE, MOVE	
		inc s1 #move
		sw s1, player_x
		#store player direction
		li t0, 1
		sw t0, player_dir
exit_move_player_LR:
	leave s0, s1, s2, s3

#makes player jump or fall
move_player_UD:
	enter s0, s1, s2, s3, s4
	#check for platform - left corner
	lw s1, player_y 
	addi s1, s1, 5
	lw a0, player_x
	move a1, s1
	jal pixel_to_tile
	move a0, v0
	move a1, v1
	jal is_tile_platform
	move s2, v0 #s2 contains player on platform status left
	#RIGHT CORNER
	lw s1, player_y 
	addi s1, s1, 5
	lw s0, player_x
	addi s0, s0, 4
	move a1, s1
	move a0, s0
	jal pixel_to_tile
	move a0, v0
	move a1, v1
	jal is_tile_platform
	move s4, v0 #s4 contains player on platform status right
player_jump:
	jal handle_input
	lw s3, up_pressed
	beqz s3, player_fall #case 1 skip: up not pressed
	lw t0, jump_frames	#case 2 skip: out of jump frames
	beqz t0, player_fall
#end control: now calculate jump
		#move player up
		#first check head collision
		#case 1: top of arena:
		lw t0, player_y
		beqz t0, jump_sub_frames
		#case 2: head hits platform
		#LEFT HEAD
		lw a0, player_x
		lw a1, player_y
		subi a1, a1, 1
		jal pixel_to_tile
		move a0, v0
		move a1, v1
		jal is_tile_platform
		bgtz v0, jump_sub_frames
		#RIGHT HEAD
		lw a0, player_x
		lw a1, player_y
		subi a1, a1, 1
		addi a0, a0, 4
		jal pixel_to_tile
		move a0, v0
		move a1, v1
		jal is_tile_platform
		bgtz v0, jump_sub_frames
		#ACTUALLY MOVE Player
		lw s3, player_y
		dec s3
		sw s3, player_y
	jump_sub_frames:
		#subtract moves left
		lw s3, jump_frames
		dec s3
		sw s3, jump_frames
	player_jump_exit:
		b exit_move_player_UD
player_fall:
	bgtz s2, exit_player_fall
	bgtz s4, exit_player_fall#if player's on solid ground, skip
		lw s1, player_y
		inc s1
		sw s1, player_y
		b exit_move_player_UD
	exit_player_fall: #if on ground, reset jump frames
		li t0, 11
		sw t0, jump_frames
exit_move_player_UD:
	leave s0, s1, s2, s3
	
	
#takes pixel x (a0) and y (a1). returns tile x (v0) and y (v1)
pixel_to_tile:
	enter s0, s1, s2, s3
	move s0, a0
	subi s0, s0, 2 #adjust for arena wall
	move s1, a1
	#x calculation
	div s2, s0, 5
	move v0, s2
	#y calculation
	div s3, s1, 5
	move v1, s3
	leave s0, s1, s2, s3

#takes tile x (a0) and y (a1). returns 1/0 is tile platform (v0)
is_tile_platform:
	enter s0, s1, s2
	move s0, a0
	move s1, a1
	la s2, arena_tiles
	#move row
	mul s1, s1, 12
	add s2, s2, s1
	#move col
	add s2, s2, s0
	#load the byte
	lb v0, (s2)
	leave s0, s1, s2
	
	
#shoots a bullet if one doesn't exist and player presses action button
player_shoot:
	enter s0
	jal handle_input
	lw t0, action_pressed
	beqz t0, player_shoot_end #check if player is shooting
	lw t0, bullet_dir
	bnez t0, player_shoot_end #check if bullet exists
	#spawn bullet
	lw s0, player_dir
	bgtz s0, player_shoot_right
	player_shoot_left:
		#case 1: move left
		sw s0, bullet_dir
		lw t0, player_x
		subi t0, t0, 1
		sw t0, bullet_x #start bullet at left hand
		lw t1, player_y
		addi t1, t1, 2
		sw t1, bullet_y
		b player_shoot_end
	player_shoot_right: #case 2: move right
		sw s0, bullet_dir
		lw t0, player_x
		addi t0, t0, 5
		sw t0, bullet_x
		lw t1, player_y
		addi t1, t1, 2
		sw t1, bullet_y
player_shoot_end:
	leave s0

#moves the bullet 1 px per frame
bullet_move:
	enter
		lw t0, bullet_x 
		#check for it hitting the border
		li t2, 2
		li t3, 61
		ble t0, t2, delete_bullet_move
		bge t0, t3, delete_bullet_move
			lw t1, bullet_dir #move it
			add t0, t0, t1
			sw t0, bullet_x
			b exit_bullet_move
	delete_bullet_move:
		li t0, 0 
		sw t0, bullet_dir
	exit_bullet_move:		
	leave

#input: enemy number (0-4). (a0). output: enemy address in memory (v0)
get_enemy_address:
	enter s0, s1
		move s0, a0
		mul s0, s0, 4
		la s1, enemy_array
		add s1, s1, s0
		move v0, s1
	leave s0, s1
	
#moves enemies, checks for collisions
enemies_move:
	enter s0, s1, s2, s3, s4
	#control: moves enemies every 5th loop
	lw t0, frame_counter
	rem t0, t0, 5
	bnez t0, check_collisions
	
	#for each enemy, move
	li s0, 0 #counter
	enemies_move_loop:
		li t0, 5
		beq s0, t0, enemies_move_exit
			move a0, s0
			jal get_enemy_address
			move s1, v0 #s1 contains address						
			#get enemy x in s2
			lb s2, ENEMY_GET_X(s1)
			#get enemy direction in s3
			lb s3, ENEMY_GET_DIR(s1)
			#control: change dir if at end of platform or at wall
			#case 1: left wall
			enemies_check_left_wall:
			li t0, 2
			bne s2, t0, enemies_check_right_wall
				li t0, 1
				sb t0, ENEMY_GET_DIR(s1)
				b enemies_move_regular
			#case 2: right wall
			enemies_check_right_wall:
			li t0, 57
			bne s2, t0, enemies_move_regular
				li t0, -1
				sb t0, ENEMY_GET_DIR(s1)
				b enemies_move_regular
			#case 3: boutta fall off platform
			enemies_move_regular:
			move a0, s0
			jal enemies_turn_platform
			#change x
			lb s3, ENEMY_GET_DIR(s1)
			add s2, s2, s3
			sb s2, ENEMY_GET_X(s1)	
		enemies_move_inc:
		inc s0
		b enemies_move_loop
	enemies_move_exit:
	leave s0, s1, s2, s3, s4

#for each enemy, checks bullet collisions and player colisions
check_collisions:
	enter s0, s1, s2, s3, s4, s5
		#s0 iterator over enemies
		li s0, 0
		check_collisions_loop:
		li t0, 5
		beq s0, t0, check_collisions_exit

			move a0, s0
			jal get_enemy_address
			move s1, v0 #s1 contains enemy address
			lb t0, (s1)
			beqz t0, check_collisions_loop_end #if enemy dead, skip check
			#load enemy coordinates
			lb s2, ENEMY_GET_X(s1)
			lb s3, ENEMY_GET_Y(s1)
			#check if bullet exists
			lw t0, bullet_dir
			beqz t0, check_player_collisions
			#if bullet collides
			lw s4, bullet_x
			lw s5, bullet_y
			sub t0, s4, s2 #t0 = bx - ex
			sub t1, s5, s3 #t1 = by - ey
			abs t2, t0	# t2 = |t0|
			abs t3, t1	# t3 = |t1|
			bgt t2, 4, check_player_collisions
			bltz t0, check_player_collisions
			bgt t3, 4, check_player_collisions
			bltz t1, check_player_collisions
				move a0, s0
				jal enemy_die
				
			#CHECK PLAYER COLLISIONS HERE
			check_player_collisions:
			#check for invulnerability
			lw t0, inv_frames
			bgtz t0, check_collisions_loop_end
				#load player coords
				lw s4, player_x
				lw s5, player_y
				#if player collides..
				sub t0, s4, s2 #t0 = player x - enemy x
				abs t0, t0
				sub t1, s5, s3 #t1 = player y - enemy y
				abs t1, t1
				li t2, 5
				bge t0, t2, check_collisions_loop_end
				bge t1, t2, check_collisions_loop_end
					jal player_lose_life
			check_collisions_loop_end:
			inc s0
			b check_collisions_loop
		check_collisions_exit:
	leave s0, s1, s2, s3, s4, s5
	
#takes enemy index in a0. kills enemy
enemy_die:
	enter s0, s1
		jal get_enemy_address
		move s1, v0 #s1 contains address
		li t0, 0
		sb t0, (s1)
		#enemy now dead 
		#delete bullet
		li t0, 0
		sw t0, bullet_dir
	leave s0, s1

#decrements player life by 1. grants player invulnerability
player_lose_life:
	enter
		lw t0, player_hearts
		dec t0 #lose a heart
		sw t0, player_hearts
		#gain invincibility
		li t0, 150
		sw t0, inv_frames
	leave
	
#turns enemies around at the end of the platform. broke it up for readability
enemies_turn_platform:
	enter s0, s1, s2, s3, s4, s5
	move s0, a0 # s0 is again our counter
	jal get_enemy_address
	move s1, v0 #(s1 contains address)
	lb s2, ENEMY_GET_X(s1)
	lb s3, ENEMY_GET_Y(s1)
	move a0, s2
	addi a1, s3, 5
	jal pixel_to_tile
	move a0, v0
	move a1, v1
	jal is_tile_platform
	move s5, v0 #s2 contains player on platform status left
	#get right foot
	addi a0, s2, 4
	addi a1, s3, 5
	jal pixel_to_tile
	move a0, v0
	move a1, v1
	jal is_tile_platform
	move t1, v0
	add t1, t1, s5 #check both feet on platform
	li t2, 2
	beq t1, t2, enemies_turn_platform_exit
		lb t0, ENEMY_GET_DIR(s1)
		mul t0, t0, -1
		sb t0, ENEMY_GET_DIR(s1)
enemies_turn_platform_exit:
	
	leave s0, s1, s2, s3, s4, s5
	

# --------------------------------------------------------------------------------------------------
# call once per main loop to keep the game running at 60FPS.
# if your code is too slow (longer than 16ms per frame), the framerate will drop.
# otherwise, this will account for different lengths of processing per frame.

wait_for_next_frame:
	enter	s0
	lw	s0, last_frame_time
_wait_next_frame_loop:
	# while (sys_time() - last_frame_time) < GAME_TICK_MS {}
	li	v0, 30
	syscall # why does this return a value in a0 instead of v0????????????
	sub	t1, a0, s0
	bltu	t1, GAME_TICK_MS, _wait_next_frame_loop

	# save the time
	sw	a0, last_frame_time

	# frame_counter++
	lw	t0, frame_counter
	inc	t0
	sw	t0, frame_counter
	leave	s0

# --------------------------------------------------------------------------------------------------

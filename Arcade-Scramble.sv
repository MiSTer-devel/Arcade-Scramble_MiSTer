//============================================================================
//  Arcade: Scramble
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================


module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output [11:0] VIDEO_ARX,
	output [11:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	// Use framebuffer from DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of 16 bytes.
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,    // 1 - signed audio samples, 0 - unsigned

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	`ifdef USE_SDRAM
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,
	`endif


	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign {FB_PAL_CLK, FB_FORCE_BLANK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;

wire [1:0] ar = status[20:19];

assign VIDEO_ARX = (!ar) ? ((status[2] ) ? 8'd4 : 8'd3) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2] ) ? 8'd3 : 8'd4) : 12'd0;


`include "build_id.v" 
localparam CONF_STR = {
	"A.SCRMBL;;",
	"H0OJK,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H1H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"h2O6,Rotation,Buttons,Spinner;",
	"h2-;",
	"h3O6,Fire Mode,4-Way,Move+Fire;",
	"h3-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Fire 3,Fire 4,Start 1P,Start 2P,Coin;",
	"jn,A,B,X,Y,Start,Select,R;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys,clk_vid,clk_mem;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_mem),
	.outclk_1(clk_vid),
	.outclk_2(clk_sys),
	.locked(pll_locked)
);

reg ce_6p, ce_6n, ce_12, ce_1p79;
always @(posedge clk_sys) begin
	reg [1:0] div = 0;
	reg [3:0] div179 = 0;
	
	div <= div + 1'd1;

	ce_12 <= div[0];
	ce_6p <= div[0] & ~div[1];
	ce_6n <= div[0] &  div[1];
	
   ce_1p79 <= 0;
   div179 <= div179 - 1'd1;
   if(!div179) begin
		div179 <= 13;
		ce_1p79 <= 1;
   end
end

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_index;
wire [15:0] sdram_sz;

wire [31:0] joy1,joy2;
wire [31:0] joy = joy1 | joy2;
wire  [8:0] sp1, sp2;

wire [21:0] gamma_bus;

wire        rom_download = ioctl_download && !ioctl_index;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.status_menumask({fourfire,has_spinner,landscape,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),
	.sdram_sz(sdram_sz),

	.joystick_0(joy1),
	.joystick_1(joy2),

	.spinner_0(sp1),
	.spinner_1(sp2)
	
);


wire m_up1     = joy1[3];
wire m_down1   = joy1[2];
wire m_left1   = joy1[1];
wire m_right1  = joy1[0];
wire m_fire1a  = joy1[4];
wire m_fire1b  = joy1[5];
wire m_fire1c  = joy1[6];
wire m_fire1d  = joy1[7];
wire m_fire1e  = joy1[8];
wire m_spccw1  = joy1[30];
wire m_spcw1   = joy1[31];

wire m_up2     = joy2[3];
wire m_down2   = joy2[2];
wire m_left2   = joy2[1];
wire m_right2  = joy2[0];
wire m_fire2a  = joy2[4];
wire m_fire2b  = joy2[5];
wire m_fire2c  = joy2[6];
wire m_fire2d  = joy2[7];
wire m_fire2e  = joy2[8];
wire m_spccw2  = joy2[30];
wire m_spcw2   = joy2[31];

wire m_up      = m_up1       | m_up2;
wire m_down    = m_down1     | m_down2;
wire m_left    = m_left1     | m_left2;
wire m_right   = m_right1    | m_right2;
wire m_fire_a  = m_fire1a    | m_fire2a;
wire m_fire_b  = m_fire1b    | m_fire2b;
wire m_fire_c  = m_fire1c    | m_fire2c;
wire m_fire_d  = m_fire1d    | m_fire2d;
wire m_fire_e  = m_fire1e    | m_fire2e;
wire m_spccw   = m_spccw1    | m_spccw2;
wire m_spcw    = m_spcw1     | m_spcw2;

wire m_start1  = joy[8];
wire m_start2  = joy[9];
wire m_coin    = joy[10];

reg [8:0] sp;
always @(posedge clk_sys) begin
	reg [8:0] old_sp1, old_sp2;
	reg       sp_sel = 0;

	old_sp1 <= sp1;
	old_sp2 <= sp2;
	
	if(old_sp1 != sp1) sp_sel <= 0;
	if(old_sp2 != sp2) sp_sel <= 1;

	sp <= sp_sel ? sp2 : sp1;
end


localparam mod_scramble = 0;
localparam mod_amidar   = 1;
localparam mod_frogger  = 2;
localparam mod_scobra   = 3;
localparam mod_tazman   = 4;
localparam mod_armorcar = 5;
localparam mod_moonwar  = 6;
localparam mod_spdcoin  = 7;
localparam mod_calipso  = 8;
localparam mod_darkplnt = 9;
localparam mod_anteater = 10;
localparam mod_losttomb = 11;
localparam mod_theend   = 12;
localparam mod_mars     = 13;
localparam mod_stratgyx = 14;
localparam mod_turtles  = 15;
localparam mod_minefld  = 16;
localparam mod_rescue   = 17;
localparam mod_mimonkey = 18;

reg [7:0] mod = 0;
always @(posedge clk_sys) if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;

// load the DIPS
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout; 

reg       landscape;
reg       has_spinner;
reg       fourfire;
reg       galaxian_video;
reg [7:0] hwsel;
reg [7:0] input0;
reg [7:0] input1;
reg [7:0] input2;
reg [7:0] input3;

always @(*) begin
	has_spinner = 0;
	fourfire = 0;
	landscape = 0;
	galaxian_video = 0;
	hwsel  = 0;
	input0 = ~{ m_coin, 1'b0, m_left, m_right, m_fire_a, 1'b0, m_fire_b, m_up };
	input1 = ~{ m_start1, m_start2, m_left, m_right, m_fire_a, m_fire_b, 2'b00 };
	input2 = ~{ 1'b0, m_down, 1'b0, m_up, 3'b000, m_down };
	input3 = 8'hFF;

	case (mod)
		mod_frogger:
			begin
				hwsel = 1;
			end
		mod_scobra:
			begin
				hwsel = 2;
			end
		mod_tazman:
			begin
				hwsel = 2;
				input0 = ~{ m_coin, 1'b0, m_left, m_right, m_down, m_up, m_fire_a, m_fire_b };
				input1 = 8'hFF;
				input2 = ~{ 1'b0, m_start2, 2'b00, 3'b000, m_start1 };
			end
		mod_armorcar:
			begin
				hwsel = 2;
			end
		mod_moonwar:
			begin
				hwsel = 2;
				has_spinner = 1;
				input0 = ~{ m_coin, 1'b0, 1'b0, moon_dial_dir, moon_dial[4:1] };
				input1 = ~{ m_fire_a, m_fire_b, m_fire_c, m_fire_d, m_start2, m_start1, 2'b00 };
				input2 = 8'hFF;
			end
		mod_spdcoin:
			begin
				hwsel = 2;
				input0 = ~{ m_coin, 1'b0, m_left, m_right, m_start2, 1'b0, m_start1, 1'b0 };
				input1 = 8'hFF;
				input2 = 8'hFF;
			end
		mod_calipso:
			begin
				hwsel = 3;
				input0 = ~{ m_coin, 1'b0, m_left, m_right, m_down, m_up, 1'b0, m_start2 | m_fire_a };
				input1 = ~{ 1'b0, 1'b0, m_left, m_right, m_down, m_up, 1'b0, 1'b0 };
				input2 = ~{ 5'b00000, 2'b00, m_fire_a | m_start1 };
			end
		mod_darkplnt:
			begin
				hwsel = 4;
				landscape = 1;
				has_spinner = 1;
				input0 = ~{ m_coin, 1'b0, 3'b000, m_start2 | m_fire_b, m_start1 | m_fire_a, m_fire_c };
				input1 = { darkplnt_dial, 2'b11 };
				input2 = 8'hFF;
			end
		mod_anteater:
			begin
				hwsel = 6;
				input0 = ~{ m_coin, 1'b0, m_left, m_right, m_down, m_up, 1'b0, m_fire_a };
				input1 = ~{ 1'b0, m_fire_a, m_left, m_right, m_up, m_down, 2'b00 };
				input2 = ~{ 1'b0, m_start2, 2'b00, 3'b000, m_start1 };
			end
		mod_losttomb:
			begin
				hwsel = 7;
				fourfire = 1;
				input0 = ~{ m_coin, 1'b0, m_left, m_right, m_down, m_up, m_start1, m_start2 };
				input1 = status[6] ?
				         ~{ 1'b0, m_fire_e|m_fire_a, m_left,   m_right,  m_down,   m_up,     2'b00 }:
				         ~{ 1'b0, m_fire_e,          m_fire_d, m_fire_a, m_fire_b, m_fire_c, 2'b00 };
				input2 = 8'hFF;
			end
		mod_theend:
			begin
				galaxian_video = 1;
			end
		mod_mars:
			begin
				hwsel = 10;
				fourfire = 1;
				if(status[6]) begin
					input0 = ~{ m_coin, 1'b0, m_left, m_right, m_left, m_right, 1'b0, m_up };
					input1 = ~{ m_start1, m_start2, m_left, m_right, m_left, m_right, 2'b00 };
					input2 = ~{ m_up, m_down, m_down, m_up, 3'b000, m_down };
					input3 = ~{ m_up, 1'b0, m_down, 5'b00000 };
				end
				else begin
					input0 = ~{ m_coin, 1'b0, m_left, m_right, m_fire_d, m_fire_a, 1'b0, m_up };
					input1 = ~{ m_start1, m_start2, m_left, m_right, m_fire_d, m_fire_a, 2'b00 };
					input2 = ~{ m_fire_c, m_down, m_fire_b, m_up, 3'b000, m_down };
					input3 = ~{ m_fire_c, 1'b0, m_fire_b, 5'b00000 };
				end
			end
		mod_stratgyx:
			begin
				hwsel = 5;
				landscape = 1;
				input0 = ~{ m_coin, 1'b0, m_left, m_right, m_fire_a, 1'b0, m_fire_b, m_up };
				input1 = ~{ m_start1, m_start2, m_left, m_right, m_fire_a, m_fire_b, 2'b00 };
				input2 = ~{ m_fire_c, m_down, m_fire_c, m_up, 3'b000, m_down };
			end
		mod_turtles:
			begin
				hwsel = 11;
				input0 = ~{ m_coin, 1'b0, m_left, m_right, m_fire_a, 2'b00, m_up };
				input1 = ~{ m_start1, m_start2, m_left, m_right, m_fire_a, 3'b000 };
				input2 = ~{ 1'b0, m_down, 1'b0, m_up, 3'b000, m_down };
			end
		mod_minefld:
			begin
				hwsel = 8;
				fourfire = 1;
				input0 = ~{ m_coin, 1'b0, m_left, m_right, m_down, m_up, 1'b0, m_start1 };
				input1 = status[6] ? ~{ 2'b00, m_left, m_right, m_down, m_up, 2'b00 } : ~{ 2'b00, m_fire_d, m_fire_a, m_fire_b, m_fire_c, 2'b00 };
				input2 = ~{ 1'b0, m_start2, 2'b00, 3'b000, m_start1 };
			end
		mod_rescue:
			begin
				hwsel = 9;
				fourfire = 1;
				input0 = ~{ m_coin, 1'b0, m_left, m_right, m_down, m_up, 1'b0, m_start1 };
				input1 = status[6] ? ~{ 2'b00, m_left, m_right, m_down, m_up, 2'b00 } : ~{ 2'b00, m_fire_d, m_fire_a, m_fire_b, m_fire_c, 2'b00 };
				input2 = ~{ 1'b0, m_start2, 2'b00, 3'b000, m_start1 };
			end
		mod_mimonkey:
			begin
				hwsel = 12;
			end
		default:;
	endcase
end

wire [4:0] moon_dial;
spinner #(1,2,1) moon_sp (
	.clk(clk_sys),
	.fast(m_spccw | m_spcw),
	.plus(m_left|m_up|m_right|m_down|m_spccw|m_spcw),
	.strobe(vs),
	.spin_in({sp[8], sp[7] ? 8'd0 - sp[7:0] : sp[7:0]}),
	.spin_out(moon_dial)
);

reg moon_dial_dir;
always @(posedge clk_sys) begin
	reg old_sp;

	old_sp <= sp[8];
	if(old_sp ^ sp[8]) moon_dial_dir <= sp[7];

	if(m_left|m_up|m_spccw)   moon_dial_dir <= 1;
	if(m_right|m_down|m_spcw) moon_dial_dir <= 0;
end

wire [5:0] dp_remap[64] = 
'{
	6'h03, 6'h02, 6'h00, 6'h01, 6'h21, 6'h20, 6'h22, 6'h23,
	6'h33, 6'h32, 6'h30, 6'h31, 6'h11, 6'h10, 6'h12, 6'h13,
	6'h17, 6'h16, 6'h14, 6'h15, 6'h35, 6'h34, 6'h36, 6'h37,
	6'h3f, 6'h3e, 6'h3c, 6'h3d, 6'h1d, 6'h1c, 6'h1e, 6'h1f,
	6'h1b, 6'h1a, 6'h18, 6'h19, 6'h39, 6'h38, 6'h3a, 6'h3b,
	6'h2b, 6'h2a, 6'h28, 6'h29, 6'h09, 6'h08, 6'h0a, 6'h0b,
	6'h0f, 6'h0e, 6'h0c, 6'h0d, 6'h2d, 6'h2c, 6'h2e, 6'h2f,
	6'h27, 6'h26, 6'h24, 6'h25, 6'h05, 6'h04, 6'h06, 6'h07 
};

wire [5:0] darkplnt_dial = dp_remap[dp_remap_addr];

reg [5:0] dp_remap_addr;
always @(posedge clk_sys) dp_remap_addr <= dp_dial;

wire [5:0] dp_dial;
spinner #(2,4,2) dp_sp (
	.clk(clk_sys),
	.fast(m_spccw | m_spcw),
	.minus(m_left | m_up | m_spccw),
	.plus(m_right | m_down | m_spcw),
	.strobe(vs),
	.spin_in(sp),
	.spin_out(dp_dial)
);

wire hblank, vblank;
wire hs, vs;
wire [7:0] r,g,b;
wire ce_pix = ce_6p;

wire no_rotate = status[2] | direct_video | landscape;

wire fg = |{r,g,b};
wire rotate_ccw = 0;
screen_rotate screen_rotate (.*);

arcade_video #(256,24) arcade_video
(
	.*,

	.clk_video(clk_vid),

	.RGB_in((fg && !bg_a) ? {r,g,b} : {bg_r,bg_g,bg_b}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.fx(status[5:3])
);

wire [9:0] audio;
assign AUDIO_L = {audio, 6'd0};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

scramble_top scramble
(
	.O_VIDEO_R(r),
	.O_VIDEO_G(g),
	.O_VIDEO_B(b),
	.O_HSYNC(hs),
	.O_VSYNC(vs),
	.O_HBLANK(hblank),
	.O_VBLANK(vblank),

	.dl_addr(ioctl_addr[15:0]),
	.dl_data(ioctl_dout),
	.dl_wr(ioctl_wr & rom_download),

	.O_AUDIO(audio),

	.I_HWSEL(hwsel),
	.I_GALAXIAN_VIDEO(galaxian_video),
	.I_PA(sw[0] & input0),
	.I_PB(sw[1] & input1),
	.I_PC(sw[2] & input2),
	.I_PD(sw[3] & input3),

	.RESET(RESET | status[0] | buttons[1]),
	.clk(clk_sys),
	.ena_12(ce_12),
	.ena_6(ce_6p),
	.ena_6b(ce_6n),
	.ena_1_79(ce_1p79)
);

wire bg_download = ioctl_download && (ioctl_index == 2);

reg [7:0] ioctl_dout_r;
always @(posedge clk_sys) if(ioctl_wr & ~ioctl_addr[0]) ioctl_dout_r <= ioctl_dout;

wire [31:0] pic_data;
sdram sdram
(
	.*,

	.init(~pll_locked),
	.clk(clk_mem),
	.ch1_addr(bg_download ? ioctl_addr[24:1] : pic_addr),
	.ch1_dout(pic_data),
	.ch1_din({ioctl_dout, ioctl_dout_r}),
	.ch1_req(bg_download ? (ioctl_wr & ioctl_addr[0]) : pic_req),
	.ch1_rnw(~bg_download)
);

reg        pic_req;
reg [24:1] pic_addr;
reg  [7:0] bg_r,bg_g,bg_b,bg_a;
always @(posedge clk_sys) begin
	reg old_vs;
	reg use_bg = 0;
	
	if(bg_download && sdram_sz[2:0]) use_bg <= 1;

	pic_req <= 0;

	if(use_bg) begin
		if(ce_pix) begin
			old_vs <= vs;
			{bg_a,bg_b,bg_g,bg_r} <= pic_data;
			if(~(hblank|vblank)) begin
				pic_addr <= pic_addr + 2'd2;
				pic_req <= 1;
			end
			
			if(~old_vs & vs) begin
				pic_addr <= 0;
				pic_req <= 1;
			end
		end
	end
	else begin
		{bg_a,bg_b,bg_g,bg_r} <= 0;
	end
end

endmodule

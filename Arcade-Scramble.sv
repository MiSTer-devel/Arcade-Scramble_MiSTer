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
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	
	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);

assign VGA_F1    = 0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : status[2] ? 8'd4 : 8'd3;
assign HDMI_ARY = status[1] ? 8'd9  : status[2] ? 8'd3 : 8'd4;

`include "build_id.v" 
localparam CONF_STR = {
	"A.SCRMBL;;",
	"H0O1,Aspect Ratio,Original,Wide;",
	"H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Fire 3,Fire 4,Start 1P,Start 2P,Coin;",
	"jn,A,B,X,Y,Start,Select,R;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys,clk_vid;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_vid),
	.outclk_1(clk_sys)
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

wire [10:0] ps2_key;

wire [15:0] joy1,joy2;
wire [15:0] joy = joy1 | joy2;

wire [21:0] gamma_bus;

wire        rom_download = ioctl_download && !ioctl_index;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.status_menumask(direct_video),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joy1),
	.joystick_1(joy2),
	.ps2_key(ps2_key)
);

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'hX75: btn_up          <= pressed; // up
			'hX72: btn_down        <= pressed; // down
			'hX6B: btn_left        <= pressed; // left
			'hX74: btn_right       <= pressed; // right
			'h029: btn_fire2       <= pressed; // space
			'h014: btn_fire1       <= pressed; // ctrl
			'h005: btn_start_1     <= pressed; // F1
			'h006: btn_start_2     <= pressed; // F2

			// JPAC/IPAC/MAME Style Codes
			'h016: btn_start_1     <= pressed; // 1
			'h01E: btn_start_2     <= pressed; // 2
			'h02E: btn_coin_1      <= pressed; // 5
			'h036: btn_coin_2      <= pressed; // 6
			'h02D: btn_up_2        <= pressed; // R
			'h02B: btn_down_2      <= pressed; // F
			'h023: btn_left_2      <= pressed; // D
			'h034: btn_right_2     <= pressed; // G
			'h01C: btn_fire1_2     <= pressed; // A
         'h01B: btn_fire2_2     <= pressed; // S			
		endcase
	end
end

reg btn_start_1=0;
reg btn_start_2=0;
reg btn_coin_1 =0;
reg btn_coin_2 =0;

reg btn_up     =0;
reg btn_down   =0;
reg btn_right  =0;
reg btn_left   =0;
reg btn_fire1  =0;
reg btn_fire2  =0;
reg btn_fire3  =0;
reg btn_fire4  =0;

reg btn_up_2   =0;
reg btn_down_2 =0;
reg btn_left_2 =0;
reg btn_right_2=0;
reg btn_fire1_2=0;
reg btn_fire2_2=0;
reg btn_fire3_2=0;
reg btn_fire4_2=0;

wire no_rotate = status[2] | direct_video;

wire m_up1     = btn_up      | joy1[3];
wire m_down1   = btn_down    | joy1[2];
wire m_left1   = btn_left    | joy1[1];
wire m_right1  = btn_right   | joy1[0];
wire m_fire1a  = btn_fire1   | joy1[4];
wire m_fire1b  = btn_fire2   | joy1[5];
wire m_fire1c  = btn_fire3   | joy1[6];
wire m_fire1d  = btn_fire4   | joy1[7];

wire m_up2     = btn_up_2    | joy2[3];
wire m_down2   = btn_down_2  | joy2[2];
wire m_left2   = btn_left_2  | joy2[1];
wire m_right2  = btn_right_2 | joy2[0];
wire m_fire2a  = btn_fire1_2 | joy2[4];
wire m_fire2b  = btn_fire2_2 | joy2[5];
wire m_fire2c  = btn_fire3_2 | joy2[6];
wire m_fire2d  = btn_fire4_2 | joy2[7];

wire m_up      = m_up1       | m_up2;
wire m_down    = m_down1     | m_down2;
wire m_left    = m_left1     | m_left2;
wire m_right   = m_right1    | m_right2;
wire m_fire_a  = m_fire1a    | m_fire2a;
wire m_fire_b  = m_fire1b    | m_fire2b;
wire m_fire_c  = m_fire1c    | m_fire2c;
wire m_fire_d  = m_fire1d    | m_fire2d;

wire m_start1  = btn_start_1 | joy[8];
wire m_start2  = btn_start_2 | joy[9];
wire m_coin    = btn_coin_1  | btn_coin_2 | joy[10];

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

reg [7:0] mod = 0;
always @(posedge clk_sys) if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;

// load the DIPS
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout; 

reg       galaxian_video;
reg [7:0] hwsel;
reg [7:0] input0;
reg [7:0] input1;
reg [7:0] input2;

always @(*) begin
	galaxian_video = 0;
	hwsel  = 0;
	input0 = ~{ m_coin, 1'b0, m_left, m_right, m_fire_a, 1'b0, m_fire_b, m_up };
	input1 = ~{ m_start1, m_start2, m_left, m_right, m_fire_a, m_fire_b, 2'b00 };
	input2 = ~{ 1'b0, m_down, 1'b0, m_up, 3'b000, m_down };

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
				input1 = ~{ m_fire_a, m_fire_b, m_left, m_right, m_up, m_down, 2'b00 };
				input2 = ~{ 1'b0, m_start2, 2'b00, 3'b000, m_start1 };
			end
		mod_armorcar:
			begin
				hwsel = 2;
			end
		mod_moonwar:
			begin
				hwsel = 2;
				input0 = ~{ m_coin, 1'b0, 1'b0, dial };
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
				// buggy
				hwsel = 4;
				input0 = ~{ m_coin, 1'b0, 3'b000, m_start2 | m_fire_b, m_start1 | m_fire_a, m_fire_c };
				input1 = 8'hFF;
				input2 = 8'hFF;
			end
		mod_anteater:
			begin
				hwsel = 5;
				input0 = ~{ m_coin, 1'b0, m_left, m_right, m_down, m_up, m_fire_a, m_fire_b };
				input1 = ~{ m_fire_a, m_fire_b, m_left, m_right, m_up, m_down, 2'b00 };
				input2 = ~{ 1'b0, m_start2, 2'b00, 3'b000, m_start1 };
			end
		mod_losttomb:
			begin
				hwsel = 6;
				input0 = ~{ m_coin, 1'b0, m_left, m_right, m_down, m_up, m_start1, m_start2 };
				input1 = ~{ 1'b0, m_fire_a, m_left, m_right, m_down, m_up, 2'b00 };
				input2 = 8'hFF;
			end
		mod_theend:
			begin
				galaxian_video = 1;
			end
		default:;
	endcase
end

wire [4:0] dial;
moonwar_dial moonwar_dial (
	.clk(clk_sys),
	.moveleft(m_left | m_up),
	.moveright(m_right | m_down),
	.dialout(dial)
);


wire hblank, vblank;
wire hs, vs;
wire [3:0] r,g;
wire [3:0] b;

reg ce_pix;
always @(posedge clk_vid) begin
	reg [2:0] div;

	div <= div + 1'd1;
	ce_pix <= !div;
end

arcade_video #(256,224,12) arcade_video
(
	.*,

	.clk_video(clk_vid),

	.RGB_in({r,g,b}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.rotate_ccw(0),
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

	.RESET(RESET | status[0] | buttons[1]),
	.clk(clk_sys),
	.ena_12(ce_12),
	.ena_6(ce_6p),
	.ena_6b(ce_6n),
	.ena_1_79(ce_1p79)
);

endmodule

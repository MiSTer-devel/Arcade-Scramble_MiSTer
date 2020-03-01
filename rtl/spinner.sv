
//
// spinner
//
// Copyright (c) 2020 Alexey Melnikov
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module spinner #(parameter INC_NORMAL = 20, INC_FAST = 27, INC_SPINNER = 20)
(
	inout        clk,
	input        reset,

	input        minus,
	input        plus,
	input        fast,
	input        strobe,

	input  [8:0] spin_in,
	output [7:0] spin_out
);

assign spin_out = spin_count[9:2];

wire [31:0] inc = fast ? INC_FAST : INC_NORMAL;
reg  [31:0] spin_count;

always @(posedge clk) begin
	reg strobe_r;
	reg sp_r;
	reg use_sp;

	sp_r <= spin_in[8];
	if((sp_r ^ spin_in[8])) spin_count <= spin_count + ($signed(spin_in[7:0])*$signed(INC_SPINNER)); 

	strobe_r <= strobe;
	if (~strobe_r & strobe) begin
		if (minus) spin_count <= spin_count - inc;
		if (plus)  spin_count <= spin_count + inc;
	end

	if(reset) spin_count <= 0;
end

endmodule

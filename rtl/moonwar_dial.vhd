library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity moonwar_dial is
port(
	clk        : in std_logic;
	moveleft   : in std_logic;
	moveright  : in std_logic;
	use_spinner: in std_logic;
	dialout    : out std_logic_vector(4 downto 0)
);
end moonwar_dial;

architecture rtl of moonwar_dial is

signal count       : std_logic_vector(8 downto 0);
signal old_r,old_l : std_logic;
signal mleft       : std_logic := '0';

begin

process (clk) begin
	if rising_edge(clk) then
		old_r <= moveright;
		old_l <= moveleft;
		if use_spinner = '0' then
			if moveleft = '1' or moveright = '1' then
				count <= count + 3;
				mleft <= moveleft;
			end if;
		else
			if (moveleft = '1' and old_l = '0') or (moveright = '1' and old_r = '0') then
				count <= count + 16;
				mleft <= moveleft;
			end if;
		end if;
	end if;
end process;

dialout <= mleft & count(8 downto 5);

end rtl;

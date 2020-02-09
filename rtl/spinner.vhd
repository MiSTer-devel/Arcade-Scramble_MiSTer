library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity spinner is
generic (
	inc_normal  : integer := 20;
	inc_fast    : integer := 27
);
port
(
	clk         : in std_logic;
	reset       : in std_logic;
	minus       : in std_logic;
	plus        : in std_logic;
	fast        : in std_logic := '0';
	strobe      : in std_logic;
	use_spinner : in std_logic := '0';
	spin_angle  : out std_logic_vector(7 downto 0)
);
end spinner;

architecture rtl of spinner is

signal strobe_r   : std_logic;
signal minus_r    : std_logic;
signal plus_r     : std_logic;
signal spin_count : std_logic_vector(9 downto 0);
signal inc        : integer;

begin

spin_angle <= spin_count(9 downto 2);
inc <= inc_normal when fast = '0' else inc_fast;

process (clk, reset)
begin
	if reset = '1' then
		spin_count <= (others => '0');
	elsif rising_edge(clk) then
		strobe_r <= strobe;
		minus_r <= minus;
		plus_r <= plus;

		if (strobe_r ='0' and strobe = '1' and use_spinner = '0') or 
			(((minus_r = '0' and minus = '1') or (plus_r = '0' and plus = '1')) and use_spinner = '1') then
			if minus = '1' then spin_count <= spin_count - inc; end if;
			if plus = '1' then spin_count <= spin_count + inc; end if;
		end if;
	end if;
end process;

end rtl;
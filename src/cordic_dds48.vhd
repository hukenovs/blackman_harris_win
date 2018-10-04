-------------------------------------------------------------------------------
--
-- Title       : cordic_dds48
-- Design      : Blackman-Harris Windows
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-- Description : Simple cordic algorithm for sine and cosine generator (DDS)
-- 
-------------------------------------------------------------------------------
--
--	Version 1.0  30.08.2018
--    Description: Cordic for sin/cos wave generator (DDS style)
--
--  Coordinates: X represents the sine, Y represents the cosine, and 
--  Z represents theta.
--
--  Cosine mode:
--  x0 - initialized to 1/Magnitude = 1/2^(WIDTH);
--  y0 - initialized to 0;
--  z0 - initialized to the THETA input argument value (phase);
--
--  Sine mode:
--  x0 - initialized to 0;
--  y0 - initialized to (+/-)1/Magnitude = 1/2^(WIDTH);
--  z0 - initialized to the THETA input argument value (phase);
--
--  Phase radians - Look up table array ROM [WIDTH-1 : 0]
--  Formula: Angle = Round[atan(2^-i) * (2^48/(2*pi))] where i - variable of ROM array
--
--  Gain for output signal is production of:
--      Gain = PROD[ SQRT(1.0+2.0**(-2*i)) ] = 1.64676025812106541,
--        where i = 0 to 47.
--
--  ROM_LUT := (
--    x"200000000000", x"12E4051D9DF3", x"09FB385B5EE4", x"051111D41DDE", 
--    x"028B0D430E59", x"0145D7E15904", x"00A2F61E5C28", x"00517C5511D4",
--    x"0028BE5346D1", x"00145F2EBB31", x"000A2F980092", x"000517CC14A8", 
--    x"00028BE60CE0", x"000145F306C1", x"0000A2F9836B", x"0000517CC1B7",
--    x"000028BE60DC", x"0000145F306E", x"00000A2F9837", x"00000517CC1B", 
--    x"0000028BE60E", x"00000145F307", x"000000A2F983", x"000000517CC2",
--    x"00000028BE61", x"000000145F30", x"0000000A2F98", x"0000000517CC", 
--    x"000000028BE6", x"0000000145F3", x"00000000A2FA", x"00000000517D",
--    x"0000000028BE", x"00000000145F", x"000000000A30", x"000000000518", 
--    x"00000000028C", x"000000000146", x"0000000000A3", x"000000000051",
--    x"000000000029", x"000000000014", x"00000000000A", x"000000000005", 
--    x"000000000003", x"000000000001", x"000000000001", x"000000000000" );
--
--
--  The fixed-point CORDIC requires:
--    > 1 LUT,
--    > 2 shifts,
--    > 3 additions,
--        per iteration.
--
--  Internal data width and phase width are 48-bit vector.
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--	GNU GENERAL PUBLIC LICENSE
--  Version 3, 29 June 2007
--
--	Copyright (c) 2018 Kapitanov Alexander
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
--  APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT 
--  HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY 
--  OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, 
--  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
--  PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM 
--  IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF 
--  ALL NECESSARY SERVICING, REPAIR OR CORRECTION. 
-- 
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
library ieee; 
use ieee.std_logic_1164.all; 
use ieee.std_logic_arith.all;
use ieee.std_logic_signed.all;

entity cordic_dds48 is
	generic (
		PHASE_WIDTH    : integer := 16;-- Phase width: sets period of signal
		DATA_WIDTH     : integer := 16 -- Output width: sets magnitude of signal
	);
	port (
		CLK           : in  std_logic; --! Clock source
		RESET         : in  std_logic; --! Positive reset: '1' - reset, '0' - calculate
		PH_IN         : in  std_logic_vector(PHASE_WIDTH-1 downto 0); --! Input phase increment
		PH_EN         : in  std_logic; --! Input phase enable
		DT_SIN        : out std_logic_vector(DATA_WIDTH-1 downto 0); --! Output sine value
		DT_COS        : out std_logic_vector(DATA_WIDTH-1 downto 0); --! Output cosine value
		DT_VAL        : out std_logic --! Output data valid
	);
end cordic_dds48;

architecture cordic_dds48 of cordic_dds48 is

---------------- Constant declaration ----------------
constant GAIN48			: std_logic_vector(47 downto 0):=x"26DD3B6A10D8";

---------------- ROM: Look up table for CORDIC ----------------
type rom_array is array (0 to 47) of std_logic_vector(47 downto 0);

constant ROM_LUT : rom_array := (
		x"200000000000", x"12E4051D9DF3", x"09FB385B5EE4", x"051111D41DDE", 
		x"028B0D430E59", x"0145D7E15904", x"00A2F61E5C28", x"00517C5511D4",
		x"0028BE5346D1", x"00145F2EBB31", x"000A2F980092", x"000517CC14A8", 
		x"00028BE60CE0", x"000145F306C1", x"0000A2F9836B", x"0000517CC1B7",
		x"000028BE60DC", x"0000145F306E", x"00000A2F9837", x"00000517CC1B", 
		x"0000028BE60E", x"00000145F307", x"000000A2F983", x"000000517CC2",
		x"00000028BE61", x"000000145F30", x"0000000A2F98", x"0000000517CC", 
		x"000000028BE6", x"0000000145F3", x"00000000A2FA", x"00000000517D",
		x"0000000028BE", x"00000000145F", x"000000000A30", x"000000000518", 
		x"00000000028C", x"000000000146", x"0000000000A3", x"000000000051",
		x"000000000029", x"000000000014", x"00000000000A", x"000000000005", 
		x"000000000003", x"000000000001", x"000000000001", x"000000000000"
	);

type rom_atan is array (0 to DATA_WIDTH-2) of std_logic_vector(47 downto 0);

function func_atan return rom_atan is
	variable ret    : rom_atan;
begin					
	for ii in 0 to DATA_WIDTH-2 loop
		ret(ii) := ROM_LUT(ii);
	end loop;
	return ret;
end function func_atan;

constant ROM_TABLE : rom_atan := func_atan;

---------------- Signal declaration ----------------
type dat_array is array (0 to DATA_WIDTH) of std_logic_vector(47 downto 0);
type phi_array is array (0 to DATA_WIDTH-1) of std_logic_vector(47 downto 0);

signal sigX             : dat_array := (others => (others => '0'));
signal sigY             : dat_array := (others => (others => '0'));
signal sigZ             : phi_array := (others => (others => '0'));

signal init_x           : std_logic_vector(47 downto 0);
signal init_y           : std_logic_vector(47 downto 0);
signal init_t           : std_logic_vector(PHASE_WIDTH-1 downto 0);
signal init_z           : std_logic_vector(47 downto 0);

signal quadrant         : std_logic_vector(1 downto 0);
signal dt_vld           : std_logic_vector(DATA_WIDTH+1 downto 0);

begin

---------------------------------------------------------------------
---------------- Convert phase width  -------------------------------
---------------------------------------------------------------------
init_z(47 downto 47-(PHASE_WIDTH-1)) <= init_t(PHASE_WIDTH-1 downto 0);
init_z(47-PHASE_WIDTH downto 00) <= (others => '0'); 

---------------------------------------------------------------------
---------------- Calculate Quadrant: two MSBs of input phase --------
---------------------------------------------------------------------
quadrant <= ph_in(ph_in'left downto ph_in'left-1);

pr_phi: process(clk) is
begin
	if rising_edge(clk) then
		if (reset = '1') then		
			init_t <= (others => '0');
		else
			if (ph_en = '1') then
				case quadrant is
					when "00" | "11" => init_t <= ph_in;
					when "01"        => init_t <= ("00" & ph_in(ph_in'left-2 downto 0));
					when "10"        => init_t <= ("11" & ph_in(ph_in'left-2 downto 0));
					when others      => null;
				end case;
			end if;
		end if;
	end if;
end process;

---------------------------------------------------------------------
---------------- Registered: initial values for X, Y, Z -------------
---------------------------------------------------------------------
pr_xy: process(clk) is
begin
	if rising_edge(clk) then
		if (reset = '1') then		
			init_x <= (others => '0');
			init_y <= (others => '0');
		else
			if (ph_en = '1') then
				case quadrant is
					when "00" | "11" =>
						init_x <= GAIN48;
						init_y <= (others => '0');
					when "01" =>
						init_x <= (others => '0');
						init_y <= not(GAIN48) + '1';
					when "10" =>
						init_x <= (others => '0');
						init_y <= GAIN48;
					when others => null;
				end case;
			end if;
		end if;
	end if;
end process;

---------------------------------------------------------------------
---------------- Compute Angle array and X/Y ------------------------ 
---------------------------------------------------------------------
pr_crd: process(clk, reset)
begin
    if (reset = '1') then
        ---- Reset [x y z] vector ----
		sigX <= (others => (others => '0'));
		sigY <= (others => (others => '0'));
		sigZ <= (others => (others => '0'));		
    elsif rising_edge(clk) then
		---- Initial values ----
		sigX(0) <= init_x;
		sigY(0) <= init_y; 
		sigZ(0) <= init_z;
		---- calculate sine & cosine ----
        xl: for ii in 0 to DATA_WIDTH-1 loop
            if (sigZ(ii)(sigZ(ii)'left) = '0') then
                sigX(ii+1) <= sigX(ii) + sigY(ii)(47 downto ii);
                sigY(ii+1) <= sigY(ii) - sigX(ii)(47 downto ii);
            else
                sigX(ii+1) <= sigX(ii) - sigY(ii)(47 downto ii);
                sigY(ii+1) <= sigY(ii) + sigX(ii)(47 downto ii);
            end if;
        end loop;
		---- calculate phase ----
        xp: for ii in 0 to DATA_WIDTH-2 loop
            if (sigZ(ii)(sigZ(ii)'left) = '1') then
                sigZ(ii+1) <= sigZ(ii) + ROM_TABLE(ii);
            else
                sigZ(ii+1) <= sigZ(ii) - ROM_TABLE(ii);
            end if;
        end loop;
    end if;
end process;

dt_vld <= dt_vld(dt_vld'left-1 downto 0) & ph_en when rising_edge(clk);

---- Output data ----
dt_sin <= sigY(DATA_WIDTH)(47 downto 47-(DATA_WIDTH-1)) when rising_edge(clk);
dt_cos <= sigX(DATA_WIDTH)(47 downto 47-(DATA_WIDTH-1)) when rising_edge(clk);
dt_val <= dt_vld(dt_vld'left) when rising_edge(clk);

end cordic_dds48;
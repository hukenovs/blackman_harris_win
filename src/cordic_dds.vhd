-------------------------------------------------------------------------------
--
-- Title       : cordic_dds
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
--      Gain = PROD[ SQRT(1.0+2.0**(-2*i)) ], where i = 0 to DATA_WIDTH.
--
--  Example: WIDTH = 16: create ROM array from 0 to 14:
--    { 0x2000, 0x12E4, 0x09FB, 0x0511, 0x028B, 0x0146, 0x00A3, 0x0051
--              0x0029, 0x0014, 0x000A, 0x0005, 0x0003, 0x0001, 0x0000 } 
--
--  The fixed-point CORDIC requires:
--    > 1 LUT,
--    > 2 shifts,
--    > 3 additions,
--        per iteration.
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

entity cordic_dds is
	generic (
		PRECISION      : integer := 4; --! Data precision: from 1 to 7, avg = 2-4
		PHASE_WIDTH    : integer := 20;-- Phase width: sets period of signal
		DATA_WIDTH     : integer := 24 -- Output width: sets magnitude of signal
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
end cordic_dds;

architecture cordic_dds of cordic_dds is

---------------- Constant declaration ----------------
constant GAIN48			: std_logic_vector(47 downto 0):=x"4DBA76D421AF";
constant GAIN			: std_logic_vector(DATA_WIDTH+PRECISION-1 downto 0):="0" & GAIN48(47 downto 48-DATA_WIDTH-PRECISION+1);

---------------- ROM: Look up table for CORDIC ----------------
---- Result of [ATAN(2^-i) * (2^47/MATH_PI)] rounded and converted to HEX
type rom_array is array (0 to 47) of std_logic_vector(47 downto 0);

constant ROM_LUT : rom_array := (
		x"400000000000", x"25C80A3B3BE6", x"13F670B6BDC7", x"0A2223A83BBB", 
		x"05161A861CB1", x"028BAFC2B209", x"0145EC3CB850", x"00A2F8AA23A9", 
		x"00517CA68DA2", x"0028BE5D7661", x"00145F300123", x"000A2F982950", 
		x"000517CC19C0", x"00028BE60D83", x"000145F306D6", x"0000A2F9836D", 
		x"0000517CC1B7", x"000028BE60DC", x"0000145F306E", x"00000A2F9837", 
		x"00000517CC1B", x"0000028BE60E", x"00000145F307", x"000000A2F983", 
		x"000000517CC2", x"00000028BE61", x"000000145F30", x"0000000A2F98", 
		x"0000000517CC", x"000000028BE6", x"0000000145F3", x"00000000A2FA", 
		x"00000000517D", x"0000000028BE", x"00000000145F", x"000000000A30", 
		x"000000000518", x"00000000028C", x"000000000146", x"0000000000A3", 
		x"000000000051", x"000000000029", x"000000000014", x"00000000000A", 
		x"000000000005", x"000000000003", x"000000000001", x"000000000000"
	);

type rom_atan is array (0 to DATA_WIDTH-2) of std_logic_vector(DATA_WIDTH+PRECISION-1 downto 0);

function func_atan return rom_atan is
	variable ret    : rom_atan;
begin					
	for ii in 0 to DATA_WIDTH-2 loop
		ret(ii)(DATA_WIDTH+PRECISION-2 downto 0) := ROM_LUT(ii)(47 downto (47-(DATA_WIDTH+PRECISION-2)));
		ret(ii)(DATA_WIDTH+PRECISION-1 downto DATA_WIDTH+PRECISION-1) := (others => '0');
	end loop;
	return ret;
end function func_atan;

constant ROM_TABLE : rom_atan := func_atan;

---------------- Signal declaration ----------------
type dat_array is array (0 to DATA_WIDTH-1) of std_logic_vector(DATA_WIDTH+PRECISION-1 downto 0);
type phi_array is array (0 to DATA_WIDTH-1) of std_logic_vector(DATA_WIDTH+PRECISION-1 downto 0);

signal sigX             : dat_array := (others => (others => '0'));
signal sigY             : dat_array := (others => (others => '0'));
signal sigZ             : phi_array := (others => (others => '0'));

signal init_x           : std_logic_vector(DATA_WIDTH+PRECISION-1 downto 0);
signal init_y           : std_logic_vector(DATA_WIDTH+PRECISION-1 downto 0);
signal init_t           : std_logic_vector(PHASE_WIDTH-1 downto 0);
signal init_z           : std_logic_vector(DATA_WIDTH+PRECISION-1 downto 0);

signal quadrant         : std_logic_vector(1 downto 0);
signal quadz1         	: std_logic_vector(DATA_WIDTH-1 downto 0);
signal quadz2         	: std_logic_vector(DATA_WIDTH-1 downto 0);
signal dt_vld           : std_logic_vector(DATA_WIDTH-1 downto 0);

signal dat_sin          : std_logic_vector(DATA_WIDTH-1 downto 0);
signal dat_cos          : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

---------------------------------------------------------------------
---------------- Convert phase width  -------------------------------
---------------------------------------------------------------------
xPHI_LESS: if (PHASE_WIDTH >= DATA_WIDTH) generate
	init_z(PRECISION-1 downto 0) <= (others => '0');
	init_z(DATA_WIDTH+PRECISION-1 downto PRECISION) <= init_t(PHASE_WIDTH-1 downto PHASE_WIDTH-DATA_WIDTH);
end generate;
xPHI_MORE: if (PHASE_WIDTH < DATA_WIDTH) generate
	init_z(DATA_WIDTH-PHASE_WIDTH+PRECISION-1 downto 0) <= (others => '0');
	init_z(DATA_WIDTH+PRECISION-1 downto DATA_WIDTH-PHASE_WIDTH+PRECISION) <= init_t(PHASE_WIDTH-1 downto 0);
end generate;
---------------------------------------------------------------------
---------------- Calculate Quadrant: two MSBs of input phase --------
---------------------------------------------------------------------
quadz1 <= quadz1(DATA_WIDTH-2 downto 0) & ph_in(PHASE_WIDTH-1) when rising_edge(clk);
quadz2 <= quadz2(DATA_WIDTH-2 downto 0) & ph_in(PHASE_WIDTH-2) when rising_edge(clk);
quadrant <= quadz1(DATA_WIDTH-1) & quadz2(DATA_WIDTH-1);

---------------------------------------------------------------------
---------------- Registered: initial values for X, Y, Z -------------
---------------------------------------------------------------------
init_x <= GAIN;
init_y <= (others => '0');
init_t <= ("00" & ph_in(ph_in'left-2 downto 0));

---------------------------------------------------------------------
---------------- Compute Angle array and X/Y ------------------------ 
---------------------------------------------------------------------
pr_crd: process(clk, reset)
begin
    if (reset = '1') then
        ---- Reset sine / cosine / angle vector ----
		sigX <= (others => (others => '0'));
		sigY <= (others => (others => '0'));
		sigZ <= (others => (others => '0'));		
    elsif rising_edge(clk) then
		sigX(0) <= init_x;
		sigY(0) <= init_y; 
		sigZ(0) <= init_z;
		---- calculate sine & cosine ----
        lpXY: for ii in 0 to DATA_WIDTH-2 loop
            if (sigZ(ii)(sigZ(ii)'left) = '1') then
                sigX(ii+1) <= sigX(ii) + sigY(ii)(DATA_WIDTH+PRECISION-1 downto ii);
                sigY(ii+1) <= sigY(ii) - sigX(ii)(DATA_WIDTH+PRECISION-1 downto ii);
            else
                sigX(ii+1) <= sigX(ii) - sigY(ii)(DATA_WIDTH+PRECISION-1 downto ii);
                sigY(ii+1) <= sigY(ii) + sigX(ii)(DATA_WIDTH+PRECISION-1 downto ii);
            end if;
        end loop;
		---- calculate phase ----
        lpZ: for ii in 0 to DATA_WIDTH-2 loop
            if (sigZ(ii)(sigZ(ii)'left) = '1') then
                sigZ(ii+1) <= sigZ(ii) + ROM_TABLE(ii);
            else
                sigZ(ii+1) <= sigZ(ii) - ROM_TABLE(ii);
            end if;
        end loop;
    end if;
end process;

dat_sin <= sigY(DATA_WIDTH-1)(DATA_WIDTH+PRECISION-1 downto PRECISION);
dat_cos <= sigX(DATA_WIDTH-1)(DATA_WIDTH+PRECISION-1 downto PRECISION);

dt_vld <= dt_vld(dt_vld'left-1 downto 0) & ph_en when rising_edge(clk);
dt_val <= dt_vld(dt_vld'left);

---- Output data ----
pr_xy: process(clk) is
begin
	if rising_edge(clk) then
		if (reset = '1') then		
			dt_sin <= (others => '0');
			dt_cos <= (others => '0');
		else
			case quadrant is
				when "00" =>
					dt_sin <= dat_sin;
					dt_cos <= dat_cos;
				when "01" =>
					dt_sin <= dat_cos;
					dt_cos <= not(dat_sin) + '1';
				when "10" =>
					dt_sin <= not(dat_sin) + '1';
					dt_cos <= not(dat_cos) + '1';
				when "11" =>
					dt_sin <= not(dat_cos) + '1';
					dt_cos <= dat_sin;		
				when others => null;
			end case;
		end if;
	end if;
end process;

end cordic_dds;
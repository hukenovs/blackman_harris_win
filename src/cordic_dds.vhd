-------------------------------------------------------------------------------
--
-- Title       : cordic_dds
-- Design      : CORDIC HDL
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
--  Phase radians - Look up table array ROM [WIDTH-1 : 0]
--  Formula: Angle = Round[atan(2^-i) * (2^32/(2*pi))] where i - variable of ROM array
--
--  Example: WIDTH = 16: create ROM array from 0 to 14:
--    { 0x2000, 0x12E4, 0x09FB, 0x0511, 0x028B, 0x0146, 0x00A3, 0x0051
--              0x0029, 0x0014, 0x000A, 0x0005, 0x0003, 0x0001, 0x0000 } 
--
--  The fixed-point CORDIC requires:
--    > 1 LUT,
--    > 2 shifts,
--    > 3 additions,
--  per iteration.
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

use ieee.MATH_REAL.MATH_PI;
use ieee.MATH_REAL.ROUND;
use ieee.MATH_REAL.ARCTAN;

entity cordic_dds is
	generic (
		PHASE_WIDTH		: integer := 16;-- Phase width: sets period of signal
		OUT_WIDTH		: integer := 16 -- Output width: sets magnitude of signal
	);
	port (
		clk             : in  std_logic; --! Clock source
		reset           : in  std_logic; --! Positive reset: '1' - reset, '0' - calculate
		ph_in           : in  std_logic_vector(PHASE_WIDTH-1 downto 0); --! Input phase increment
		ph_en           : in  std_logic; --! Input phase enable
		dt_sin          : out std_logic_vector(OUT_WIDTH-1 downto 0); --! Output sine value
		dt_cos          : out std_logic_vector(OUT_WIDTH-1 downto 0) --! Output cosine value
	);
end cordic_dds;

architecture cordic_dds of cordic_dds is

---------------- Log2(N) function ----------------
function fn_log2( i : natural) return integer is
	variable temp    : integer := i;
	variable ret_val : integer := 0; 
begin					
	while temp > 1 loop
		ret_val := ret_val + 1;
		temp    := temp / 2;     
	end loop;

	return ret_val;
end function fn_log2;

constant SHIFT_LEN		: integer:=fn_log2(OUT_WIDTH);

---------------- ROM: Look up table for CORDIC ----------------
---- Result of [ATAN(2^-i) * (2^32/360)] rounded and converted to HEX

type lut_array is array (0 to 30) of std_logic_vector(31 downto 0);
type rom_array is array (0 to OUT_WIDTH-2) of std_logic_vector(PHASE_WIDTH-1 downto 0);

constant ROM_LUT : lut_array := (
						x"20000000", x"12E4051E", x"09FB385B", x"051111D4", x"028B0D43", x"0145D7E1",
						x"00A2F61E", x"00517C55", x"0028BE53", x"00145F2F", x"000A2F98", x"000517CC",
						x"00028BE6", x"000145F3", x"0000A2FA", x"0000517D", x"000028BE", x"0000145F",
						x"00000A30", x"00000518", x"0000028C", x"00000146", x"000000A3", x"00000051",
						x"00000029", x"00000014", x"0000000A", x"00000005", x"00000003", x"00000001",
						x"00000000"
);

---------------- Recalculate ROM array ----------------
function fn_atan return rom_array is
	variable ret    : rom_array;
begin					
	for ii in 0 to OUT_WIDTH-2 loop
		ret(ii) := ROM_LUT(ii)(31 downto 32-PHASE_WIDTH);
	end loop;
	return ret;
end function fn_atan;

constant ROM_PHASE		: rom_array:=fn_atan;

function calc_atan return rom_array is
	variable ret    : rom_array;
begin					
	for ii in 0 to OUT_WIDTH-2 loop
		ret(ii) := CONV_STD_LOGIC_VECTOR(integer(ROUND(ARCTAN(1.0/2.0**(ii)) * (2.0**(PHASE_WIDTH-1))/(MATH_PI))), PHASE_WIDTH);
	end loop;
	return ret;
end function calc_atan;

constant ROM_NEW : rom_array := calc_atan; 

-- constant POWER			: real:=1.646760258121 * 2.0**(OUT_WIDTH-3);
constant POWER			: real:=2.0**(OUT_WIDTH-2) / 1.647; --! FIX THIS
constant GAIN			: std_logic_vector(OUT_WIDTH-1 downto 0):=conv_std_logic_vector(integer(POWER), OUT_WIDTH);

signal init_x			: std_logic_vector(OUT_WIDTH-1 downto 0);
signal init_y			: std_logic_vector(OUT_WIDTH-1 downto 0);
signal init_z			: std_logic_vector(PHASE_WIDTH-1 downto 0);

type dat_array is array (0 to OUT_WIDTH-1) of std_logic_vector(OUT_WIDTH-1 downto 0);
type phi_array is array (0 to OUT_WIDTH-1) of std_logic_vector(PHASE_WIDTH-1 downto 0);

signal sigX				: dat_array:=(others=>(others=>'0'));
signal sigY				: dat_array:=(others=>(others=>'0'));
signal sigZ 			: phi_array:=(others=>(others=>'0'));

signal quadrant			: std_logic_vector(1 downto 0);

begin

---- Calculate Quadrant: two MSBs of input phase ----
quadrant <= ph_in(PHASE_WIDTH-1 downto PHASE_WIDTH-2);

---------------------------------------------------------------------
---------------- Registered: initial values for X, Y, Z -------------
---------------------------------------------------------------------
pr_xyz: process(clk) is
begin
	if rising_edge(clk) then
		if (ph_en = '1') then
			case quadrant is
				when "00" | "11" =>
					init_z <= ph_in;
					init_x <= GAIN;
					init_y <= (others => '0');
				when "01" =>
					init_z <= ("00" & ph_in(PHASE_WIDTH-3 downto 0));
					init_x <= (others => '0');
					init_y <= GAIN;
				when "10" =>
					init_z <= ("11" & ph_in(PHASE_WIDTH-3 downto 0));
					init_x <= (others => '0');
					init_y <= not(GAIN) + '1';
				when others => null;
			end case;
		end if;
	end if;
end process;

---------------------------------------------------------------------
---------------- Compute Angle array -------------------------------- 
---------------------------------------------------------------------
pr_crd: process(clk, reset)
begin
    if (reset = '1') then
        for ii in 0 to (OUT_WIDTH-1) loop
            sigX(ii) <= (others => '0');
            sigY(ii) <= (others => '0');            
			sigZ(ii) <= (others => '0');
        end loop;
    elsif rising_edge(clk) then
        sigX(0) <= init_x;
        sigY(0) <= init_y;        
		sigZ(0) <= init_z;

        xp: for ii in 0 to OUT_WIDTH-2 loop
            if (sigZ(ii)(sigZ(ii)'left) = '1') then
                sigZ(ii+1) <= sigZ(ii) + ROM_NEW(ii);
            else
                sigZ(ii+1) <= sigZ(ii) - ROM_NEW(ii);
            end if;
        end loop;
		
        xl: for ii in 0 to OUT_WIDTH-2 loop
            if (sigZ(ii)(sigZ(ii)'left) = '1') then
                sigX(ii+1) <= sigX(ii) + STD_LOGIC_VECTOR(SHR(SIGNED(sigY(ii)), CONV_UNSIGNED(ii, SHIFT_LEN)));
                sigY(ii+1) <= sigY(ii) - STD_LOGIC_VECTOR(SHR(SIGNED(sigX(ii)), CONV_UNSIGNED(ii, SHIFT_LEN)));
            else
                sigX(ii+1) <= sigX(ii) - STD_LOGIC_VECTOR(SHR(SIGNED(sigY(ii)), CONV_UNSIGNED(ii, SHIFT_LEN)));
                sigY(ii+1) <= sigY(ii) + STD_LOGIC_VECTOR(SHR(SIGNED(sigX(ii)), CONV_UNSIGNED(ii, SHIFT_LEN)));
            end if;
        end loop;		
    end if;
end process;

dt_sin <= sigY(OUT_WIDTH-1)(OUT_WIDTH-1 downto 0) when rising_edge(clk);
dt_cos <= sigX(OUT_WIDTH-1)(OUT_WIDTH-1 downto 0) when rising_edge(clk);

-- -- function fn_atan return rom_array is
	-- -- variable ret    : rom_array;
-- -- begin					
	-- -- for ii in 0 to OUT_WIDTH-2 loop
		-- -- ret(OUT_WIDTH-1-ii) := ROM_LUT32(30-ii)(PHASE_WIDTH-1 downto 0);
	-- -- end loop;
	-- -- return ret;
-- -- end function fn_atan;

-- -- constant ROM_LUT : rom_array := fn_atan; 
-- type rom_real is array (0 to OUT_WIDTH-2) of real;
-- function calc_real return rom_real is
	-- variable ret    : rom_real;
-- begin					
	-- for ii in 0 to OUT_WIDTH-2 loop
		-- -- ret(ii) := ROUND(ARCTAN(2.0**(-ii)) * (2.0**(PHASE_WIDTH))/(2.0*MATH_PI));
		-- ret(ii) := ARCTAN(2.0**(-ii));
	-- end loop;
	-- return ret;
-- end function calc_real;

-- constant ROM_RL : rom_real := calc_real; 

-- function calc_atan return rom_array is
	-- variable ret    : rom_array;
-- begin					
	-- for ii in 0 to OUT_WIDTH-2 loop
		-- ret(ii) := CONV_STD_LOGIC_VECTOR(integer(ROUND(ARCTAN(1.0/2.0**(ii-1)) * (2.0**(PHASE_WIDTH-1))/(MATH_PI))), PHASE_WIDTH);
	-- end loop;
	-- return ret;
-- end function calc_atan;

-- constant ROM_LUT : rom_array := calc_atan; 

end cordic_dds;
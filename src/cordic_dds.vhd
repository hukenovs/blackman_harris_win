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

use ieee.math_real.all;

-- use ieee.MATH_REAL.MATH_PI;
-- use ieee.MATH_REAL.ROUND;
-- use ieee.MATH_REAL.ARCTAN;

entity cordic_dds is
	generic (
		PHASE_WIDTH		: integer := 16;-- Phase width: sets period of signal
		DATA_WIDTH		: integer := 16 -- Output width: sets magnitude of signal
	);
	port (
		clk             : in  std_logic; --! Clock source
		reset           : in  std_logic; --! Positive reset: '1' - reset, '0' - calculate
		ph_in           : in  std_logic_vector(PHASE_WIDTH-1 downto 0); --! Input phase increment
		ph_en           : in  std_logic; --! Input phase enable
		dt_sin          : out std_logic_vector(DATA_WIDTH-1 downto 0); --! Output sine value
		dt_cos          : out std_logic_vector(DATA_WIDTH-1 downto 0) --! Output cosine value
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


---------------- Constant declaration ----------------
function fn_magn return std_logic_vector is
	variable ret_val : real := 0.0; 
	variable tmp_val : real := 1.0; 
	constant sig_val : std_logic_vector(DATA_WIDTH+2 downto 0):=(DATA_WIDTH+2 => '0', others => '1'); 
	variable sig_mgn : std_logic_vector(31 downto 0); 
	variable sig_ret : std_logic_vector(DATA_WIDTH+2+32 downto 0); 
begin					
	for ii in 0 to DATA_WIDTH+2 loop
		ret_val := SQRT(1.0+2.0**(-2*ii));
		tmp_val := tmp_val*ret_val;     
	end loop;
	-- 0.00001 from 12 to 19 --
	-- 0.000001 from 20 to 22 --
	-- 0.0000001 from 23 to 25 --
	
	ret_val := 2.0**31/(tmp_val+0.0000001); -- equal ~1.6467...
	ret_val := 2.0**31/(1.6468); -- equal ~1.6467...
	sig_mgn := conv_std_logic_vector(integer(ret_val), 32);
	sig_ret := sig_mgn * sig_val;

	return sig_ret(DATA_WIDTH+2+31 downto 31);
end function;

constant GAIN			: std_logic_vector(DATA_WIDTH+2 downto 0):=fn_magn;

constant SHIFT_LEN		: integer:=fn_log2(DATA_WIDTH)+1;
-- constant SHIFT_PHI		: integer:=DATA_WIDTH-PHASE_WIDTH+1;

---------------- ROM: Look up table for CORDIC ----------------
---- Result of [ATAN(2^-i) * (2^32/360)] rounded and converted to HEX
type rom_array is array (0 to DATA_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

function CALC_ATAN return rom_array is
	variable ret    : rom_array;
begin					
	for ii in 0 to DATA_WIDTH-2 loop
		ret(ii) := CONV_STD_LOGIC_VECTOR(integer(ROUND(ARCTAN(2.0**(-ii)) * (2.0**DATA_WIDTH)/(MATH_PI))), DATA_WIDTH);
	end loop;
	ret(DATA_WIDTH-1) := (others=>'0');
	return ret;
end function CALC_ATAN;

constant ROM_NEW	: rom_array := CALC_ATAN;

---------------- Signal declaration ----------------


signal init_x			: std_logic_vector(DATA_WIDTH+2 downto 0);
signal init_y			: std_logic_vector(DATA_WIDTH+2 downto 0);
signal init_t			: std_logic_vector(PHASE_WIDTH-1 downto 0);
signal init_z			: std_logic_vector(DATA_WIDTH-1 downto 0);


type dat_array is array (0 to DATA_WIDTH-1) of std_logic_vector(DATA_WIDTH+2 downto 0);
type phi_array is array (0 to DATA_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

signal sigX				: dat_array := (others => (others => '0'));
signal sigY				: dat_array := (others => (others => '0'));
signal sigZ 			: phi_array := (others => (others => '0'));

signal quadrant			: std_logic_vector(1 downto 0);


begin

---- Calculate Quadrant: two MSBs of input phase ----
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


xGEN_ZERO: if (DATA_WIDTH-PHASE_WIDTH+1 = 0) generate
begin
	init_z <= init_t(DATA_WIDTH-1 downto 0);
end generate;

xGEN_MORE: if (DATA_WIDTH-PHASE_WIDTH+1 > 0) generate
	constant ZEROS : std_logic_vector(DATA_WIDTH-PHASE_WIDTH downto 0):=(others=>'0');
begin
	init_z <= init_t(PHASE_WIDTH-2 downto 0) & ZEROS;
end generate;

xGEN_LESS: if (DATA_WIDTH-PHASE_WIDTH+1 < 0) generate
begin
	init_z <= init_t(PHASE_WIDTH-(PHASE_WIDTH-DATA_WIDTH-1)-1 downto (PHASE_WIDTH-DATA_WIDTH-1));
end generate;




-- xGEN_COM: if (DATA_WIDTH-PHASE_WIDTH-2 > 0) generate
	-- constant ZEROS : std_logic_vector(DATA_WIDTH-PHASE_WIDTH-2 downto 0):=(others=>'0');
-- begin	
	-- init_z <= init_t & ZEROS;
-- end generate;
-- xGEN_COM: if (DATA_WIDTH-PHASE_WIDTH <= 0) generate
	-- init_z <= init_t;
-- end generate;
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
						init_x <= GAIN;
						init_y <= (others => '0');
					when "01" =>
						init_x <= (others => '0');
						init_y <= not(GAIN) + '1';
					when "10" =>
						init_x <= (others => '0');
						init_y <= GAIN;
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
        for ii in 0 to (DATA_WIDTH-1) loop
            sigX(ii) <= (others => '0');
            sigY(ii) <= (others => '0');
			sigZ(ii) <= (others => '0');
        end loop;
    elsif rising_edge(clk) then
        sigX(0) <= init_x;
        sigY(0) <= init_y; 
		sigZ(0) <= init_z;
		---- calculate sine & cosine ----
        xl: for ii in 0 to DATA_WIDTH-2 loop
            if (sigZ(ii)(sigZ(ii)'left) = '0') then
                sigX(ii+1) <= sigX(ii) + STD_LOGIC_VECTOR(SHR(SIGNED(sigY(ii)), CONV_UNSIGNED(ii, SHIFT_LEN)));
                sigY(ii+1) <= sigY(ii) - STD_LOGIC_VECTOR(SHR(SIGNED(sigX(ii)), CONV_UNSIGNED(ii, SHIFT_LEN)));
            else
                sigX(ii+1) <= sigX(ii) - STD_LOGIC_VECTOR(SHR(SIGNED(sigY(ii)), CONV_UNSIGNED(ii, SHIFT_LEN)));
                sigY(ii+1) <= sigY(ii) + STD_LOGIC_VECTOR(SHR(SIGNED(sigX(ii)), CONV_UNSIGNED(ii, SHIFT_LEN)));
            end if;
        end loop;
		---- calculate phase ----
        xp: for ii in 0 to DATA_WIDTH-2 loop
            if (sigZ(ii)(sigZ(ii)'left) = '1') then
                sigZ(ii+1) <= sigZ(ii) + ROM_NEW(ii);
            else
                sigZ(ii+1) <= sigZ(ii) - ROM_NEW(ii);
            end if;
        end loop;
    end if;
end process;

dt_sin <= sigY(DATA_WIDTH-1)(DATA_WIDTH+2 downto 2+1) when rising_edge(clk);
dt_cos <= sigX(DATA_WIDTH-1)(DATA_WIDTH+2 downto 2+1) when rising_edge(clk);

end cordic_dds;
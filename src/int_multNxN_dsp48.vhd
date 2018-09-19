-------------------------------------------------------------------------------
--
-- Title       : int_multiplier_dsp48
-- Design      : FFTK
-- Author      : Kapitanov
-- Company     :
--
-- Description : Integer multiplier based on DSP48 block
--
-------------------------------------------------------------------------------
--
--	Version 1.0: 11.09.2018
--
--  Description: Simple multiplier by DSP48 unit
--
--  Math:
--
--  Out:    In:
--  DO_DAT = DI_DAT * DQ_DAT;
--
--	Input variables:
--    1. DTW - DSP48 input width (from 8 to 48): data width
--    3. XSER - Xilinx series: 
--        "NEW" - DSP48E2 (Ultrascale), 
--        "OLD" - DSP48E1 (6/7-series).
--
--  DSP48 data signals:
--    A port - In B data (MSB part),
--    B port - In B data (LSB part),
--    C port - In A data,
--    P port - Output data: P = C +/- A*B 
--
--  IF (DTW < 19)
--      use single DSP48 for mult operation*
--  ELSE IF (DTW > 18) and (DTW < 25)
--      use double DSP48 for mult operation
--  ELSE
--      use triple DSP48 for mult operation (35x35)
--
-- *   - 25 bit for DSP48E1, 27 bit for DSP48E2,
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
use ieee.std_logic_signed.all;
use ieee.std_logic_arith.all;

entity int_multNxN_dsp48 is
	generic (	
		DTW		: natural:=24   --! Input data width
	);
	port (
		DAT_A 	: in  std_logic_vector(DTW-1 downto 0); --! A port
		DAT_B 	: in  std_logic_vector(DTW-1 downto 0); --! B port
		DAT_Q 	: out std_logic_vector(2*DTW-1 downto 0); --! Output data: Q = A * B
		RST  	: in  std_logic; --! Global reset
		CLK 	: in  std_logic	 --! Math clock	
	);
end int_multNxN_dsp48;

architecture int_multNxN_dsp48 of int_multNxN_dsp48 is

signal sig_a, sig_b		: std_logic_vector(DTW-1 downto 0);

attribute USE_DSP : string;
attribute USE_DSP of DAT_Q : signal is "YES";

begin

pr_psp: process(clk) is
begin
	if (rising_edge(clk)) then
		sig_a <= DAT_A; -- Make Input delay A port
		sig_b <= DAT_B; -- Make Input delay B port
		if (rst = '1') then
			DAT_Q <= (others=>'0');
		else
			DAT_Q <= SIGNED(sig_a) * SIGNED(sig_b);
		end if;
	end if;
end process;

end int_multNxN_dsp48;
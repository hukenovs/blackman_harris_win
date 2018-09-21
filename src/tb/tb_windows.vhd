-------------------------------------------------------------------------------
--
-- Title       : tb_windows
-- Design      : Blackman-Harris Windows
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-- Description : Simple model for calculating window functions (upto 7 terms)
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
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity tb_windows is
end tb_windows;


architecture testbench of tb_windows is

    -------- Common Constants --------
	constant CLK_PERIOD 	: time := 10 ns;
	constant CLK_TD 		: time := 0.5 ns;
	
	-------- Phase & Data width --------
	constant PHASE_WIDTH	: integer:=11;
	constant DATA_WIDTH		: integer:=16;
	
	-------- Signal declaration --------
	signal clk   			: std_logic:='0';
	signal rst   			: std_logic:='0';
	signal ph_in			: std_logic_vector(PHASE_WIDTH-1 downto 0);
	signal ph_en			: std_logic;

	-------- Windows constants declaration --------
	constant CONST_WIDTH		: integer:=16;
	-------- 7-term --------
	constant CNT7_FLT0		: real:=0.271220360585039;
	constant CNT7_FLT1		: real:=0.433444612327442;
	constant CNT7_FLT2		: real:=0.218004122892930;
	constant CNT7_FLT3		: real:=0.065785343295606;
	constant CNT7_FLT4		: real:=0.010761867305342;
	constant CNT7_FLT5		: real:=0.000770012710581;
	constant CNT7_FLT6		: real:=0.000013680883060;

	constant CNT7_STD0		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT7_FLT0*(2.0**(CONST_WIDTH-1)-1.0)), CONST_WIDTH);
	constant CNT7_STD1		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT7_FLT1*(2.0**(CONST_WIDTH-1)-1.0)), CONST_WIDTH);
	constant CNT7_STD2		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT7_FLT2*(2.0**(CONST_WIDTH-1)-1.0)), CONST_WIDTH);
	constant CNT7_STD3		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT7_FLT3*(2.0**(CONST_WIDTH-1)-1.0)), CONST_WIDTH);
	constant CNT7_STD4		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT7_FLT4*(2.0**(CONST_WIDTH-1)-1.0)), CONST_WIDTH);
	constant CNT7_STD5		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT7_FLT5*(2.0**(CONST_WIDTH-1)-1.0)), CONST_WIDTH);
	constant CNT7_STD6		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT7_FLT6*(2.0**(CONST_WIDTH-1)-1.0)), CONST_WIDTH);
	
	-------- 5-term --------
	-- constant CNT5_FLT0		: real:=0.3232153788877343;
	-- constant CNT5_FLT1		: real:=0.4714921439576260;
	-- constant CNT5_FLT2		: real:=0.1755341299601972;
	-- constant CNT5_FLT3		: real:=0.0284969901061499;
	-- constant CNT5_FLT4		: real:=0.0012613570882927;
	-------- Flat-top --------
	constant CNT5_FLT0		: real:=1.000;
	constant CNT5_FLT1		: real:=1.930;
	constant CNT5_FLT2		: real:=1.290;
	constant CNT5_FLT3		: real:=0.388;
	constant CNT5_FLT4		: real:=0.030;	

	constant CNT5_STD0		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT5_FLT0*(2.0**(CONST_WIDTH-2)-1.0)), CONST_WIDTH);
	constant CNT5_STD1		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT5_FLT1*(2.0**(CONST_WIDTH-2)-1.0)), CONST_WIDTH);
	constant CNT5_STD2		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT5_FLT2*(2.0**(CONST_WIDTH-2)-1.0)), CONST_WIDTH);
	constant CNT5_STD3		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT5_FLT3*(2.0**(CONST_WIDTH-2)-1.0)), CONST_WIDTH);
	constant CNT5_STD4		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT5_FLT4*(2.0**(CONST_WIDTH-2)-1.0)), CONST_WIDTH);
	
	-------- 4-term --------
	constant CNT4_FLT0		: real:= 0.35875;
	constant CNT4_FLT1		: real:= 0.48829;
	constant CNT4_FLT2		: real:= 0.14128;
	constant CNT4_FLT3		: real:= 0.01168;
	
	constant CNT4_STD0		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT4_FLT0*(2.0**(CONST_WIDTH)-1.0)), CONST_WIDTH);
	constant CNT4_STD1		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT4_FLT1*(2.0**(CONST_WIDTH)-1.0)), CONST_WIDTH);
	constant CNT4_STD2		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT4_FLT2*(2.0**(CONST_WIDTH)-1.0)), CONST_WIDTH);
	constant CNT4_STD3		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT4_FLT3*(2.0**(CONST_WIDTH)-1.0)), CONST_WIDTH);
	
	-------- 3-term --------
	constant CNT3_FLT0		: real:=0.42;
	constant CNT3_FLT1		: real:=0.5;
	constant CNT3_FLT2		: real:=0.08;
	
	constant CNT3_STD0		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT3_FLT0*(2.0**(CONST_WIDTH)-16.0)), CONST_WIDTH);
	constant CNT3_STD1		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT3_FLT1*(2.0**(CONST_WIDTH)-16.0)), CONST_WIDTH);
	constant CNT3_STD2		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT3_FLT2*(2.0**(CONST_WIDTH)-16.0)), CONST_WIDTH);

	-------- 2-term --------
	constant CNT2_FLT0		: real:=0.5434783;
	constant CNT2_FLT1		: real:=1.0-CNT2_FLT0;
	
	constant CNT2_STD0		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT2_FLT0*(2.0**(CONST_WIDTH-1)-1.0)), CONST_WIDTH);
	constant CNT2_STD1		: std_logic_vector(CONST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT2_FLT1*(2.0**(CONST_WIDTH-1)-1.0)), CONST_WIDTH);

begin

-------------------------------------------------------------------------------
---------------- Clock and Reset Processes ------------------------------------
-------------------------------------------------------------------------------
clk_gen: process
begin
    clk <= '1';
    wait for clk_period/2;
    clk <= '0';
    wait for clk_period/2;
end process;

rst_gen: process
begin
    rst <= '1';
    wait for clk_period * 4;
    rst <= '0';
    wait;
end process;

-------------------------------------------------------------------------------
---------------- Phase Increment for CORDIC and WIN components ----------------
-------------------------------------------------------------------------------
clk_phase: process(clk) is
begin
    if rising_edge(clk) then
		if (rst = '1') then
			ph_in <= (others=>'0');
			ph_en <= '0';
		else
			ph_en <= '1' after CLK_TD;
			if (ph_en = '1') then
				ph_in <= ph_in + '1' after CLK_TD;
			end if;
		end if;
	end if;
end process;

-------------------------------------------------------------------------------
---------------- Window function: 7-term Blackman-Harris ----------------------
-------------------------------------------------------------------------------
xWIN7: entity work.bh_win_7term 
	generic map(
		PHI_WIDTH	=> PHASE_WIDTH,
		DAT_WIDTH	=> CONST_WIDTH
	)
	port map (
		RESET		=> rst,
		CLK 		=> clk,

		AA0			=> CNT7_STD0,
		AA1			=> CNT7_STD1,
		AA2			=> CNT7_STD2,
		AA3			=> CNT7_STD3,
		AA4			=> CNT7_STD4,
		AA5			=> CNT7_STD5,
		AA6			=> CNT7_STD6,
		ENABLE		=> ph_en	
	);

-------------------------------------------------------------------------------
---------------- Window function: 5-term Blackman-Harris ----------------------
-------------------------------------------------------------------------------
xWIN5: entity work.bh_win_5term 
	generic map(
		PHI_WIDTH	=> PHASE_WIDTH,
		DAT_WIDTH	=> CONST_WIDTH
	)
	port map (
		RESET		=> rst,
		CLK 		=> clk,

		AA0			=> CNT5_STD0,
		AA1			=> CNT5_STD1,
		AA2			=> CNT5_STD2,
		AA3			=> CNT5_STD3,
		AA4			=> CNT5_STD4,
		ENABLE		=> ph_en	
	);
	
-------------------------------------------------------------------------------
---------------- Window function: 4-term Blackman-Harris ----------------------
-------------------------------------------------------------------------------
xWIN4: entity work.bh_win_4term 
	generic map (
		PHI_WIDTH	=> PHASE_WIDTH,
		DAT_WIDTH	=> CONST_WIDTH
	)
	port map (
		RESET  		=> rst,
		CLK 		=> clk,

		AA0			=> CNT4_STD0,
		AA1			=> CNT4_STD1,
		AA2			=> CNT4_STD2,
		AA3			=> CNT4_STD3,
		ENABLE		=> ph_en	
	);
	
-------------------------------------------------------------------------------
---------------- Window function: 3-term Blackman-Harris ----------------------
-------------------------------------------------------------------------------
xWIN3: entity work.bh_win_3term 
	generic map (
		PHI_WIDTH	=> PHASE_WIDTH,
		DAT_WIDTH	=> CONST_WIDTH
	)
	port map (
		RESET  		=> rst,
		CLK 		=> clk,

		AA0			=> CNT3_STD0,
		AA1			=> CNT3_STD1,
		AA2			=> CNT3_STD2,
		ENABLE		=> ph_en	
	);
	
-------------------------------------------------------------------------------
---------------- Window function: 2-term Hann & Hamming -----------------------
-------------------------------------------------------------------------------
xWIN2: entity work.hamming_win 
	generic map (
		PHI_WIDTH	=> PHASE_WIDTH,
		DAT_WIDTH	=> CONST_WIDTH
	)
	port map (
		RESET  		=> rst,
		CLK 		=> clk,

		AA0			=> CNT2_STD0,
		AA1			=> CNT2_STD1,
		ENABLE		=> ph_en	
	);

-- UUT: entity work.cordic_dds
	-- generic map (
		-- PHASE_WIDTH		=> PHASE_WIDTH,
		-- DATA_WIDTH		=> DATA_WIDTH
	-- )
	-- port map (
		-- clk				=> clk,
		-- reset			=> rst,
		-- ph_in			=> ph_in,
		-- ph_en			=> ph_en,
		-- dt_sin			=> sine,
		-- dt_cos			=> cosine
	-- );

-------------------------------------------------------------------------------
---------------- Taylor generator for sine and cosine -------------------------
-------------------------------------------------------------------------------
xTAY: entity work.taylor_sincos 
	generic map (
		TAY_ORDER	=> 1,
		LUT_SIZE	=> 10,
		PHASE_WIDTH	=> 14,
		DATA_WIDTH	=> 16
	)
	port map (
		RST  		=> rst,
		CLK 		=> clk,
		PHI_ENA		=> ph_en	
	);

end testbench;
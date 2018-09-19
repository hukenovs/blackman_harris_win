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

entity tb_cordic_dds is
end tb_cordic_dds;

architecture testbench of tb_cordic_dds is

constant PHASE_WIDTH	: integer:=11;
constant DATA_WIDTH		: integer:=16;

signal clk   			: std_logic:='0';
signal rst   			: std_logic:='0';
signal ph_in			: std_logic_vector(PHASE_WIDTH-1 downto 0);
signal ph_en			: std_logic;
signal sine  			: std_logic_vector(DATA_WIDTH-1 downto 0);
signal cosine			: std_logic_vector(DATA_WIDTH-1 downto 0);


constant CLK_PERIOD 	: time := 10 ns;
constant CLK_TD 		: time := 0.5 ns;


constant CNST_WIDTH			: integer:=16;
constant CNST_FLT0			: real:=0.3232153788877343;
constant CNST_FLT1			: real:=0.4714921439576260;
constant CNST_FLT2			: real:=0.1755341299601972;
constant CNST_FLT3			: real:=0.0284969901061499;
constant CNST_FLT4			: real:=0.0012613570882927;

constant CNST_STD0			: std_logic_vector(CNST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNST_FLT0*(2.0**(CNST_WIDTH)-1.0)),CNST_WIDTH);
constant CNST_STD1			: std_logic_vector(CNST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNST_FLT1*(2.0**(CNST_WIDTH)-1.0)),CNST_WIDTH);
constant CNST_STD2			: std_logic_vector(CNST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNST_FLT2*(2.0**(CNST_WIDTH)-1.0)),CNST_WIDTH);
constant CNST_STD3			: std_logic_vector(CNST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNST_FLT3*(2.0**(CNST_WIDTH)-1.0)),CNST_WIDTH);
constant CNST_STD4			: std_logic_vector(CNST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNST_FLT4*(2.0**(CNST_WIDTH)-1.0)),CNST_WIDTH);


constant CNT3_FLT0			: real:=0.42;
constant CNT3_FLT1			: real:=0.5;
constant CNT3_FLT2			: real:=0.08;

constant CNT3_STD0			: std_logic_vector(CNST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT3_FLT0*(2.0**(CNST_WIDTH)-1.0)),CNST_WIDTH);
constant CNT3_STD1			: std_logic_vector(CNST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT3_FLT1*(2.0**(CNST_WIDTH)-1.0)),CNST_WIDTH);
constant CNT3_STD2			: std_logic_vector(CNST_WIDTH-1 downto 0):=conv_std_logic_vector(integer(CNT3_FLT2*(2.0**(CNST_WIDTH)-1.0)),CNST_WIDTH);

begin

xWIN: entity work.bh_win_5term 
	generic map(
		PHI_WIDTH	=> 10,
		DAT_WIDTH	=> 16
	)
	port map (
		RESET  		=> rst,
		CLK 		=> clk,

		CNST0		=> CNST_STD0,
		CNST1		=> CNST_STD1,
		CNST2		=> CNST_STD2,
		CNST3		=> CNST_STD3,
		CNST4		=> CNST_STD4,

		ENABLE		=> ph_en	
	);

xWIN3: entity work.bh_win_3term 
	generic map(
		PHI_WIDTH	=> 10,
		DAT_WIDTH	=> 16
	)
	port map (
		RESET  		=> rst,
		CLK 		=> clk,

		CNST0		=> CNT3_STD0,
		CNST1		=> CNT3_STD1,
		CNST2		=> CNT3_STD2,

		ENABLE		=> ph_en	
	);


UUT: entity work.cordic_dds
	generic map (
		PHASE_WIDTH		=> PHASE_WIDTH,
		DATA_WIDTH		=> DATA_WIDTH
	)
	port map (
		clk				=> clk,
		reset			=> rst,
		ph_in			=> ph_in,
		ph_en			=> ph_en,
		dt_sin			=> sine,
		dt_cos			=> cosine
	);

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

end testbench;
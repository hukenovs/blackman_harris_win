-------------------------------------------------------------------------------
--
-- Title       : bh_win_4term
-- Design      : Blackman-Harris Windows
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-- Description : Simple Blackman-Harris window function: 4- term
--               Configurable data length and number of terms.
--
-- Constants {0-3} (gain for harmonics): type - REAL (float IEEE-754)
--     
--  > Blackman-Harris:
--     a0 = 0.35875, a1 = 0.48829, a2 = 0.14128, a3 = 0.01168.
--  > Nuttall:
--     a0 = 0.355768, a1 = 0.487396, a2 = 0.144323, a3 = 0.012604.
--  > Blackman-Nuttall:
--     a0 = 0.3635819, a1 = 0.4891775, a2 = 0.1365995, a3 = 0.0106411.
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
library ieee;
use ieee.std_logic_1164.all;   
use ieee.std_logic_arith.all;
use ieee.std_logic_signed.all;

-- library unisim;
-- use unisim.vcomponents.DSP48E1;
-- use unisim.vcomponents.DSP48E2;

entity bh_win_4term is
	generic(
		TD			: time:=0.5ns;		--! Time delay
		PHI_WIDTH	: integer:=10;		--! Signal period = 2^PHI_WIDTH
		DAT_WIDTH	: integer:=16		--! Output data width
	);
	port(
		RESET  		: in  std_logic;	--! Global reset 
		CLK 		: in  std_logic;	--! System clock 

		CNST0		: in  std_logic_vector(DAT_WIDTH-1 downto 0); -- Constant A0
		CNST1		: in  std_logic_vector(DAT_WIDTH-1 downto 0); -- Constant A1
		CNST2		: in  std_logic_vector(DAT_WIDTH-1 downto 0); -- Constant A2
		CNST3		: in  std_logic_vector(DAT_WIDTH-1 downto 0); -- Constant A3

		ENABLE		: in  std_logic;	--! Input data enable block = NFFT clocks
		DT_WIN		: out std_logic_vector(DAT_WIDTH-1 downto 0);	--! Output (cos)	
		DT_VLD		: out std_logic		--! Output data valid	
	);
end bh_win_4term;

architecture bh_win_4term of bh_win_4term is

---------------- Cordic signals ----------------
signal cos1				: std_logic_vector(DAT_WIDTH-1 downto 0);
signal cos2				: std_logic_vector(DAT_WIDTH-1 downto 0);
signal cos3				: std_logic_vector(DAT_WIDTH-1 downto 0);

signal ph_in1			: std_logic_vector(PHI_WIDTH-1 downto 0);
signal ph_in2			: std_logic_vector(PHI_WIDTH-1 downto 0);
signal ph_in3			: std_logic_vector(PHI_WIDTH-1 downto 0);

---------------- Multiplier signals ----------------
signal mult_a1			: std_logic_vector(DAT_WIDTH-1 downto 0);
signal mult_a2			: std_logic_vector(DAT_WIDTH-1 downto 0);
signal mult_a3			: std_logic_vector(DAT_WIDTH-1 downto 0);

signal mult_b1			: std_logic_vector(DAT_WIDTH-1 downto 0);
signal mult_b2			: std_logic_vector(DAT_WIDTH-1 downto 0);
signal mult_b3			: std_logic_vector(DAT_WIDTH-1 downto 0);

signal mult_p1			: std_logic_vector(2*DAT_WIDTH-1 downto 0);
signal mult_p2			: std_logic_vector(2*DAT_WIDTH-1 downto 0);
signal mult_p3			: std_logic_vector(2*DAT_WIDTH-1 downto 0);

---------------- Product signals ----------------
signal dsp_b0			: std_logic_vector(DAT_WIDTH-1 downto 0);
signal dsp_b1			: std_logic_vector(DAT_WIDTH-1 downto 0);
signal dsp_b2			: std_logic_vector(DAT_WIDTH-1 downto 0);
signal dsp_b3			: std_logic_vector(DAT_WIDTH-1 downto 0);

signal dsp_r1			: std_logic_vector(DAT_WIDTH downto 0);
signal dsp_r2			: std_logic_vector(DAT_WIDTH downto 0);
signal dsp_r3			: std_logic_vector(DAT_WIDTH downto 0);

---------------- DSP48 signals ----------------
signal dsp_p1			: std_logic_vector(DAT_WIDTH downto 0);
signal dsp_p2			: std_logic_vector(DAT_WIDTH downto 0);
signal dsp_pp			: std_logic_vector(DAT_WIDTH+1 downto 0);
signal vldx				: std_logic;
signal ena_zz			: std_logic_vector(DAT_WIDTH+5 downto 0);

attribute USE_DSP : string;
attribute USE_DSP of dsp_pp : signal is "YES";
attribute USE_DSP of dsp_p1 : signal is "YES";
attribute USE_DSP of dsp_p2 : signal is "YES";

begin

---------------- Multiplier ----------------
mult_a1 <= CNST1 after td when rising_edge(clk);
mult_a2 <= CNST2 after td when rising_edge(clk);
mult_a3 <= CNST3 after td when rising_edge(clk);

mult_b1 <= cos1 after td when rising_edge(clk);
mult_b2 <= cos2 after td when rising_edge(clk);
mult_b3 <= cos3 after td when rising_edge(clk);

---------------- Counter for phase ----------------
PR_CNT1: process(clk) is
begin
	if rising_edge(clk) then
		if (reset = '1') then
			ph_in1 <= (others => '0') after TD;
			ph_in2 <= (others => '0') after TD;
			ph_in3 <= (others => '0') after TD;
		else
			if (ENABLE = '1') then
				ph_in1 <= ph_in1 + 1 after TD;
				ph_in2 <= ph_in2 + 2 after TD;
				ph_in3 <= ph_in3 + 3 after TD;
			end if;
		end if;
	end if;
end process;

---------------- Twiddle part 1 ----------------
xCRD1: entity work.cordic_dds
    generic map (
        DATA_WIDTH	=> DAT_WIDTH,
        PHASE_WIDTH	=> PHI_WIDTH
    )	
    port map (		   
        RESET	=> reset,
        CLK		=> clk,
        PH_IN	=> ph_in1,
        PH_EN	=> ENABLE,
		DT_COS	=> cos1, 
		DT_VAL	=> vldx
    );

xMLT1: entity work.int_multNxN_dsp48
	generic map ( DTW => DAT_WIDTH)
	port map (
		DAT_A	=> mult_a1,
		DAT_B	=> mult_b1,
		DAT_Q	=> mult_p1,
		CLK		=> clk,
		RST		=> reset
	);	

---------------- Twiddle part 2 ----------------
xCRD2: entity work.cordic_dds
    generic map (
        DATA_WIDTH	=> DAT_WIDTH,
        PHASE_WIDTH	=> PHI_WIDTH
    )	
    port map (		   
        RESET	=> reset,
        CLK		=> clk,
        PH_IN	=> ph_in2,
        PH_EN	=> ENABLE,
		DT_COS	=> cos2, 
		DT_VAL	=> vldx
    );


xMLT2: entity work.int_multNxN_dsp48
	generic map ( DTW => DAT_WIDTH)
	port map (
		DAT_A	=> mult_a2,
		DAT_B	=> mult_b2,
		DAT_Q	=> mult_p2,
		CLK		=> clk,
		RST		=> reset
	);		
	
---------------- Twiddle part 3 ----------------	
xCRD3: entity work.cordic_dds
    generic map (
        DATA_WIDTH	=> DAT_WIDTH,
        PHASE_WIDTH	=> PHI_WIDTH
    )	
    port map (		   
        RESET	=> reset,
        CLK		=> clk,
        PH_IN	=> ph_in3,
        PH_EN	=> ENABLE,
		DT_COS	=> cos3, 
		DT_VAL	=> vldx
    );

xMLT3: entity work.int_multNxN_dsp48
	generic map ( DTW => DAT_WIDTH)
	port map (
		DAT_A	=> mult_a3,
		DAT_B	=> mult_b3,
		DAT_Q	=> mult_p3,
		CLK		=> clk,
		RST		=> reset
	);		
	
---------------- DSP48E2 1-2 ----------------
dsp_b0 <= CNST0 after td when rising_edge(clk);

dsp_r1 <= mult_p1(2*DAT_WIDTH-2 downto DAT_WIDTH-2) after td when rising_edge(clk);
dsp_r2 <= mult_p2(2*DAT_WIDTH-2 downto DAT_WIDTH-2) after td when rising_edge(clk);
dsp_r3 <= mult_p3(2*DAT_WIDTH-2 downto DAT_WIDTH-2) after td when rising_edge(clk);

---------------- Round data from 25 to 24 bits ----------------
pr_rnd: process(clk) is
begin
	if rising_edge(clk) then
		---- Round 1 ----
		if (dsp_r1(0) = '0') then
			dsp_b1 <= dsp_r1(DAT_WIDTH downto 1) after td;
		else
			dsp_b1 <= dsp_r1(DAT_WIDTH downto 1) + 1 after td;
		end if;	
		---- Round 2 ----
		if (dsp_r2(0) = '0') then
			dsp_b2 <= dsp_r2(DAT_WIDTH downto 1) after td;
		else
			dsp_b2 <= dsp_r2(DAT_WIDTH downto 1) + 1 after td;
		end if;
		---- Round 3 ----
		if (dsp_r3(0) = '0') then
			dsp_b3 <= dsp_r3(DAT_WIDTH downto 1) after td;
		else
			dsp_b3 <= dsp_r3(DAT_WIDTH downto 1) + 1 after td;
		end if;

	end if;
end process;

---------------- DSP48 signal mapping ----------------
pr_add: process(clk) is
begin
	if rising_edge(clk) then
		dsp_p1 <= 	(dsp_b3(DAT_WIDTH-1) & dsp_b3) + 
					(dsp_b2(DAT_WIDTH-1) & dsp_b2);
		dsp_p2 <= 	(dsp_b1(DAT_WIDTH-1) & dsp_b1) + 
		            (dsp_b0(DAT_WIDTH-1) & dsp_b0);
		dsp_pp <= 	(dsp_p1(DAT_WIDTH) & dsp_p1) + 
					(dsp_p2(DAT_WIDTH) & dsp_p2);
	end if;
end process;

ena_zz <= ena_zz(ena_zz'left-1 downto 0) & enable after td when rising_edge(clk);
---------------- Round output data from 25 to 24 bits ----------------
pr_out: process(clk) is
begin
	if rising_edge(clk) then
		---- Round 1 ----
		if (dsp_pp(1) = '0') then
			DT_WIN <= dsp_pp(DAT_WIDTH+1 downto 2) after td;
		else
			DT_WIN <= dsp_pp(DAT_WIDTH+1 downto 2) + 1 after td;
		end if;
		DT_VLD <= ena_zz(ena_zz'left) after td;
	end if;
end process;   

end bh_win_4term;
-------------------------------------------------------------------------------
--
-- Title       : bh_win_3term
-- Design      : Blackman-Harris Windows
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-- Description : Simple Blackman-Harris window function: 3- term
--               Configurable data length and number of terms.
--
-- Constants {0-2} (gain for harmonics): type - REAL (float IEEE-754)
--   AA_FLT0 = (1 - alpha)/2;
--   AA_FLT1 = 1/2;
--   AA_FLT2 = alpha/2;
--
--   where:
--     
--     a0 = 0.42, a1 = 0.5, a2 = 0.08. (alpha = 0.16) Side-lobe level 58 dB. 
--     a0 = 0.4243801, a1 = 0.4973406, a2 = 0.0782793). Side-lobe level 71.48 dB.
--
--  Parameters:
--    PHI_WIDTH - Signal period = 2^PHI_WIDTH
--    DAT_WIDTH - Output data width		
--    SIN_TYPE  -Sine generator type: CORDIC / TAYLOR
--    ---- For Taylor series only ----
--    LUT_SIZE  - ROM depth for sin/cos (must be less than PHASE_WIDTH)
--    XSERIES   - for 6/7 series: "7SERIES"; for ULTRASCALE: "ULTRA"; 
--
--  Note: While using TAYLOR scheme You must set LUT_SIZE < (PHASE_WIDTH - 3) 
--        for correct delays. 
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

entity bh_win_3term is
	generic (
		TD			: time:=0.5ns;      --! Time delay
		PHI_WIDTH	: integer:=10;      --! Signal period = 2^PHI_WIDTH
		DAT_WIDTH	: integer:=16;      --! Output data width		
		SIN_TYPE    : string:="CORDIC"; --! Sine generator type: CORDIC / TAYLOR
		---- For Taylor series only ----
		LUT_SIZE    : integer:= 9;      --! ROM depth for sin/cos (must be less than PHASE_WIDTH)
        XSERIES     : string:="ULTRA"   --! for 6/7 series: "7SERIES"; for ULTRASCALE: "ULTRA";
	);
	port (
		RESET  		: in  std_logic;	--! Global reset 
		CLK 		: in  std_logic;	--! System clock 

		AA0			: in  std_logic_vector(DAT_WIDTH-1 downto 0); -- Constant A0
		AA1			: in  std_logic_vector(DAT_WIDTH-1 downto 0); -- Constant A1
		AA2			: in  std_logic_vector(DAT_WIDTH-1 downto 0); -- Constant A2

		ENABLE		: in  std_logic;	--! Input data enable block = NFFT clocks
		DT_WIN		: out std_logic_vector(DAT_WIDTH-1 downto 0);	--! Output (cos)	
		DT_VLD		: out std_logic		--! Output data valid	
	);
end bh_win_3term;

architecture bh_win_3term of bh_win_3term is

---------------- Cordic signals ----------------
signal cos1				: std_logic_vector(DAT_WIDTH-1 downto 0);
signal cos2				: std_logic_vector(DAT_WIDTH-1 downto 0);

signal ph_in1			: std_logic_vector(PHI_WIDTH-1 downto 0);
signal ph_in2			: std_logic_vector(PHI_WIDTH-1 downto 0);

---------------- Multiplier signals ----------------
signal mult_a1			: std_logic_vector(DAT_WIDTH-1 downto 0);
signal mult_a2			: std_logic_vector(DAT_WIDTH-1 downto 0);

signal mult_b1			: std_logic_vector(DAT_WIDTH-1 downto 0);
signal mult_b2			: std_logic_vector(DAT_WIDTH-1 downto 0);

signal mult_p1			: std_logic_vector(2*DAT_WIDTH-1 downto 0);
signal mult_p2			: std_logic_vector(2*DAT_WIDTH-1 downto 0);

---------------- Product signals ----------------
signal dsp_b0			: std_logic_vector(DAT_WIDTH-1 downto 0);
signal dsp_b1			: std_logic_vector(DAT_WIDTH-1 downto 0);
signal dsp_b2			: std_logic_vector(DAT_WIDTH-1 downto 0);

signal dsp_r1			: std_logic_vector(DAT_WIDTH downto 0);
signal dsp_r2			: std_logic_vector(DAT_WIDTH downto 0);

---------------- DSP48 signals ----------------
---- Addition delay ----
function find_delay return integer is
	variable ret    : integer:=0;
begin
	if (SIN_TYPE = "CORDIC") then
		ret := DAT_WIDTH+7;
	elsif (SIN_TYPE = "TAYLOR") then
		if (PHI_WIDTH - LUT_SIZE <= 2) then
			ret := 10;
		else
			if (DAT_WIDTH < 19) then
				ret := 13;
			else
				ret := 16;
			end if;
		end if;
	end if;
	return ret;
end find_delay;

constant ADD_DELAY	: integer:=find_delay;

signal dsp_pp			: std_logic_vector(DAT_WIDTH+1 downto 0);
-- signal vldx				: std_logic;
signal ena_zz			: std_logic_vector(ADD_DELAY downto 0);

attribute USE_DSP : string;
attribute USE_DSP of dsp_pp : signal is "YES";

begin

---------------- Multiplier ----------------
mult_a1 <= AA1 after td when rising_edge(clk);
mult_a2 <= AA2 after td when rising_edge(clk);

mult_b1 <= cos1 after td when rising_edge(clk);
mult_b2 <= cos2 after td when rising_edge(clk);

---------------- Counter for phase ----------------
PR_CNT1: process(clk) is
begin
	if rising_edge(clk) then
		if (reset = '1') then
			ph_in1 <= (others => '0') after TD;
			ph_in2 <= (others => '0') after TD;
		else
			if (ENABLE = '1') then
				ph_in1 <= ph_in1 + 1 after TD;
				ph_in2 <= ph_in2 + 2 after TD;
			end if;
		end if;
	end if;
end process;

---------------- Cordic scheme ----------------
xUSE_CORD: if (SIN_TYPE = "CORDIC") generate
	---------------- Twiddle part 1 ----------------
	xCRD1: entity work.cordic_dds
		generic map (
			DATA_WIDTH	=> DAT_WIDTH,
			PHASE_WIDTH	=> PHI_WIDTH
		)	
		port map (
			RESET       => reset,
			CLK         => clk,
			PH_IN       => ph_in1,
			PH_EN       => ENABLE,
			DT_COS      => cos1 
		);	
	---------------- Twiddle part 2 ----------------
	xCRD2: entity work.cordic_dds
		generic map (
			DATA_WIDTH	=> DAT_WIDTH,
			PHASE_WIDTH	=> PHI_WIDTH
		)	
		port map (
			RESET       => reset,
			CLK         => clk,
			PH_IN       => ph_in2,
			PH_EN       => ENABLE,
			DT_COS      => cos2 
		);	
end generate;

---------------- Taylor series scheme ----------------
xUSE_TAY: if (SIN_TYPE = "TAYLOR") generate
	---------------- Twiddle part 1 ----------------
	xTAY1: entity work.taylor_sincos
		generic map (
			XSERIES     => XSERIES,
			LUT_SIZE    => LUT_SIZE,
			DATA_WIDTH  => DAT_WIDTH,
			PHASE_WIDTH => PHI_WIDTH
		)	
		port map (
			RST         => reset,
			CLK         => clk,
			PHI_ENA     => ENABLE,
			OUT_COS     => cos1
		);
	---------------- Twiddle part 2 ----------------	
	xTAY2: entity work.taylor_sincos
		generic map (
			XSERIES     => XSERIES,
			LUT_SIZE    => LUT_SIZE,
			DATA_WIDTH  => DAT_WIDTH,
			PHASE_WIDTH => PHI_WIDTH-1
		)	
		port map (
			RST         => reset,
			CLK         => clk,
			PHI_ENA     => ENABLE,
			OUT_COS     => cos2
		);	
end generate;

---------------- Weight constants ----------------
xMLT1: entity work.int_multNxN_dsp48
	generic map ( DTW => DAT_WIDTH)
	port map (
		DAT_A	=> mult_a1,
		DAT_B	=> mult_b1,
		DAT_Q	=> mult_p1,
		CLK		=> clk,
		RST		=> reset
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

---------------- DSP48E2 1-2 ----------------
dsp_b0 <= AA0 after td when rising_edge(clk);

dsp_r1 <= mult_p1(2*DAT_WIDTH-2 downto DAT_WIDTH-2) after td when rising_edge(clk);
dsp_r2 <= mult_p2(2*DAT_WIDTH-2 downto DAT_WIDTH-2) after td when rising_edge(clk);

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
	end if;
end process;

---------------- DSP48 signal mapping ----------------
pr_add: process(clk) is
begin
	if rising_edge(clk) then
		dsp_pp <= 	(dsp_b2(DAT_WIDTH-1) & dsp_b2(DAT_WIDTH-1) & dsp_b2) - 
					(dsp_b1(DAT_WIDTH-1) & dsp_b1(DAT_WIDTH-1) & dsp_b1) + 
					(dsp_b0(DAT_WIDTH-1) & dsp_b0(DAT_WIDTH-1) & dsp_b0); 
	end if;
end process;

ena_zz <= ena_zz(ena_zz'left-1 downto 0) & enable after td when rising_edge(clk);

---------------- Round output data from N+1 to N bits ----------------
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

end bh_win_3term;
-------------------------------------------------------------------------------
--
-- Title       : win_selector
-- Design      : Blackman-Harris Windows
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-- Description : Select type of windows: Hamming, Blackman-Harris 3, 4, 5, 7-term
--
--  Parameters:
--    PHI_WIDTH - Signal period = 2^PHI_WIDTH
--    DAT_WIDTH - Output data width		
--    SIN_TYPE  -Sine generator type: CORDIC / TAYLOR
--
--    ---- For Taylor series only and Hamming / BH 3-term windows ----
--    LUT_SIZE  - ROM depth for sin/cos (must be less than PHASE_WIDTH)
--    XSERIES   - for 6/7 series: "7SERIES"; for ULTRASCALE: "ULTRA"; 
--
--  Note: While using TAYLOR scheme You must set LUT_SIZE < (PHASE_WIDTH - 3) 
--        for correct delays. 
--
--    WIN_TYPE - type of window func: Hamming, Blackman-Harris 3, 4, 5, 7-term
--
--      > HAMMING - Hamming (Hann) window,
--      > BH3TERM - Blackman-Harris 3-term,
--      > BH4TERM - Blackman-Harris 4-term,
--      > BH5TERM - Blackman-Harris 5-term,
--      > BH7TERM - Blackman-Harris 7-term.
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

entity win_selector is
	generic (
		TD			: time:=0.5ns;       --! Time delay
		PHI_WIDTH	: integer:=10;       --! Signal period = 2^PHI_WIDTH
		DAT_WIDTH	: integer:=16;       --! Output data width		
		WIN_TYPE    : string:="HAMMING"; --! Window type: Hamming, Blackman-Harris 3-, 4-, 5-, 7-term
		SIN_TYPE    : string:="CORDIC";  --! Sine generator type: CORDIC / TAYLOR
		---- For Taylor series only ----
		LUT_SIZE    : integer:= 9;       --! ROM depth for sin/cos (must be less than PHASE_WIDTH)
        XSERIES     : string:="ULTRA"    --! for 6/7 series: "7SERIES"; for ULTRASCALE: "ULTRA";
	);
	port (
		RESET       : in  std_logic; --! Global reset 
		CLK         : in  std_logic; --! System clock 

		AA0         : in  std_logic_vector(DAT_WIDTH-1 downto 0); --! Constant A0
		AA1         : in  std_logic_vector(DAT_WIDTH-1 downto 0); --! Constant A1
		AA2         : in  std_logic_vector(DAT_WIDTH-1 downto 0); --! Constant A1
		AA3         : in  std_logic_vector(DAT_WIDTH-1 downto 0); --! Constant A1
		AA4         : in  std_logic_vector(DAT_WIDTH-1 downto 0); --! Constant A1
		AA5         : in  std_logic_vector(DAT_WIDTH-1 downto 0); --! Constant A1
		AA6         : in  std_logic_vector(DAT_WIDTH-1 downto 0); --! Constant A1

		ENABLE      : in  std_logic; --! Input data enable block = NFFT clocks
		DT_WIN      : out std_logic_vector(DAT_WIDTH-1 downto 0); --! Output (cos)	
		DT_VLD      : out std_logic --! Output data valid	
	);
end win_selector;

architecture win_selector of win_selector is

begin

xHAMMING: if (WIN_TYPE = "HAMMING") generate
	xWIN2: entity work.hamming_win 
		generic map (
			PHI_WIDTH   => PHI_WIDTH,
			DAT_WIDTH   => DAT_WIDTH,
			SIN_TYPE    => SIN_TYPE,
			LUT_SIZE    => LUT_SIZE,
			XSERIES     => XSERIES
		)
		port map (
			RESET       => RESET,
			CLK         => CLK,

			AA0         => AA0,
			AA1         => AA1,
			ENABLE      => ENABLE,
			DT_WIN      => DT_WIN,
            DT_VLD      => DT_VLD
			
		);
end generate;

xBH3: if (WIN_TYPE = "BH3TERM") generate
	xWIN3: entity work.bh_win_3term 
		generic map (
			PHI_WIDTH   => PHI_WIDTH,
			DAT_WIDTH   => DAT_WIDTH,
			SIN_TYPE    => SIN_TYPE,
			LUT_SIZE    => LUT_SIZE,
			XSERIES     => XSERIES
		)
		port map (
			RESET       => RESET,
			CLK         => CLK,

			AA0         => AA0,
			AA1         => AA1,
			AA2         => AA2,
			ENABLE      => ENABLE,
			DT_WIN      => DT_WIN,
            DT_VLD      => DT_VLD
		);
end generate;

xBH4: if (WIN_TYPE = "BH4TERM") generate
	xWIN4: entity work.bh_win_4term 
		generic map (
			PHI_WIDTH   => PHI_WIDTH,
			DAT_WIDTH   => DAT_WIDTH
		)
		port map (
			RESET       => RESET,
			CLK         => CLK,

			AA0         => AA0,
			AA1         => AA1,
			AA2         => AA2,
			AA3         => AA3,
			ENABLE      => ENABLE,
			DT_WIN      => DT_WIN,
            DT_VLD      => DT_VLD
		);
end generate;

xBH5: if (WIN_TYPE = "BH5TERM") generate
	xWIN5: entity work.bh_win_5term 
		generic map (
			PHI_WIDTH   => PHI_WIDTH,
			DAT_WIDTH   => DAT_WIDTH
		)
		port map (
			RESET       => RESET,
			CLK         => CLK,

			AA0         => AA0,
			AA1         => AA1,
			AA2         => AA2,
			AA3         => AA3,
			AA4         => AA4,
			ENABLE      => ENABLE,
			DT_WIN      => DT_WIN,
            DT_VLD      => DT_VLD
		);
end generate;

xBH7: if (WIN_TYPE = "BH7TERM") generate
	xWIN7: entity work.bh_win_7term 
		generic map (
			PHI_WIDTH   => PHI_WIDTH,
			DAT_WIDTH   => DAT_WIDTH
		)
		port map (
			RESET       => RESET,
			CLK         => CLK,

			AA0         => AA0,
			AA1         => AA1,
			AA2         => AA2,
			AA3         => AA3,
			AA4         => AA4,
			AA5         => AA5,
			AA6         => AA6,
			ENABLE      => ENABLE,
			DT_WIN      => DT_WIN,
            DT_VLD      => DT_VLD
		);
end generate;

end win_selector;
-------------------------------------------------------------------------------
--
-- Title       : taylor_sincos
-- Design      : Blackman-Harris Windows
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-- Description : Sine & Cosine generator by using Taylor function: 1 order.
--
--   Data decoder for sine / cosine
--   Main algorithm for calculation FFT coefficients	by Taylor scheme.
--   
--   Wcos(x) = cos(x) + sin(x) * (pi * cnt(x) / NFFT); *
--   Wsin(x) = sin(x) - cos(x) * (pi * cnt(x) / NFFT);
--   
--   * where	pi is 0x6487ED / Iteration
--   
--   MPX = (M_PI * CNT) is always has [24:0] bit field!
--   
--   RAMB (Width * Depth) is constant value and equals 2Nx1K,
--   
--   Taylor alrogithm takes 3 Mults and 2 Adders in INT format. 
--
--  List of parameters:
--    DATA_WIDTH  - sin/cos width (Magnitude = 2**Amag)		
--    XSERIES     - FPGA family: for 6/7 series: "7SERIES"; for ULTRASCALE: "ULTRA"
--    VAL_SHIFT   - Shift value for data: MIN(LUT_SIZE) = 8, MAX(LUT_SIZE) = 10; 
--    USE_MLT     - 'TRUE' - use DSP48 for calculation PI * CNT, 'FALSE' - use look-up table
--    STAGE       - Counter of data width in Taylor series
--
-------------------------------------------------------------------------------
--  
--                       DSP48E1/E2
--             __________________________
--            |                          |
--            |     MULT 18x25           |
--   SIN/COS  | A   _____      ADD/SUB   |
--  --------->|--->|     |      _____    |
--   M_PI     | B  |  *  |---->|     |   | NEW SIN/COS
--  --------->|--->|_____|     |  +  | P |
--   COS/SIN  | C              |  /  |---|-->
--  --------->|--------------->|  -  |   |
--            |                |_____|   |
--            |                          |
--            |__________________________|
-- 
--             P = A[24:0]*B[17:0]+C[47:0]
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
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_SIGNED.all; 
use IEEE.STD_LOGIC_ARITH.all;

use ieee.math_real.all;

library UNISIM;
use UNISIM.vcomponents.DSP48E1;	
use UNISIM.vcomponents.DSP48E2;

entity tay1_order is
	generic(
		DATA_WIDTH  : integer:=16;       --! Sin/cos MSB (Mag = 2**Amag)		
		XSERIES     : string:="7SERIES"; --! FPGA family: for 6/7 series: "7SERIES"; for ULTRASCALE: "ULTRA";
		VAL_SHIFT   : integer:=10;       --! Shift value depends on LUT SIZE
		USE_MLT     : boolean:=false;    --! use DSP48 for calculation PI * CNT
		STAGE       : integer:=2         --! 0, 1, 2, 3, 4, 5, 6, 7 -- 16-stages-stage_num
	);
	port (
		rom_dat     : in  std_logic_vector(2*DATA_WIDTH-1 downto 0); --! Input data coefficient  
		rom_cnt     : in  std_logic_vector(STAGE downto 0); --! Counter for Taylor series		

		dsp_dat     : out std_logic_vector(2*DATA_WIDTH-1 downto 0); --! Output data coefficient 		
		
		clk         : in  std_logic; --! Common clock
		rst         : in  std_logic	 --! Positive reset
	);
end tay1_order;

architecture tay1_order of tay1_order is 

constant XSHIFT         : integer:=19+VAL_SHIFT;

signal mpi              : std_logic_vector(23 downto 00);
signal mpx              : std_logic_vector(29 downto 00);
signal cnt_exp          : std_logic_vector(15 downto 00);

signal cos_rnd          : std_logic_vector(DATA_WIDTH-1 downto 00);
signal sin_rnd          : std_logic_vector(DATA_WIDTH-1 downto 00);

begin 

---------------- Find counter for MATH_PI ----------------
xCNTEXP: for jj in 0 to 14-STAGE generate 
	cnt_exp(15-jj) <= '0';
end generate;  
cnt_exp(STAGE downto 0) <= rom_cnt;

---------------- USE ROM when calculation MATH_PI --------------------
xROM_PI: if (USE_MLT = FALSE) generate
	
	type std_logic_array_KKxNN is array (0 to (2**(STAGE+1))-1) of std_logic_vector(23 downto 0);	
	constant ramb_pi    : integer:=integer(round(MATH_PI*2.0**(17-STAGE)));
	
	function read_rom(stg : integer) return std_logic_array_KKxNN is
		variable ramb_init  : std_logic_array_KKxNN;		
	begin 
		for jj in 0 to (2**(stg+1)-1) loop
			ramb_init(jj) := conv_std_logic_vector(ramb_pi*jj, 24);
		end loop;		
		return ramb_init;
	end read_rom;	 
	
	constant rom_pi 	: std_logic_array_KKxNN := read_rom(STAGE);
begin
	mpi <= rom_pi(conv_integer(unsigned(cnt_exp(STAGE downto 0)))) when rising_edge(clk);	
end generate;

---------------- USE DSP when calculation MATH_PI ----------------
xDSP_PI: if (USE_MLT = TRUE) generate
	function find_pi(xx: in integer) return std_logic_vector is
		variable ramb_pi    : integer:=integer(round(MATH_PI*2.0**(17-STAGE)));
	begin
		return conv_std_logic_vector(ramb_pi, 24);
	end;
	constant std_pi	: std_logic_vector(23 downto 0):=find_pi(STAGE);

begin
	pr_pi: process(clk) is
	begin
		if rising_edge(clk) then
			if (rst = '1') then
				mpi <= (others=>'0');
			else
				mpi <= unsigned(std_pi) * unsigned(cnt_exp);
			end if;
		end if;
	end process;
end generate;

-------------------------------------------------------
---- DSP48 MACC PORTS: P = A[24:0]*B[17:0]+C[47:0] ----
-------------------------------------------------------

---- DATA FOR A PORT (25-bit) ----
mpx(23 downto 00) <= mpi;
mpx(29 downto 24) <= (others => '0');

-------------------------------------------------------
xWIDTH18: if (DATA_WIDTH < 19) generate
	signal cos_aa      : std_logic_vector(17 downto 00);
	signal sin_aa      : std_logic_vector(17 downto 00);
	signal cos_cc      : std_logic_vector(47 downto 00);
	signal sin_cc      : std_logic_vector(47 downto 00);

	signal sin_prod    : std_logic_vector(47 downto 00);
	signal cos_prod    : std_logic_vector(47 downto 00);
	
begin

	---- Wrap input data B ----
	sin_aa <= SXT(rom_dat(2*DATA_WIDTH-1 downto 1*DATA_WIDTH), 18);
	cos_aa <= SXT(rom_dat(1*DATA_WIDTH-1 downto 0*DATA_WIDTH), 18);	

	---- Wrap input data C ----
	xM12C: for ii in XSHIFT to 47 generate
		xLSB: if (ii < DATA_WIDTH+XSHIFT) generate 
			sin_cc(ii) <= rom_dat(ii+1*DATA_WIDTH-XSHIFT) when rising_edge(clk);
			cos_cc(ii) <= rom_dat(ii+0*DATA_WIDTH-XSHIFT) when rising_edge(clk);
		end generate;
		xMSB: if (ii >= DATA_WIDTH+XSHIFT) generate
			sin_cc(ii) <= rom_dat(2*DATA_WIDTH-1) when rising_edge(clk);
			cos_cc(ii) <= rom_dat(1*DATA_WIDTH-1) when rising_edge(clk);
		end generate;
	end generate;
	
	cos_cc(XSHIFT-1 downto 00) <= (others => '0');
	sin_cc(XSHIFT-1 downto 00) <= (others => '0');		

	---- Wrap DPS48E1 ----
	xDSP48E1: if (XSERIES = "7SERIES") generate
		MULT_ADD: DSP48E1 --   +/-(A*B+Cin)   -- for Virtex-6 and 7 families
			generic map (
				-- Feature Control Attributes: Data Path Selection
				A_INPUT 			=> "DIRECT",
				B_INPUT 			=> "DIRECT",
				USE_DPORT 			=> FALSE,
				USE_MULT 			=> "MULTIPLY",
				-- Register Control Attributes: Pipeline Register Configuration
				ACASCREG 			=> 1,
				ADREG 				=> 0,
				ALUMODEREG 			=> 1,
				AREG 				=> 1,
				BCASCREG 			=> 1,
				BREG 				=> 1,
				CARRYINREG 			=> 1,
				CARRYINSELREG 		=> 1,
				CREG 				=> 1,
				DREG 				=> 0,
				INMODEREG 			=> 1,
				MREG 				=> 1,
				OPMODEREG 			=> 1,
				PREG 				=> 1 
			)
			port map (
				-- Data Product Output 
				P                 => cos_prod,
				-- Cascade: 30-bit (each) input: Cascade Ports
				ACIN              => (others=>'0'),
				BCIN              => (others=>'0'),
				CARRYCASCIN       => '0',    
				MULTSIGNIN        => '0',    
				PCIN              => (others=>'0'),
				-- Control: 4-bit (each) input: Control Inputs/Status Bits
				ALUMODE           => (0 => '1', 1 => '1', others=>'0'),
				CARRYINSEL        => (others=>'0'),
				CLK               => clk, 
				INMODE            => (others=>'0'),
				OPMODE            => "0110101", 
				-- Data: 30-bit (each) input: Data Ports
				A                 => mpx,    
				B                 => sin_aa,    
				C                 => cos_cc,         
				CARRYIN           => '0',
				D                 => (others=>'0'),
				-- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
				CEA1              => '1',
				CEA2              => '1',
				CEAD              => '1',
				CEALUMODE         => '1',
				CEB1              => '1',
				CEB2              => '1',
				CEC               => '1',
				CECARRYIN         => '1',
				CECTRL            => '1',
				CED               => '1',
				CEINMODE          => '1',
				CEM               => '1',
				CEP               => '1',
				RSTA              => rst,
				RSTALLCARRYIN     => rst,
				RSTALUMODE        => rst,
				RSTB              => rst,
				RSTC              => rst,
				RSTCTRL           => rst,
				RSTD              => rst,
				RSTINMODE         => rst,
				RSTM              => rst,
				RSTP              => rst 
			);

		MULT_SUB: DSP48E1 --   +/-(A*B+Cin)   -- for Virtex-6 and 7 families
			generic map (
				-- Feature Control Attributes: Data Path Selection
				A_INPUT           => "DIRECT",
				B_INPUT           => "DIRECT",
				USE_DPORT         => FALSE,
				USE_MULT          => "MULTIPLY",
				USE_SIMD          => "ONE48",
				-- Register Control Attributes: Pipeline Register Configuration
				ACASCREG 	      => 1,
				ADREG 		      => 0,
				ALUMODEREG 	      => 1,
				AREG 		      => 1,
				BCASCREG 	      => 1,
				BREG 		      => 1,
				CARRYINREG 	      => 1,
				CARRYINSELREG     => 1,
				CREG 		      => 1,
				DREG 		      => 0,
				INMODEREG 	      => 1,
				MREG 		      => 1,
				OPMODEREG         => 1,
				PREG              => 1 
			)
			port map (
				-- Data Product Output 
				P                 => sin_prod,
				-- Cascade: 30-bit (each) input: Cascade Ports
				ACIN              => (others=>'0'),
				BCIN              => (others=>'0'),
				CARRYCASCIN       => '0',
				MULTSIGNIN        => '0',
				PCIN              => (others=>'0'),
				-- Control: 4-bit (each) input: Control Inputs/Status Bits
				ALUMODE           => (others=>'0'),
				CARRYINSEL        => (others=>'0'),
				CLK               => clk, 
				INMODE            => (others=>'0'),
				OPMODE            => "0110101", 
				-- Data: 30-bit (each) input: Data Ports
				A                 => mpx,
				B                 => cos_aa,
				C                 => sin_cc,
				CARRYIN           => '0',
				D                 => (others=>'0'),
				-- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
				CEA1              => '1',
				CEA2              => '1',
				CEAD              => '1',
				CEALUMODE         => '1',
				CEB1              => '1',
				CEB2              => '1',
				CEC               => '1',
				CECARRYIN         => '1',
				CECTRL            => '1',
				CED               => '1',
				CEINMODE          => '1',
				CEM               => '1',
				CEP               => '1',
				RSTA              => rst,
				RSTALLCARRYIN     => rst,
				RSTALUMODE        => rst,
				RSTB              => rst,
				RSTC              => rst,
				RSTCTRL           => rst,
				RSTD              => rst,
				RSTINMODE         => rst,
				RSTM              => rst,
				RSTP              => rst 
			);
	end generate;

	---- Wrap DPS48E2 ----
	xDSP48E2: if (XSERIES = "ULTRA") generate
		MULT_ADD: DSP48E2 --   +/-(A*B+Cin)   -- for Virtex-6 and 7 families
			generic map (
				-- Feature Control Attributes: Data Path Selection
				AMULTSEL 			=> "A",
				A_INPUT 			=> "DIRECT",
				BMULTSEL 			=> "B",
				B_INPUT 			=> "DIRECT",
				PREADDINSEL 		=> "A",
				USE_MULT 			=> "MULTIPLY",
				-- Register Control Attributes: Pipeline Register Configuration
				ACASCREG 			=> 1,
				ADREG 				=> 0,
				ALUMODEREG 			=> 1,
				AREG 				=> 1,
				BCASCREG 			=> 1,
				BREG 				=> 1,
				CARRYINREG 			=> 1,
				CARRYINSELREG 		=> 1,
				CREG 				=> 1,
				DREG 				=> 0,
				INMODEREG 			=> 1,
				MREG 				=> 1,
				OPMODEREG 			=> 1,
				PREG 				=> 1 
			)
			port map (   
				-- Data: 4-bit (each) output: Data Ports
				P 					=> cos_prod,			
				-- Cascade: 30-bit (each) input: Cascade Ports
				ACIN 				=> (others=>'0'),
				BCIN 				=> (others=>'0'),
				CARRYCASCIN 		=> '0',    
				MULTSIGNIN 			=> '0',    
				PCIN 				=> (others=>'0'),              
				-- Control: 4-bit (each) input: Control Inputs/Status Bits
				ALUMODE 			=> (0 => '1', 1 => '1', others=>'0'),
				CARRYINSEL 			=> (others=>'0'),
				CLK 				=> clk, 
				INMODE 				=> (others=>'0'),
				OPMODE 				=> "000110101", 
				-- Data: 30-bit (each) input: Data Ports
				A 					=> mpx,    
				B 					=> sin_aa,    
				C 					=> cos_cc,
				CARRYIN 			=> '0',
				D 					=> (others=>'0'),
				-- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
				CEA1 				=> '1',
				CEA2 				=> '1',
				CEAD 				=> '1',
				CEALUMODE 			=> '1',
				CEB1 				=> '1',
				CEB2 				=> '1',
				CEC 				=> '1',    
				CECARRYIN 			=> '1',
				CECTRL 				=> '1',
				CED 				=> '1',   
				CEINMODE 			=> '1',
				CEM 				=> '1',    
				CEP 				=> '1',    
				RSTA				=> rst,    
				RSTALLCARRYIN 		=> rst,
				RSTALUMODE 			=> rst,
				RSTB 				=> rst,
				RSTC 				=> rst,
				RSTCTRL 			=> rst,    
				RSTD 				=> rst,
				RSTINMODE 			=> rst,
				RSTM 				=> rst,
				RSTP 				=> rst 
			);

		MULT_SUB: DSP48E2 --   +/-(A*B+Cin)   -- for Virtex-6 and 7 families
			generic map (
				-- Feature Control Attributes: Data Path Selection
				AMULTSEL 			=> "A",             
				A_INPUT 			=> "DIRECT",        
				BMULTSEL 			=> "B",             
				B_INPUT 			=> "DIRECT",        
				PREADDINSEL 		=> "A",
				USE_MULT 			=> "MULTIPLY", 
				-- Register Control Attributes: Pipeline Register Configuration
				ACASCREG 			=> 1,
				ADREG 				=> 0,
				ALUMODEREG 			=> 1,
				AREG 				=> 1,
				BCASCREG 			=> 1,
				BREG 				=> 1,
				CARRYINREG 			=> 1,
				CARRYINSELREG 		=> 1,
				CREG 				=> 1,
				DREG 				=> 0,
				INMODEREG 			=> 1,
				MREG 				=> 1,
				OPMODEREG 			=> 1,
				PREG 				=> 1 
			)
			port map (
				-- Data: 4-bit (each) output: Data Ports
				P 					=> sin_prod,			
				-- Cascade: 30-bit (each) input: Cascade Ports
				ACIN 				=> (others=>'0'),
				BCIN 				=> (others=>'0'),
				CARRYCASCIN 		=> '0',    
				MULTSIGNIN 			=> '0',    
				PCIN 				=> (others=>'0'),              
				-- Control: 4-bit (each) input: Control Inputs/Status Bits
				ALUMODE 			=> (others=>'0'),
				CARRYINSEL 			=> (others=>'0'),
				CLK 				=> clk, 
				INMODE 				=> (others=>'0'),
				OPMODE 				=> "000110101", 
				-- Data: 30-bit (each) input: Data Ports
				A 					=> mpx,    
				B 					=> cos_aa,    
				C 					=> sin_cc,         
				CARRYIN 			=> '0',
				D 					=> (others=>'0'),
				-- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
				CEA1 				=> '1',
				CEA2 				=> '1',
				CEAD 				=> '1',
				CEALUMODE 			=> '1',
				CEB1 				=> '1',
				CEB2 				=> '1',
				CEC 				=> '1',
				CECARRYIN 			=> '1',
				CECTRL 				=> '1',
				CED 				=> '1',
				CEINMODE 			=> '1',
				CEM 				=> '1',
				CEP 				=> '1',
				RSTA				=> rst,
				RSTALLCARRYIN 		=> rst,
				RSTALUMODE 			=> rst,
				RSTB 				=> rst,
				RSTC 				=> rst,
				RSTCTRL 			=> rst,
				RSTD 				=> rst,
				RSTINMODE 			=> rst,
				RSTM 				=> rst,
				RSTP 				=> rst 
			);
	end generate;

	cos_rnd <= cos_prod(19+VAL_SHIFT+DATA_WIDTH-1 downto 19+VAL_SHIFT) when rising_edge(clk);
	sin_rnd <= sin_prod(19+VAL_SHIFT+DATA_WIDTH-1 downto 19+VAL_SHIFT) when rising_edge(clk);	

end generate;

xWIDTH35: if (DATA_WIDTH > 18) generate
	signal cos_aa			: std_logic_vector(34 downto 00):=(others=>'0');
	signal sin_aa			: std_logic_vector(34 downto 00):=(others=>'0');
	signal cos_pp			: std_logic_vector(61 downto 00):=(others=>'0');
	signal sin_pp			: std_logic_vector(61 downto 00):=(others=>'0');

	signal mlt1_bb			: std_logic_vector(DATA_WIDTH-1 downto 0):=(others=>'0');
	signal mlt1_cc			: std_logic_vector(DATA_WIDTH-1 downto 0):=(others=>'0');

	signal mlt2_bb			: std_logic_vector(DATA_WIDTH-1 downto 0):=(others=>'0');
	signal mlt2_cc			: std_logic_vector(DATA_WIDTH-1 downto 0):=(others=>'0');	

	type std_logic_array_Dx3 is array (3 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);
	signal sin_del          : std_logic_array_Dx3;
	signal cos_del          : std_logic_array_Dx3;

	signal cos_pdt          : std_logic_vector(DATA_WIDTH-1 downto 00);
	signal sin_pdt          : std_logic_vector(DATA_WIDTH-1 downto 00);
	
	attribute USE_DSP       : string;
	attribute USE_DSP of cos_pdt : signal is "yes";
	attribute USE_DSP of sin_pdt : signal is "yes";
	
begin

	sin_aa <= SXT(rom_dat(2*DATA_WIDTH-1 downto 1*DATA_WIDTH), 35);
	cos_aa <= SXT(rom_dat(1*DATA_WIDTH-1 downto 0*DATA_WIDTH), 35);

	sin_del <= sin_del(sin_del'left-1 downto 0) & rom_dat(2*DATA_WIDTH-1 downto 1*DATA_WIDTH) when rising_edge(clk);
	cos_del <= cos_del(cos_del'left-1 downto 0) & rom_dat(1*DATA_WIDTH-1 downto 0*DATA_WIDTH) when rising_edge(clk);

	---- Wrap DSP48E1 ----
	xDSP48E1: if (XSERIES = "7SERIES") generate
		
		xMLT1: entity work.mlt35x25_dsp48e1
			port map (
				MLT_A 	=> cos_aa,
				MLT_B 	=> mpx(24 downto 0),
				MLT_P 	=> cos_pp(59 downto 00),
				RST  	=> RST,
				CLK 	=> CLK
			);	
			
		xMLT2: entity work.mlt35x25_dsp48e1
			port map (
				MLT_A 	=> sin_aa,
				MLT_B 	=> mpx(24 downto 0),
				MLT_P 	=> sin_pp(59 downto 00),
				RST  	=> RST,
				CLK 	=> CLK
			);		
	end generate;	

	---- Wrap DSP48E2 ----
	xDSP48E2: if (XSERIES = "ULTRA") generate
		
		xMLT1: entity work.mlt35x25_dsp48e1
			port map (
				MLT_A 	=> cos_aa,
				MLT_B 	=> mpx(24 downto 0),
				MLT_P 	=> cos_pp,
				RST  	=> RST,
				CLK 	=> CLK
			);	
			
		xMLT2: entity work.mlt35x25_dsp48e1
			port map (
				MLT_A 	=> sin_aa,
				MLT_B 	=> mpx(24 downto 0),
				MLT_P 	=> sin_pp,
				RST  	=> RST,
				CLK 	=> CLK
			);
	end generate;

	pr_addsub: process(clk) is
	begin
		if rising_edge(clk) then
			---- 1st operand ----
			mlt1_bb <= sin_pp(DATA_WIDTH+XSHIFT-1 downto XSHIFT);
			mlt2_bb <= cos_pp(DATA_WIDTH+XSHIFT-1 downto XSHIFT);  
			---- 2nd operand ----
			mlt2_cc <= sin_del(sin_del'left);
			mlt1_cc <= cos_del(cos_del'left);			
			---- *Infer DSP48 block* ----
			if (rst = '1') then
				cos_pdt <= (others=>'0');
				sin_pdt <= (others=>'0');
			else
				cos_pdt <= mlt1_cc - mlt1_bb;
				sin_pdt <= mlt2_cc + mlt2_bb;
			end if;
		end if;
	end process;	

	---- Scale overflow values ----
	pr_rnd: process(clk) is
	begin
		if rising_edge(clk) then
			if (cos_pdt(DATA_WIDTH-1) = '0') then
				cos_rnd <= cos_pdt;
			else
				cos_rnd <= ((DATA_WIDTH-1) => '0', others=>'1');
			end if;
			
			if (sin_pdt(DATA_WIDTH-1) = '0') then
				sin_rnd <= sin_pdt;
			else
				sin_rnd <= ((DATA_WIDTH-1) => '0', others=>'1');
			end if;	
		end if;
	end process;		

	-- Rounding +/-0.5 ----
	-- pr_rnd: process(clk) is
	-- begin
		-- if rising_edge(clk) then
			-- if (cos_pdt(0) = '1') then
				-- cos_rnd <= cos_pdt(DATA_WIDTH downto 1) + 1;
			-- else
				-- cos_rnd <= cos_pdt(DATA_WIDTH downto 1);
			-- end if;
			
			-- if (sin_pdt(0) = '1') then
				-- sin_rnd <= sin_pdt(DATA_WIDTH downto 1) + 1;
			-- else
				-- sin_rnd <= sin_pdt(DATA_WIDTH downto 1);
			-- end if;		
		-- end if;
	-- end process;	
	
end generate;

dsp_dat(2*DATA_WIDTH-1 downto 1*DATA_WIDTH) <= sin_rnd;
dsp_dat(1*DATA_WIDTH-1 downto 0*DATA_WIDTH) <= cos_rnd;

end tay1_order;
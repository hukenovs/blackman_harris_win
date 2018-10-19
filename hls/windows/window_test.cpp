/*******************************************************************************
--
-- Title       : window_sel.c 
-- Design      : Window function Testbench
-- Author      : Kapitanov Alexander
-- Company     : insys.ru
-- E-mail      : sallador@bk.ru
--
-------------------------------------------------------------------------------
--
--	Version 1.0  11.09.2018
--
-------------------------------------------------------------------------------
--
-- Description : Simple model for calculating several window functions
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
*******************************************************************************/
#include <stdio.h>
#include <string.h>

#include <math.h>
#include "win_function.h"

int main () {

	printf("!!! ************************************************ !!!\n");
	printf("\nPhase = %d, Data = %d, Samples = %d Result: \n", NPHASE, NWIDTH, NSAMPLES);

	FILE *fout;	FILE *fgld;	
	fout = fopen("..\\..\\..\\..\\..\\math\\dout.dat", "w");	
	fgld = fopen("..\\..\\..\\..\\..\\math\\golden_dat.dat", "w");	
	
	/* Select window function type */
	int sel = 0xFFFF;
	if (strcmp(Wintype, "Hamming") == 0 ) {
		sel = 0x1;
	} else if (strcmp(Wintype, "Hann") == 0 ) {
		sel = 0x2;
	} else if (strcmp(Wintype, "Blackman-Harris-3") == 0 ) {
		sel = 0x3;
	} else if (strcmp(Wintype, "Blackman-Harris-4") == 0 ) {
		sel = 0x4;
	} else if (strcmp(Wintype, "Blackman-Harris-5") == 0 ) {
		sel = 0x5;
	} else if (strcmp(Wintype, "Blackman-Harris-7") == 0 ) {
		sel = 0x7;	
	} else {
		sel = 0xAAAA;
	}
	printf("Selected window is %s (Number - %d)\n", Wintype, sel);
	
	
	double calc_dbl;
	win_t win_rnd[NSAMPLES];
	win_t win_out[NSAMPLES];
	win_t win_res;
	

	int shift = 1;
	printf("HLS Data: \t Golden Data:\n");
	
	/* Weight parameters */
	double a0, a1, a2, a3, a4, a5, a6;
	
	double acc_err = 0;
	
	int i = 0x0;
	for (i = 0; i < NSAMPLES; i++)
	{
		switch (sel) {
			case 0x1:
				a0 = 0.5434783;
				a1 = 1.0 - 0.5434783;
				calc_dbl = a0 - a1 * cos((2 * i * M_PI)/NSAMPLES);
				shift = 1;
				break;
				
			case 0x2:
				a0 = 0.5;
				a1 = 0.5;
				calc_dbl = a0 - a1 * cos((2 * i * M_PI)/NSAMPLES);
				shift = 1;
				break;
				
			case 0x3:
				a0 = 0.21;
				a1 = 0.25;
				a2 = 0.04;
				calc_dbl = a0 - a1 * cos((2 * i * M_PI)/NSAMPLES) + a2 * cos((2 * 2 * i * M_PI)/NSAMPLES);
				shift = 1;
				break;
				
			case 0x4:
				/*
					> Blackman-Harris:
						a0 = 0.35875, 
						a1 = 0.48829, 
						a2 = 0.14128, 
						a3 = 0.01168.
					> Nuttall:
						a0 = 0.355768, 
						a1 = 0.487396, 
						a2 = 0.144323, 
						a3 = 0.012604.
					> Blackman-Nuttall:
						a0 = 0.3635819, 
						a1 = 0.4891775, 
						a2 = 0.1365995, 
						a3 = 0.0106411.
				*/			
				a0 = 0.35875;
				a1 = 0.48829;
				a2 = 0.14128;
				a3 = 0.01168;
				
				calc_dbl = a0 - a1 * cos((2 * i * M_PI)/NSAMPLES) + a2 * cos((2 * 2 * i * M_PI)/NSAMPLES) - a3 * cos((3 * 2 * i * M_PI)/NSAMPLES);
				shift = 1;
				break;
				
			case 0x5:
				/*
					> Blackman-Harris:
						a0 = 0.3232153788877343;
						a1 = 0.4714921439576260;
						a2 = 0.1755341299601972;
						a3 = 0.0284969901061499;
						a4 = 0.0012613570882927;
					> Flat-top (1):
						a0 = 0.25000;
						a1 = 0.49250;
						a2 = 0.32250;
						a3 = 0.09700;
						a4 = 0.00750;
					> Flat-top (2):
						a0 = 0.215578950;
						a1 = 0.416631580;
						a2 = 0.277263158;
						a3 = 0.083578947;
						a4 = 0.006947368;
				*/					
				a0 = 0.3232153788877343;
				a1 = 0.4714921439576260;
				a2 = 0.1755341299601972;
				a3 = 0.0284969901061499;
				a4 = 0.0012613570882927;

				calc_dbl = a0 - a1 * cos((2 * i * M_PI)/NSAMPLES) + a2 * cos((2 * 2 * i * M_PI)/NSAMPLES) - a3 * cos((3 * 2 * i * M_PI)/NSAMPLES) + a4 * cos((4 * 2 * i * M_PI)/NSAMPLES);
				shift = 2;
				break;
			
			case 0x7:
				a0 = 0.271220360585039;
				a1 = 0.433444612327442;
				a2 = 0.218004122892930;
				a3 = 0.065785343295606;
				a4 = 0.010761867305342;
				a5 = 0.000770012710581;
				a6 = 0.000013680883060;
				
				calc_dbl = a0 - a1 * cos((2 * i * M_PI)/NSAMPLES) + a2 * cos((2 * 2 * i * M_PI)/NSAMPLES) - a3 * cos((3 * 2 * i * M_PI)/NSAMPLES) + a4 * cos((4 * 2 * i * M_PI)/NSAMPLES) - a5 *  cos((5 * 2 * i * M_PI)/NSAMPLES) + a6 *  cos((6 * 2 * i * M_PI)/NSAMPLES);
				shift = 2;
				break;
			default: 
				calc_dbl = 0x0;
		}
		
		/* Execute window function */
		win_function(sel, i, &win_res);
		win_out[i] = win_res;

		win_rnd[i] = (win_t) (round((pow(2.0, NWIDTH-shift)-1.0) * calc_dbl));
		
		acc_err += pow(abs((double)win_rnd[i] - (double)win_out[i]), 2);
		
		fprintf(fout, "%d \n", (int)win_out[i]);
		fprintf(fgld, "%d \n", (int)win_rnd[i]);

		if (i < 16)
		{
			printf("%08X \t %08X\n", (int)win_out[i], (int)win_rnd[i]);
		}
		
	}
	acc_err = sqrt(acc_err) / NSAMPLES;
	
	fclose(fout);
	fclose(fout);

	printf("\nCalculation error between integer and double = %lf \n", acc_err);

	if (acc_err < 10) {
		printf ("PASS: Data matches the golden output!\n");
		return 0;
	} else {
		printf ("FAIL: Data DOES NOT match the golden output\n");
		return 1;
	}

}

/*******************************************************************************
--
-- Title       : cordic_test.c 
-- Design      : CORDIC Testbench
-- Author      : Kapitanov
-- Company     : insys.ru
-- E-mail      : sallador@bk.ru
--
-------------------------------------------------------------------------------
--
--	Version 1.0  11.09.2018
--
-------------------------------------------------------------------------------
--
-- Description : Simple model for calculating CORDIC sine and cosine
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
#include <math.h>
#include "cordic.h"

int main () {

	int const NSAMPLES = pow(2.0, NPHASE);

	out_t s, c;
	out_t ts, tc;

	printf("Phase = %d, Data = %d, Result: \n", NPHASE, NWIDTH);

	int acc_s = 0x0;
	int acc_c = 0x0;
	
	//int res = out_t.length;

	FILE *fout;	
	FILE *fgld;	
	fout = fopen("..\\..\\..\\..\\math\\dout.dat", "w");	
	fgld = fopen("..\\..\\..\\..\\math\\golden_dat.dat", "w");	
	
	int i = 0x0;
	for (i = 0; i < NSAMPLES; i++)
	{
		cordic(i, &c, &s);
		ts = round( (pow(2.0, NWIDTH-2)) * sin((2 * i * M_PI) / NSAMPLES) );
		tc = round( (pow(2.0, NWIDTH-2)) * cos((2 * i * M_PI) / NSAMPLES) );
		
		acc_s += sqrt(pow(abs(s - ts), 2));
		acc_c += sqrt(pow(abs(c - tc), 2));

		fprintf(fout, "%d \t %d \n", s, c);
		fprintf(fgld, "%d \t %d \n", ts, tc);
		
		if ((i > NSAMPLES/2 - 8) &&  (i < NSAMPLES/2 + 8))
		{
			printf("%08X %08X \t %08X %08X, \t Err s/c = %d %d\n", s, ts, c, tc, acc_s, acc_c);
		}
		
	}
	acc_s /= NSAMPLES;
	acc_c /= NSAMPLES;
	
	fclose(fout);
	fclose(fout);
	
	printf("\n Err_sin = %d, Err_cos = %d \n", acc_s, acc_c);

	if ((acc_s < 10) && (acc_c < 10)) {
		printf ("PASS: Data matches the golden output!\n");
		return 0;
	} else {
		printf ("FAIL: Data DOES NOT match the golden output\n");
		return 1;
	}

}

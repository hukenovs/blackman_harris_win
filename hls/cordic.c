/*******************************************************************************
--
-- Title       : CORDIC.c
-- Design      : CORDIC HLS
-- Author      : Kapitanov
-- Company     : insys.ru
--
-------------------------------------------------------------------------------
--
--	Version 1.0  01.10.2018
--
-------------------------------------------------------------------------------
--
-- Description : CORDIC mode for sine and cosine calculation
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
#include <math.h>
#include "cordic.h"

void cordic (
		phi_t phi_int,
		out_t *out_cos,
		out_t *out_sin
	)
{
	#pragma HLS INTERFACE port=phi_int
	#pragma HLS INTERFACE register port=out_cos
	#pragma HLS INTERFACE register port=out_sin
	#pragma HLS PIPELINE

	// Create Look-up table array //
	long long lut_table [48] = {
		0x400000000000, 0x25C80A3B3BE6, 0x13F670B6BDC7, 0x0A2223A83BBB,
		0x05161A861CB1, 0x028BAFC2B209, 0x0145EC3CB850, 0x00A2F8AA23A9,
		0x00517CA68DA2, 0x0028BE5D7661, 0x00145F300123, 0x000A2F982950,
		0x000517CC19C0, 0x00028BE60D83, 0x000145F306D6, 0x0000A2F9836D,
		0x0000517CC1B7, 0x000028BE60DC, 0x0000145F306E, 0x00000A2F9837,
		0x00000517CC1B, 0x0000028BE60E, 0x00000145F307, 0x000000A2F983,
		0x000000517CC2, 0x00000028BE61, 0x000000145F30, 0x0000000A2F98,
		0x0000000517CC, 0x000000028BE6, 0x0000000145F3, 0x00000000A2FA,
		0x00000000517D, 0x0000000028BE, 0x00000000145F, 0x000000000A30,
		0x000000000518, 0x00000000028C, 0x000000000146, 0x0000000000A3,
		0x000000000051, 0x000000000029, 0x000000000014, 0x00000000000A,
		0x000000000005, 0x000000000003, 0x000000000001, 0x000000000000
	};

	static dat_t lut_angle[NWIDTH - 1];

	int i;
	for (i = 0; i < NWIDTH - 1; i++) {
		lut_angle[i] = (lut_table[i] >> (48 - NWIDTH - 2 + 1) & 0xFFFFFFFFFF);
		// lut_angle[i] = (dat_t)round(atan(pow(2.0, -i)) * pow(2.0, NWIDTH+1) / M_PI);
	}	

	// Set data output gain level //
	static const dat_t GAIN48 = (0x26DD3B6A10D8 >> (48 - NWIDTH - 2));

	// Calculate quadrant and phase //
	dbl_t quadrant = phi_int >> (NPHASE - 2);

	dat_t init_t =  phi_int & (~(0x3 << (NPHASE - 2)));
	
	dat_t init_z;
	if ((NPHASE-1) < NWIDTH) {
		init_z = init_t << (NWIDTH - NPHASE + 2);
	}
	else {
		init_z = (init_t >> (NPHASE - NWIDTH)) << 2;
	}	

	// Create array for parallel calculation //
	dat_t x[NWIDTH + 1];
	dat_t y[NWIDTH + 1];
	dat_t z[NWIDTH + 1];	
	
	// Initial values //
	x[0] = GAIN48;
	y[0] = 0x0;
	z[0] = init_z;	

	// Unrolled loop //
	int k;
	stg: for (k = 0; k < NWIDTH; k++) {
	#pragma HLS UNROLL

		if (z[k] < 0) {
			x[k+1] = x[k] + (y[k] >> k);
			y[k+1] = y[k] - (x[k] >> k);

			z[k+1] = z[k] + lut_angle[k];
		} else {						
			x[k+1] = x[k] - (y[k] >> k);
			y[k+1] = y[k] + (x[k] >> k);

			z[k+1] = z[k] - lut_angle[k];
		}

	} 	

	// Shift output data by 2 //
	dat_t out_c = (x[NWIDTH] >> 2);
	dat_t out_s = (y[NWIDTH] >> 2);

	dat_t dat_c;
	dat_t dat_s;

	// Check quadrant and find output sign of data //
	if (quadrant == 0x0) {
		dat_s = out_s;
		dat_c = out_c;
	}
	else if (quadrant == 0x1) {
		dat_s = out_c;
		dat_c = ~(out_s) + 1;
	}
	else if (quadrant == 0x2) {
		dat_s = ~(out_s) + 1;
		dat_c = ~(out_c) + 1;
	}
	else {
		dat_s = ~(out_c) + 1;
		dat_c = out_s;
	}
	
	// Get output values //
	*out_cos = (dat_c);
	*out_sin = (dat_s);

}

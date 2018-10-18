/*******************************************************************************
--
-- Title       : win_function.c
-- Design      : Window functions by HLS
-- Author      : Kapitanov Alexander
-- Company     : insys.ru
-- E-mail      : sallador@bk.ru
--
-------------------------------------------------------------------------------
--
--	Version 1.0  01.10.2018
--
-------------------------------------------------------------------------------
--
-- Description : Some window functions in HLS
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
#include "win_function.h"

/* ---------------- CORDIC core ---------------- */
void cordic (
		phi_t phi_int,
		win_t *out_cos,
		win_t *out_sin
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
	duo_t quadrant = phi_int >> (NPHASE - 2);

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

/* ---------------- Window: Empty ---------------- */
void win_empty (
	win_t out_win[]
	)
{
	int i = 0x0;
	for (i = 0; i < NSAMPLES; i++) {
		out_win[i] = 0x0;
	}	
}

/* ---------------- Window: Hamming ---------------- */
void win_hamming (
	win_t out_win[]
	)
{
	const double coeA0 = 0.5434783;
	const double coeA1 = (1 - coeA0);

	dbl_t a0 = round(coeA0 * (pow(2.0, NWIDTH-1)-1.0));
	dbl_t a1 = round(coeA1 * (pow(2.0, NWIDTH-1)-1.0));
	
	win_t s, c;
	
	int i = 0x0;
	for (i = 0; i < NSAMPLES; i++) {
		cordic(i, &c, &s);

		out_win[i] = (win_t) (a0 - ((a1 * c) >> (NWIDTH-2)));
	}	
}

/* ---------------- Window: Hann ---------------- */
void win_hann (
	win_t out_win[]
	)
{
	const dbl_t a0 = round(0.5 * (pow(2.0, NWIDTH-1)-1.0));
	const dbl_t a1 = round(0.5 * (pow(2.0, NWIDTH-1)-1.0));
	
	win_t s, c;
	
	int i = 0x0;
	for (i = 0; i < NSAMPLES; i++) {
		cordic(i, &c, &s);

		out_win[i] = (win_t) (a0 - ((a1 * c) >> (NWIDTH-2)));
	}	
}

/* ---------------- Window: Blackman-Harris-3 ---------------- */
void win_blackman_harris_3 (
	win_t out_win[]
	)
{
	const double coeA0 = 0.42;
	const double coeA1 = 0.5;
	const double coeA2 = 0.08;

	dbl_t a0 = round(coeA0 * (pow(2.0, NWIDTH-1)-1.0));
	dbl_t a1 = round(coeA1 * (pow(2.0, NWIDTH-1)-1.0));
	dbl_t a2 = round(coeA2 * (pow(2.0, NWIDTH-1)-1.0));
	
	win_t s1, c1, s2, c2;

	dbl_t mlt1, mlt2;	
	
	int i = 0x0;
	for (i = 0; i < NSAMPLES; i++) {
		cordic(i, &c1, &s1);
		cordic(2*i, &c2, &s2);

		mlt1 = (a1 * c1) >> (NWIDTH-2);
		mlt2 = (a2 * c2) >> (NWIDTH-2);
		
		out_win[i] = (win_t) (a0 - mlt1 + mlt2);
	}	
}

/* ---------------- Window: Blackman-Harris-4 ---------------- */
void win_blackman_harris_4 (
	win_t out_win[]
	)
{
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

	const double coeA0 = 0.35875;
	const double coeA1 = 0.48829;
	const double coeA2 = 0.14128;
	const double coeA3 = 0.01168;

	dbl_t a0 = round(coeA0 * (pow(2.0, NWIDTH-1)-1.0));
	dbl_t a1 = round(coeA1 * (pow(2.0, NWIDTH-1)-1.0));
	dbl_t a2 = round(coeA2 * (pow(2.0, NWIDTH-1)-1.0));
	dbl_t a3 = round(coeA3 * (pow(2.0, NWIDTH-1)-1.0));
	
	win_t s1, c1, s2, c2, s3, c3;

	dbl_t mlt1, mlt2, mlt3;

	int i = 0x0;
	for (i = 0; i < NSAMPLES; i++) {
		cordic(1*i, &c1, &s1);
		cordic(2*i, &c2, &s2);
		cordic(3*i, &c3, &s3);

		mlt1 = (a1 * c1) >> (NWIDTH-2);
		mlt2 = (a2 * c2) >> (NWIDTH-2);
		mlt3 = (a3 * c3) >> (NWIDTH-2);
		
		out_win[i] = (win_t) (a0 - mlt1 + mlt2 - mlt3);
	}	
}

/* ---------------- Window: Blackman-Harris-5 ---------------- */
void win_blackman_harris_5 (
	win_t out_win[]
	)
{
	/*
		> Blackman-Harris:
			a0 = 0.35875; 
			a1 = 0.48829; 
			a2 = 0.14128; 
			a3 = 0.01168;
			a4 = 0.01168;
		> Blackman-Harris:
			a0 = 0.3232153788877343;
			a1 = 0.4714921439576260;
			a2 = 0.1755341299601972;
			a3 = 0.0284969901061499;
			a4 = 0.0012613570882927;
		> Flat-top (1):
			a0 = 0.50000;
			a1 = 0.98500;
			a2 = 0.64500;
			a3 = 0.19400;
			a4 = 0.01500;
		> Flat-top (2):
			a0 = 0.215578950; 
			a1 = 0.416631580; 
			a2 = 0.277263158; 
			a3 = 0.083578947;
			a3 = 0.006947368;
	*/	
	
	const double coeA0 = 0.35875;
	const double coeA1 = 0.48829;
	const double coeA2 = 0.14128;
	const double coeA3 = 0.01168;	
	const double coeA4 = 0.01168;	

	dbl_t a0 = round(coeA0 * (pow(2.0, NWIDTH-2)-1.0));
	dbl_t a1 = round(coeA1 * (pow(2.0, NWIDTH-2)-1.0));
	dbl_t a2 = round(coeA2 * (pow(2.0, NWIDTH-2)-1.0));
	dbl_t a3 = round(coeA3 * (pow(2.0, NWIDTH-2)-1.0));
	dbl_t a4 = round(coeA4 * (pow(2.0, NWIDTH-2)-1.0));
	
	win_t s1, c1, s2, c2, s3, c3, s4, c4;

	dbl_t mlt1, mlt2, mlt3, mlt4;	
	
	int i = 0x0;
	for (i = 0; i < NSAMPLES; i++) {
		cordic(1*i, &c1, &s1);
		cordic(2*i, &c2, &s2);
		cordic(3*i, &c3, &s3);
		cordic(4*i, &c3, &s3);

		mlt1 = (a1 * c1) >> (NWIDTH-2);
		mlt2 = (a2 * c2) >> (NWIDTH-2);
		mlt3 = (a3 * c3) >> (NWIDTH-2);
		mlt4 = (a4 * c4) >> (NWIDTH-2);
		
		out_win[i] = (win_t) (a0 - mlt1 + mlt2 - mlt3 + mlt4);
	}	
}

/* ---------------- Window: Blackman-Harris-7 ---------------- */
void win_blackman_harris_7 (
	win_t out_win[]
	)
{
	const double coeA0= 0.271220360585039;
	const double coeA1= 0.433444612327442;
	const double coeA2= 0.218004122892930;
	const double coeA3= 0.065785343295606;
	const double coeA4= 0.010761867305342;
	const double coeA5= 0.000770012710581;
	const double coeA6= 0.000013680883060;

	dbl_t a0 = round(coeA0 * (pow(2.0, NWIDTH-2)-1.0));
	dbl_t a1 = round(coeA1 * (pow(2.0, NWIDTH-2)-1.0));
	dbl_t a2 = round(coeA2 * (pow(2.0, NWIDTH-2)-1.0));
	dbl_t a3 = round(coeA3 * (pow(2.0, NWIDTH-2)-1.0));
	dbl_t a4 = round(coeA4 * (pow(2.0, NWIDTH-2)-1.0));
	dbl_t a5 = round(coeA5 * (pow(2.0, NWIDTH-2)-1.0));
	dbl_t a6 = round(coeA6 * (pow(2.0, NWIDTH-2)-1.0));
	
	win_t s1, c1, s2, c2, s3, c3, s4, c4, s5, c5, s6, c6;

	dbl_t mlt1, mlt2, mlt3, mlt4, mlt5, mlt6;	
	
	int i = 0x0;
	for (i = 0; i < NSAMPLES; i++) {
		cordic(1*i, &c1, &s1);
		cordic(2*i, &c2, &s2);
		cordic(3*i, &c3, &s3);
		cordic(4*i, &c4, &s4);
		cordic(5*i, &c5, &s5);
		cordic(6*i, &c6, &s6);

		mlt1 = (a1 * c1) >> (NWIDTH-2);
		mlt2 = (a2 * c2) >> (NWIDTH-2);
		mlt3 = (a3 * c3) >> (NWIDTH-2);
		mlt4 = (a4 * c4) >> (NWIDTH-2);
		mlt5 = (a5 * c5) >> (NWIDTH-2);
		mlt6 = (a6 * c6) >> (NWIDTH-2);

		out_win[i] = (win_t) (a0 - mlt1 + mlt2 - mlt3 + mlt4 - mlt5 + mlt6);
	}
}

/* ---------------- Window Function ---------------- */
void win_function (
		char win_type,
		win_t out_win[NSAMPLES]
	)
{
	switch (win_type) 
	{
		case 0x1:
			win_hamming(out_win);
			break;
			
		case 0x2:
			win_hann(out_win);
			break;
			
		case 0x3:
			win_blackman_harris_3(out_win);
			break;
			
		case 0x4:
			win_blackman_harris_4(out_win);
			break;
			
		case 0x5:
			win_blackman_harris_5(out_win);
			break;
			
		case 0x7:
			win_blackman_harris_7(out_win);
			break;
	
		default:
			win_empty(out_win);
			break;		
	}
	
}

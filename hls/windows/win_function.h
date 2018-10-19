/*******************************************************************************
--
-- Title       : win_function.h
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

// #include "ap_fixed.h"
#include "ap_int.h"

/* ---- Constants  --- */
#define Wintype "Blackman-Harris-5"

/* ---- Output data width and input phase (counter) width  --- */
#define NPHASE 10
#define NWIDTH 24

#define NSAMPLES (int)pow(2, NPHASE)

/* ---- Define data types for c-functions ---- */
typedef ap_int<NWIDTH> win_t;
typedef ap_int<NPHASE> phi_t;

typedef ap_int<2*NWIDTH+1> dbl_t;
typedef ap_int<2+NWIDTH> dat_t;
typedef ap_uint<2> duo_t;

/* ---- Top level function --- */
void win_function (
	const char win_type,
	phi_t i,	
	win_t* out_win
);


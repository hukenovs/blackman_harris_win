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
#include "ap_cint.h"

/* ---- Constants  --- */
#define Wintype "Blackman-Harris-3"
#define NPHASE 10
#define NWIDTH 16


#define NSAMPLES (int)pow(2, NPHASE)

/* ---- Data types --- */
typedef uint2 duo_t;

typedef uint10 phi_t;
typedef int18 dat_t;
typedef int16 win_t;

typedef int32 dbl_t;


/* ---- Top level function --- */
void win_function (
	char win_type,
	win_t out_win[]
);


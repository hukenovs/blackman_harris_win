# Blackman-Harris windows
Blackman-Harris Window functions (3-, 4-, 5-, 7-term etc.) from 16 to 64M points based only on LUTs and DSP48s FPGA resources. 
Main core for sine and cosine generator - CORDIC. Also for some window functions you can use Taylor series sine generator (1-order Taylor series is a good solution). Project contains Hann, Hamming, Blackman, Flat-top, Nuttal, Blackman–Nuttall, Blackman-Harris w/ N-term windows.

Please use maximum possible data width for correct calculation.  
Note that 1 digital bit equals 6dB of generated signal. For example if you use Blackman-Harris 4-term (-92dB) you should use at least 16 bits plus one sign bit. Total optimal bit width = 17.

License: GNU GPL 3.0.  

### Description:

**Integer** data type and weight constants.  
**Code language** - VHDL.  
**Vendor**: Xilinx, 6/7-series, Ultrascale, Ultrascale+;  
**Target frequency**: up to 400 MHz (tested on Kintex-Ultrascale XCKU040-2).

### Info:

| **Title**         | Universal window functions           |
| -- | -- |
| **Author**        | Alexander Kapitanov                  |
| **Contact**       | sallador@bk.ru                       |
| **Project lang**  | VHDL                                 |
| **Vendor**        | Xilinx: 6/7-series, Ultrascale, US+  |
| **Release Date**  | 20 Sep 2018                          |
| **Version**       | 1.0                                  |

### List of components:

| **Component name**    | Function | Side lobe lvl (dB)    |
| -- | -- | -- |
| **hamming_win**       | Hamming (Hann)            | -43  |       
| **hamming_win**       | Hann                      | -32  |
| **bh_win_3term**      | Blackman                  | -58  |
| **bh_win_3term**      | Blackman-Harris           | -71  |
| **bh_win_4term**      | Nuttall                   | -93  |
| **bh_win_4term**      | Blackman-Harris           | -92  |
| **bh_win_4term**      | Blackman-Nuttall          | -98  |
| **bh_win_5term**      | Flat-top                  | -69  |
| **bh_win_5term**      | Blackman-Harris           | -124 |
| **bh_win_7term**      | Blackman-Harris 7-term    | -180 |

### Example: 7-term Blackman-Harris window coefficients

  * _a0 = 0.27105140069342_
  * _a1 = −0.43329793923448_
  * _a2 = 0.21812299954311_
  * _a3 = −0.06592544638803_
  * _a4 = 0.01081174209837_
  * _a5 = −0.00077658482522_
  * _a6 = 0.00001388721735_

it gives you up to 180 dB side lobe level.

For more information see: https://habr.com/users/capitanov/topics/ 

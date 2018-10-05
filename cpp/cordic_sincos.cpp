#include <stdio.h>        
#include <math.h>

#define _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_DEPRECATE

#define PHASE_WIDTH 14
#define DATA_WIDTH 12

void cordic(int theta, long long *lut, int *s, int *c)
{
	int PRECISION = 1;
	long long lut_angle[DATA_WIDTH - 1];

	for (int i = 0; i < DATA_WIDTH - 1; i++)
	{
		lut_angle[i] = ((lut[i] >> (48 - DATA_WIDTH - PRECISION) & 0xFFFFFFFFFFFF));
	}

	// Gain for output data ~ 1.64676025812107...
	static const long long GAIN48 = 0x26DD3B6A10D8;
	int long long GAIN32 = GAIN48 >> (48 - DATA_WIDTH - 2);

	// Find quadrant 
	int quadrant = theta >> (PHASE_WIDTH - 2);

	long long init_t = theta & (~(0x3 << (PHASE_WIDTH - 2)));

	// Find actual phase 
	long long init_z = 0x0;
	if (PHASE_WIDTH-1 < DATA_WIDTH) {
		init_z = init_t << (DATA_WIDTH - PHASE_WIDTH + PRECISION);
	}
	else {
		init_z = (init_t >> (PHASE_WIDTH - DATA_WIDTH)) << PRECISION;
	}

	// Create array for parallel calculation
	long long x[DATA_WIDTH + 1];
	long long y[DATA_WIDTH + 1];
	long long z[DATA_WIDTH + 1];

	x[0] = GAIN32;
	y[0] = 0x0;
	z[0] = init_z;

	// Core of the CORDIC algorithm
	int k;
	for (k = 0; k < DATA_WIDTH; k++) {

		if (z[k] < 0) {
			x[k+1] = x[k] + (y[k] >> k);
			y[k+1] = y[k] - (x[k] >> k);
		} else {						
			x[k+1] = x[k] - (y[k] >> k);
			y[k+1] = y[k] + (x[k] >> k);
		}
		if (z[k] < 0) {
			z[k+1] = z[k] + lut_angle[k];
		} else {
			z[k+1] = z[k] - lut_angle[k];
		}		
	} 
	long long out_c = (x[DATA_WIDTH] >> 2);
	long long out_s = (y[DATA_WIDTH] >> 2);

	long long dat_c = 0x0;
	long long dat_s = 0x0;

	if (quadrant == 0x0) {
		dat_s = out_s;
		dat_c = out_c;
		
	}
	else if (quadrant == 0x1) {
		dat_s = out_c;
		dat_c = ~out_s;
	}
	else if (quadrant == 0x2) {
		dat_s = ~out_s;
		dat_c = ~out_c;
	}
	else {
		dat_s = ~out_c;
		dat_c = out_s;
	}


	*c = int(dat_c);
	*s = int(dat_s);

}

int main(int argc, char **argv)
{
	// Create 48-bit angle array: [ATAN(2^-i) * (2^32/PI)]
	long long lut_table [48] = {
		0x200000000000, 0x12E4051D9DF3, 0x09FB385B5EE4, 0x051111D41DDE,
		0x028B0D430E59, 0x0145D7E15904, 0x00A2F61E5C28, 0x00517C5511D4,
		0x0028BE5346D1, 0x00145F2EBB31, 0x000A2F980092, 0x000517CC14A8,
		0x00028BE60CE0, 0x000145F306C1, 0x0000A2F9836B, 0x0000517CC1B7,
		0x000028BE60DC, 0x0000145F306E, 0x00000A2F9837, 0x00000517CC1B,
		0x0000028BE60E, 0x00000145F307, 0x000000A2F983, 0x000000517CC2,
		0x00000028BE61, 0x000000145F30, 0x0000000A2F98, 0x0000000517CC,
		0x000000028BE6, 0x0000000145F3, 0x00000000A2FA, 0x00000000517D,
		0x0000000028BE, 0x00000000145F, 0x000000000A30, 0x000000000518,
		0x00000000028C, 0x000000000146, 0x0000000000A3, 0x000000000051,
		0x000000000029, 0x000000000014, 0x00000000000A, 0x000000000005,
		0x000000000003, 0x000000000001, 0x000000000001, 0x000000000000
	};

	unsigned int lut_msb = 0x0;
	unsigned int lut_lsb = 0x0;

	// Printf look-up table array 
	printf("Look-up table array: LUT_ROM := [\n");
	for (int i = 0; i < 48; i++)
	{
		lut_lsb = (lut_table[i] & 0xFFFFFFFF);
		lut_msb = ((lut_table[i] >> 32) & 0xFFFFFFFF);
		printf("  0x%04X%08X", lut_msb, lut_lsb);
		if (((i + 2) % 4) == 1) {
			printf("\n");
		}
	}
	printf("];\n\n");

    int s, c;    
    
	FILE* FT;
	errno_t err = fopen_s(&FT, "..\\math\\coe.dat", "wt");

	printf("Phase = %d, Data = %d\n", PHASE_WIDTH, DATA_WIDTH);

	for (int i = 0; i < pow(2.0, PHASE_WIDTH); i++)
	{
		cordic(i, lut_table, &s, &c);
		fprintf(FT, "%d %d\n", s, c);
		if (i < 50) {
			printf("%08X %08X %d % d\n", s, c, s, c);
		}
	}  
	printf("\n\n");
	fclose(FT);

	/* Use this m-script for testing CORDIC algorithm
	clear all;
	close all;

	DT_CRD = load ("coe.dat");

	X_new(:,1) = DT_CRD(:,1);
	Y_new(:,1) = DT_CRD(:,2);

	Spec_Re = fft(Y_new + 1e-12 * randn(size(Y_new)));
	Spec_Im = fft(X_new + 1e-12 * randn(size(X_new)));
	Spec_Re = Spec_Re .* conj(Spec_Re);
	Spec_Im = Spec_Im .* conj(Spec_Im);

	Spec_Re = fftshift(Spec_Re);
	Spec_Im = fftshift(Spec_Im);

	Sabs_Re = Spec_Re / max(Spec_Re);
	Sabs_Im = Spec_Im / max(Spec_Im);

	Sidl_Re = 10*log10(Sabs_Re);
	Sidl_Im = 10*log10(Sabs_Im);

	figure(1) % Plot loaded data in Time Domain
	subplot(2,1,1)
	plot(X_new, '-', 'LineWidth', 1, 'Color',[1 0 0])
	grid on; hold on; axis tight;
	plot(Y_new, '-', 'LineWidth', 1, 'Color',[0 0 1])
	grid on; hold on; axis tight;
	title(['CORDIC SINE / COSINE:'])

	subplot(2,1,2)
	plot(Sidl_Re, '-', 'LineWidth', 1, 'Color',[1 0 0])
	grid on; hold on; axis ([0, length(Sidl_Re), -160, 0]);
	plot(Sidl_Im, '-', 'LineWidth', 1, 'Color',[0 0 1])
	grid on; hold on; axis ([0, length(Sidl_Re), -160, 0]);
	*/

	return 0;

}
clear all; close all;
clc

n = 12;				    % number of iterations
N = 14;

theta = 0;					% initial angle

%NOUT = 16;
%NPHI = 10;
%Angle(:,1) = round(atan(2.^(-(0:(NOUT-1)))) .* (2^(NPHI-0)/pi));
%
%Angle_Int = int32(Angle);
%Angle_Hex = dec2hex(Angle_Int);
%disp(Angle_Hex);

% Run CORDIC algorith in rotation mode
function [x_out, y_out, angle] = cordic(theta, n, N)
	z = theta*8;
	rot = 0;   % Indicates if a rotation occured. 0: no rotation 1: rotation by -pi 2: rotation by +pi

	if (z > 2^(N-0)/2) && (z <= 2^(N-0))
		z = z - 2^(N-0);
		rot = 1;
	end
	if (z < -2^(N-0)/2) && (z >= -2^(N-0))
		z = z + 2^(N-0);
		rot = 1;
	end


	% Set x to 1 and y to 0
	x = 2^(n-1);
	y = 0;
  
  
	for w = 0:n
    % z

    if z < 0 
      x_next = x + round(y * 2^-w);
      y_next = y - round(x * 2^-w);
      z = z + round((2^(N)*atan(2^-w)/pi));
		else
		  x_next = x - round(y * 2^-w);
		  y_next = y + round(x * 2^-w);
      z = z - round((2^(N)*atan(2^-w)/pi));
		end
		x = x_next;
		y = y_next;
	end
  
	if rot == 0
		x_out = x;
		y_out = y;
	else
		x_out = -x;
		y_out = -y;
		
	end
  
  x_out = round(x_out / 1.6467);
  y_out = round(y_out / 1.6467);
  
  angle = z;
end


for w = 0:n
  Zz(w+1,1) = (2^(N-3)*atan(2^-w)/pi);	 
end

for w = 0:n
  Zx(w+1,1) = round((2^(N) * atan(2^-w)/pi));	 
end
Angle_Int = int32(Zx);
Angle_Hex2 = dec2hex(Angle_Int);


q = 1;
%for theta = -pi : pi/2^(N-3) :pi-pi/2^(N-3)
for theta = -2^(N-3) : 1 : 2^(N-3)-1
	[x_out(q), y_out(q), angle(q)] = cordic(theta, n, N);
	q = q + 1;
end

th(:, 1) = (0 : 2^(N-2)-1);
Id_sin(:,1) = round(2^(n-1) * sin(th(:,1) .* (2*pi) ./ (2^N/4) ) );
Id_cos(:,1) = round(2^(n-1) * cos(th(:,1) .* (2*pi) ./ (2^N/4) ) );

Id_cmps = abs(Id_sin + y_out');
Id_cmpc = abs(Id_cos + x_out');


%x_new = x_out + 1/2^(n) * randn(size(x_out));
%y_new = y_out + 1/2^(n) * randn(size(y_out));
X_new = x_out;
Y_new = y_out;
max(Y_new)
%Win = blackmanharris(length(x_out));
%Win = kaiser(length(x_out), 9); 
%Dat_X = filter2(Win, y_out);
%Dat_Y = filter2(Win, x_out);
Dat_X = X_new + 1/(2^(n)) * randn(size(y_out));
Dat_Y = Y_new + 1/(2^(n)) * randn(size(y_out));

Spec_Re = fft(Dat_X, length(Dat_X)); 
Spec_Im = fft(Dat_Y, length(Dat_X));
Spec_Re = Spec_Re .* conj(Spec_Re);
Spec_Im = Spec_Im .* conj(Spec_Im);

Spec_Re = fftshift(Spec_Re); 
Spec_Im = fftshift(Spec_Im);

Spec_Re = Spec_Re / max(Spec_Re);
Spec_Im = Spec_Im / max(Spec_Im);

Slog_Re = 10*log10(Spec_Re);
Slog_Im = 10*log10(Spec_Im);

figure(1) % Plot loaded data in Freq Domain
  subplot(3,1,1)
  plot(X_new, '-', 'LineWidth', 1, 'Color',[1 0 0])
  grid on; hold on; axis tight; 
  plot(Y_new, '-', 'LineWidth', 1, 'Color',[0 0 1])
  grid on; hold on; axis tight; 
  title(['CORDIC SINE / COSINE:'])

  subplot(3,1,2)
  plot(Slog_Re, '-', 'LineWidth', 1, 'Color',[1 0 0])
  grid on; hold on; axis ([0, length(Slog_Re), -160, 0]); 
  plot(Slog_Im, '-', 'LineWidth', 1, 'Color',[0 0 1])
  grid on; hold on; axis ([0, length(Slog_Re), -160, 0]);
  title(['REAL / IMAG SPECTRUM:'])
  
  subplot(3,1,3)
  plot(Id_cmps, '-', 'LineWidth', 1, 'Color',[1 0 0])
  grid on; hold on; axis ([0, length(Id_cmps), -1, 7]); 
  plot(Id_cmpc, '-', 'LineWidth', 1, 'Color',[0 0 1])
  grid on; hold on; axis ([0, length(Id_cmps), -1, 7]);  
  title(['ABS SIGNAL DIFFERENCE:'])
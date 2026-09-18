%% Guardian Battery ECM Project - Initialization Script (Continuous Version)
clc; clear; close all;

%% 1. Battery Specifications & Initial Conditions
Q_nominal = 50;             % Nominal capacity in Ah[cite: 1]
SOC_0 = 80;                 % Initial State of Charge in %[cite: 1]

%% 2. Thevenin Model Parameters (1RC)
% Converting milli-Ohms to Ohms to match Simulink SI units requirement[cite: 1]
R0 = 0.70 / 1000;           % Series resistance in Ohms[cite: 1]
R1 = 1.60 / 1000;           % R1 in Ohms[cite: 1]
C1 = 17000;                 % C1 in Farads[cite: 1]

% (Optional) Bonus 1: 2RC Extension Parameters[cite: 1]
R2 = 0.35 / 1000;         % R2 in Ohms[cite: 1]
C2 = 5200;                % C2 in Farads[cite: 1]

%% 3. Load Drive Cycle Current Data
% Importing the current profile: Time_s and Current_A[cite: 1]
% Note: Ensure 'Guardian_Battery_DriveCycle_Current.csv' is in the same folder
try
    current_data = readmatrix('Guardian_Battery_DriveCycle_Current.csv');
    time_s = current_data(:, 1);
    current_A = current_data(:, 2);
    
    % Create a timeseries object for the 'From Workspace' block in Simulink
    % This is highly recommended for continuous solvers (ode45 / ode4)
    Current_Input = timeseries(current_A, time_s);
catch
    warning('Drive cycle CSV file not found. Please check the file name and path.');
end

%% 4. Load OCV-SOC Table
% Importing the OCV lookup table[cite: 1]
try
    ocv_data = readmatrix('Guardian_Battery_OCV_SOC_Table.csv');
    SOC_breakpoints = ocv_data(:, 1);  % SOC values (%) for Lookup Table[cite: 1]
    OCV_tableData   = ocv_data(:, 2);  % OCV values (V) for Lookup Table[cite: 1]
catch
    warning('OCV table CSV file not found. Please check the file name and path.');
end

%% 5. Hysteresis Noise Parameters
noise_seed = 23341;         % Noise seed[cite: 1]
noise_power = 1e-4;         % Noise power[cite: 1]
noise_upper_limit = 0.005;  % Saturation upper limit in V[cite: 1]
noise_lower_limit = -0.005; % Saturation lower limit in V[cite: 1]

%% 6. Simulation Setup
% The simulation should stop at the end of the loaded current profile
if exist('time_s', 'var')
    T_end = time_s(end);
else
    T_end = 3600;           % Default to 3600s if file is missing[cite: 1]
end

disp('Workspace is perfectly set up! You can now run the Simulink model.');

%% 7. Run Simulation and Plot Results
disp('Running Simulation...');


out = sim('Main');

disp('Simulation completed successfully! Launching post-processing...');


%% 8. Post-Processing, Plotting & Bonus 3 SOH Check
disp('Plotting results and calculating SOH...');

time_vol = out.Terminal_Voltage_log.time;
voltage  = out.Terminal_Voltage_log.signals.values;
time_soc = out.SOC_CC_log.time;
soc_cc   = out.SOC_CC_log.signals.values;
time_ekf = out.SOC_EKF_log.time;
soc_ekf  = out.SOC_EKF_log.signals.values;

% Figure setup
figure('Name', 'Battery ECM Results - Core + EKF', 'Color', 'k');

ax1 = subplot(2,1,1);
plot(time_vol, voltage, 'b', 'LineWidth', 1.5);
title('Terminal Voltage V(t)', 'Color', 'w');
xlabel('Time (s)', 'Color', 'w'); ylabel('Voltage (V)', 'Color', 'w');
grid on; set(ax1, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'GridColor', 'w', 'MinorGridColor', 'w');

ax2 = subplot(2,1,2);
plot(time_soc, soc_cc, 'r', 'LineWidth', 1.5); hold on;
plot(time_ekf, soc_ekf, 'g--', 'LineWidth', 1.5); hold off;
title('State of Charge: Coulomb Counting vs EKF', 'Color', 'w');
xlabel('Time (s)', 'Color', 'w'); ylabel('SOC (%)', 'Color', 'w');
legend({'Coulomb Counting', 'EKF Estimator'}, 'TextColor', 'w', 'Color', 'none', 'EdgeColor', 'w', 'Location', 'best');
grid on; set(ax2, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'GridColor', 'w', 'MinorGridColor', 'w');

% TLS and SOH Calculation
I_k = current_A; 
V_meas_k = interp1(time_vol, voltage, time_s, 'linear', 'extrap');                     
SOC_CC_k = interp1(time_soc, soc_cc, time_s, 'linear', 'extrap');                      

Ts = 1; 
a1 = exp(-Ts / (R1 * C1));
V1_hat = zeros(length(I_k), 1);
for k = 1:length(I_k)-1
    V1_hat(k+1) = a1 * V1_hat(k) + R1 * (1 - a1) * I_k(k);
end

OCV_used = interp1(SOC_breakpoints, OCV_tableData, SOC_CC_k, 'linear', 'extrap');
y_k = OCV_used(:) - V1_hat(:) - V_meas_k(:);
x_k = I_k(:);

x_centered = x_k - mean(x_k);
y_centered = y_k - mean(y_k);
[U, S, V] = svd([x_centered, y_centered]);

R0_TLS = -V(1,2) / V(2,2);
R0_datasheet = 0.0007; 
SOH_ratio = (R0_datasheet / R0_TLS) * 100;

fprintf('\n======================================\n');
fprintf('Bonus 3 Results (TLS Identification):\n');
fprintf('Estimated R0 (TLS) = %.6f Ohms\n', R0_TLS);
fprintf('State of Health (SOH) = %.2f %%\n', SOH_ratio);
fprintf('======================================\n');




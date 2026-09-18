disp('Plotting results...');

% Extract simulation data
time_vol = out.Terminal_Voltage_log.time;
voltage  = out.Terminal_Voltage_log.signals.values;
time_soc = out.SOC_CC_log.time;
soc_cc   = out.SOC_CC_log.signals.values;
time_ekf = out.SOC_EKF_log.time;
soc_ekf  = out.SOC_EKF_log.signals.values;

%% Plot Results (Dark Theme)
figure('Name', 'Battery ECM Results - Core + EKF', 'Color', 'k');

% Terminal Voltage Subplot
ax1 = subplot(2,1,1);
plot(time_vol, voltage, 'b', 'LineWidth', 1.5);
title('Terminal Voltage V(t)', 'Color', 'w');
xlabel('Time (s)', 'Color', 'w'); ylabel('Voltage (V)', 'Color', 'w');
grid on; set(ax1, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'GridColor', 'w', 'MinorGridColor', 'w');

% SOC Comparison Subplot
ax2 = subplot(2,1,2);
plot(time_soc, soc_cc, 'r', 'LineWidth', 1.5); hold on;
plot(time_ekf, soc_ekf, 'g--', 'LineWidth', 1.5); hold off;
title('State of Charge: Coulomb Counting vs EKF', 'Color', 'w');
xlabel('Time (s)', 'Color', 'w'); ylabel('SOC (%)', 'Color', 'w');
legend({'Coulomb Counting', 'EKF Estimator'}, 'TextColor', 'w', 'Color', 'none', 'EdgeColor', 'w', 'Location', 'best');
grid on; set(ax2, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'GridColor', 'w', 'MinorGridColor', 'w');

% %% Bonus 3: TLS R0 Identification & SOH Check
% disp('Calculating TLS R0 and SOH...');
% 
% % Initialize variables
% I_k = current_A; 
% V_meas_k = interp1(time_vol, voltage, time_s, 'linear', 'extrap');                     
% SOC_CC_k = interp1(time_soc, soc_cc, time_s, 'linear', 'extrap');
% 
% % Calculate open-loop polarization voltage (V1_hat)
% Ts = 1; R1 = 0.0016; C1 = 17000;
% a1 = exp(-Ts / (R1 * C1));
% V1_hat = zeros(length(I_k), 1);
% for k = 1:length(I_k)-1
%     V1_hat(k+1) = a1 * V1_hat(k) + R1 * (1 - a1) * I_k(k);
% end
% 
% % Extract OCV and prepare regression variables
% OCV_used = interp1(SOC_breakpoints, OCV_tableData, SOC_CC_k, 'linear', 'extrap');
% y_k = OCV_used(:) - V1_hat(:) - V_meas_k(:);
% x_k = I_k(:);
% 
% % Apply Total Least Squares (TLS) via SVD
% x_centered = x_k - mean(x_k);
% y_centered = y_k - mean(y_k);
% [U, S, V] = svd([x_centered, y_centered]);
% 
% % Calculate SOH based on estimated internal resistance
% R0_TLS = -V(1,2) / V(2,2);
% R0_datasheet = 0.0007; 
% SOH_ratio = (R0_datasheet / R0_TLS) * 100;
% 
% % Display Results
% fprintf('\n======================================\n');
% fprintf('Bonus 3 Results (TLS Identification):\n');
% fprintf('Estimated R0 (TLS) = %.6f Ohms\n', R0_TLS);
% fprintf('State of Health (SOH) = %.2f %%\n', SOH_ratio);
% fprintf('======================================\n');
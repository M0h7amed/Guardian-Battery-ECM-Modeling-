function [SOC_hat, V1_hat] = EKF_SOC_Estimator(I_meas, V_meas, Ts)
%EKF_SOC_ESTIMATOR  Extended Kalman Filter SOC estimator for the Guardian
%   Battery ECM Project (1RC Thevenin model, LF50K 3.2V/50Ah LFP cell).
%
%   [SOC_hat, V1_hat] = EKF_SOC_Estimator(I_meas, V_meas, Ts)
%
%   Inputs:
%     I_meas  - measured cell current (A), discharge = POSITIVE
%     V_meas  - measured terminal voltage (V)
%     Ts      - sample time (s) -- must match the model's discrete step
%
%   Outputs:
%     SOC_hat - estimated state of charge (%)
%     V1_hat  - estimated RC-branch polarization voltage (V)
%
%   THIS FILE IS PROVIDED AS-IS. Do not modify the cell parameters,
%   OCV breakpoints, or filter structure -- only the noise tuning
%   (Qcov, Rcov) and initial covariance (P0) are meant to be adjusted
%   by students, and only if they can justify the change in their report.
%
%   Usage in Simulink: paste this exact function body into a MATLAB
%   Function block with two inputs (I_meas, V_meas) and two outputs
%   (SOC_hat, V1_hat). Pass Ts as a block mask parameter or hardcode it
%   to match your model's Fixed-Step discrete sample time.
%
%   Guardian Battery ECM Project - Part 2 Addendum
%   Reference cell parameters: see project datasheet, Appendix A.

%#codegen
persistent x P initialized
if isempty(initialized)
    x = [80; 0];            % initial state estimate [SOC(%); V1(V)]
                             % (80% matches the shared drive-cycle test's
                             % given initial condition -- do not change
                             % unless your report explains a cold-start
                             % scenario with an unknown initial SOC)
    P = diag([4, 0.01]);    % initial covariance
    initialized = true;
end

% ---- Fixed cell/model parameters (from project datasheet, Appendix A) ----
Q_nominal_Ah = 50;
R0 = 0.00070;      % ohm  (datasheet AC impedance, 1 kHz, mid-SOC, 25 C)
R1 = 0.00160;      % ohm  (scaled from literature HPPC fit, see Appendix A)
C1 = 17000;        % F
tau1 = R1 * C1;
a = exp(-Ts / tau1);

% ---- OCV-SOC breakpoints -- MUST match Guardian_Battery_OCV_SOC_Table.csv ----
soc_bp = [0 5 10 20 30 40 50 60 70 80 90 95 100];
ocv_bp = [2.50 2.95 3.05 3.15 3.20 3.22 3.24 3.26 3.28 3.30 3.33 3.45 3.65];

% ---- Process/measurement noise tuning ----
% Qcov reflects trust in the process model (SOC integration, V1 dynamics).
% Rcov reflects trust in the voltage measurement (~20 mV sensor noise assumed).
% Students may retune these two lines; document any change and why.
Qcov = diag([1e-3, 1e-6]);
Rcov = 4e-4;

% =====================================================================
% PREDICT
% =====================================================================
SOC_pred = x(1) - (Ts / (Q_nominal_Ah * 3600)) * I_meas * 100;
V1_pred  = a * x(2) + R1 * (1 - a) * I_meas;
x_pred = [SOC_pred; V1_pred];

F = [1, 0; 0, a];
P_pred = F * P * F' + Qcov;

% =====================================================================
% UPDATE
% =====================================================================
OCV_pred  = interp1(soc_bp, ocv_bp, x_pred(1), 'linear', 'extrap');

% Local OCV slope (finite-difference approximation of dOCV/dSOC at the
% predicted operating point) -- this is the nonlinear part of the EKF;
% a standard Kalman filter cannot handle this curved OCV(SOC) relationship.
d = 0.5;
dOCV_dSOC = interp1(soc_bp, ocv_bp, x_pred(1) + d, 'linear', 'extrap') ...
          - interp1(soc_bp, ocv_bp, x_pred(1) - d, 'linear', 'extrap');
dOCV_dSOC = dOCV_dSOC / (2 * d);

H = [dOCV_dSOC, -1];

V_pred = OCV_pred - I_meas * R0 - x_pred(2);
y_resid = V_meas - V_pred;

S = H * P_pred * H' + Rcov;
K = P_pred * H' / S;

x = x_pred + K * y_resid;
P = (eye(2) - K * H) * P_pred;

% Physical bound -- SOC cannot leave [0, 100]%
x(1) = min(max(x(1), 0), 100);

SOC_hat = x(1);
V1_hat  = x(2);

end

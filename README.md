# Guardian Battery ECM Project

Individual Simulink project (Model-Based Design — Module 3): a 2RC Thevenin equivalent-circuit model (ECM) plus State-of-Charge (SOC) estimation for a real, commercially available LFP cell.

**Reference cell:** EVE Energy LF50K, 3.2 V nominal / 50 Ah, prismatic LiFePO4.

Scope is pure signal/estimation logic — no thermal model, no closed-loop control, no PID.

## Architecture

```
Current Input I(t) [CSV]
        │
        ▼
OCV(SOC) Lookup + Hysteresis Noise ──► Terminal Voltage V(t) [Output]
        │                                       ▲
        ▼                                       │
R0 – R1C1 (– R2C2) Thevenin Branch ──────────────┘
        │
        ▼  (shared I(t), V(t) feed)
┌───────────────┬───────────────────┬──────────────────────┐
│ Coulomb        │ EKF SOC Estimator │ TLS R0 Identifier /  │
│ Counting (core)│ (Bonus 2)         │ SOH Check (Bonus 3)  │
└───────────────┴───────────────────┴──────────────────────┘
        │
        ▼
Logged outputs (To Workspace): Terminal_Voltage_log, SOC_CC_log, ...
```

Current sign convention: **positive during discharge, negative during charge/regen** — used consistently throughout the model, dataset, and equations.

## Deliverable tiers

| Tier | Content | Status |
|---|---|---|
| Core (required) | 1RC Thevenin ECM, OCV lookup + hysteresis noise, Coulomb Counting SOC, logging/plotting | ✅ Implemented |
| Bonus 1 | Full 2RC Thevenin ECM (R2, C2 branch) | ✅ Implemented |
| Bonus 2 | EKF SOC estimator (provided `EKF_SOC_Estimator.m`, unmodified) | ✅ Implemented |
| Bonus 3 | TLS-based R0 identification + SOH ratio check | ⬜ Not yet attempted |

## Repository structure

```
├── Guardian_Top.slx                        # Top-level Simulink model
├── init_workspace.m                        # Loads parameters, CSVs, builds timeseries
├── Guardian_Battery_DriveCycle_Current.csv # Shared current profile, 3600 pts @ 1 Hz
├── Guardian_Battery_OCV_SOC_Table.csv      # OCV-SOC lookup table
├── EKF_SOC_Estimator.m                     # Provided EKF implementation (Bonus 2)
└── report/                                 # Project report (spec + results write-up)
```

## Getting started

1. Clone the repo and keep all files in one working folder (paths in the init script are relative).
2. Open MATLAB with Simulink installed.
3. Run `init_workspace.m` to load `Q_nominal`, `SOC_0`, the R/C parameters, the drive-cycle `timeseries`, and the OCV-SOC table into the base workspace.
4. Open `Guardian_Top.slx`.
5. Confirm solver settings: **Fixed-step, discrete (no continuous states), Ts = 1 s**.
6. Run the simulation.
7. Logged signals land in the base workspace as `Structure With Time`; use the provided plotting script/App Designer app to visualize results.

## Model parameters

| Parameter | Value | Notes |
|---|---|---|
| Q_nominal | 50 Ah | Datasheet |
| SOC(0) | 80 % | Fixed initial condition for the shared test |
| SOC operating window | 10–90 % | Clamp/flag boundary |
| R0 | 0.70 mΩ | Datasheet AC impedance |
| R1 / C1 | 1.60 mΩ / 17,000 F | Scaled from HPPC reference data |
| R2 / C2 (Bonus 1) | 0.35 mΩ / 5,200 F | Scaled from HPPC reference data |
| Ts | 1 s | Matches current dataset's native rate |
| Hysteresis noise | power 1e-4, seed 23341, filter [0.02]/[1 -0.98], sat ±0.005 V | Identical for every student |

## Logged outputs

| Variable | Type | Units | Tier |
|---|---|---|---|
| `Terminal_Voltage_log` | double | V | Core |
| `SOC_CC_log` | double | % | Core |
| `SOC_EKF_log` | double | % | Bonus 2 |
| `R0_TLS_estimate` | double | Ω | Bonus 3 |
| `SOH_ratio` | double | % | Bonus 3 |

## Notes / assumptions

- Fixed ambient temperature of 25 °C throughout — no thermal sub-model.
- Every student uses an identical current profile, OCV table, R/C values, and noise seed, so `Terminal_Voltage_log` should match the instructor reference trace within ±15 mV RMS.
- Because Coulomb Counting is open-loop in this simulation environment, `SOC_CC_log` tracks near-exactly with the "true" SOC — this is expected here, not proof of correctness on its own (real current-sensor bias is the motivation for the EKF in Bonus 2).

## Author

Mohamed Nabil Ali — Mechatronics and Robotics Engineering, Ain Shams University

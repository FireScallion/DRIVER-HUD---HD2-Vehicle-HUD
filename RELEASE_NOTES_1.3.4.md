# DRIVER HUD 1.3.4

Performance update for Bastion, HMG FRV and Supply FRV.

- Reduce ownership enumeration during stable native-bound vehicle use.
- Skip redundant tank binding reads.
- Reuse memory protection checks within each native sample and batch selected reads.
- Add optional performance diagnostics (`perf=true`, disabled by default).
- Preserve tank ammunition cadence/logic, FRV health cadence and HUD layout.

Requires Bingus Shared Loader v15 / API 1. Disable old DRIVER HUD versions before installing, then Purge / Deploy. GitHub release includes the bilingual FRV configurator. Nexus distributes the configurator as a separate Optional File.

33 focused offline checks passed. Live game FPS improvement has not been measured here.

# P-Tech Mediora Escort v0.1.0

Independent patient carry, escort and vehicle transfer resource extracted from `Peridoll/NovaPeridoll`, previously packaged inside `ptech_medical v0.5.0`.

## Features
- Medical-role-controlled patient movement, carrying and releasing
- Player and eligible NPC transport, configurable downed-state classifications
- Vehicle seating and removal for supported patient types
- Configurable carry styles (fireman, piggyback, bridal, drag and experimental variants)
- Target interactions and optional test NPC body command (`emsdummy`)
- Server-side target and proximity validation, action state and cleanup on disconnect/stop

## Install
1. Place this folder under server resources.
2. Ensure `qbx_core`, `ox_lib`, `ox_target` and OneSync are running.
3. Edit `config.lua` for EMS jobs, carry types, targeting and supported patient states.
4. Add `ensure ptech_mediora_escort` to server config.
5. Before starting, disable the **escort feature** of legacy `ptech_medical` (or stop that legacy resource if its other features have already migrated). Do not start old `ptech_emsEscort` concurrently. Otherwise multiple carry handlers / target entries may compete.

## API / migrations
- Network event prefix changes from `ems-escort:` to `ptech_mediora_escort:` to prevent legacy collisions.
- Resource exports `getEscorting`, `isEscorted`, `stopEscort` (server), `getEscortingNPCs` remain, but caller references must change to `exports.ptech_mediora_escort`.
- Player state keys like `emsDownDummy` used for compatibility are intentionally preserved.
- No Mediora Core, Medical, or Patients resource is required for base transport.
- All legacy event callers must be inventoried and migrated before switching a production installation.

## Verification
The four ported Lua source files and the standalone manifest were checked for leftover `MedicalModules` references and legacy `ems-escort:` event prefixes. **Lua syntax, mock tests and FiveM in-game behavior have not yet been run for this extracted resource.**

Run in-game tests for two players, death/down states, NPC dummy handling, vehicle entry/exit, OneSync transfer, nearby PD priority (if enabled), death/respawn, cleanup and reconnection before release.

No changes are made to NovaPeridoll.

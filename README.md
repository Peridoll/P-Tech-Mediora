# P-Tech Mediora

Modular medical systems for FiveM roleplay servers, developed under the P-Tech (Peridoll Technorogy) brand.

## Status

Early development. This repository is being prepared for a safe, incremental migration from `Peridoll/NovaPeridoll`.

## Principles

- Each subsystem is an independently deployable FiveM resource by default.
- Cross-module integration is optional unless an explicit dependency is documented.
- A shared `ptech_mediora_core` may be introduced where shared infrastructure is justified.
- Existing production resources are not modified by this repository's development.
- New resource names follow `ptech_mediora_<module>`.

Development work takes place on `develop` and feature branches before review and merge into `main`.

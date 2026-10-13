# P-Tech 共通開発規約 (Draft v0.1)

Scope: all P-Tech product families, not just Mediora.

## Resource design

1. Split resources by coherent capabilities. Default to stand-alone deployment.
2. Name new resources `ptech_<family>_<module>`.
3. Shared family Core resources are permitted when they provide meaningful reusable functionality; do not mandate Core by default.
4. Use optional, checked exports/events to integrate independently deployed modules. Explicitly list required and optional dependencies.
5. State resource-specific framework, inventory, targeting, database and OneSync requirements in each manifest and README.
6. Avoid mutating unrelated production resources or replacing vendor files. Provide installation patches/instructions separately.
7. Put development helpers, archives, fixtures and test runners under `dev/` or `tests/`, outside the runtime manifest.
8. Document versioned APIs, configuration keys, upgrade paths, backwards compatibility and restart-order constraints.
9. Validate all privileged and inventory/money-changing operations server-side. Restrict client data to observations; never treat client injury reports as authoritative for charges or treatment.
10. Require code review and appropriate mock plus in-game tests before production deployment.

## Branch policy

- `main`: reviewed release baseline.
- `develop`: integration branch for work in progress.
- `feature/*`: focused changes, merged by PR.

## Independence test

For every module, describe: which resources must be started, which other P-Tech resources are optional, what features degrade gracefully when integrations are absent, and how to install/uninstall without disrupting other modules.

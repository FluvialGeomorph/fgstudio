# Development scripts

Store maintained automation supporting development workflows here. Scripts should document inputs, outputs, dependencies, and safe execution expectations.

Run from the repository root:

- `bootstrap.R`: initial usethis scaffold; already completed, not a routine launcher.
- `prepare-dev.R`: build the sibling backend into an isolated library, document,
  test and validate context. Re-running updates that development backend snapshot.
- `run-dev.R`: launch the preview on loopback port 8780 with `.local-data` storage.
- `check-package.ps1`: Windows package build/check, with process-local locale
  corrections restored on exit. No remote deployment or global R installation.

# Contributing

Thank you for your interest in contributing to this repository.

This project is intentionally small, personal, and experimental. Contributions are welcome, but the bar for inclusion is clarity, coherence, and alignment with the goals described below.

---

## Scope of Contributions

Contributions may include:

* New shell scripts placed under `bin/`
* Refactors or improvements to existing scripts
* Shell completions (bash, zsh, fish)
* Tests (unit or integration) for existing scripts
* Documentation improvements

Out of scope:

* Large frameworks or heavy abstractions
* Background services or daemons
* Dependencies on non-standard tools without strong justification

---

## Design Principles

When contributing, keep in mind:

* **Explicit over implicit**: scripts should be readable without magic
* **Shell-first**: prefer POSIX shell or Bash; avoid unnecessary external dependencies
* **Topology-aware, not wrapper-heavy**: scripts should express intent, not mirror CLI tools blindly
* **Composable**: scripts should work standalone, but also coexist cleanly with others

If a script becomes complex enough to need deep abstractions, it probably belongs elsewhere.

---

## Repository Layout

A quick reminder of responsibilities:

* `bin/` – user-facing executables
* `lib/` – shared logic sourced by scripts (not executables)
* `completions/` – shell completion definitions
* `init/` – environment bootstrap scripts (PATH, sourcing completions)
* `tests/` – automated tests (unit and integration)

Do not place executable logic directly in `lib/`.

---

## Tests

Tests are encouraged but not mandatory.

Valid test targets include:

* Argument parsing
* State validation
* Output generation (stdout / stderr)
* Dry-run behavior

Anything that depends on a real X server, real devices, or global system state should be clearly marked as **manual** or **integration-only**.

---

## Commit Style

There is no strict commit message format, but commits should:

* Be small and focused
* Explain *why*, not just *what*
* Avoid mixing refactors with behavior changes

Force-pushes are discouraged once a branch is shared.

---

## Philosophy

This repository exists primarily as a personal lab.

The goal is not popularity, stability guarantees, or mass adoption. The goal is to:

* Understand systems more deeply
* Reduce friction in daily workflows
* Share useful ideas, even if imperfect

If that resonates with you, contributions are welcome.

---

## Questions

If something is unclear, open an issue or start a discussion.

Silence usually means the idea needs clarification, not rejection.

# Architecture Decisions

## ADR-000: Build Environment and Package Manager

**Status:** Accepted

**Decision:** Use **opam** as the primary package manager and environment manager
for development and CI.

**Rationale:**
- Dune projects integrate cleanly with opam metadata generated from
  `dune-project`
- Widely adopted across the OCaml ecosystem and easy to reproduce in CI
- Minimal setup for contributors compared to maintaining a separate nix flake

**Consequences:**
- Contributors should install dependencies with opam switches
- A nix development environment is out of scope for MVP
- Formatting is pinned via `.ocamlformat` (rather than a dune extension stanza)
  for compatibility with the current dune toolchain

---

## ADR-001: Networking Runtime — Eio

**Status:** Accepted

**Context:**
We need an I/O runtime for the TCP server. Options considered:
- **Lwt** — mature, callback-based, widely used
- **Eio** — OCaml 5 native, structured concurrency, direct-style

**Decision:** Use **Eio** with a single domain.

**Rationale:**
- Direct-style code is easier to reason about and debug
- OCaml 5's effect handlers are the future of I/O in OCaml
- Single domain keeps the system single-threaded (matching TigerBeetle's
  deterministic execution model)
- `Eio.Time` provides monotonic clocks needed for batch latency windows

**Consequences:**
- Requires OCaml >= 5.1.1
- Libraries must be Eio-compatible

---

## ADR-002: Binary Layout — Cstruct

**Status:** Accepted

**Decision:** Use `cstruct` for all binary encoding/decoding.

**Rationale:**
- Zero-copy reads over bigarray-backed buffers
- Well-tested in the MirageOS ecosystem
- Natural fit for fixed-width, little-endian layouts

---

## ADR-003: Checksums — Digestif

**Status:** Accepted

**Decision:** Use `digestif` for checksum computation (BLAKE3/SHA-256).

**Rationale:**
- Pure OCaml implementation available (no C stubs required)
- Supports multiple hash algorithms; we can start with SHA-256
  and switch to BLAKE3 or xxHash if performance demands it

**Compatibility Note:**
- TigerBeetle uses AEGIS-128L for checksumming.
- This ADR is an MVP implementation choice, not wire-compatible with TigerBeetle checksum semantics.

---

## ADR-004: Testing — Alcotest + QCheck

**Status:** Accepted

**Decision:** Use `alcotest` for unit tests and `qcheck` for property-based tests.

**Rationale:**
- Alcotest provides clear test output and structure
- QCheck integrates with Alcotest for property tests
- Property tests are critical for verifying replay determinism

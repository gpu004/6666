# Step 01 - Repo setup and conventions

Goal: Create a stable OCaml project skeleton with clear conventions before any
logic is written.

## Deliverables
- dune project with core libs and bins
- formatting and linting rules
- CI script for build and tests
- skeleton module layout

## Files to create
- `dune-project`
- `.ocamlformat`
- `src/core/dune`
- `src/codec/dune`
- `src/storage/dune`
- `src/engine/dune`
- `src/server/dune`
- `src/client/dune`
- `bin/dune`
- `test/dune`
- `ci.sh`
- `docs/decisions.md`

## Tasks
1. Create dune project
   - `dune-project`:
     - `(lang dune 3.10)`
     - `(name tigerocaml)`
     - `(using ocamlformat 0.26)`
     - `(package (name tigerocaml))`
     - `(depends (ocaml (>= 5.1.1)))`
   - Decide whether you use opam or nix and document it.

2. Choose runtime for networking
   - **Decision: Eio** (single domain).
   - Record decision in `docs/decisions.md` and list dependencies.

3. Add dependencies (minimal set)
   - `eio`, `eio_main`
   - `cstruct` for binary layout
   - `digestif` or `xxhash` for checksums
   - `qcheck` for property tests
   - `cmdliner` for CLI flags

4. Create dune stanzas per library
   - Example `src/core/dune`:
     - `(library (name tiger_core) (libraries))`
   - Example `src/storage/dune`:
     - `(library (name tiger_storage) (libraries tiger_core cstruct digestif))`

5. Create top level binaries
   - `bin/server.ml` (uses `Eio_main.run`)
   - `bin/cli.ml`
   - Add `bin/dune` with two executables linking to libs.

6. Formatting and linting
   - `.ocamlformat` with a fixed profile (example: `profile=conventional`).
   - Optional: enable `-w @a` in dune to show warnings.

7. CI script
   - `ci.sh` with:
     - `dune build`
     - `dune runtest`
   - Make it executable.

## Checklists
- [ ] `dune build` works on a clean checkout
- [ ] `dune runtest` runs with no tests yet
- [ ] All modules compile with no warnings
- [ ] `docs/decisions.md` contains the networking runtime choice (Eio)

## Notes
TigerBeetle enforces style via engineering rules. In OCaml, encode this as:
- small modules with clear boundaries
- short functions
- strict type constructors and explicit validation

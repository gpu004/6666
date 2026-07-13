# Agent instructions

These instructions apply to the whole repository.

## Project

- Read `README.md` first for the current layout, toolchain, dependencies, and
  Jane Street/OxCaml library choices.
- Treat the pinned TigerBeetle submodule as the upstream behavior reference.
  Do not edit or advance it unless explicitly requested.
- Prefer the documented Jane Street/OxCaml stack, including Base/Core, Async,
  Magic Trace, and the selected OxCaml tools. Keep deterministic core logic
  independent of Async and keep wire/storage representations explicit.
- Keep the README and plan synchronized with material workflow or design
  changes.

## Version control

- Use `jj`, not Git, for version-control operations.
- Inspect `jj status` and `jj diff` before and after changes. Preserve unrelated
  working-copy changes.
- Do not commit, rebase, squash, abandon, move bookmarks, or push unless asked.
- Before committing or pushing, inspect `jj log` and `jj bookmark list`. Use the
  actual bookmark name; never assume `main` or `trunk`.
- After `jj commit`, `@` is normally the new working change and `@-` is the
  commit just created. Do not try to fix this with Git checkout commands.

### Commit and push workflow

When the user explicitly asks to commit and push:

1. Inspect `jj status`, `jj diff`, `jj log`, and `jj bookmark list`.
2. Each commit should represent one coherent change; use explicit paths and
   never include generated artifacts.
3. Move the actual bookmark to `@-`: `jj bookmark move <bookmark> --to @-`.
4. Push it: `jj git push --remote origin --bookmark <bookmark>`.
5. Fetch and verify the remote bookmark matches the expected commit.

## Working style

- Inspect the README, manifests, code, tests, and real execution path before
  changing anything.
- Make the smallest coherent change. Avoid unrelated cleanup, speculative
  abstractions, and unsupported correctness or performance claims.
- Treat review-only requests as read-only until fixes are explicitly requested.
- Match requested artifacts exactly; executable code, fixtures, transcripts,
  benchmark data, and prose are not interchangeable.
- Keep interfaces small, terminology consistent, invariants explicit, and side
  effects at the edges. Comment constraints and non-obvious reasoning only.

## Verification

- Run repository-native formatting, build, tests, and static checks in
  proportion to the change. Derive commands from current docs and manifests.
- Compare compatibility work against the pinned TigerBeetle revision.
- Report exact checks run and any remaining blockers. Do not claim completion
  from static inspection when the real execution path can be tested.

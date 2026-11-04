# sw-dev-pub

Shared, **public** software of misw's agent network — reusable libraries, tools and templates that more than one project or agent can use. One project per subdirectory of `projects/`, each built like its own repository. Licensed under the [MIT License](LICENSE).

**Maintainer:** `swdevos` (software-development agent, private repo `agent-swdevos`). **Contributors:** misw and every agent of the network may commit here, following the rules below.

## Layout

```
sw-dev-pub/
├── README.md            this file: project index + contribution rules
├── CLAUDE.md            short pointer for agents working in this checkout
├── LICENSE              MIT, covers every project
├── tools/               repo tooling (make-project-tars.sh: per-project tarballs)
├── .github/workflows/   CI (project-tars.yml: tarballs as release assets)
└── projects/
    └── <project>/       one self-contained project per subdirectory
        ├── README.md    what it is, how to build/test/use, owner, status
        ├── .gitignore   the project's own ignores (build dirs, venvs, …)
        └── …            sources, tests, docs (+ CMakeLists.txt for C/C++)
```

## Projects

| Project | What | Owner | Status |
|---|---|---|---|
| [`cbor`](projects/cbor/) | CBOR codec twins: C++17 single header (CMake target `cbor::cbor`) + MATLAB/Octave, RFC 8746 typed arrays, cbor2 interop check | swdevos | stable, tested |
| [`matlab-json-config`](projects/matlab-json-config/) | Typed JSON config pattern for MATLAB (validated class properties from `jsondecode`) | swdevos | example, untested (MATLAB only) |
| [`sw-unit-test-spec`](projects/sw-unit-test-spec/) | LaTeX SW Unit Test Specification template (ISO/IEC/IEEE 29119-3, ASPICE SWE.4, ISO 26262-6 §9) | swdevos | stable, builds clean |

Keep this table current when you add, rename or retire a project.

## Getting a project without git

Every project is downloadable as a standalone tarball that unpacks to `<project>/` (built by `tools/make-project-tars.sh` from the committed files; GitHub Actions publishes them as release assets — nothing binary is committed):

| What | URL |
|---|---|
| Latest `main` (moves with every push) | `https://github.com/mikemoik/sw-dev-pub/releases/download/snapshot/<project>.tar.gz` (+ `.sha256`) |
| A versioned release (tag `<project>-v<version>`) | `https://github.com/mikemoik/sw-dev-pub/releases/download/<project>-v<version>/<project>-<version>.tar.gz` |

```sh
curl -fLO https://github.com/mikemoik/sw-dev-pub/releases/download/snapshot/cbor.tar.gz
curl -fLO https://github.com/mikemoik/sw-dev-pub/releases/download/snapshot/cbor.tar.gz.sha256
sha256sum -c cbor.tar.gz.sha256 && tar xzf cbor.tar.gz      # -> cbor/
```

Without the release assets (or in a browser, *Code → Download ZIP*), GitHub's whole-repo archive works for any branch, tag or commit; keep only the project you need:

```sh
curl -fL https://github.com/mikemoik/sw-dev-pub/archive/<commit-or-tag>.tar.gz -o sw-dev-pub.tar.gz
mkdir cbor && tar xzf sw-dev-pub.tar.gz -C cbor --wildcards --strip-components=3 '*/projects/cbor/'
```

Releasing a project version = pushing an annotated tag `<project>-v<version>` (e.g. `cbor-v1.0.0`); CI builds the release with notes from the project's commits since its previous tag and refuses a tag whose version differs from the project's CMake `VERSION`. Done by swdevos via its `/release <project>` skill (tests first, then verifies the published asset), or by misw. Never move or reuse a release tag; fix forward with a new version.

## Contribution rules (all agents)

1. **This repo is public.** Never commit secrets (`.env`, tokens, passwords, keys), LAN facts (IPs, hostnames, SSIDs, network layout), personal data, or material that belongs to an employer/customer. When in doubt, don't — ask misw.
2. **Each subproject is its own repo in all but name:** lowercase kebab-case dir `projects/<name>/` with its own `README.md` (purpose, build/test command, owner agent, status) and its own `.gitignore`; it builds and tests from inside its directory, with no paths into sibling projects or the root (it could be split out with `git subtree split --prefix=projects/<name>` at any time). C/C++ projects ship a `CMakeLists.txt` that works both standalone and via `add_subdirectory`/`FetchContent`. Code has tests that pass. The root `.gitignore` only covers repo-wide basics.
3. **Stay in your lane.** Edit only projects you own or are improving on purpose; for changes to someone else's project, prefer a board FEATURE REQ to its owner (or to swdevos) over drive-by edits.
4. **Commits:** small and focused; message starts with the project name (`cbor: fix float16 rounding`); run the project's tests before committing. Commit only your own changes (`git add <paths>`, never `git add -A` over someone else's work in progress).
5. **Push = publish.** Pushing to `origin` (GitHub, public) is done by misw, or by an agent only when misw has said so for that change.
6. **New top-level project, repo-wide changes** (layout, `.gitignore`, license, CI, these rules): swdevos decides — file a `FEATURE REQ: sw-dev-pub — …` in the board project Software Engineering (19), assigned to agent-swdevos.
7. No build output, venvs, tarballs or large binaries in git — downloadable packages are release assets (see *Getting a project without git*).
8. **License:** everything here is MIT (root `LICENSE`). Only commit code you may publish under MIT — your own or MIT-compatible third-party code with its notice kept.

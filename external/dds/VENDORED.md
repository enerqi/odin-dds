# Vendored DDS source

This directory is a partial copy of the DDS double-dummy solver. Every file kept is **byte-for-byte
upstream** — nothing is patched. Files are only ever dropped, never edited.

| | |
| --- | --- |
| Upstream | <https://github.com/dds-bridge/dds> |
| Commit | `7219c956f4ed9a9f8d1585e9a1a2c57465745ac5` (`7219c95`, `v2.8.2-206-g7219c95`) |
| Version | 2.9.1 code (`DDS_VERSION` upstream is still `20900`; never bumped) |
| Vendored on | 2026-07-29 |
| License | Apache 2.0 — see [`LICENSE`](./LICENSE) |

No source file is patched. All build configuration lives outside this directory, in
[`../../src/build.cmd`](../../src/build.cmd) (Windows) and [`../../src/Makefile`](../../src/Makefile)
(Linux/macOS), which compile `src/*.cpp` into a static archive staged in `../../lib`.

## Why vendored rather than a submodule

The bindings pin one upstream commit and never track a moving branch, so a submodule bought nothing but
a recursive-clone footgun and a dependency on GitHub still serving that commit. Committing the source
outright means `just build-lib` works offline, and the exact code behind the shipped `lib/dds.lib` and
`lib/dds.a` cannot disappear or drift.

## What is here

| Included | Size | What it is |
| -------- | ---- | ---------- |
| `include/` | 20K | Public ABI — `dll.h` (what the Odin bindings are generated from) and `portab.h` |
| `src/` | 565K | The solver itself; the two build scripts compile these 26 `.cpp` files |
| `doc/` | 4.7M | Upstream's own documentation, kept so the reference survives independently of GitHub |
| `LICENSE` | 12K | Apache 2.0 |

`doc/dll-description.md` is the canonical interface reference and the one worth reading. The rest of
`doc/` is the same handful of documents in redundant formats (`.pdf`/`.rtf`/`.htm`/`.mht`/`.docx`) —
`DLL-dds_x.*` is an older rendering of that same interface doc. It is kept whole rather than curated —
the redundancy is cheap and picking a winning format is a judgement that ages badly.

> The text renderings (`.rtf`, `.htm`, `.mht`, `.html`, `.md`, and the `.xml` under `DLL-dds_x-Dateien/`)
> are stored with LF endings, per this repo's `.gitattributes` `* text=auto eol=lf`. The PDFs, the
> `.docx`, `themedata.thmx` and `Par Calculation.rtf` are detected as binary and stored byte-for-byte.

## What was excluded

The rest of the upstream tree — ~61M — is not needed to build or use the bindings:

| Excluded | Size | What it is |
| -------- | ---- | ---------- |
| `hands/` | 51M | Reference deal/result fixtures for `dtest` |
| `build/` | 9.7M | Upstream's checked-in build outputs |
| `examples/`, `test/` | 295K | Upstream C++ sample programs and the `dtest` harness |
| `src/Makefiles/` | 60K | Upstream's own makefiles — superseded by `../../src` (see below) |
| `ChangeLog`, `INSTALL`, `README.md` | 40K | Upstream project docs |

`src/Makefiles/` held upstream's nine platform makefiles (`Makefile_linux_static`, `Makefile_Visual`, …)
plus their generated dependency lists. This project does not use them: [`../../src/build.cmd`](../../src/build.cmd)
and [`../../src/Makefile`](../../src/Makefile) are the build, with their own compiler flags, threading
selection, and static-only output. Keeping upstream's copies would just offer a second, wrong way to build.
Dropping them is the one place this tree's *file list* diverges from upstream — no file content does.

The 2.9.1 pin was validated against upstream's own `dtest` (0 differences across solve/calc/play/par)
before the test tree was dropped.

## Updating

There is no submodule to `git submodule update`, and no subtree merge. Re-vendor by hand so the diff
against the code actually being compiled is reviewable:

```sh
git clone --filter=blob:none --no-checkout --sparse https://github.com/dds-bridge/dds.git /tmp/dds
git -C /tmp/dds sparse-checkout set include src doc
git -C /tmp/dds checkout <new-rev>
rm -rf external/dds/include external/dds/src external/dds/doc
cp -r /tmp/dds/include /tmp/dds/src /tmp/dds/doc /tmp/dds/LICENSE external/dds/
rm -rf external/dds/src/Makefiles          # we build with ../../src, not upstream's makefiles
```

Then update the commit/version rows above, rerun `just build-lib` and `just bindgen`, and check the
[version table](../../README.md#version) in the top-level README.

Apache 2.0 requires that modified files carry prominent notices. If DDS is ever patched locally, record
each change here and mark the file, or the "verbatim, unmodified" claim at the top stops being true.

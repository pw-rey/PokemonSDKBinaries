# macOS ARM64 runtime

This build targets ordinary **arm64** and **macOS 11.0**, with **Ruby 3.4.10**.
It uses the Linux release's component revisions. It does not use `-march=native`,
arm64e, or Homebrew runtime dylibs. Apple's frameworks, libSystem, libc++,
libiconv, libffi and zlib remain system-provided. Other dependencies are built
from pinned sources, except FMOD's official runtime (its ARM64 slice also
targets macOS 11.0).

`dist/MacOS-arm64.7z` contains `ruby-dist/`. Like the legacy package it provides
`bin/ruby`, `lib/LiteRGSS.bundle`, `lib/RubyFmod.bundle`, and sourceable `setup.sh`.
It additionally includes `SFMLAudio.bundle`, `SFEMovie.bundle`, FFmpeg 6.0 and
subtitle support. Native extensions for legacy Ruby 3.2 must be rebuilt for 3.4.

```bash
source /path/to/ruby-dist/setup.sh
ruby /path/to/game/Game.rb
```

Source this script from Bash. It resolves its own directory, selects bundled
Ruby, sets UTF-8 defaults and excludes host gem paths. Ruby uses
`--enable-load-relative`; native dependencies use `@loader_path`.
No `DYLD_LIBRARY_PATH` is needed. The legacy `clean_load_path` require remains.

## Local build

Use an Apple Silicon Mac with Xcode or Command Line Tools. Install build tools
`cmake`, `ninja`, `pkgconf` and `sevenzip`; they are not shipped. From the repo:

```bash
bash .github/scripts/fetch-sources.sh config/macos-arm64.conf
export FMOD_SDK_DIR=/absolute/path/to/FMOD-core
bash macos/arm64/build.sh
ARCHIVE_PATH="$PWD/dist/MacOS-arm64.7z" bash macos/arm64/assemble-release.sh
RELEASE_DIR="$PWD/generated/MacOS-arm64/ruby-dist" bash macos/arm64/verify-release.sh
```

`FMOD_SDK_DIR` must contain `inc/fmod_common.h` and `lib/libfmod.dylib`, version
2.02.20. Alternatively, run `bash macos/arm64/extract-fmod.sh /path/to/fmodstudioapi20220mac-installer.dmg`
and use the printed Core directory. Extraction mounts the DMG read-only and
unpacks package payloads without running the installer.

Build output is in `generated/macos-arm64/`. Local dependency stamps allow
resuming failed later stages. After changing the compiler, target, configuration
or pins, remove that generated directory and use fresh source checkouts.
CI uses fresh runners, without shared build caches.

Individual stages: `build.sh dependencies`, `build.sh ruby`, `build.sh components`.
`build.sh` only compiles. Assembly: `bash macos/arm64/assemble-release.sh`.
Validation: `bash macos/arm64/verify-release.sh`. As on Linux, assembly requires
an empty `OUTPUT_DIR`; omit `ARCHIVE_PATH` to assemble without archiving.
Set `JOBS` to limit compilation concurrency; set `SEVENZIP` to an absolute `7zz`
path when necessary. Native validation needs WindowServer/OpenGL and CoreAudio
access; restricted execution sandboxes may block these services.

## New files and their purpose

Paths are relative to this repository. Existing upstream `extconf.rb`, Rakefiles
and CMake files are retained. There are no replacement extension definitions or
CMake projects.

| File | Responsibility |
| --- | --- |
| `config/macos-arm64.conf` | Component pins, Ruby/FMOD versions and deployment target. |
| `config/macos-arm64-sources.lock` | Source archive URLs and SHA-256 hashes. |
| `.github/scripts/fetch-sources.sh` | Shared Linux/macOS pinned component fetching; also verifies macOS dependency archives. Replaces macOS `fetch.sh` and inline Linux checkout code. |
| `.github/scripts/prepare-sfemovie-ruby.sh` | Shared Linux/macOS preparation of disposable Ruby binding checkouts: links matching pinned LiteRGSS/LiteCGSS headers. |
| `tests/sfemovie-texture.rb` | Generates an uncompressed green AVI and reference PNG; checks actual movie pixels, Bitmap subclasses, snapshots and disposed/uninitialized objects. Called by macOS smoke verification. |
| `macos/arm64/build.sh` | Runs upstream configure/CMake/extconf builds with ARM64/macOS 11 flags; isolates dependencies; builds Ruby, SFML and LiteCGSS once. |
| `macos/arm64/sfemovie-channel-layout.patch` | Corrects two FFmpeg resampler option names in the temporary checkout; details below. |
| `macos/arm64/assemble-release.sh` | Shell file assembly and optional archiving, matching Linux's entry point and environment-variable interface. Replaces assembly in `package.py`. |
| `macos/arm64/mach_o.py` | Binary relocation, signing, symlink normalization and portability audits extracted from `package.py`; no file assembly or source discovery. |
| `macos/arm64/setup.sh` | Sourceable legacy launcher interface for relocated Ruby 3.4. |
| `macos/arm64/clean_load_path.rb` | Legacy require target; Ruby and setup.sh now handle path isolation. |
| `macos/arm64/verify-release.sh` | Renamed from `verify.sh` to match Linux; audits and relocates the package to a path containing spaces and runs tests with a clean environment. |
| `macos/arm64/smoke.rb` | macOS adapter for the packaged shared functional suite in `tests/runtime-functional.rb`; coverage is documented in `tests/README.md`. |
| `macos/arm64/archive-release.sh` | Renamed from `archive.sh`; assembler helper that creates `.7z`, tests its extracted contents and writes the SHA-256 sidecar. |
| `macos/arm64/extract-fmod.sh` | Unpacks an authorized FMOD installer without a system-wide installation. |
| `.github/workflows/build-macos-arm64.yml` | Builds on ARM64 macOS 14, verifies the archive on fresh macOS 15/26 runners and uploads runtime artifacts. |
| `.github/workflows/build-linux-x86_64.yml` | Linux build extracted from the old combined workflow, using the same reusable workflow structure as macOS. |
| `.github/workflows/release.yml` | Shared protected-tag entry point and publisher; replaces `release-linux-x86_64.yml`. |
| `docker/linux-gnu/extract-fmod.sh` | Linux SDK extraction moved out of inline YAML, matching the macOS shell entry point. |
| `macos/arm64/README.md` | Reproduction, compatibility, validation and file rationale. |

The existing downloader gains a macOS entry. The existing protected-tag release
workflow calls the macOS workflow and waits for both platforms before publishing
both archives. Read-only build permissions and SHA-pinned actions remain.
There is no additional tag trigger or independent macOS publisher.

## Upstream build adjustments

FMOD's extracted `FMOD Programmers API` path contains spaces. The build escapes
the include/library paths inside the flags passed to the existing `extconf.rb`,
so both mkmf's probes and the generated Makefile preserve them. Quoting only
the outer command-line argument is insufficient. Failed FMOD configuration
prints `mkmf.log` before CI removes the temporary SDK.

1. **LiteRGSS Clang flag:** upstream extconf adds
   `-frelaxed-template-template-args`. Apple Clang 21 rejects this removed flag.
   The build probes support and, only when necessary, omits this flag using a
   `make CXXFLAGS=...` override. No source file is edited.
2. **sfeMovie framework:** the original CMake framework target is built normally.
   Its Mach-O image is staged as `libsfeMovie.dylib` with an updated install name,
   allowing the existing Ruby binding to link with `-lsfeMovie`.
3. **FFmpeg resampler correction:** sfeMovie passes `AVChannelLayout` structures
   to `av_opt_set_chlayout` using `in_channel_layout`/`out_channel_layout`. In
   FFmpeg 6.0 these names identify deprecated integer mask fields. The setter
   writes to the wrong fields and corrupts the resampler configuration. The
   patch changes the names to `in_chlayout`/`out_chlayout`. Actual audio loading
   reproduced the failure; simply loading the extension did not. Submit this
   upstream and replace the patch with a commit pin once merged. The Linux
   builder is not changed by this macOS patch.
4. **SFEMovie texture ABI:** upstream commit `5f42b7b3dabc641d73c6fe533f08d9d69e3e4377` includes the TypedData access, disposed-object checks, snapshot initialization and header configuration fixes. All platforms pin this commit; no local texture patch is needed. The preparation helper still links matching LiteCGSS headers, and builders supply the LiteRGSS include directory.

Ruby configure options disable DTrace/JIT build dependencies and optional native
dbm/gdbm/readline extensions; Ruby 3.4's Reline is still bundled. Font rendering
uses source-built FreeType/HarfBuzz/FriBidi/libass with Apple's CoreText provider.
FFmpeg uses the Linux feature selection with generic ARM64 code and does not
enable GPL/nonfree codecs.

## Validation and limits

Every Mach-O, including native standard-library and gem extensions, is checked:
only ARM64, minimum OS at most 11.0, valid ad-hoc signature, private or system
dependencies only, and no escaping/broken symlinks. The extracted archive is
checked again. An explicit smoke-test completion marker catches premature exits.
Library symlink chains are flattened to direct relative links while retaining
all aliases, so 7-Zip's safe extraction accepts the archive.

The movie regression reproduced `expected Data` with the previous macOS bundle
and passed with the corrected Ruby 3.4.10 bundle. It compares exported texture
pixels with a reference image, including a Bitmap subclass like PSDK's Texture.
The earlier audio-only movie smoke did not exercise this interface. The shared
upstream fix is pinned for Linux builds too, but its Linux execution still needs CI
validation; the graphical regression currently runs in macOS verification.

The deployment target is a compatibility constraint, not proof of testing on
every OS/hardware model. Hosted CI covers macOS 14, 15 and 26. macOS 11/12/13
machines and a complete Pokémon SDK game still need testing before claiming
coverage of every Apple Silicon macOS release.

Signing is ad-hoc, required after modifying ARM64 binaries. Developer ID signing
and notarization belong to the distributable game/application and are not
performed here. Only `libfmod.dylib` is packaged from FMOD; SDK files remain
ignored build inputs. The repository's existing FMOD licensing conditions apply.

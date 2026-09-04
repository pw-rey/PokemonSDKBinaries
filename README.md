# Pokémon SDK Binaries

Prebuilt runtime packages for projects made with [Pokémon SDK](https://gitlab.com/pokemonsdk). This repository builds, validates, and publishes the native libraries required by the SDK; it is not the Pokémon SDK source repository itself.

## Platform support

| Platform | Architecture | Status |
| --- | --- | --- |
| Linux | x86-64 | Available through tagged releases |
| Windows | — | Planned |
| macOS | — | Planned |

The Linux package is built for a **glibc 2.28** baseline. It has been validated on Ubuntu and Fedora-family distributions. The runtime expects a typical desktop graphics and audio stack: the system OpenGL driver, X11/XWayland libraries, and an ALSA-compatible audio stack.

## Download and use

Download `Linux-x86-64.7z` from the [latest release](../../releases/latest), then extract it. The archive contains one top-level directory named `ruby-dist/`:

```text
ruby-dist/
├── bin/
├── lib/
├── setup.sh
└── BUILD-INFO
```

Place `ruby-dist/` where your Pokémon SDK project expects its embedded Ruby runtime. Before starting the game, load the environment prepared by `setup.sh`:

```bash
source /path/to/ruby-dist/setup.sh
```

`setup.sh` configures the bundled Ruby, native-library search path, and Ruby load path for the current shell. `BUILD-INFO` records the component revisions used for that package.

## Included Linux runtime

The Linux x86-64 package contains:

- LiteRGSS2 and LiteCGSS
- Embedded Ruby
- SFML and SFMLAudio
- RubyFMOD and FMOD Core 2.02
- sfeMovie, FFmpeg 6.0, and the `SFEMovie` Ruby binding

FFmpeg includes the `png` and `mov_text` decoders required by the SDK's movie support. Graphics drivers, X11 integration, ALSA, and the system C++ runtime remain host-provided so they can match the target distribution and desktop driver stack.

## Releases

Releases are produced by GitHub Actions when a protected tag beginning with `v` is pushed:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow checks out immutable component revisions, builds the runtime in a `manylinux_2_28` environment, assembles `Linux-x86-64.7z`, and smoke-tests the completed payload in a separate glibc 2.28 container before publishing it.

Normal branch pushes and pull requests do not run the release workflow.

## Building locally

The workflow is the supported release path. For local CI-style testing, install Docker and [act](https://github.com/nektos/act), configure the FMOD credentials described below, then run the Linux job from this repository:

```bash
act push \
  -W .github/workflows/release-linux-x86_64.yml \
  -j linux_x86_64 \
  -e ../.act/tag-push.json \
  -P ubuntu-24.04=ghcr.io/catthehacker/ubuntu:act-24.04 \
  --bind \
  -s FMOD_USER \
  -s FMOD_PASSWORD
```

`--bind` is required for this workflow because Docker build containers need access to component source directories created by `act`. Artifacts created by `act` are local test output; GitHub Releases are published only by GitHub Actions.

To exercise the release job locally without creating or changing a GitHub Release, add:

```bash
--env RELEASE_DRY_RUN=true
```

## Maintainer notes

### Required GitHub Actions secrets

Create these **repository Actions secrets** under **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
| --- | --- |
| `FMOD_USER` | FMOD account username or email authorized to download the SDK |
| `FMOD_PASSWORD` | Password for that FMOD account |

The workflow uses them only in the trusted tag workflow to obtain the Linux FMOD SDK. Never commit them, add them as Actions variables, or expose them to pull-request workflows. A dedicated FMOD account with the minimum required download entitlement is recommended.

### Release security

Protect the `v*` tag pattern with a GitHub ruleset and allow only maintainers or the release team to create, update, or delete matching tags. This is essential because a tag push authorizes the workflow to access the FMOD secrets and publish a release.

The workflow has no branch-push, pull-request, or manual-dispatch trigger. It pins component source commits and GitHub Actions by revision, restricts default permissions to read-only, and grants release-write permission only to the final publication job.

### FMOD runtime and licensing

The Linux release contains only the FMOD runtime shared library (`libfmod.so`); a future Windows release will likewise contain only the required FMOD `.dll` runtime. It does **not** publish FMOD SDK headers, static libraries, import libraries, or other development files.

That separation alone does not automatically grant redistribution rights. FMOD is proprietary software, and the [FMOD EULA](https://www.fmod.com/legal) requires the FMOD Engine to be integrated and redistributed in a qualifying software application/product, subject to the licence tier and its conditions. In particular, the EULA's listed licence grants restrict distribution as part of a game engine or tool set. Maintainers and downstream projects must confirm that their intended distribution is covered by the applicable FMOD licence before publishing or redistributing a package.

The authenticated CI download approach was informed by the open-source [utopia-rise/fmod-gdextension](https://github.com/utopia-rise/fmod-gdextension) project. Thank you to its contributors for publishing a useful reference for downloading the FMOD SDK in CI.

## Contributing

Changes to a release component should be merged upstream first. Then update its immutable repository URL and commit pin in [config/linux-x86_64.conf](config/linux-x86_64.conf), run the Linux workflow with `act`, and publish a new protected `v*` tag after review.

## License

The build and release tooling in this repository is available under the [MIT License](LICENSE). Bundled third-party runtime libraries remain subject to their respective licences.

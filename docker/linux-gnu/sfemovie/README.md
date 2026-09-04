# Portable Linux sfeMovie build

This build produces the native `libsfeMovie` library and its required FFmpeg
6.0 shared-library closure for `x86_64-linux-gnu` with a glibc 2.28 baseline.
It deliberately does not build or package a Ruby extension. It reuses the
already-built LiteRGSS image and its SFML 2.6.2 installation, avoiding a
second SFML build and ensuring both components use the same SFML ABI.

The FFmpeg source archive is SHA-256 pinned in the Dockerfile. Its
configuration builds shared libraries without external autodetected
dependencies or network support; this keeps the runtime closure predictable.

Build LiteRGSS first, then run from this repository:

```sh
RUBY_VERSION=3.4.10 \
SOURCE_DIR=/path/to/sfeMovie \
docker/linux-gnu/sfemovie/build.sh
```

Set `OUTPUT_DIR` to choose an empty output directory. The result contains the
native sfeMovie library, the FFmpeg libraries it uses, SFML, and any required
non-glibc runtime dependencies. Host-provided graphics drivers, ALSA, and the
C++ runtime are intentionally not bundled.

#!/usr/bin/env bash

set -euo pipefail

: "${RELEASE_DIR:?Set RELEASE_DIR to the assembled Linux release payload.}"

readonly release_dir="$(cd "${RELEASE_DIR}" && pwd)"
readonly manylinux_image="quay.io/pypa/manylinux_2_28_x86_64@sha256:4dc41da7df20400310c80d162a2fe2d2c2f3d9734d8dec20f6b9843711618deb"

docker run --rm --entrypoint /bin/bash \
  -v "${release_dir}:/release:ro" \
  "${manylinux_image}" \
  -ceu '
    # These are intentionally host-provided by the release: they select the
    # target desktop X11/GL driver and ALSA device stack.
    dnf install -y --setopt=install_weak_deps=False \
      alsa-lib libX11 libXcursor libXi libXrandr libstdc++ mesa-libGL
    export LD_LIBRARY_PATH=/release/lib
    ruby_library_dir=$(find /release/lib/ruby -mindepth 1 -maxdepth 1 -type d -name "[0-9]*" -print -quit)
    ruby_arch_library_dir=$(find "$ruby_library_dir" -mindepth 1 -maxdepth 1 -type d -name "*-linux*" -print -quit)
    /release/bin/ruby -I/release/lib -I"$ruby_library_dir" -I"$ruby_arch_library_dir" -e '\''
      require "LiteRGSS"
      require "SFMLAudio"
      require "RubyFmod"
      require "SFEMovie"
      require "fiddle/import"
      Fiddle.dlopen(Dir["/release/lib/libsfeMovie.so.*"].first)
      abort "Unexpected FMOD API version" unless FMOD::VERSION == 0x00020220
      abort "SFEMovie extension did not define SFE::Movie" unless defined?(SFE::Movie)
      module AVCodec
        extend Fiddle::Importer
        dlload "/release/lib/libavcodec.so.60"
        extern "void *avcodec_find_decoder_by_name(const char *)"
      end
      %w[png mov_text].each do |decoder|
        abort "Missing required FFmpeg decoder: #{decoder}" if AVCodec.avcodec_find_decoder_by_name(decoder).to_i == 0
      end
      puts "All staged Linux runtime components load on glibc 2.28"
    '\''
  '

ARG LITERGSS_IMAGE=litergss-linux-gnu:3.4.10
FROM ${LITERGSS_IMAGE}

ARG FFMPEG_VERSION=6.0
ARG FFMPEG_SHA256=57be87c22d9b49c112b6d24bc67d42508660e6b718b3db89c44e47e289137082

RUN dnf install -y --setopt=install_weak_deps=False \
      xz \
      libass-devel harfbuzz-devel fribidi-devel fontconfig-devel \
 && dnf clean all

RUN curl -fsSL "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" -o /tmp/ffmpeg.tar.xz \
 && echo "${FFMPEG_SHA256}  /tmp/ffmpeg.tar.xz" | sha256sum -c - \
 && mkdir /tmp/ffmpeg \
 && tar -xJf /tmp/ffmpeg.tar.xz --strip-components=1 -C /tmp/ffmpeg \
 && cd /tmp/ffmpeg \
 && CC=/usr/bin/gcc CXX=/usr/bin/g++ ./configure \
      --prefix=/opt/sfemovie/ffmpeg \
      --enable-shared \
      --disable-static \
      --disable-programs \
      --disable-doc \
      --disable-network \
      --disable-autodetect \
      --disable-avfilter \
      --disable-postproc \
      --disable-inline-asm \
      --disable-x86asm \
      --enable-zlib \
      --enable-decoder=png \
      --enable-decoder=movtext \
 && make -j"$(nproc)" \
 && make install \
 && rm -rf /tmp/ffmpeg /tmp/ffmpeg.tar.xz

COPY docker/linux-gnu/sfemovie/entrypoint.sh /usr/local/bin/sfemovie-entrypoint.sh
COPY docker/linux-gnu/sfemovie/quiet-attached-pictures.patch /opt/sfemovie/quiet-attached-pictures.patch
COPY macos/arm64/sfemovie-channel-layout.patch /opt/sfemovie/sfemovie-channel-layout.patch
RUN chmod +x /usr/local/bin/sfemovie-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/sfemovie-entrypoint.sh"]

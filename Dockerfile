# syntax=docker/dockerfile:labs
FROM fedora:39

#Set build type : release, debug
ENV BUILD_TYPE=debug

# App versions - change settings here
ENV LIBJPEG_TURBO_VERSION=1.5.3
ENV LIBPNG_VERSION=1.6.37
ENV FREETYPE2_VERSION=2.10.4
ENV OPENAL_VERSION=1.21.1
ENV BOOST_VERSION=1.83.0
ENV LIBICU_VERSION=70-1
ENV FFMPEG_VERSION=4.4
ENV SDL2_VERSION=2.0.22
ENV BULLET_VERSION=3.17
ENV MYGUI_VERSION=3.4.3
ENV GL4ES_VERSION=1.1.4
ENV OSG_VERSION=69cfecebfb6dc703b42e8de39eed750a84a87489
ENV LZ4_VERSION=1.9.3
ENV LUAJIT_VERSION=2.1.ROLLING
ENV OPENMW_VERSION=19a6fd4e1be0b9928940a575f00d31b5af76beb5
ENV NDK_VERSION=26.1.10909125
ENV SDK_CMDLINE_TOOLS=10406996_latest
ENV PLATFORM_TOOLS_VERSION=29.0.0
ENV JAVA_VERSION=17

# Android API Settings
ENV API=21

# Global C, CXX and LDFLAGS
ENV CFLAGS="-fPIC -O3"
ENV CXXFLAGS="-fPIC -frtti -fexceptions -O3"
ENV LDFLAGS="-fPIC -Wl,--undefined-version"

RUN dnf install -y copr-cli dnf-plugins-core && dnf copr enable -y dturner/OpenMW-Deps
RUN dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    && dnf install -y xz unshield bzip2 unshield-devel mygui mygui-devel unzip openCOLLADA clang OpenSceneGraph-OMW recastnavigation bullet redhat-lsb-core doxygen openal-devel SDL2-devel qt5-qtbase-devel nano git boost-devel java-$JAVA_VERSION-openjdk\
    ffmpeg-devel ffmpeg-libs gcc-c++ tinyxml-devel cmake lz4-devel zlib-devel freetype-devel luajit-devel libXt-devel

ENV JAVA_HOME='/usr/lib/jvm/java-17-openjdk-17.0.9.0.9-3.fc39.x86_64'

RUN wget https://dl.google.com/android/repository/commandlinetools-linux-$SDK_CMDLINE_TOOLS.zip && unzip commandlinetools-linux-$SDK_CMDLINE_TOOLS.zip && mkdir -p ~/Android/cmdline-tools/ && mv cmdline-tools/ ~/Android/cmdline-tools/latest && rm commandlinetools-linux-$SDK_CMDLINE_TOOLS.zip
RUN yes | ~/Android/cmdline-tools/latest/bin/sdkmanager --licenses
RUN ~/Android/cmdline-tools/latest/bin/sdkmanager --install "ndk;$NDK_VERSION" --channel=0
RUN ~/Android/cmdline-tools/latest/bin/sdkmanager --install "build-tools;$PLATFORM_TOOLS_VERSION"
#COPY --chmod=0755 build.sh /
#COPY --chmod=0755 openmw-android /openmw-android
#COPY --chmod=0755 patches /patches

ENV PATH=$PATH:~/Android/cmdline-tools/latest/bin/
ENV PATH=$PATH:~/Android/platform-tools/
ENV PATH=$PATH:~/Android/ndk/$NDK_VERSION/

ENV prefix=${CMAKE_INSTALL_PREFIX}

# Setup ICU
RUN set -e && mkdir -p $HOME/downloads/ && cd $_ && wget https://github.com/unicode-org/icu/archive/refs/tags/release-$LIBICU_VERSION.zip && unzip release-$LIBICU_VERSION.zip
RUN mkdir -p $HOME/build/icu-host-build && cd $_ && $HOME/downloads/icu-release-$LIBICU_VERSION/icu4c/source/configure --disable-tests --disable-samples --disable-icuio --disable-extras CC="gcc" CXX="g++"
RUN cd $HOME/build/icu-host-build && make -j $(nproc)

# NDK Toolchain Settings
ENV TOOLCHAIN=/root/Android/ndk/$NDK_VERSION/toolchains/llvm/prebuilt/linux-x86_64/bin
ENV PATH=$PATH:~/Android/ndk/$NDK_VERSION/toolchains/llvm/prebuilt/linux-x86_64/bin

# NDK Settings
ENV ABI=arm64-v8a
ENV NDK_TRIPLET=aarch64-linux-android
ENV TARGET=armv7a-linux-androideabi

# Patch it to ensure gcc is never ever never used
RUN rm -f $TOOLCHAIN/$NDK_TRIPLET-gcc
RUN rm -f $TOOLCHAIN/$NDK_TRIPLET-g++

# symlink gcc to clang
RUN ln -s $NDK_TRIPLET$API-clang /$TOOLCHAIN/$NDK_TRIPLET-gcc
RUN ln -s $NDK_TRIPLET$API-clang++ /$TOOLCHAIN/$NDK_TRIPLET-g++

ENV COMMON_CMAKE_ARGS="\
-DCMAKE_TOOLCHAIN_FILE=/root/Android/ndk/$NDK_VERSION/build/cmake/android.toolchain.cmake \
-DANDROID_ABI=$ABI \
-DANDROID_PLATFORM=android-$API \
-DANDROID_STL=c++_shared \
-DANDROID_CPP_FEATURES=rtti exceptions \
-DANDROID_ALLOW_UNDEFINED_VERSION_SCRIPT_SYMBOLS=ON \
-DCMAKE_SHARED_LINKER_FLAGS=$LDFLAGS \
-DCMAKE_BUILD_TYPE=$BUILD_TYPE \
-DCMAKE_DEBUG_POSTFIX= \
-DCMAKE_INSTALL_PREFIX= \
-DCMAKE_FIND_ROOT_PATH="

ENV COMMON_AUTOCONF_FLAGS="--enable-static --disable-shared"

ENV NDK_BUILD_FLAGS="\
NDK_PROJECT_PATH=. \
APP_BUILD_SCRIPT=./Android.mk \
APP_PLATFORM=$API \
APP_ABI=$ABI APP_LD=deprecated \
LOCAL_LDFLAGS=$LDFLAGS"


#  █████       █████ ███████████        █████ ███████████  ██████████   █████████
# ░░███       ░░███ ░░███░░░░░███      ░░███ ░░███░░░░░███░░███░░░░░█  ███░░░░░███
#  ░███        ░███  ░███    ░███       ░███  ░███    ░███ ░███  █ ░  ███     ░░░
#  ░███        ░███  ░██████████        ░███  ░██████████  ░██████   ░███
#  ░███        ░███  ░███░░░░░███       ░███  ░███░░░░░░   ░███░░█   ░███    █████
#  ░███      █ ░███  ░███    ░███ ███   ░███  ░███         ░███ ░   █░░███  ░░███
#  ███████████ █████ ███████████ ░░████████   █████        ██████████ ░░█████████
# ░░░░░░░░░░░ ░░░░░ ░░░░░░░░░░░   ░░░░░░░░   ░░░░░        ░░░░░░░░░░   ░░░░░░░░░

# Setup LIBJPEG_TURBO_VERSION

RUN wget -c https://sourceforge.net/projects/libjpeg-turbo/files/$LIBJPEG_TURBO_VERSION/libjpeg-turbo-$LIBJPEG_TURBO_VERSION.tar.gz  -O - | tar -xz -C $HOME/build/ && cd $HOME/build/libjpeg-turbo-$LIBJPEG_TURBO_VERSION && ./configure $COMMON_AUTOCONF_FLAGS --without-simd && make PROGRAMS= && make install-libLTLIBRARIES install-data-am

#RUN mkdir -p $HOME/build/libjpeg-turbo && git clone --depth 1 --branch $LIBJPEG_TURBO_VERSION https://github.com/libjpeg-turbo/libjpeg-turbo/ $HOME/build/libjpeg-turbo
#RUN cd $HOME/build/libjpeg-turbo/ && ./configure $COMMON_AUTOCONF_FLAGS --without-simd && make PROGRAMS= && make install-libLTLIBRARIES install-data-am

#  █████       █████ ███████████  ███████████  ██████   █████   █████████
# ░░███       ░░███ ░░███░░░░░███░░███░░░░░███░░██████ ░░███   ███░░░░░███
#  ░███        ░███  ░███    ░███ ░███    ░███ ░███░███ ░███  ███     ░░░
#  ░███        ░███  ░██████████  ░██████████  ░███░░███░███ ░███
#  ░███        ░███  ░███░░░░░███ ░███░░░░░░   ░███ ░░██████ ░███    █████
#  ░███      █ ░███  ░███    ░███ ░███         ░███  ░░█████ ░░███  ░░███
#  ███████████ █████ ███████████  █████        █████  ░░█████ ░░█████████
# ░░░░░░░░░░░ ░░░░░ ░░░░░░░░░░░  ░░░░░        ░░░░░    ░░░░░   ░░░░░░░░░

# Setup LIBPNG_VERSION

RUN wget -c http://prdownloads.sourceforge.net/libpng/libpng-$LIBPNG_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/libpng-$LIBPNG_VERSION && ./configure $COMMON_AUTOCONF_FLAGS && make PROGRAMS= && make install-libLTLIBRARIES install-data-am

#RUN mkdir -p $HOME/build/libpng && git clone --depth 1 --branch v$LIBPNG_VERSION https://github.com/glennrp/libpng/ $HOME/build/libpng
#RUN cd $HOME/build/libpng && ./configure && make check_PROGRAMS= bin_PROGRAMS= && make install check_PROGRAMS= bin_PROGRAMS=

#  █████       █████ ███████████  █████   █████████  █████  █████
# ░░███       ░░███ ░░███░░░░░███░░███   ███░░░░░███░░███  ░░███
#  ░███        ░███  ░███    ░███ ░███  ███     ░░░  ░███   ░███
#  ░███        ░███  ░██████████  ░███ ░███          ░███   ░███
#  ░███        ░███  ░███░░░░░███ ░███ ░███          ░███   ░███
#  ░███      █ ░███  ░███    ░███ ░███ ░░███     ███ ░███   ░███
#  ███████████ █████ ███████████  █████ ░░█████████  ░░████████
# ░░░░░░░░░░░ ░░░░░ ░░░░░░░░░░░  ░░░░░   ░░░░░░░░░    ░░░░░░░░

ENV LIBICU_FLAGS="\
--disable-tests \
--disable-samples \
--disable-icuio \
--disable-extras \
--with-cross-build=/root/build/icu-host-build"

# Setup LIBICU
#RUN cd /root/build && wget https://github.com/unicode-org/icu/archive/refs/tags/release-$LIBICU_VERSION.zip && unzip -o release-$LIBICU_VERSION.zip && rm -rf release-$LIBICU_VERSION.zip
#RUN /root/downloads/icu-release-70-1/icu4c/source/configure $COMMON_AUTOCONF_FLAGS $LIBICU_FLAGS && make check_PROGRAMS= bin_PROGRAMS= && make install check_PROGRAMS= bin_PROGRAMS=

#RUN mkdir -p $HOME/build/icu-$LIBICU_VERSION && cd $_ && unzip $HOME/downloads/release-$LIBICU_VERSION.zip && icu-release-$LIBICU_VERSION/icu4c/source/configure $LIBICU_FLAGS
# RUN cd $HOME/downloads/icu-release-$LIBICU_VERSION/icu4c/source/ && make check_PROGRAMS= bin_PROGRAMS= && make install check_PROGRAMS= bin_PROGRAMS=

#  ███████████ ███████████   ██████████ ██████████ ███████████ █████ █████ ███████████  ██████████  ████████
# ░░███░░░░░░█░░███░░░░░███ ░░███░░░░░█░░███░░░░░█░█░░░███░░░█░░███ ░░███ ░░███░░░░░███░░███░░░░░█ ███░░░░███
#  ░███   █ ░  ░███    ░███  ░███  █ ░  ░███  █ ░ ░   ░███  ░  ░░███ ███   ░███    ░███ ░███  █ ░ ░░░    ░███
#  ░███████    ░██████████   ░██████    ░██████       ░███      ░░█████    ░██████████  ░██████      ███████
#  ░███░░░█    ░███░░░░░███  ░███░░█    ░███░░█       ░███       ░░███     ░███░░░░░░   ░███░░█     ███░░░░
#  ░███  ░     ░███    ░███  ░███ ░   █ ░███ ░   █    ░███        ░███     ░███         ░███ ░   █ ███      █
#  █████       █████   █████ ██████████ ██████████    █████       █████    █████        ██████████░██████████
# ░░░░░       ░░░░░   ░░░░░ ░░░░░░░░░░ ░░░░░░░░░░    ░░░░░       ░░░░░    ░░░░░        ░░░░░░░░░░ ░░░░░░░░░░

# Setup FREETYPE2_VERSION

RUN wget -c https://download.savannah.gnu.org/releases/freetype/freetype-$FREETYPE2_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/freetype-$FREETYPE2_VERSION && ./configure $COMMON_AUTOCONF_FLAGS --with-png=no && make && make install

#RUN mkdir -p $HOME/build/freetype2 && git clone --depth 1 --branch VER-$FREETYPE2_VERSION https://github.com/freetype/freetype/ $HOME/build/freetype2
#RUN cd $HOME/build/freetype2 && ./configure $COMMON_AUTOCONF_FLAGS --with-png=no && make && make install

#     ███████    ███████████  ██████████ ██████   █████   █████████   █████
#   ███░░░░░███ ░░███░░░░░███░░███░░░░░█░░██████ ░░███   ███░░░░░███ ░░███
#  ███     ░░███ ░███    ░███ ░███  █ ░  ░███░███ ░███  ░███    ░███  ░███
# ░███      ░███ ░██████████  ░██████    ░███░░███░███  ░███████████  ░███
# ░███      ░███ ░███░░░░░░   ░███░░█    ░███ ░░██████  ░███░░░░░███  ░███
# ░░███     ███  ░███         ░███ ░   █ ░███  ░░█████  ░███    ░███  ░███      █
#  ░░░███████░   █████        ██████████ █████  ░░█████ █████   █████ ███████████
#    ░░░░░░░    ░░░░░        ░░░░░░░░░░ ░░░░░    ░░░░░ ░░░░░   ░░░░░ ░░░░░░░░░░░

ENV OPENAL_FLAGS="\
-DALSOFT_EXAMPLES=OFF \
-DALSOFT_TESTS=OFF \
-DALSOFT_UTILS=OFF \
-DALSOFT_NO_CONFIG_UTIL=ON \
-DALSOFT_BACKEND_OPENSL=ON \
-DALSOFT_BACKEND_WAVE=OFF"

# Setup OPENAL_VERSION
RUN wget -c https://github.com/kcat/openal-soft/archive/$OPENAL_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/openal-soft-$OPENAL_VERSION && cmake . $COMMON_CMAKE_ARGS $OPENAL_FLAGS && make && make install

#RUN mkdir -p $HOME/build/openal && git clone --depth 1 --branch $OPENAL_VERSION https://github.com/kcat/openal-soft/ $HOME/build/openal
#RUN cmake ../ $COMMON_CMAKE_ARGS $OPENAL_FLAGS
#RUN cd /root/build/openal-soft-$OPENAL_VERSION/build && make && make install

#  ███████████ █████       █████ ███████████
# ░█░░░░░░███ ░░███       ░░███ ░░███░░░░░███
# ░     ███░   ░███        ░███  ░███    ░███
#      ███     ░███        ░███  ░██████████
#     ███      ░███        ░███  ░███░░░░░███
#   ████     █ ░███      █ ░███  ░███    ░███
#  ███████████ ███████████ █████ ███████████
# ░░░░░░░░░░░ ░░░░░░░░░░░ ░░░░░ ░░░░░░░░░░░

# Setup ZLIB_VERSION

RUN wget -c https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/zlib-1.3 && wget https://github.com/madler/zlib/commit/01253ecd7e0a01d311670f2d03c61b82fc12d338.patch -O - | git apply && cmake . $COMMON_CMAKE_ARGS && make && make install

#RUN mkdir -p $HOME/build/zlib && git clone --depth 1 --branch v1.3 https://github.com/madler/zlib/ $HOME/build/zlib
#ADD https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.gz /root/downloads/
#RUN tar xvzf /root/downloads/zlib-1.3.tar.gz -C /root/build/ && mkdir -p /root/build/zlib-1.3/build && cd $_ && cmake ../ $COMMON_CMAKE_ARGS

#  ███████████     ███████       ███████     █████████  ███████████
# ░░███░░░░░███  ███░░░░░███   ███░░░░░███  ███░░░░░███░█░░░███░░░█
#  ░███    ░███ ███     ░░███ ███     ░░███░███    ░░░ ░   ░███  ░
#  ░██████████ ░███      ░███░███      ░███░░█████████     ░███
#  ░███░░░░░███░███      ░███░███      ░███ ░░░░░░░░███    ░███
#  ░███    ░███░░███     ███ ░░███     ███  ███    ░███    ░███
#  ███████████  ░░░███████░   ░░░███████░  ░░█████████     █████
# ░░░░░░░░░░░     ░░░░░░░       ░░░░░░░     ░░░░░░░░░     ░░░░░

ENV BOOST_FLAGS="-j4 \
--with-filesystem \
--with-program_options \
--with-system \
--with-iostreams \
--with-regex \
--ignore-site-config \
--toolset=clang \
--architecture=arm \
--address-model=64 \
--cflags=CFLAGS \
--cxxflags=CXXFLAGS \
--variant=release \
--target-os=android \
--threading=multi \
--threadapi=pthread \
--link=static \
--runtime-link=static \
--install"

# Setup BOOST_VERSION

RUN wget -c https://github.com/boostorg/boost/releases/download/boost-$BOOST_VERSION/boost-$BOOST_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/boost-$BOOST_VERSION && ./bootstrap.sh && ./b2 $BOOST_FLAGS

#  ███████████ ███████████ ██████   ██████ ███████████  ██████████   █████████
# ░░███░░░░░░█░░███░░░░░░█░░██████ ██████ ░░███░░░░░███░░███░░░░░█  ███░░░░░███
#  ░███   █ ░  ░███   █ ░  ░███░█████░███  ░███    ░███ ░███  █ ░  ███     ░░░
#  ░███████    ░███████    ░███░░███ ░███  ░██████████  ░██████   ░███
#  ░███░░░█    ░███░░░█    ░███ ░░░  ░███  ░███░░░░░░   ░███░░█   ░███    █████
#  ░███  ░     ░███  ░     ░███      ░███  ░███         ░███ ░   █░░███  ░░███
#  █████       █████       █████     █████ █████        ██████████ ░░█████████
# ░░░░░       ░░░░░       ░░░░░     ░░░░░ ░░░░░        ░░░░░░░░░░   ░░░░░░░░░

ENV FFMPEG_FLAGS="--disable-asm \
--disable-optimizations \
--target-os=android \
--enable-cross-compile \
--cross-prefix=llvm- \
--cc=$aarch64-linux-android-clang \
--arch=arm64 \
--cpu=armv8-a \
--enable-version3 \
--enable-pic \
--disable-everything \
--disable-doc \
--disable-programs \
--disable-autodetect \
--disable-iconv \
--enable-decoder=mp3 \
--enable-demuxer=mp3 \
--enable-decoder=bink \
--enable-decoder=binkaudio_rdft \
--enable-decoder=binkaudio_dct \
--enable-demuxer=bink \
--enable-demuxer=wav \
--enable-decoder=pcm_* \
--enable-decoder=vp8 \
--enable-decoder=vp9 \
--enable-decoder=opus \
--enable-decoder=vorbis \
--enable-demuxer=matroska \
--enable-demuxer=ogg"


# Setup FFMPEG_VERSION

RUN wget -c http://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.bz2 -O - | tar -xjf - -C $HOME/build/ && cd $HOME/build/ffmpeg-$FFMPEG_VERSION

#RUN mkdir -p $HOME/build/ffmpeg && git clone --depth 1 --branch n$FFMPEG_VERSION https://github.com/FFmpeg/FFmpeg/ $HOME/build/ffmpeg
#RUN cd $HOME/build/ffmpeg && ./configure $FFMPEG_FLAGS

#   █████████  ██████████   █████        ████████
#  ███░░░░░███░░███░░░░███ ░░███        ███░░░░███
# ░███    ░░░  ░███   ░░███ ░███       ░░░    ░███
# ░░█████████  ░███    ░███ ░███          ███████
#  ░░░░░░░░███ ░███    ░███ ░███         ███░░░░
#  ███    ░███ ░███    ███  ░███      █ ███      █
# ░░█████████  ██████████   ███████████░██████████
#  ░░░░░░░░░  ░░░░░░░░░░   ░░░░░░░░░░░ ░░░░░░░░░░

# Setup SDL2_VERSION

RUN wget -c https://www.libsdl.org/release/SDL2-$SDL2_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/SDL2-$SDL2_VERSION

#RUN mkdir -p $HOME/build/sdl2 && git clone --depth 1 --branch release-$SDL2_VERSION https://github.com/libsdl-org/SDL/ $HOME/build/sdl2
#RUN cd $HOME/build/sdl2 && ndk-build $NDK_BUILD_FLAGS

#  ███████████  █████  █████ █████       █████       ██████████ ███████████
# ░░███░░░░░███░░███  ░░███ ░░███       ░░███       ░░███░░░░░█░█░░░███░░░█
#  ░███    ░███ ░███   ░███  ░███        ░███        ░███  █ ░ ░   ░███  ░
#  ░██████████  ░███   ░███  ░███        ░███        ░██████       ░███
#  ░███░░░░░███ ░███   ░███  ░███        ░███        ░███░░█       ░███
#  ░███    ░███ ░███   ░███  ░███      █ ░███      █ ░███ ░   █    ░███
#  ███████████  ░░████████   ███████████ ███████████ ██████████    █████
# ░░░░░░░░░░░    ░░░░░░░░   ░░░░░░░░░░░ ░░░░░░░░░░░ ░░░░░░░░░░    ░░░░░

ENV BULLET_FLAGS="\
-DBUILD_BULLET2_DEMOS=OFF \
-DBUILD_CPU_DEMOS=OFF \
-DBUILD_UNIT_TESTS=OFF \
-DBUILD_EXTRAS=OFF \
-DUSE_DOUBLE_PRECISION=ON \
-DBULLET2_MULTITHREADING=ON"

# Setup BULLET_VERSION

RUN wget -c https://github.com/bulletphysics/bullet3/archive/$BULLET_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/bullet3-$BULLET_VERSION

#RUN mkdir -p $HOME/build/bullet && git clone --depth 1 --branch $BULLET_VERSION https://github.com/bulletphysics/bullet3/ $HOME/build/bullet
#RUN cd $HOME/build/bullet && cmake . $COMMON_CMAKE_ARGS $BULLET_FLAGS && make && make install

#    █████████  █████       █████ █████  ██████████  █████████
#   ███░░░░░███░░███       ░░███ ░░███  ░░███░░░░░█ ███░░░░░███
#  ███     ░░░  ░███        ░███  ░███ █ ░███  █ ░ ░███    ░░░
# ░███          ░███        ░███████████ ░██████   ░░█████████
# ░███    █████ ░███        ░░░░░░░███░█ ░███░░█    ░░░░░░░░███
# ░░███  ░░███  ░███      █       ░███░  ░███ ░   █ ███    ░███
#  ░░█████████  ███████████       █████  ██████████░░█████████
#   ░░░░░░░░░  ░░░░░░░░░░░       ░░░░░  ░░░░░░░░░░  ░░░░░░░░░

# Setup GL4ES_VERSION

RUN wget -c https://github.com/ptitSeb/gl4es/archive/v$GL4ES_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/gl4es-$GL4ES_VERSION

#RUN mkdir -p $HOME/build/gl4es && git clone --depth 1 --branch v$GL4ES_VERSION https://github.com/ptitSeb/gl4es/ $HOME/build/gl4es
#RUN cd $HOME/build/gl4es && ndk-build $NDK_BUILD_FLAGS
#RUN mkdir -p ${prefix}/lib/ && cp libs/${app_abi}/libGL.so ${prefix}/lib/ && cp -r <SOURCE_DIR>/include ${prefix}/include/gl4es/ && cp -r <SOURCE_DIR>/include ${prefix}/

#  ██████   ██████ █████ █████   █████████  █████  █████ █████
# ░░██████ ██████ ░░███ ░░███   ███░░░░░███░░███  ░░███ ░░███
#  ░███░█████░███  ░░███ ███   ███     ░░░  ░███   ░███  ░███
#  ░███░░███ ░███   ░░█████   ░███          ░███   ░███  ░███
#  ░███ ░░░  ░███    ░░███    ░███    █████ ░███   ░███  ░███
#  ░███      ░███     ░███    ░░███  ░░███  ░███   ░███  ░███
#  █████     █████    █████    ░░█████████  ░░████████   █████
# ░░░░░     ░░░░░    ░░░░░      ░░░░░░░░░    ░░░░░░░░   ░░░░░

ENV MYGUI_FLAGS="\
-DMYGUI_RENDERSYSTEM=1 \
-DMYGUI_BUILD_DEMOS=OFF \
-DMYGUI_BUILD_TOOLS=OFF \
-DMYGUI_BUILD_PLUGINS=OFF \
-DMYGUI_DONT_USE_OBSOLETE=ON \
-DFREETYPE_FT2BUILD_INCLUDE_DIR=/include/freetype2/ \
-DMYGUI_STATIC=ON"

# Setup MYGUI_VERSION

RUN wget -c https://github.com/MyGUI/mygui/archive/MyGUI$MYGUI_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/mygui-MyGUI$MYGUI_VERSION

#RUN mkdir -p $HOME/build/mygui && git clone --depth 1 --branch MyGUI$MYGUI_VERSION https://github.com/MyGUI/mygui/ $HOME/build/mygui
#RUN cd $HOME/build/mygui && cmake . $COMMON_CMAKE_ARGS $MYGUI_FLAGS && make && make install

#  █████       ███████████ █████ █████
# ░░███       ░█░░░░░░███ ░░███ ░░███
#  ░███       ░     ███░   ░███  ░███ █
#  ░███            ███     ░███████████
#  ░███           ███      ░░░░░░░███░█
#  ░███      █  ████     █       ░███░
#  ███████████ ███████████       █████
# ░░░░░░░░░░░ ░░░░░░░░░░░       ░░░░░

# Setup LZ4_VERSION

RUN wget -c https://github.com/lz4/lz4/archive/v$LZ4_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/lz4-$LZ4_VERSION

#RUN mkdir -p $HOME/build/lz4 && git clone --depth 1 --branch v$LZ4_VERSION https://github.com/lz4/lz4/ $HOME/build/lz4
#RUN cd $HOME/build/lz4 && cmake . $COMMON_CMAKE_ARGS -DBUILD_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=OFF && make && make install

#  █████       █████  █████   █████████         █████ █████ ███████████
# ░░███       ░░███  ░░███   ███░░░░░███       ░░███ ░░███ ░█░░░███░░░█
#  ░███        ░███   ░███  ░███    ░███        ░███  ░███ ░   ░███  ░
#  ░███        ░███   ░███  ░███████████        ░███  ░███     ░███
#  ░███        ░███   ░███  ░███░░░░░███        ░███  ░███     ░███
#  ░███      █ ░███   ░███  ░███    ░███  ███   ░███  ░███     ░███
#  ███████████ ░░████████   █████   █████░░████████   █████    █████
# ░░░░░░░░░░░   ░░░░░░░░   ░░░░░   ░░░░░  ░░░░░░░░   ░░░░░    ░░░░░

ENV LUAJIT_FLAGS="\
HOST_CC=gcc -m64 \
CFLAGS= \
TARGET_CFLAGS=$CFLAGS \
CROSS=llvm- \
STATIC_CC=$NDK_TRIPLET-clang \
DYNAMIC_CC=$NDK_TRIPLET-clang\ -fPIC \
TARGET_LD=$NDK_TRIPLET-clang"

# Setup LUAJIT_VERSION

RUN wget -c https://github.com/luaJit/LuaJIT/archive/v$LUAJIT_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/LuaJIT-$LUAJIT_VERSION

#RUN mkdir -p $HOME/build/luajit && git clone --depth 1 --branch v$LUAJIT_VERSION https://github.com/LuaJIT/LuaJIT/ $HOME/build/luajit
#RUN cd $HOME/build/luajit && make amalg $LUAJIT_FLAGS
#RUN cd $HOME/build/luajit && make install $LUAJIT_FLAGS
#RUN bash -c "rm ${prefix}/lib/libluajit*.so*"

#  █████       █████ ███████████  █████ █████ ██████   ██████ █████
# ░░███       ░░███ ░░███░░░░░███░░███ ░░███ ░░██████ ██████ ░░███
#  ░███        ░███  ░███    ░███ ░░███ ███   ░███░█████░███  ░███
#  ░███        ░███  ░██████████   ░░█████    ░███░░███ ░███  ░███
#  ░███        ░███  ░███░░░░░███   ███░███   ░███ ░░░  ░███  ░███
#  ░███      █ ░███  ░███    ░███  ███ ░░███  ░███      ░███  ░███      █
#  ███████████ █████ ███████████  █████ █████ █████     █████ ███████████
# ░░░░░░░░░░░ ░░░░░ ░░░░░░░░░░░  ░░░░░ ░░░░░ ░░░░░     ░░░░░ ░░░░░░░░░░░

ENV LIBXML_FLAGS="\
-DBUILD_SHARED_LIBS=OFF \
-DLIBXML2_WITH_CATALOG=OFF \
-DLIBXML2_WITH_ICONV=OFF \
-DLIBXML2_WITH_LZMA=OFF \
-DLIBXML2_WITH_PROGRAMS=OFF \
-DLIBXML2_WITH_PYTHON=OFF \
-DLIBXML2_WITH_TESTS=OFF \
-DLIBXML2_WITH_ZLIB=ON"

# Setup LIBXML_VERSION

RUN wget -c https://github.com/GNOME/libxml2/archive/refs/tags/v2.12.2.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/libxml2-2.12.2

#RUN mkdir -p $HOME/build/libxml && git clone --depth 1 --branch v2.12.2 https://github.com/GNOME/libxml2/ $HOME/build/libxml
#RUN cd $HOME/build/libxml && cmake . $COMMON_CMAKE_ARGS $LIBXML_FLAGS
#RUN make && make install

#    █████████     ███████    █████       █████         █████████   ██████████     █████████
#   ███░░░░░███  ███░░░░░███ ░░███       ░░███         ███░░░░░███ ░░███░░░░███   ███░░░░░███
#  ███     ░░░  ███     ░░███ ░███        ░███        ░███    ░███  ░███   ░░███ ░███    ░███
# ░███         ░███      ░███ ░███        ░███        ░███████████  ░███    ░███ ░███████████
# ░███         ░███      ░███ ░███        ░███        ░███░░░░░███  ░███    ░███ ░███░░░░░███
# ░░███     ███░░███     ███  ░███      █ ░███      █ ░███    ░███  ░███    ███  ░███    ░███
#  ░░█████████  ░░░███████░   ███████████ ███████████ █████   █████ ██████████   █████   █████
#   ░░░░░░░░░     ░░░░░░░    ░░░░░░░░░░░ ░░░░░░░░░░░ ░░░░░   ░░░░░ ░░░░░░░░░░   ░░░░░   ░░░░░

ENV COLLADA_FLAGS="\
-DBoost_USE_STATIC_LIBS=ON \
-DBoost_USE_STATIC_RUNTIME=ON \
-DBoost_NO_SYSTEM_PATHS=ON \
-DBoost_INCLUDE_DIR=/include \
-DHAVE_STRTOQ=0 \
-DUSE_FILE32API=1 \
-DCMAKE_CXX_FLAGS=-std=gnu++11\ -I /include/\ $ENV{CXXFLAGS}"

# Setup LIBCOLLADA_VERSION

RUN wget -c https://github.com/rdiankov/collada-dom/archive/v2.5.0.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/collada-dom-2.5.0

#RUN mkdir -p $HOME/build/collada-dom && git clone --depth 1 --branch v2.5.0 https://github.com/rdiankov/collada-dom/ $HOME/build/collada-dom
#RUN cd $HOME/build/collada-dom && cmake . $COMMON_CMAKE_ARGS $COLLADA_FLAGS
#RUN make && make install

#     ███████     █████████    █████████
#   ███░░░░░███  ███░░░░░███  ███░░░░░███
#  ███     ░░███░███    ░░░  ███     ░░░
# ░███      ░███░░█████████ ░███
# ░███      ░███ ░░░░░░░░███░███    █████
# ░░███     ███  ███    ░███░░███  ░░███
#  ░░░███████░  ░░█████████  ░░█████████
#    ░░░░░░░     ░░░░░░░░░    ░░░░░░░░░

ENV OSG_FLAGS="\
-DOPENGL_PROFILE="GL1" \
-DDYNAMIC_OPENTHREADS=OFF \
-DDYNAMIC_OPENSCENEGRAPH=OFF \
-DBUILD_OSG_PLUGIN_OSG=ON \
-DBUILD_OSG_PLUGIN_DAE=ON \
-DBUILD_OSG_PLUGIN_DDS=ON \
-DBUILD_OSG_PLUGIN_TGA=ON \
-DBUILD_OSG_PLUGIN_BMP=ON \
-DBUILD_OSG_PLUGIN_JPEG=ON \
-DBUILD_OSG_PLUGIN_PNG=ON \
-DBUILD_OSG_PLUGIN_FREETYPE=ON \
-DJPEG_INCLUDE_DIR=/include/ \
-DPNG_INCLUDE_DIR=/include/ \
-DFREETYPE_DIR= \
-DCOLLADA_INCLUDE_DIR=/include/collada-dom2.5 \
-DCOLLADA_DIR=/include/collada-dom2.5/1.4 \
-DOSG_CPP_EXCEPTIONS_AVAILABLE=TRUE \
-DOSG_GL1_AVAILABLE=ON \
-DOSG_GL2_AVAILABLE=OFF \
-DOSG_GL3_AVAILABLE=OFF \
-DOSG_GLES1_AVAILABLE=OFF \
-DOSG_GLES2_AVAILABLE=OFF \
-DOSG_GL_LIBRARY_STATIC=OFF \
-DOSG_GL_DISPLAYLISTS_AVAILABLE=OFF \
-DOSG_GL_MATRICES_AVAILABLE=ON \
-DOSG_GL_VERTEX_FUNCS_AVAILABLE=ON \
-DOSG_GL_VERTEX_ARRAY_FUNCS_AVAILABLE=ON \
-DOSG_GL_FIXED_FUNCTION_AVAILABLE=ON \
-DBUILD_OSG_APPLICATIONS=OFF \
-DBUILD_OSG_PLUGINS_BY_DEFAULT=OFF \
-DBUILD_OSG_DEPRECATED_SERIALIZERS=OFF \
-DCMAKE_CXX_FLAGS=-std=gnu++11\ -I/include/\ $ENV{CXXFLAGS}"

# Setup OPENSCENEGRAPH_VERSION

RUN wget -c https://github.com/openmw/osg/archive/$OSG_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/osg-$OSG_VERSION

#RUN mkdir -p $HOME/build/osg && git clone --depth 1 --branch OpenSceneGraph-$OSG_VERSION https://github.com/openmw/osg/ $HOME/build/osg
#RUN cd $HOME/build/osg && cmake . $COMMON_CMAKE_ARGS $OSG_FLAGS
#RUN make && make install

#     ███████    ███████████  ██████████ ██████   █████ ██████   ██████ █████   ███   █████
#   ███░░░░░███ ░░███░░░░░███░░███░░░░░█░░██████ ░░███ ░░██████ ██████ ░░███   ░███  ░░███
#  ███     ░░███ ░███    ░███ ░███  █ ░  ░███░███ ░███  ░███░█████░███  ░███   ░███   ░███
# ░███      ░███ ░██████████  ░██████    ░███░░███░███  ░███░░███ ░███  ░███   ░███   ░███
# ░███      ░███ ░███░░░░░░   ░███░░█    ░███ ░░██████  ░███ ░░░  ░███  ░░███  █████  ███
# ░░███     ███  ░███         ░███ ░   █ ░███  ░░█████  ░███      ░███   ░░░█████░█████░
#  ░░░███████░   █████        ██████████ █████  ░░█████ █████     █████    ░░███ ░░███
#    ░░░░░░░    ░░░░░        ░░░░░░░░░░ ░░░░░    ░░░░░ ░░░░░     ░░░░░      ░░░   ░░░

ENV OPENMW_FLAGS="\
-DBUILD_BSATOOL=0 \
-DBUILD_NIFTEST=0 \
-DBUILD_ESMTOOL=0 \
-DBUILD_LAUNCHER=0 \
-DBUILD_MWINIIMPORTER=0 \
-DBUILD_ESSIMPORTER=0 \
-DBUILD_OPENCS=0 \
-DBUILD_NAVMESHTOOL=0 \
-DBUILD_WIZARD=0 \
-DBUILD_MYGUI_PLUGIN=0 \
-DBUILD_BULLETOBJECTTOOL=0 \
-DOPENMW_USE_SYSTEM_SQLITE3=OFF \
-DOPENMW_USE_SYSTEM_YAML_CPP=OFF \
-DOPENMW_USE_SYSTEM_ICU=ON \
-DOPENAL_INCLUDE_DIR=/include/AL/ \
-DBullet_INCLUDE_DIR=/include/bullet/ \
-DOSG_STATIC=TRUE \
-DMyGUI_LIBRARY=/lib/libMyGUIEngineStatic.a"

# Setup OPENMW_VERSION

RUN wget -c https://github.com/OpenMW/openmw/archive/$OPENMW_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/openmw-$OPENMW_VERSION

#RUN git clone --depth 1 --branch $OPENMW_VERSION https://github.com/OpenMW/openmw/
#RUN mkdir -p $HOME/build/openmw && git clone http://github.com/openmw/openmw/ $HOME/build/openmw
#RUN cd $HOME/build/openmw && cmake . $COMMON_CMAKE_ARGS $OPENMW_FLAGS
#RUN make

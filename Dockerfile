# syntax=docker/dockerfile:labs
FROM rockylinux:9

#Set build type : release, debug
ENV BUILD_TYPE=release

# App versions - change settings here
ENV LIBJPEG_TURBO_VERSION=3.0.2
ENV LIBPNG_VERSION=1.6.42
ENV FREETYPE2_VERSION=2.13.2
ENV OPENAL_VERSION=1.23.1
ENV BOOST_VERSION=1.83.0
ENV LIBICU_VERSION=70-1
ENV FFMPEG_VERSION=6.1
ENV SDL2_VERSION=2.24.0
ENV BULLET_VERSION=3.25
ENV ZLIB_VERSION=1.3.1
ENV LIBXML2_VERSION=2.12.5
ENV MYGUI_VERSION=3.4.3
ENV GL4ES_VERSION=1.1.5
ENV COLLADA_DOM_VERSION=2.5.0
ENV OSG_VERSION=69cfecebfb6dc703b42e8de39eed750a84a87489
ENV LZ4_VERSION=1.9.3
ENV LUAJIT_VERSION=2.1.ROLLING
ENV OPENMW_VERSION=05815b39527e41f820f8d24895e4fa1e82bb753c
ENV NDK_VERSION=26.3.11579264
ENV SDK_CMDLINE_TOOLS=10406996_latest
ENV PLATFORM_TOOLS_VERSION=29.0.0
ENV JAVA_VERSION=17

# Version of Release
ARG APP_VERSION=unknown

RUN dnf install -y dnf-plugins-core && dnf config-manager --set-enabled crb && dnf install -y epel-release
RUN dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-9.noarch.rpm \
    && dnf install -y xz p7zip bzip2 libstdc++-devel glibc-devel zip unzip libcurl-devel java-11-openjdk which wget python-devel doxygen nano gcc-c++ git java-${JAVA_VERSION}-openjdk cmake patch

RUN alternatives --set java java-17-openjdk.x86_64
RUN JAVA_HOME=$(dirname $(dirname $(readlink $(readlink $(which java)))))
ENV ANDROID_SDK_ROOT=/root/Android/cmdline-tools/latest/bin
ENV ANDROID_HOME=/root/Android
RUN mkdir -p ${HOME}/prefix
RUN mkdir -p ${HOME}/src

# Set the installation Dir
ENV PREFIX=/root/prefix
RUN cd ${HOME}/src && wget https://github.com/unicode-org/icu/archive/refs/tags/release-${LIBICU_VERSION}.zip && unzip -o ${HOME}/src/release-${LIBICU_VERSION}.zip && rm -rf release-${LIBICU_VERSION}.zip
RUN wget https://dl.google.com/android/repository/commandlinetools-linux-${SDK_CMDLINE_TOOLS}.zip && unzip commandlinetools-linux-${SDK_CMDLINE_TOOLS}.zip && mkdir -p ${HOME}/Android/cmdline-tools/ && mv cmdline-tools/ ${HOME}/Android/cmdline-tools/latest && rm commandlinetools-linux-${SDK_CMDLINE_TOOLS}.zip
RUN yes | ~/Android/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null
RUN ~/Android/cmdline-tools/latest/bin/sdkmanager --install "ndk;${NDK_VERSION}" "platforms;android-28" "platform-tools" "build-tools;29.0.2" --channel=0
RUN yes | ~/Android/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null

COPY --chmod=0755 patches /root/patches

#Setup ICU for the Host
RUN mkdir -p ${HOME}/src/icu-host-build && cd $_ && ${HOME}/src/icu-release-70-1/icu4c/source/configure --disable-tests --disable-samples --disable-icuio --disable-extras CC="gcc" CXX="g++" && make -j $(nproc)
ENV PATH=$PATH:/root/Android/cmdline-tools/latest/bin/:/root/Android/ndk/${NDK_VERSION}/:/root/Android/ndk/${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64:/root/Android/ndk/${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin:/root/prefix/include:/root/prefix/lib:/root/prefix/:/root/.cargo/bin

# NDK Settings
ENV API=28
ENV ABI=arm64-v8a
ENV ARCH=aarch64
ENV NDK_TRIPLET=${ARCH}-linux-android
ENV TOOLCHAIN=/root/Android/ndk/${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64
ENV NDK_SYSROOT=${TOOLCHAIN}/sysroot/
ENV ANDROID_SYSROOT=${TOOLCHAIN}/sysroot/
ENV AR=${TOOLCHAIN}/bin/llvm-ar
ENV LD=${TOOLCHAIN}/bin/ld
ENV RANLIB=${TOOLCHAIN}/bin/llvm-ranlib
ENV STRIP=${TOOLCHAIN}/bin/llvm-strip
ENV CC=${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang
ENV CXX=${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang++
ENV clang=${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang
ENV clang++=${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang++

# Global C, CXX and LDFLAGS
ENV CFLAGS="-fPIC -O3 -flto=thin"
ENV CXXFLAGS="-fPIC -O3 -frtti -fexceptions -flto=thin"
ENV LDFLAGS="-fPIC -Wl,--undefined-version -flto=thin -fuse-ld=lld"

ENV COMMON_CMAKE_ARGS \
  "-DCMAKE_TOOLCHAIN_FILE=/root/Android/ndk/${NDK_VERSION}/build/cmake/android.toolchain.cmake" \
  "-DANDROID_ABI=$ABI" \
  "-DANDROID_PLATFORM=android-${API}" \
  "-DANDROID_STL=c++_shared" \
  "-DANDROID_CPP_FEATURES=" \
  "-DANDROID_ALLOW_UNDEFINED_VERSION_SCRIPT_SYMBOLS=ON" \
  "-DCMAKE_BUILD_TYPE=$BUILD_TYPE" \
  "-DCMAKE_C_FLAGS=-I${PREFIX}" \
  "-DCMAKE_DEBUG_POSTFIX=" \
  "-DCMAKE_INSTALL_PREFIX=${PREFIX}" \
  "-DCMAKE_FIND_ROOT_PATH=${PREFIX}" \
  "-DCMAKE_CXX_COMPILER=${NDK_TRIPLET}${API}-clang++" \
  "-DCMAKE_CC_COMPILER=${NDK_TRIPLET}${API}-clang" \
  "-DHAVE_LD_VERSION_SCRIPT=OFF"

ENV COMMON_AUTOCONF_FLAGS="--enable-static --disable-shared --prefix=${PREFIX} --host=${NDK_TRIPLET}${API}"

ENV NDK_BUILD_FLAGS \
    "NDK_PROJECT_PATH=." \
    "APP_BUILD_SCRIPT=./Android.mk" \
    "APP_PLATFORM=${API}" \
    "APP_ABI=${ABI}"

RUN mkdir -p ${HOME}/{zips,src}
COPY --chmod=0755 patches ${HOME}/patches

RUN wget https://sh.rustup.rs -O rustup.sh && sha256sum rustup.sh && \
    echo "32a680a84cf76014915b3f8aa44e3e40731f3af92cd45eb0fcc6264fd257c428  rustup.sh" | sha256sum -c - && \
    sh rustup.sh -y && rm rustup.sh && \
    ${HOME}/.cargo/bin/rustup target add ${NDK_TRIPLET} && \
    ${HOME}/.cargo/bin/rustup toolchain install nightly && \
    ${HOME}/.cargo/bin/rustup target add --toolchain nightly ${NDK_TRIPLET} && \
    echo "[target.${NDK_TRIPLET}]" >> /root/.cargo/config && \
    echo "linker = \"${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang\"" >> /root/.cargo/config

# Setup LIBICU
RUN mkdir -p ${HOME}/prefix/icu
RUN mkdir -p ${HOME}/src/icu-${LIBICU_VERSION} && cd $_ && \
    ${HOME}/src/icu-release-${LIBICU_VERSION}/icu4c/source/configure \
        ${COMMON_AUTOCONF_FLAGS} \
        --disable-tests \
        --disable-samples \
        --disable-icuio \
        --disable-extras \
        --prefix=${HOME}/prefix/icu \
        --with-cross-build=${HOME}/src/icu-host-build && \
    make -j $(nproc) check_PROGRAMS= bin_PROGRAMS= && \
    make install check_PROGRAMS= bin_PROGRAMS=
RUN cd ${HOME}/prefix/icu && zip -r ${HOME}/zips/LibIcu.zip ./*
RUN cp -rl ${HOME}/prefix/icu/* ${HOME}/prefix/

# Setup Bzip2
RUN mkdir -p ${HOME}/prefix/Bzip2
RUN cd $HOME/src/ && \
    git clone https://github.com/libarchive/bzip2 && cd bzip2 && \
    cmake . $COMMON_CMAKE_ARGS \
        -DCMAKE_INSTALL_PREFIX=${HOME}/prefix/Bzip2 && \
    make -j $(nproc) && make install
RUN cd ${HOME}/prefix/Bzip2 && zip -r ${HOME}/zips/Bzip2.zip ./*
RUN cp -rl ${HOME}/prefix/Bzip2/* ${HOME}/prefix/

# Setup ZLIB
RUN mkdir -p ${HOME}/prefix/zlib
RUN wget -c https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/zlib-${ZLIB_VERSION}/build && cd $_ && \
    cmake ${HOME}/src/zlib-${ZLIB_VERSION} \
        ${COMMON_CMAKE_ARGS} \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DCMAKE_INSTALL_PREFIX=${HOME}/prefix/zlib && \
    make -j $(nproc) && make install
RUN cd ${HOME}/prefix/zlib && zip -r ${HOME}/zips/Zlib.zip ./*
RUN cp -rl ${HOME}/prefix/zlib/* ${HOME}/prefix/

# Setup LIBJPEG_TURBO
RUN mkdir -p ${HOME}/prefix/libjpeg
RUN wget -c https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${LIBJPEG_TURBO_VERSION}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}/build && cd $_ && \
    cmake ${HOME}/src/libjpeg-turbo-${LIBJPEG_TURBO_VERSION} \
        ${COMMON_CMAKE_ARGS} \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DCMAKE_INSTALL_PREFIX=${HOME}/prefix/libjpeg \
        -DENABLE_SHARED=false && \
    make -j $(nproc) && make install
RUN cd ${HOME}/prefix/libjpeg && zip -r ${HOME}/zips/Libjpeg.zip ./*
RUN cp -rl ${HOME}/prefix/libjpeg/* ${HOME}/prefix/

# Setup LIBPNG
RUN mkdir -p ${HOME}/prefix/libpng
RUN wget -c http://prdownloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/libpng-${LIBPNG_VERSION}/build && cd $_ && \
        ${HOME}/src/libpng-${LIBPNG_VERSION}/configure \
        ${COMMON_AUTOCONF_FLAGS} --prefix=${HOME}/prefix/libpng && \
    make -j $(nproc) check_PROGRAMS= bin_PROGRAMS= && \
    make install check_PROGRAMS= bin_PROGRAMS=
RUN cd ${HOME}/prefix/libpng && zip -r ${HOME}/zips/Libpng.zip ./*
RUN cp -rl ${HOME}/prefix/libpng/* ${HOME}/prefix/

# Setup FREETYPE2
RUN mkdir -p ${HOME}/prefix/freetype2
RUN wget -c https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE2_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/freetype-${FREETYPE2_VERSION}/build && cd $_ && \
        ${HOME}/src/freetype-${FREETYPE2_VERSION}/configure \
        ${COMMON_AUTOCONF_FLAGS} --prefix=${HOME}/prefix/freetype2 \
        --with-png=no && \
    make -j $(nproc) && make install
RUN cd ${HOME}/prefix/freetype2 && zip -r ${HOME}/zips/Freetype2.zip ./*
RUN cp -rl ${HOME}/prefix/freetype2/* ${HOME}/prefix/

# Setup LIBXML
RUN mkdir -p ${HOME}/prefix/libxml
RUN wget -c https://github.com/GNOME/libxml2/archive/refs/tags/v${LIBXML2_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/libxml2-${LIBXML2_VERSION}/build && cd $_ && \
    cmake ${HOME}/src/libxml2-${LIBXML2_VERSION} \
        ${COMMON_CMAKE_ARGS} \
        -DBUILD_SHARED_LIBS=OFF \
        -DLIBXML2_WITH_THREADS=ON \
        -DLIBXML2_WITH_CATALOG=OFF \
        -DLIBXML2_WITH_ICONV=OFF \
        -DLIBXML2_WITH_LZMA=OFF \
        -DLIBXML2_WITH_PROGRAMS=OFF \
        -DLIBXML2_WITH_PYTHON=OFF \
        -DLIBXML2_WITH_TESTS=OFF \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DCMAKE_INSTALL_PREFIX=${HOME}/prefix/libxml \
        -DLIBXML2_WITH_ZLIB=ON && \
    make -j $(nproc) && make install
RUN cd ${HOME}/prefix/libxml && zip -r ${HOME}/zips/Libxml.zip ./*
RUN cp -rl ${HOME}/prefix/libxml/* ${HOME}/prefix/

# Setup OPENAL
RUN mkdir -p ${HOME}/prefix/openal
RUN wget -c https://github.com/kcat/openal-soft/archive/${OPENAL_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/openal-soft-${OPENAL_VERSION}/build && cd $_ && \
    cmake ${HOME}/src/openal-soft-${OPENAL_VERSION} \
        ${COMMON_CMAKE_ARGS} \
        -DALSOFT_EXAMPLES=OFF \
        -DALSOFT_TESTS=OFF \
        -DALSOFT_UTILS=OFF \
        -DALSOFT_NO_CONFIG_UTIL=ON \
        -DALSOFT_BACKEND_OPENSL=ON \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DCMAKE_INSTALL_PREFIX=${HOME}/prefix/openal \
        -DALSOFT_BACKEND_WAVE=OFF && \
    make -j $(nproc) && make install
RUN cd ${HOME}/prefix/openal && zip -r ${HOME}/zips/Openal.zip ./*
RUN cp -rl ${HOME}/prefix/openal/* ${HOME}/prefix/

# Setup BOOST
RUN mkdir -p ${HOME}/prefix/boost
ENV JAM=/root/src/boost-${BOOST_VERSION}/user-config.jam
RUN wget -c https://github.com/boostorg/boost/releases/download/boost-${BOOST_VERSION}/boost-${BOOST_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
        cd ${HOME}/src/boost-${BOOST_VERSION} && \
        echo "using clang : ${ARCH} : ${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang++ ;" >> ${JAM} && \
    ./bootstrap.sh \
        --with-toolset=clang \
        prefix=${HOME}/prefix/boost && \
    ./b2 \
        -j4 \
        --with-filesystem \
        --with-program_options \
        --with-system \
        --with-iostreams \
        --with-regex \
        --prefix=${HOME}/prefix/boost \
        --ignore-site-config \
        --user-config=${JAM} \
        toolset=clang \
        binary-format=elf \
        abi=aapcs \
        address-model=64 \
        architecture=arm \
        cflags="${CFLAGS}" \
        cxxflags="${CXXFLAGS}" \
        variant=release \
        target-os=android \
        threading=multi \
        threadapi=pthread \
        link=static \
        runtime-link=static \
        install
RUN $RANLIB ${HOME}/prefix/boost/lib/*.a
RUN cd ${HOME}/prefix/boost && zip -r ${HOME}/zips/Boost.zip ./*
RUN cp -rl ${HOME}/prefix/boost/* ${HOME}/prefix/

# Setup FFMPEG_VERSION
RUN mkdir -p ${HOME}/prefix/ffmpeg
RUN wget -c http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 -O - | tar -xjf - -C ${HOME}/src/ && \
    mkdir -p ${HOME}/src/ffmpeg-${FFMPEG_VERSION} && cd $_ && \
    ${HOME}/src/ffmpeg-${FFMPEG_VERSION}/configure \
        --disable-asm \
        --disable-optimizations \
        --target-os=android \
        --enable-cross-compile \
        --cross-prefix=${TOOLCHAIN}/bin/llvm- \
        --cc=${NDK_TRIPLET}${API}-clang \
        --arch=arm64 \
        --cpu=armv8-a \
        --prefix=${HOME}/prefix/ffmpeg \
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
        --enable-demuxer=ogg && \
    make -j $(nproc) && make install
RUN cd ${HOME}/prefix/ffmpeg && zip -r ${HOME}/zips/FFmpeg.zip ./*
RUN cp -rl ${HOME}/prefix/ffmpeg/* ${HOME}/prefix/

# Setup SDL2_VERSION
RUN mkdir -p ${HOME}/prefix/SDL2/lib
RUN wget -c https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.tar.gz -O - | tar -xz -C ${HOME}/src/ && \
    cd ${HOME}/src/SDL2-${SDL2_VERSION} && \
    ndk-build ${NDK_BUILD_FLAGS}
RUN cp ${HOME}/src/SDL2-${SDL2_VERSION}/libs/${ABI}/libSDL2.so ${HOME}/prefix/SDL2/lib/
RUN cp -rf ${HOME}/src/SDL2-${SDL2_VERSION}/include ${HOME}/prefix/SDL2/
RUN cd ${HOME}/prefix/SDL2 && zip -r ${HOME}/zips/SDL2.zip ./*
RUN cp -rl ${HOME}/prefix/SDL2/* ${HOME}/prefix/

# Setup BULLET
RUN mkdir -p ${HOME}/prefix/bullet
RUN wget -c https://github.com/bulletphysics/bullet3/archive/${BULLET_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/bullet3-${BULLET_VERSION}/build && cd $_ && \
    cmake ${HOME}/src/bullet3-${BULLET_VERSION} \
        ${COMMON_CMAKE_ARGS} \
        -DCMAKE_INSTALL_PREFIX=${HOME}/prefix/bullet \
        -DBUILD_BULLET2_DEMOS=OFF \
        -DBUILD_CPU_DEMOS=OFF \
        -DBUILD_UNIT_TESTS=OFF \
        -DBUILD_EXTRAS=OFF \
        -DUSE_DOUBLE_PRECISION=ON \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DBULLET2_MULTITHREADING=ON && \
    make -j $(nproc) && make install
RUN cd ${HOME}/prefix/bullet && zip -r ${HOME}/zips/Bullet.zip ./*
RUN cp -rl ${HOME}/prefix/bullet/* ${HOME}/prefix/

# Setup GL4ES_VERSION
RUN mkdir -p ${HOME}/prefix/gl4es/lib
RUN mkdir -p ${HOME}/prefix/gl4es/include/gl4es
RUN wget -c https://github.com/Duron27/gl4es/archive/refs/tags/${GL4ES_VERSION}.tar.gz -O - | tar -xz -C ${HOME}/src/
RUN cd ${HOME}/src/gl4es-${GL4ES_VERSION} && \
    ndk-build ${NDK_BUILD_FLAGS} && \
    cp libs/${ABI}/libGL.so ${HOME}/prefix/gl4es/lib/ && \
    cp -r ${HOME}/src/gl4es-${GL4ES_VERSION}/include ${HOME}/prefix/gl4es
RUN cd ${HOME}/prefix/gl4es/ && zip -r ${HOME}/zips/GL4ES.zip ./*
RUN cp -rl ${HOME}/prefix/gl4es/* ${HOME}/prefix/

# Setup MYGUI
RUN mkdir -p ${HOME}/prefix/mygui
RUN wget -c https://github.com/MyGUI/mygui/archive/MyGUI${MYGUI_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/mygui-MyGUI${MYGUI_VERSION}/build && cd $_ && \
    cmake ${HOME}/src/mygui-MyGUI${MYGUI_VERSION} \
        ${COMMON_CMAKE_ARGS} \
        -DMYGUI_RENDERSYSTEM=1 \
        -DMYGUI_BUILD_DEMOS=OFF \
        -DMYGUI_BUILD_TOOLS=OFF \
        -DMYGUI_BUILD_PLUGINS=OFF \
        -DMYGUI_DONT_USE_OBSOLETE=ON \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DCMAKE_INSTALL_PREFIX=${HOME}/prefix/mygui \
        -DMYGUI_STATIC=ON && \
    make -j $(nproc) && make install
RUN cd ${HOME}/prefix/mygui && zip -r ${HOME}/zips/MYGUI.zip ./*
RUN cp -rl ${HOME}/prefix/mygui/* ${HOME}/prefix/

# Setup LZ4
RUN mkdir -p ${HOME}/prefix/lz4
RUN wget -c https://github.com/lz4/lz4/archive/v${LZ4_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && \
    mkdir -p ${HOME}/src/lz4-${LZ4_VERSION}/build && cd $_ && \
    cmake ${HOME}/src/lz4-${LZ4_VERSION}/build/cmake/ \
        ${COMMON_CMAKE_ARGS} \
        -DBUILD_STATIC_LIBS=ON \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DCMAKE_INSTALL_PREFIX=${HOME}/prefix/lz4 \
        -DBUILD_SHARED_LIBS=OFF && \
    make -j $(nproc) && make install
RUN cd ${HOME}/prefix/lz4 && zip -r ${HOME}/zips/LZ4.zip ./*
RUN cp -rl ${HOME}/prefix/lz4/* ${HOME}/prefix/

# Setup LUAJIT_VERSION
RUN mkdir -p ${HOME}/prefix/luajit
RUN wget -c https://github.com/luaJit/LuaJIT/archive/v${LUAJIT_VERSION}.tar.gz -O - | tar -xz -C ${HOME}/src/ && \
    cd ${HOME}/src/LuaJIT-${LUAJIT_VERSION} && \
    make amalg \
    HOST_CC='gcc -m64' \
    CFLAGS= \
    TARGET_CFLAGS="${CFLAGS}" \
    PREFIX=${HOME}/prefix/luajit \
    CROSS=${TOOLCHAIN}/bin/llvm- \
    STATIC_CC=${NDK_TRIPLET}${API}-clang \
    DYNAMIC_CC='${NDK_TRIPLET}${API}-clang -fPIC' \
    TARGET_LD=${NDK_TRIPLET}${API}-clang && \
    make install \
    HOST_CC='gcc -m64' \
    CFLAGS= \
    TARGET_CFLAGS="${CFLAGS}" \
    PREFIX=${HOME}/prefix/luajit \
    CROSS=${TOOLCHAIN}/bin/llvm- \
    STATIC_CC=${NDK_TRIPLET}${API}-clang \
    DYNAMIC_CC='${NDK_TRIPLET}${API}-clang -fPIC' \
    TARGET_LD=${NDK_TRIPLET}${API}-clang
RUN bash -c "rm /root/prefix/luajit/lib/libluajit*.so*"
RUN cd ${HOME}/prefix/luajit && zip -r ${HOME}/zips/LUAjit.zip ./*
RUN cp -rl ${HOME}/prefix/luajit/* ${HOME}/prefix/

# Setup LIBCOLLADA_VERSION
RUN mkdir -p ${HOME}/prefix/libcollada
RUN wget -c https://github.com/rdiankov/collada-dom/archive/v${COLLADA_DOM_VERSION}.tar.gz -O - | tar -xz -C ${HOME}/src/ && cd ${HOME}/src/collada-dom-${COLLADA_DOM_VERSION} && \
    patch -ruN dom/external-libs/minizip-1.1/ioapi.h < /patches/libcollada-minizip-fix.patch && \
    mkdir -p ${HOME}/src/collada-dom-${COLLADA_DOM_VERSION}/build && cd $_ && \
    cmake .. \
        ${COMMON_CMAKE_ARGS} \
        -DBoost_USE_STATIC_LIBS=ON \
        -DBoost_USE_STATIC_RUNTIME=ON \
        -DBoost_NO_SYSTEM_PATHS=ON \
        -DBoost_INCLUDE_DIR=${PREFIX}/include \
        -DCMAKE_CXX_FLAGS=-Dauto_ptr=unique_ptr\ "${CXXFLAGS}" \
        -DCMAKE_INSTALL_PREFIX=${HOME}/prefix/libcollada && \
    make -j $(nproc) && make install
RUN cd ${HOME}/prefix/libcollada && zip -r ${HOME}/zips/Libcollada.zip ./*
RUN cp -rl ${HOME}/prefix/libcollada/* ${HOME}/prefix/

# Setup OPENSCENEGRAPH_VERSION
RUN mkdir -p ${HOME}/prefix/osg
RUN wget -c https://github.com/openmw/osg/archive/${OSG_VERSION}.tar.gz -O - | tar -xz -C ${HOME}/src/ && \
    mkdir -p ${HOME}/src/osg-${OSG_VERSION}/build && cd $_ && \
    patch -d ${HOME}/src/osg-${OSG_VERSION} -p1 -t -N < /patches/osg/osgcombined.patch && \
    patch -d ${HOME}/src/osg-${OSG_VERSION} -p1 -t -N < /patches/osg/mipmaps.patch && \
    cmake .. \
        ${COMMON_CMAKE_ARGS} \
        -DOPENGL_PROFILE=GL1 \
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
        -DOSG_CPP_EXCEPTIONS_AVAILABLE=TRUE \
        -DCMAKE_INSTALL_PREFIX=${HOME}/prefix/osg \
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
        -DOSG_FIND_3RD_PARTY_DEPS=OFF \
        -DOPENGL_INCLUDE_DIR=${PREFIX}/include/ \
        -DCMAKE_CXX_FLAGS=-Dauto_ptr=unique_ptr\ "${CXXFLAGS}" && \
    make -j $(nproc) && make install
RUN cd ${HOME}/prefix/osg && zip -r ${HOME}/zips/osg.zip ./*
RUN cp -rl ${HOME}/prefix/osg/* ${HOME}/prefix/

RUN cd root/src && git clone https://gitlab.com/bmwinger/delta-plugin && cd delta-plugin && cargo build --target ${NDK_TRIPLET} --release
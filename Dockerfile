# syntax=docker/dockerfile:labs
FROM rockylinux:9

#Set build type : release, debug
ENV BUILD_TYPE=release

# App versions - change settings here
ENV NDK_VERSION=r26b
ENV NDK_HASH=fdf33d9f6c1b3f16e5459d53a82c7d2201edbcc4

ENV LIBICU_VERSION=70-1
ENV LIBICU_HASH=554a3ac6d096d0b687b1753ddd25a8bc951f84d2

ENV ZLIB_VERSION=1.3.1
ENV ZLIB_HASH=a7991aa4cf4911817f50b7d0ad4e50dcc9867041

ENV LIBJPEG_TURBO_VERSION=3.0.2
ENV LIBJPEG_HASH=b6c5d5081ced8502eb1e1e72f1f5cc2856ce90ee

ENV LIBPNG_VERSION=1.6.42
ENV LIBPNG_HASH=9aba3f5ab7b83c02ec2055f68dc2c0348515c994

ENV FREETYPE2_VERSION=2.13.2
ENV FREETYPE2_HASH=7a26f7f2174f257afbfd4c88ec874621a0a84ea9

ENV LIBXML2_VERSION=2.12.5
ENV LIBXML2_HASH=de25470529d0a9a7cb2de78c39855134adf1d78a

ENV OPENAL_VERSION=1.23.1
ENV OPENAL_HASH=db17e5ea24792b3fcbbb04d8f0b28e9d1e28ea7b

ENV BOOST_VERSION=1.83.0
ENV BOOST_HASH=c72fe0c4cbd17c643c51d5d9d9bf5acc520eccf5

ENV FFMPEG_VERSION=6.1
ENV FFMPEG_HASH=1b2c93bed564b31da4d76794ec317a6a54978ab1

ENV SDL2_VERSION=2.24.0
ENV SDL2_HASH=04d7768f4418ba03537ef14a86a0c1c45582f5c3

ENV BULLET_VERSION=3.25
ENV BULLET_HASH=cd427218bc9244d60ce8ef73793c4e9df0bf8b9c

ENV GL4ES_VERSION=1.1.6
ENV GL4ES_HASH=66521506a90d6e543c92722780519a7987b253f9

ENV MYGUI_VERSION=3.4.3
ENV MYGUI_HASH=97ffe5ff84aae0149898d97b3df558ca324e834d

ENV LZ4_VERSION=1.9.3
ENV LZ4_HASH=5a19554ef404a609123b756ddcbbb677df838f05

ENV LUAJIT_VERSION=2.1.ROLLING
ENV LUAJIT_HASH=5f3268607255e43e6bfdbde61fc120b67539064f

ENV COLLADA_DOM_VERSION=2.5.0
ENV COLLADA_DOM_HASH=445568d00356d06dcee3869c443d27b0c9245948

ENV OSG_VERSION=69cfecebfb6dc703b42e8de39eed750a84a87489
ENV OSG_HASH=eecfc683c87cdb07f6607f7d2c8273d37dbe1ac6

# Install linux requirements
RUN dnf install -y dnf-plugins-core && dnf config-manager --set-enabled crb && dnf install -y epel-release
RUN dnf install -y https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-9.noarch.rpm \
    && dnf install -y xz p7zip bzip2 libstdc++-devel which glibc-devel zip unzip libcurl-devel wget doxygen gcc-c++ git cmake patch

RUN mkdir -p /build/{prefix,src,files,downloads}

# Set the build paths
ENV PREFIX=/build/prefix
ENV SRC=/build/src
ENV FILES=/build/files
ENV PATCHES=/build/patches
ENV DOWNLOADS=/build/downloads

# Download NDK and unzip
RUN cd /root && \
    wget -q https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip && \
    echo "Expected HASH" && sha1sum android-ndk-${NDK_VERSION}-linux.zip && \
    echo "${NDK_HASH} android-ndk-${NDK_VERSION}-linux.zip" | sha1sum -c - && \
    unzip -q android-ndk-${NDK_VERSION}-linux.zip && \
    rm android-ndk-${NDK_VERSION}-linux.zip

#Setup ICU for the Host
RUN cd ${SRC} && wget https://github.com/unicode-org/icu/archive/refs/tags/release-${LIBICU_VERSION}.zip && \
    echo "Expected HASH" && sha1sum release-${LIBICU_VERSION}.zip && \
    echo "${LIBICU_HASH} release-${LIBICU_VERSION}.zip" | sha1sum -c - && \
    unzip -o ${SRC}/release-${LIBICU_VERSION}.zip && rm -rf release-${LIBICU_VERSION}.zip
RUN mkdir -p ${SRC}/icu-host-build && cd $_ && ${SRC}/icu-release-70-1/icu4c/source/configure --disable-tests --disable-samples --disable-icuio --disable-extras CC="gcc" CXX="g++" && make -j $(nproc)

ENV PATH=$PATH:/root/android-ndk-${NDK_VERSION}/:/root/android-ndk-${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64:/root/android-ndk-${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin:${PREFIX}/include:${PREFIX}/lib:${PREFIX}/:$PATH

# NDK Settings
ENV API=24
ENV ABI=arm64-v8a
ENV ARCH=aarch64
ENV NDK_TRIPLET=${ARCH}-linux-android
ENV TOOLCHAIN=/root/android-ndk-${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64
ENV NDK_SYSROOT=${TOOLCHAIN}/sysroot/
ENV ANDROID_SYSROOT=${TOOLCHAIN}/sysroot/
# ANDROID_NDK is needed for SDL2 cmake
ENV ANDROID_NDK=/root/Android/ndk/${NDK_VERSION}/
ENV AR=${TOOLCHAIN}/bin/llvm-ar
ENV LD=${TOOLCHAIN}/bin/ld
ENV RANLIB=${TOOLCHAIN}/bin/llvm-ranlib
ENV STRIP=${TOOLCHAIN}/bin/llvm-strip
ENV CC=${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang
ENV CXX=${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang++
ENV clang=${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang
ENV clang++=${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang++
ENV PKG_CONFIG_LIBDIR=${PREFIX}/lib/pkgconfig

# Global C, CXX and LDFLAGS
ENV CFLAGS="-fPIC -O3 -flto=thin"
ENV CXXFLAGS="-fPIC -O3 -frtti -fexceptions -flto=thin"
ENV LDFLAGS="-fPIC -Wl,--undefined-version -flto=thin -fuse-ld=lld"

ENV COMMON_CMAKE_ARGS \
  "-DCMAKE_TOOLCHAIN_FILE=/root/android-ndk-${NDK_VERSION}/build/cmake/android.toolchain.cmake" \
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

COPY --chmod=0755 patches ${PATCHES}

# Setup LIBICU
RUN mkdir -p ${SRC}/icu-${LIBICU_VERSION} && cd $_ && \
    ${SRC}/icu-release-${LIBICU_VERSION}/icu4c/source/configure \
        ${COMMON_AUTOCONF_FLAGS} \
        --disable-tests \
        --disable-samples \
        --disable-icuio \
        --disable-extras \
        --with-cross-build=${SRC}/icu-host-build && \
    make -j $(nproc) check_PROGRAMS= bin_PROGRAMS= && \
    make install check_PROGRAMS= bin_PROGRAMS=

# Setup ZLIB
RUN cd ${DOWNLOADS} && wget -c https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum v${ZLIB_VERSION}.tar.gz && \
    echo "${ZLIB_HASH} v${ZLIB_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f v${ZLIB_VERSION}.tar.gz && \
    mkdir -p ${SRC}/zlib-${ZLIB_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} && \
    make -j $(nproc) && make install

# Setup LIBJPEG_TURBO
RUN cd ${DOWNLOADS} && wget -c https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${LIBJPEG_TURBO_VERSION}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz && \
    echo "${LIBJPEG_HASH} libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz && \
    mkdir -p ${SRC}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} \
        -DENABLE_SHARED=false && \
    make -j $(nproc) && make install

# Setup LIBPNG
RUN cd ${DOWNLOADS} && wget -c http://prdownloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum libpng-${LIBPNG_VERSION}.tar.gz && \
    echo "${LIBPNG_HASH} libpng-${LIBPNG_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f libpng-${LIBPNG_VERSION}.tar.gz && \
    mkdir -p ${SRC}/libpng-${LIBPNG_VERSION}/build && cd $_ && \
        ../configure \
        ${COMMON_AUTOCONF_FLAGS} && \
    make -j $(nproc) check_PROGRAMS= bin_PROGRAMS= && \
    make install check_PROGRAMS= bin_PROGRAMS=

# Setup FREETYPE2
RUN cd ${DOWNLOADS} && wget -c https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE2_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum freetype-${FREETYPE2_VERSION}.tar.gz && \
    echo "${FREETYPE2_HASH} freetype-${FREETYPE2_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f freetype-${FREETYPE2_VERSION}.tar.gz && \
    mkdir -p ${SRC}/freetype-${FREETYPE2_VERSION}/build && cd $_ && \
        ../configure \
        ${COMMON_AUTOCONF_FLAGS} \
        --with-png=no && \
    make -j $(nproc) && make install

# Setup LIBXML
RUN cd ${DOWNLOADS} && wget -c https://github.com/GNOME/libxml2/archive/refs/tags/v${LIBXML2_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum v${LIBXML2_VERSION}.tar.gz && \
    echo "${LIBXML2_HASH} v${LIBXML2_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f v${LIBXML2_VERSION}.tar.gz && \
    mkdir -p ${SRC}/libxml2-${LIBXML2_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} \
        -DBUILD_SHARED_LIBS=OFF \
        -DLIBXML2_WITH_THREADS=ON \
        -DLIBXML2_WITH_CATALOG=OFF \
        -DLIBXML2_WITH_ICONV=OFF \
        -DLIBXML2_WITH_LZMA=OFF \
        -DLIBXML2_WITH_PROGRAMS=OFF \
        -DLIBXML2_WITH_PYTHON=OFF \
        -DLIBXML2_WITH_TESTS=OFF \
        -DLIBXML2_WITH_ZLIB=ON && \
    make -j $(nproc) && make install

# Setup OPENAL
RUN cd ${DOWNLOADS} && wget -c https://github.com/kcat/openal-soft/archive/${OPENAL_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum ${OPENAL_VERSION}.tar.gz && \
    echo "${OPENAL_HASH} ${OPENAL_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f ${OPENAL_VERSION}.tar.gz && \
    mkdir -p ${SRC}/openal-soft-${OPENAL_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} \
        -DALSOFT_EXAMPLES=OFF \
        -DALSOFT_TESTS=OFF \
        -DALSOFT_UTILS=OFF \
        -DALSOFT_NO_CONFIG_UTIL=ON \
        -DALSOFT_BACKEND_OPENSL=ON \
        -DALSOFT_BACKEND_WAVE=OFF && \
    make -j $(nproc) && make install

# Setup BOOST
ENV JAM=${SRC}/boost-${BOOST_VERSION}/user-config.jam
RUN cd ${DOWNLOADS} && wget -c https://github.com/boostorg/boost/releases/download/boost-${BOOST_VERSION}/boost-${BOOST_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum boost-${BOOST_VERSION}.tar.gz && \
    echo "${BOOST_HASH} boost-${BOOST_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f boost-${BOOST_VERSION}.tar.gz && \
        cd ${SRC}/boost-${BOOST_VERSION} && \
        echo "using clang : ${ARCH} : ${TOOLCHAIN}/bin/${NDK_TRIPLET}${API}-clang++ ;" >> ${JAM} && \
    ./bootstrap.sh \
        --with-toolset=clang \
        prefix=${PREFIX} && \
    ./b2 \
        -j4 \
        --with-filesystem \
        --with-program_options \
        --with-system \
        --with-iostreams \
        --with-regex \
        --prefix=${PREFIX} \
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
RUN $RANLIB ${PREFIX}/lib/libboost_{system,filesystem,program_options,iostreams,regex}.a

# Setup FFMPEG_VERSION
RUN cd ${DOWNLOADS} && wget -c http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
    echo "Expected HASH" && sha1sum ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
    echo "${FFMPEG_HASH} ffmpeg-${FFMPEG_VERSION}.tar.bz2" | sha1sum -c - && \
    tar -xjf ffmpeg-${FFMPEG_VERSION}.tar.bz2 -C ${SRC}/ && \
    mkdir -p ${SRC}/ffmpeg-${FFMPEG_VERSION} && cd $_ && \
    ${SRC}/ffmpeg-${FFMPEG_VERSION}/configure \
        --disable-asm \
        --disable-optimizations \
        --target-os=android \
        --enable-cross-compile \
        --cross-prefix=${TOOLCHAIN}/bin/llvm- \
        --cc=${NDK_TRIPLET}${API}-clang \
        --arch=arm64 \
        --cpu=armv8-a \
        --prefix=${PREFIX} \
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

# Setup SDL2_VERSION
RUN cd ${DOWNLOADS} && wget -c https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum SDL2-${SDL2_VERSION}.tar.gz && \
    echo "${SDL2_HASH} SDL2-${SDL2_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f SDL2-${SDL2_VERSION}.tar.gz && \
    mkdir -p ${SRC}/SDL2-${SDL2_VERSION}/build && cd $_ && \
    cmake ../ ${COMMON_CMAKE_ARGS} \
        -DSDL_STATIC=OFF \
        -DCMAKE_C_FLAGS=-DHAVE_GCC_FVISIBILITY=OFF\ "${CFLAGS}" && \
    make -j $(nproc) && make install

# Setup BULLET
RUN cd ${DOWNLOADS} && wget -c https://github.com/bulletphysics/bullet3/archive/${BULLET_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum ${BULLET_VERSION}.tar.gz && \
    echo "${BULLET_HASH} ${BULLET_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f ${BULLET_VERSION}.tar.gz && \
    mkdir -p ${SRC}/bullet3-${BULLET_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} \
        -DBUILD_BULLET2_DEMOS=OFF \
        -DBUILD_CPU_DEMOS=OFF \
        -DBUILD_UNIT_TESTS=OFF \
        -DBUILD_EXTRAS=OFF \
        -DUSE_DOUBLE_PRECISION=ON \
        -DBULLET2_MULTITHREADING=ON && \
    make -j $(nproc) && make install

# Setup GL4ES_VERSION
RUN cd ${DOWNLOADS} && wget -c https://github.com/ptitSeb/gl4es/archive/refs/tags/v${GL4ES_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum v${GL4ES_VERSION}.tar.gz && \
    echo "${GL4ES_HASH} v${GL4ES_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f v${GL4ES_VERSION}.tar.gz
RUN cd ${SRC}/gl4es-${GL4ES_VERSION} && \
    patch -d . -p1 -t -N < ${PATCHES}/gl4es_enable_shaders.patch && \
    patch -d . -p1 -t -N < ${PATCHES}/gl4es_shared-library.patch && \
    ndk-build ${NDK_BUILD_FLAGS} && \
    cp libs/${ABI}/libGL.so ${PREFIX}/lib/ && \
    cp -r ${SRC}/gl4es-${GL4ES_VERSION}/include ${PREFIX} && \
    cp -r ${SRC}/gl4es-${GL4ES_VERSION}/include ${PREFIX}/include/gl4es/

# Setup MYGUI
RUN cd ${DOWNLOADS} && wget -c https://github.com/MyGUI/mygui/archive/MyGUI${MYGUI_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum MyGUI${MYGUI_VERSION}.tar.gz && \
    echo "${MYGUI_HASH} MyGUI${MYGUI_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f MyGUI${MYGUI_VERSION}.tar.gz && \
    mkdir -p ${SRC}/mygui-MyGUI${MYGUI_VERSION}/build && cd $_ && \
    cmake ../ \
        ${COMMON_CMAKE_ARGS} \
        -DMYGUI_RENDERSYSTEM=1 \
        -DMYGUI_BUILD_DEMOS=OFF \
        -DMYGUI_BUILD_TOOLS=OFF \
        -DMYGUI_BUILD_PLUGINS=OFF \
        -DMYGUI_DONT_USE_OBSOLETE=ON \
        -DMYGUI_STATIC=ON && \
    make -j $(nproc) && make install

# Setup LZ4
RUN cd ${DOWNLOADS} && wget -c https://github.com/lz4/lz4/archive/v${LZ4_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum v${LZ4_VERSION}.tar.gz && \
    echo "${LZ4_HASH} v${LZ4_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f v${LZ4_VERSION}.tar.gz && \
    mkdir -p ${SRC}/lz4-${LZ4_VERSION}/build && cd $_ && \
    cmake cmake/ \
        ${COMMON_CMAKE_ARGS} \
        -DBUILD_STATIC_LIBS=ON \
        -DBUILD_SHARED_LIBS=OFF && \
    make -j $(nproc) && make install

# Setup LUAJIT_VERSION
RUN cd ${DOWNLOADS} && wget -c https://github.com/luaJit/LuaJIT/archive/v${LUAJIT_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum v${LUAJIT_VERSION}.tar.gz && \
    echo "${LUAJIT_HASH} v${LUAJIT_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f v${LUAJIT_VERSION}.tar.gz && \
    cd ${SRC}/LuaJIT-${LUAJIT_VERSION} && \
    make amalg \
    HOST_CC='gcc -m64' \
    CFLAGS= \
    TARGET_CFLAGS="${CFLAGS}" \
    PREFIX=${PREFIX} \
    CROSS=${TOOLCHAIN}/bin/llvm- \
    STATIC_CC=${NDK_TRIPLET}${API}-clang \
    DYNAMIC_CC="${NDK_TRIPLET}${API}-clang -fPIC" \
    TARGET_LD=${NDK_TRIPLET}${API}-clang && \
    make install \
    HOST_CC='gcc -m64' \
    CFLAGS= \
    TARGET_CFLAGS="${CFLAGS}" \
    PREFIX=${PREFIX} \
    CROSS=${TOOLCHAIN}/bin/llvm- \
    STATIC_CC=${NDK_TRIPLET}${API}-clang \
    DYNAMIC_CC="${NDK_TRIPLET}${API}-clang -fPIC" \
    TARGET_LD=${NDK_TRIPLET}${API}-clang
RUN bash -c "rm ${PREFIX}/lib/libluajit*.so*"

# Setup LIBCOLLADA_VERSION
RUN cd ${DOWNLOADS} && wget -c https://github.com/rdiankov/collada-dom/archive/v${COLLADA_DOM_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum v${COLLADA_DOM_VERSION}.tar.gz && \
    echo "${COLLADA_DOM_HASH} v${COLLADA_DOM_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f v${COLLADA_DOM_VERSION}.tar.gz && \
    mkdir -p ${SRC}/collada-dom-${COLLADA_DOM_VERSION}/build && cd $_ && \
    cmake .. \
        ${COMMON_CMAKE_ARGS} \
        -DBoost_USE_STATIC_LIBS=ON \
        -DBoost_USE_STATIC_RUNTIME=ON \
        -DBoost_NO_SYSTEM_PATHS=ON \
        -DBoost_INCLUDE_DIR=${PREFIX}/include \
        -DCMAKE_CXX_FLAGS=-Dauto_ptr=unique_ptr\ "${CXXFLAGS}" && \
    make -j $(nproc) && make install

# Setup OPENSCENEGRAPH_VERSION
RUN cd ${DOWNLOADS} && wget -c https://github.com/openmw/osg/archive/${OSG_VERSION}.tar.gz && \
    echo "Expected HASH" && sha1sum ${OSG_VERSION}.tar.gz && \
    echo "${OSG_HASH} ${OSG_VERSION}.tar.gz" | sha1sum -c - && \
    tar -xz -C ${SRC}/ -f ${OSG_VERSION}.tar.gz && \
    mkdir -p ${SRC}/osg-${OSG_VERSION}/build && cd $_ && \
    patch -d ${SRC}/osg-${OSG_VERSION} -p1 -t -N < ${PATCHES}/osg_std_atomic.patch && \
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
        -DCMAKE_CXX_FLAGS=-Dauto_ptr=unique_ptr\ -I${PREFIX}/include/freetype2/\ "${CXXFLAGS}" && \
    make -j $(nproc) && make install

# create the TAR!
RUN cd ${PREFIX} && tar -cJf ${FILES}/openmw_android_deps.tar.xz ./*

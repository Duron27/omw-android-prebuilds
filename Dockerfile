# syntax=docker/dockerfile:labs
FROM fedora:39

#Set build type : release, debug
ENV BUILD_TYPE=release

# App versions - change settings here
ENV LIBJPEG_TURBO_VERSION=1.5.3
ENV LIBPNG_VERSION=1.6.37
ENV FREETYPE2_VERSION=2.10.4
ENV OPENAL_VERSION=1.23.1
ENV BOOST_VERSION=1.83.0
ENV LIBICU_VERSION=70-1
ENV FFMPEG_VERSION=4.4
ENV SDL2_VERSION=2.0.22
ENV BULLET_VERSION=3.25
ENV ZLIB_VERSION=1.3.1
ENV LIBXML2_VERSION=2.12.4
ENV MYGUI_VERSION=3.4.3
ENV GL4ES_VERSION=5ac069d82ad8ca2cc3c574484e4c5bad880db83e
ENV COLLADA_DOM_VERSION=2.5.0
ENV OSG_VERSION=69cfecebfb6dc703b42e8de39eed750a84a87489
ENV LZ4_VERSION=1.9.3
ENV LUAJIT_VERSION=2.1.ROLLING
ENV OPENMW_VERSION=19a6fd4e1be0b9928940a575f00d31b5af76beb5
ENV NDK_VERSION=26.1.10909125
ENV SDK_CMDLINE_TOOLS=10406996_latest
ENV PLATFORM_TOOLS_VERSION=29.0.0
ENV JAVA_VERSION=17

RUN dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    && dnf install -y xz bzip2 unzip which wget redhat-lsb-core python-devel nano git java-${JAVA_VERSION}-openjdk\
    gcc-c++ cmake

ENV JAVA_HOME /usr/lib/jvm/java-17-openjdk-17.0.9.0.9-3.fc39.x86_64

RUN mkdir -p $HOME/build
RUN mkdir -p $HOME/downloads
RUN mkdir -p $HOME/prefix
RUN mkdir -p $HOME/src

# Set the installation Dir
ENV PREFIX=/root/prefix

RUN cd $HOME/src && wget https://github.com/unicode-org/icu/archive/refs/tags/release-${LIBICU_VERSION}.zip && unzip -o $HOME/src/release-${LIBICU_VERSION}.zip && rm -rf release-${LIBICU_VERSION}.zip
RUN wget https://dl.google.com/android/repository/commandlinetools-linux-${SDK_CMDLINE_TOOLS}.zip && unzip commandlinetools-linux-${SDK_CMDLINE_TOOLS}.zip && mkdir -p $HOME/Android/cmdline-tools/ && mv cmdline-tools/ $HOME/Android/cmdline-tools/latest && rm commandlinetools-linux-${SDK_CMDLINE_TOOLS}.zip
RUN yes | ~/Android/cmdline-tools/latest/bin/sdkmanager --licenses
RUN ~/Android/cmdline-tools/latest/bin/sdkmanager --install "ndk;${NDK_VERSION}" --channel=0
#RUN wget https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip

#Setup ICU for the Host
RUN mkdir -p $HOME/build/icu-host-build && cd $_ && $HOME/src/icu-release-70-1/icu4c/source/configure --disable-tests --disable-samples --disable-icuio --disable-extras CC="gcc" CXX="g++" && make -j $(nproc)

#RUN dnf remove -y gcc g++  --noautoremove

#COPY --chmod=0755 openmw-android /openmw-android
ENV PATH=$PATH:/root/Android/cmdline-tools/latest/bin/
ENV PATH=$PATH:/root/Android/ndk/${NDK_VERSION}/
ENV PATH=$PATH:/root/Android/ndk/${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64
ENV PATH=$PATH:/root/Android/ndk/${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin
ENV PATH=$PATH:/root/prefix/include:/root/prefix/lib:/root/prefix/

# NDK Settings
ENV API=21
ENV ABI=arm64-v8a
ENV NDK_TRIPLET=aarch64-linux-android
ENV TOOLCHAIN=/root/Android/ndk/${NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64
ENV AR=llvm-ar
ENV LD=ld
ENV RANLIB=llvm-ranlib
ENV STRIP=llvm-strip
ENV CC=${NDK_TRIPLET}-gcc
ENV CXX=${NDK_TRIPLET}-g++

# symlink gcc to clang
RUN ln -s ${NDK_TRIPLET}${API}-clang ${TOOLCHAIN}/bin/${NDK_TRIPLET}-gcc
RUN ln -s ${NDK_TRIPLET}${API}-clang++ ${TOOLCHAIN}/bin/${NDK_TRIPLET}-g++

# Global C, CXX and LDFLAGS
ENV CFLAGS="-fPIC -O3"
ENV CXXFLAGS="-fPIC -frtti -fexceptions -O3"
ENV LDFLAGS="-fPIC -Wl,--undefined-version"

ENV COMMON_CMAKE_ARGS=" \
    -DCMAKE_TOOLCHAIN_FILE=/root/Android/ndk/$NDK_VERSION/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=$ABI \
    -DANDROID_PLATFORM=android-$API \
    -DANDROID_STL=c++_shared \
    -DANDROID_CPP_FEATURES= \
    -DANDROID_ALLOW_UNDEFINED_VERSION_SCRIPT_SYMBOLS=ON \
    -DCMAKE_C_FLAGS= \
    -DCMAKE_CXX_FLAGS= \
    -DCMAKE_SHARED_LINKER_FLAGS=$LDFLAGS \
    -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
    -DCMAKE_DEBUG_POSTFIX= \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DCMAKE_FIND_ROOT_PATH=$PREFIX \
    -DCMAKE_CXX_COMPILER=${NDK_TRIPLET}${API}-clang++ \
    -DCMAKE_CC_COMPILER=${NDK_TRIPLET}${API}-clang \
    -DHAVE_LD_VERSION_SCRIPT=OFF"


ENV COMMON_AUTOCONF_FLAGS="--enable-static --disable-shared --prefix=${PREFIX} --host=${NDK_TRIPLET} --build=x86_64-linux-gnu CC=${NDK_TRIPLET}${API}-clang CXX=${NDK_TRIPLET}${API}-clang++"

ENV NDK_BUILD_FLAGS=" \
    NDK_PROJECT_PATH=. \
    APP_BUILD_SCRIPT=./Android.mk \
    APP_PLATFORM=${API} \
    APP_ABI=${ABI} \
    APP_LD=deprecated"

ENV LIBICU_FLAGS=" \
    --disable-tests \
    --disable-samples \
    --disable-icuio \
    --disable-extras \
    --with-cross-build=/root/build/icu-host-build"

ENV OPENAL_FLAGS=" \
    -DALSOFT_EXAMPLES=OFF \
    -DALSOFT_TESTS=OFF \
    -DALSOFT_UTILS=OFF \
    -DALSOFT_NO_CONFIG_UTIL=ON \
    -DALSOFT_BACKEND_OPENSL=ON \
    -DALSOFT_BACKEND_WAVE=OFF"

ENV BOOST_FLAGS=" \
    -j4 \
    binary-format=elf \
    --with-filesystem \
    --with-program_options \
    --with-system \
    --with-regex \
    --with-iostreams \
    --prefix=${PREFIX} \
    --ignore-site-config \
    toolset=clang \
    architecture=arm \
    address-model=64 \
    abi=aapcs \
    cflags= \
    cxxflags=--target=${NDK_TRIPLET} \
    variant=release \
    target-os=android \
    threading=multi \
    threadapi=pthread \
    link=static \
    runtime-link=static \
    install"

ENV CMAKE_BOOST_FLAGS=" \
    -DBOOST_INCLUDE_LIBRARIES=filesystem;iostreams;system;program_options \
    -DBOOST_RUNTIME_LINK=static"

ENV FFMPEG_FLAGS=" \
    --disable-asm \
    --disable-optimizations \
    --target-os=android \
    --enable-cross-compile \
    --cross-prefix=llvm- \
    --cc=${NDK_TRIPLET}${API}-clang \
    --arch=arm64 \
    --cpu=armv8-a \
    --prefix=/root/prefix \
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

ENV BULLET_FLAGS=" \
    -DBUILD_BULLET2_DEMOS=OFF \
    -DBUILD_CPU_DEMOS=OFF \
    -DBUILD_UNIT_TESTS=OFF \
    -DBUILD_EXTRAS=OFF \
    -DUSE_DOUBLE_PRECISION=ON \
    -DBULLET2_MULTITHREADING=ON"

ENV MYGUI_FLAGS=" \
    -DMYGUI_RENDERSYSTEM=1 \
    -DMYGUI_BUILD_DEMOS=OFF \
    -DMYGUI_BUILD_TOOLS=OFF \
    -DMYGUI_BUILD_PLUGINS=OFF \
    -DMYGUI_DONT_USE_OBSOLETE=ON \
    -DMYGUI_STATIC=ON"

ENV LIBXML_FLAGS=" \
    -DBUILD_SHARED_LIBS=OFF \
    -DLIBXML2_WITH_CATALOG=OFF \
    -DLIBXML2_WITH_ICONV=OFF \
    -DLIBXML2_WITH_LZMA=OFF \
    -DLIBXML2_WITH_PROGRAMS=OFF \
    -DLIBXML2_WITH_PYTHON=OFF \
    -DLIBXML2_WITH_TESTS=OFF \
    -DLIBXML2_WITH_ZLIB=ON"

ENV COLLADA_FLAGS=" \
    -DBoost_USE_STATIC_LIBS=ON \
    -DBoost_USE_STATIC_RUNTIME=ON \
    -DBoost_NO_SYSTEM_PATHS=ON \
    -DHAVE_STRTOQ=0 \
    -DUSE_FILE32API=1 \
    -DBoost_INCLUDE_DIR=/root/prefix/include \
    -DCMAKE_CXX_FLAGS=-Dauto_ptr=unique_ptr"

ENV OSG_FLAGS=" \
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
    -DOPENGL_INCLUDE_DIR=${PREFIX}/include/gl4es/ \
    -DCMAKE_CXX_FLAGS=-std=gnu++11"

#patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/osg/disable-polygon-offset.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/osg/remove-lib-prefix-from-plugins.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/osg/fix-freetype-include-dirs.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/osg/0001-Replace-Atomic-impl-with-std-atomic.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/osg/0002-BufferObject-make-numClients-atomic.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/osg/0004-IncrementalCompileOperation-wrap-some-stuff-in-atomi.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/osg/remove-zlib-dependency.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/osg/force-add-plugins.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/osg/dae_collada.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/osg/psa.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/osg/0005-CullSettings-make-inheritanceMask-atomic-to-silence-.patch

ENV OPENMW_FLAGS=" \
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
    -DOSG_STATIC=TRUE"

#patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/openmw/gamma.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N -R < ${CMAKE_SOURCE_DIR}/patches/openmw/sdlfix.patch \
#	patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/openmw/cmakefix.patch \
#	patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/openmw/0001-loadingscreen-disable-for-now.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/openmw/0009-windowmanagerimp-always-show-mouse-when-possible-pat.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/openmw/0010-android-fix-context-being-lost-on-app-minimize.patch \
#	#patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/openmw/0012-components-misc-stringops-use-boost-format-instead-o.patch \
#	patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/openmw/fix-build.patch \
#    patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/openmw/psa.patch \
#	#patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/openmw/refraction-fix.patch \
#	cp ${CMAKE_SOURCE_DIR}/patches/openmw/android_main.cpp <SOURCE_DIR>/apps/openmw/android_main.cpp

#RUN export CC=${NDK_TRIPLET}${API}-clang CXX=${NDK_TRIPLET}${API}-clang++

#ENV LUAJIT_FLAGS="CROSS=${NDK_TRIPLET}${API}- STATIC_CC=${NDK_TRIPLET}${API}-clang DYNAMIC_CC='${NDK_TRIPLET}${API}-clang\ -fPIC' TARGET_LD=${NDK_TRIPLET}${API}-clang TARGET_AR='llvm-ar\ rcus' TARGET_STRIP=llvm-strip"

# Setup Bzip2
#RUN cd $HOME/src/ && git clone https://github.com/libarchive/bzip2 && cd bzip2 && cmake . ${COMMON_CMAKE_ARGS} && make -j $(nproc) && make install

# Setup LIBICU
RUN mkdir -p $HOME/build/icu-release-${LIBICU_VERSION} && cd $_ && $HOME/src/icu-release-70-1/icu4c/source/configure ${COMMON_AUTOCONF_FLAGS} ${LIBICU_FLAGS} && make -j $(nproc) check_PROGRAMS= bin_PROGRAMS= && make install check_PROGRAMS= bin_PROGRAMS=

# Setup ZLIB_VERSION
RUN wget -c https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && cd $HOME/src/zlib-${ZLIB_VERSION} && mkdir -p $HOME/build/zlib-${ZLIB_VERSION} && cd $_ && cmake $HOME/src/zlib-${ZLIB_VERSION} ${COMMON_CMAKE_ARGS} && make -j $(nproc) && make install

# Setup LIBJPEG_TURBO_VERSION
RUN wget -c https://sourceforge.net/projects/libjpeg-turbo/files/${LIBJPEG_TURBO_VERSION}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz  -O - | tar -xz -C $HOME/src/ && mkdir -p $HOME/build/libjpeg-turbo-${LIBJPEG_TURBO_VERSION} && cd $_ && $HOME/src/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}/configure ${COMMON_AUTOCONF_FLAGS} --without-simd && make -j $(nproc) check_PROGRAMS= bin_PROGRAMS= && make install check_PROGRAMS= bin_PROGRAMS=

# Setup LIBPNG_VERSION
RUN wget -c http://prdownloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && mkdir -p $HOME/build/libpng-${LIBPNG_VERSION} && cd $_ && $HOME/src/libpng-${LIBPNG_VERSION}/configure ${COMMON_AUTOCONF_FLAGS} && make -j $(nproc) check_PROGRAMS= bin_PROGRAMS= && make install check_PROGRAMS= bin_PROGRAMS=

# Setup FREETYPE2_VERSION
RUN wget -c https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE2_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && mkdir -p $HOME/build/freetype-${FREETYPE2_VERSION} && cd $_ && $HOME/src/freetype-${FREETYPE2_VERSION}/configure ${COMMON_AUTOCONF_FLAGS} --with-png=no && make -j $(nproc) && make install

# Setup OPENAL_VERSION
RUN wget -c https://github.com/kcat/openal-soft/archive/${OPENAL_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && mkdir -p $HOME/build/openal-soft-${OPENAL_VERSION} && cd $_ && cmake $HOME/src/openal-soft-${OPENAL_VERSION} ${COMMON_CMAKE_ARGS} $OPENAL_FLAGS && make -j $(nproc) && make install

# Setup BOOST_VERSION
#RUN wget -c https://github.com/boostorg/boost/releases/download/boost-${BOOST_VERSION}/boost-${BOOST_VERSION}.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/boost-${BOOST_VERSION} && ./bootstrap.sh --with-toolset=clang --prefix=${PREFIX} && ./b2 ${BOOST_FLAGS}

#RUN wget -c https://github.com/boostorg/boost/releases/download/boost-$BOOST_VERSION/boost-$BOOST_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/boost-$BOOST_VERSION && ./bootstrap.sh --prefix=$PREFIX --with-toolset=clang && echo using clang : arm : aarch64-linux-android21-clang++ ; >> project-config.jam && ./b2 --prefix=$PREFIX $BOOST_FLAGS --cxx="$TOOLCHAIN/bin/$NDK_TRIPLET$API-clang++ -fPIC"

#RUN wget -c https://github.com/boostorg/boost/releases/download/boost-${BOOST_VERSION}/boost-${BOOST_VERSION}.tar.gz -O - | tar -xz -C $HOME/build/ && mkdir -p $HOME/build/boost-${BOOST_VERSION}/build && cd $_ && cmake .. ${COMMON_CMAKE_ARGS} $CMAKE_BOOST_FLAGS && cmake --build . --target install --config Release -j $(nproc)

RUN cd /root/src/ && wget -c  https://github.com/dec1/Boost-for-Android/releases/download/ndk_26b_boost_1.83.0/ndk_26b_boost_1.83.0.zip && unzip ndk_26b_boost_1.83.0.zip && cd /root/src/ndk_26c_boost_1.83.0/include/ && mv boost /root/prefix/include && cd /root/src/ndk_26c_boost_1.83.0/libs/arm64-v8a/static/ && cp -r * /root/prefix/lib/

RUN $RANLIB ${PREFIX}/lib/libboost_filesystem.a
RUN $RANLIB ${PREFIX}/lib/libboost_program_options.a
RUN $RANLIB ${PREFIX}/lib/libboost_system.a
RUN $RANLIB ${PREFIX}/lib/libboost_iostreams.a
RUN $RANLIB ${PREFIX}/lib/libboost_regex.a

#RUN mkdir -p /root/prefix/lib && cd $_ && unzip /boost.zip

# Setup FFMPEG_VERSION
RUN wget -c http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 -O - | tar -xjf - -C $HOME/src/ && mkdir -p $HOME/build/ffmpeg-${FFMPEG_VERSION} && cd $_ && $HOME/src/ffmpeg-${FFMPEG_VERSION}/configure ${FFMPEG_FLAGS} && make -j $(nproc) && make install

# Setup SDL2_VERSION
RUN wget -c https://www.libsdl.org/release/SDL2-${SDL2_VERSION}.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/SDL2-${SDL2_VERSION} && ndk-build ${NDK_BUILD_FLAGS}
RUN cp $HOME/build/SDL2-${SDL2_VERSION}/libs/${ABI}/libSDL2.so /root/prefix/lib/
RUN cp -rf $HOME/build/SDL2-${SDL2_VERSION}/include /root/prefix/

# Setup BULLET_VERSION
RUN wget -c https://github.com/bulletphysics/bullet3/archive/${BULLET_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && mkdir -p $HOME/build/bullet3-${BULLET_VERSION} && cd $_ && cmake $HOME/src/bullet3-${BULLET_VERSION} ${COMMON_CMAKE_ARGS} ${BULLET_FLAGS} && make -j $(nproc) && make install

# Setup GL4ES_VERSION
RUN wget -c https://github.com/sisah2/gl4es/archive/${GL4ES_VERSION}.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/gl4es-${GL4ES_VERSION} && ndk-build ${NDK_BUILD_FLAGS} && cp libs/${ABI}/libGL.so /root/prefix/lib/ && cp -r $HOME/build/gl4es-${GL4ES_VERSION}/include /root/prefix/include/gl4es/ && cp -r $HOME/build/gl4es-${GL4ES_VERSION}/include /root/prefix/

# Setup MYGUI_VERSION
RUN wget -c https://github.com/MyGUI/mygui/archive/MyGUI${MYGUI_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && mkdir -p $HOME/build/mygui-MyGUI${MYGUI_VERSION} && cd $_ && cmake $HOME/src/mygui-MyGUI${MYGUI_VERSION} ${COMMON_CMAKE_ARGS} ${MYGUI_FLAGS} && make -j $(nproc) && make install

# Setup LZ4_VERSION
RUN wget -c https://github.com/lz4/lz4/archive/v${LZ4_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && mkdir -p $HOME/build/lz4-${LZ4_VERSION} && cd $_ && cmake $HOME/src/lz4-${LZ4_VERSION}/build/cmake/ ${COMMON_CMAKE_ARGS} -DBUILD_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=OFF && make -j $(nproc) && make install

# Setup LUAJIT_VERSION
RUN wget -c https://github.com/luaJit/LuaJIT/archive/v${LUAJIT_VERSION}.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/LuaJIT-${LUAJIT_VERSION} && make PREFIX=${PREFIX} amalg CROSS=${NDK_TRIPLET}${API}- STATIC_CC=${NDK_TRIPLET}${API}-clang DYNAMIC_CC='${NDK_TRIPLET}${API}-clang -fPIC' TARGET_LD=${NDK_TRIPLET}${API}-clang TARGET_AR='llvm-ar rcus' TARGET_STRIP=llvm-strip && make install PREFIX=${PREFIX} CROSS=${NDK_TRIPLET}${API}- STATIC_CC=${NDK_TRIPLET}${API}-clang DYNAMIC_CC='${NDK_TRIPLET}${API}-clang -fPIC' TARGET_LD=${NDK_TRIPLET}${API}-clang TARGET_AR='llvm-ar rcus' TARGET_STRIP=llvm-strip
#RUN bash -c "rm /root/prefix/lib/libluajit*.so*"

# Setup LIBXML_VERSION
RUN wget -c https://github.com/GNOME/libxml2/archive/refs/tags/v${LIBXML2_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && mkdir -p $HOME/build/libxml2-${LIBXML2_VERSION} && cd $_ && cmake $HOME/src/libxml2-${LIBXML2_VERSION} ${COMMON_CMAKE_ARGS} ${LIBXML_FLAGS} && make -j $(nproc) && make install

# Setup LIBCOLLADA_VERSION
RUN wget -c https://github.com/rdiankov/collada-dom/archive/v${COLLADA_DOM_VERSION}.tar.gz -O - | tar -xz -C $HOME/src/ && cd $HOME/src/collada-dom-${COLLADA_DOM_VERSION} && wget https://raw.githubusercontent.com/Duron27/Dockers/experimental/libcollada-minizip-fix.patch && patch -ruN dom/external-libs/minizip-1.1/ioapi.h < libcollada-minizip-fix.patch && mkdir -p $HOME/src/collada-dom-${COLLADA_DOM_VERSION}/build && cd $_ && cmake .. ${COMMON_CMAKE_ARGS} ${COLLADA_FLAGS} && make -j $(nproc) && make install

# Setup OPENSCENEGRAPH_VERSION
RUN wget -c https://github.com/openmw/osg/archive/$OSG_VERSION.tar.gz -O - | tar -xz -C $HOME/build/ && mkdir -p $HOME/build/osg-${OSG_VERSION}/build && cd $_ && cmake .. ${COMMON_CMAKE_ARGS} ${OSG_FLAGS} && make -j $(nproc) && make install

# Setup OPENMW_VERSION
#RUN wget -c https://github.com/OpenMW/openmw/archive/${OPENMW_VERSION}.tar.gz -O - | tar -xz -C $HOME/build/ && cd $HOME/build/openmw-${OPENMW_VERSION}
#RUN cd $HOME/build/openmw && cmake ${COMMON_CMAKE_ARGS} ${OPENMW_FLAGS}
#RUN make

#!/bin/bash
#
# build-libssh2.sh
# Copyright © 2020 Dmitriy Borovikov. All rights reserved.
#

source "$ROOT_PATH/script/build-commons"

set -e

if [[ -f "$BUILT_PRODUCTS_DIR/lib/libssh2.a" ]]; then
    echo "$PLATFORM libssh2 already build"
    exit 0
fi

CLANG=$(xcrun --find clang)
export CLANG
DEVELOPER=$(xcode-select --print-path)
export DEVELOPER
mkdir -p "$BUILT_PRODUCTS_DIR"

for ARCH in $ARCHS
do
    OPENSSLDIR="$BUILT_PRODUCTS_DIR/"
    PLATFORM_SRC="$LIBSSHDIR/${PLATFORM}$EFFECTIVE_PLATFORM_NAME-$ARCH/src"
    PLATFORM_OUT="$LIBSSHDIR/${PLATFORM}$EFFECTIVE_PLATFORM_NAME-$ARCH/install"
    LOG="$BUILT_PRODUCTS_DIR/$PLATFORM$EFFECTIVE_PLATFORM_NAME-$ARCH-libssh2-build.log"
    LIPO_SSH2="$LIPO_SSH2 $PLATFORM_OUT/lib/libssh2.a"

    mkdir -p "$PLATFORM_SRC"
    mkdir -p "$PLATFORM_OUT"
    cp -R "$LIBSSH_SOURCE" "$PLATFORM_SRC"
    cd "$PLATFORM_SRC"

    touch "$LOG"
    echo "LOG: $LOG"
    
    if [[ "$ARCH" == arm64* ]]; then
      HOST="aarch64-apple-darwin"
    else
      HOST="$ARCH-apple-darwin"
    fi

    export DEVROOT="$DEVELOPER/Platforms/$PLATFORM.platform/Developer"
    export SDKROOT="$DEVROOT/SDKs/$PLATFORM.sdk"
    export CC="$CLANG"
    export CPP="$CLANG -E"

    # libssh2 after 1.11.1 turns these off by default; keep what 1.11.1
    # negotiated so older servers and legacy (PEM, DSA) keys still work.
    # The rest it drops (3DES, Blowfish, RC4, CAST, RIPEMD, MD5 MACs) stay off.
    COMPAT_FLAGS="-DLIBSSH2_RSA_SHA1_ENABLE -DLIBSSH2_KEX_SHA1_ENABLE -DLIBSSH2_HMAC_SHA1_ENABLE -DLIBSSH2_MD5_PEM_ENABLE -DLIBSSH2_DSA_ENABLE"
    export CFLAGS="-arch $ARCH -pipe -no-cpp-precomp -isysroot $SDKROOT $COMPAT_FLAGS"
    export CPPFLAGS="-arch $ARCH -pipe -no-cpp-precomp -isysroot $SDKROOT"

    if [[ "$SDK_PLATFORM" != "xros" ]] && [[ "$SDK_PLATFORM" != "xrsimulator" ]]; then
      export CFLAGS="$CFLAGS -m$SDK_PLATFORM-version-min=$MIN_VERSION"
      export CPPFLAGS="$CPPFLAGS -m$SDK_PLATFORM-version-min=$MIN_VERSION"
    fi

    if [[ "$EFFECTIVE_PLATFORM_NAME" == "-maccatalyst" ]]; then
        EXTRAFLAGS="-target $ARCH-apple-ios13.1-macabi -Wno-overriding-t-option"
        CFLAGS="${CFLAGS} ${EXTRAFLAGS}"
        CPPFLAGS="${CPPFLAGS} ${EXTRAFLAGS}"
    fi

    if [[ $(./configure --help | grep -c -- --with-openssl) -eq 0 ]]; then
      CRYPTO_BACKEND_OPTION="--with-crypto=openssl"
    else
      CRYPTO_BACKEND_OPTION="--with-openssl"
    fi


    {
      {
        ./configure \
          --host="$HOST" \
          --prefix="$PLATFORM_OUT" \
          --disable-debug \
          --disable-dependency-tracking \
          --disable-silent-rules \
          --disable-examples-build \
          --without-libz "$CRYPTO_BACKEND_OPTION" \
          --with-libssl-prefix="$OPENSSLDIR" \
          --disable-shared \
          --enable-static 
      } >> "$LOG" 
    } 2>&1

    make >> "$LOG" 2>&1
    make -j "$BUILD_THREADS" install >> "$LOG" 2>&1

    echo "Libssh2 - $PLATFORM $ARCH done."
done

buildFatLibrary "$LIPO_SSH2" "$BUILT_PRODUCTS_DIR/lib/libssh.a"
copyHeaders "$LIBSSH_SOURCE/include/" "$BUILT_PRODUCTS_DIR/include"
cp "$ROOT_PATH/script/module.modulemap" "$BUILT_PRODUCTS_DIR/include"
cd "$BUILT_PRODUCTS_DIR/lib"
libtool -static -D -o libssh2.a libssh.a libssl.a libcrypto.a >> "$LOG" 2>&1

echo "Libssh2 - $PLATFORM done."

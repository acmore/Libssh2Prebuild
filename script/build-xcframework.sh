#!/bin/zsh
#
# build_xctframework.sh
# Copyright © 2023 Dmitriy Borovikov. All rights reserved.
#

#Functions
fetchSource () {
  local url=$1
  local filename=$2
  local dstpath=$3
  local file=$BUILD/$filename

  mkdir -p "$dstpath"
  echo "Downloading $filename"
  curl -L -S -s "$url" --output "$file"
  local md5
  md5=$(md5 -q "$file")
  echo "MD5: $md5"

  tar -zxkf "$file" -C "$dstpath" --strip-components 1 2>&-
  rm -f "$file"
}

buildLibrary () {
  export BUILT_PRODUCTS_DIR=$1
  export SDK_PLATFORM=$2
  export PLATFORM=$3
  export EFFECTIVE_PLATFORM_NAME=$4
  export ARCHS=$5
  export MIN_VERSION=$6

  "$ROOT_PATH/script/build-openssl.sh"
  "$ROOT_PATH/script/build-libssh2.sh"

  rm -rf "$TEMPPATH"
}


#====================================================================#

set -e

#Config

BUILD_THREADS=$(sysctl hw.ncpu | awk '{print $2}')
export BUILD_THREADS
LIBSSH_TAG=$1
LIBSSL_TAG=$2
DATE=$3

# Sigmux fork: iOS device/simulator + macOS only.
VISION_OS=1

if [[ $VISION_OS == 0 ]]; then
    echo Vision OS available
fi

TAG=$LIBSSH_TAG-$LIBSSL_TAG
TAG=${TAG//_/-}
ZIPNAME=CSSH-$TAG.xcframework.zip
GIT_REMOTE_URL_UNFINISHED=$(git config --get remote.origin.url|sed "s=^ssh://==; s=^https://==; s=:=/=; s/git@//; s/.git$//;")
DOWNLOAD_URL=https://$GIT_REMOTE_URL_UNFINISHED/releases/download/$TAG/$ZIPNAME

ROOT_PATH=$(cd "$(dirname "$0")/.."; pwd -P)
export ROOT_PATH
pushd "$ROOT_PATH" > /dev/null

export BUILD=$ROOT_PATH/build
export TEMPPATH=$ROOT_PATH/temp

export LIBSSLDIR="$TEMPPATH/openssl"
export LIBSSHDIR="$TEMPPATH/libssh2"
export OPENSSL_SOURCE="$BUILD/openssl/src/"
export LIBSSH_SOURCE="$BUILD/libssh2/src/"

#Download

if [[ -d "$OPENSSL_SOURCE" ]] && [[ -d "$LIBSSH_SOURCE" ]]; then
  echo "Sources already downloaded"
else
  fetchSource "https://github.com/libssh2/libssh2/releases/download/libssh2-$LIBSSH_TAG/libssh2-$LIBSSH_TAG.tar.gz" "libssh2.tar.gz" "$LIBSSH_SOURCE"
  fetchSource "https://github.com/openssl/openssl/archive/$LIBSSL_TAG.tar.gz" "openssl.tar.gz" "$OPENSSL_SOURCE"
fi

#Build

#buildLibrary () {
#export BUILT_PRODUCTS_DIR=$1
#export SDK_PLATFORM=$2
#export PLATFORM=$3
#export EFFECTIVE_PLATFORM_NAME=$4
#export ARCHS=$5
#export MIN_VERSION=$6

buildLibrary "$BUILD/iphoneos" "iphoneos" "iPhoneOS" "" "arm64" "13.0"
buildLibrary "$BUILD/iphonesimulator" "iphonesimulator" "iPhoneSimulator" "" "x86_64 arm64" "13.0"
buildLibrary "$BUILD/macosx" "macosx" "MacOSX" "" "x86_64 arm64" "10.15"

xcodebuild -create-xcframework \
 -library "$BUILD/macosx/lib/libssh2.a" \
 -headers "$BUILD/macosx/include" \
 -library "$BUILD/iphoneos/lib/libssh2.a" \
 -headers "$BUILD/iphoneos/include" \
 -library "$BUILD/iphonesimulator/lib/libssh2.a" \
 -headers "$BUILD/iphonesimulator/include" \
 -output $BUILD/CSSH.xcframework

XCODE_STRING=$(xcodebuild -version 2>&1| tail -n 2)
XCODE_STRING=${XCODE_STRING//[$'\t\r\n']/ }
VERSION_STRING="Archive date:$DATE"
VERSION_STRING+=$'\n'
VERSION_STRING+="$XCODE_STRING"
echo $VERSION_STRING
ditto -c -k --keepParent $BUILD/CSSH.xcframework $BUILD/$ZIPNAME
rm -rf $BUILD/CSSH.xcframework
CHECKSUM=$(shasum -a 256 -b $BUILD/$ZIPNAME | awk '{print $1}')

cat >Package.swift << EOL
// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "CSSH",
    products: [
        .library(name: "CSSH", targets: ["CSSH"])
    ],
    targets: [
        .binaryTarget(name: "CSSH",
                      url: "$DOWNLOAD_URL",
                      checksum: "$CHECKSUM")
    ]
)
EOL

cat >$BUILD/release-note.md << EOL
Libssh2 $LIBSSH_TAG
$LIBSSL_TAG
$XCODE_STRING

### Supported platforms and architectures
| Platform          |  Architectures     |
|-------------------|--------------------|
| macOS             | x86_64 arm64       |
| iOS               | arm64              |
| iOS Simulator     | x86_64 arm64       |
EOL

if [[ $VISION_OS == 0 ]]; then

cat >>$BUILD/release-note.md << EOL
| xrOS              | arm64              |
| xrOS Simulator    | arm64              |
EOL

fi

if [[ $4 == "commit" ]]; then

git add Package.swift
git commit -m "Build $TAG"
git tag $TAG
git push
git push --tags
gh release create "$TAG" $BUILD/$ZIPNAME --title "$TAG" --notes-file $BUILD/release-note.md

fi

popd > /dev/null

#!/bin/bash
###########################################################################
#    build-mxe.sh
#    ---------------------
#    Date                 : February 2018
#    Copyright            : (C) 2018 by Alessandro Pasotti
#    Email                : elpaso at itopen dot it
###########################################################################
#                                                                         #
#   This program is free software; you can redistribute it and/or modify  #
#   it under the terms of the GNU General Public License as published by  #
#   the Free Software Foundation; either version 2 of the License, or     #
#   (at your option) any later version.                                   #
#                                                                         #
###########################################################################


set -e

# This script is designed to be run inside the Docker image containing
# QField building environment, see mxe.Dockerfile.
#
#
# Usage: you can pass an optional "package" command to skip the build
#        and directly go to the packaging
#        This script needs to be called from the main QField directory, the
#        one which contains CMakeLists.txt
#        The artifact will be saved as a zip package in the directory
#        from which this script is launched.


COMMAND=$1

# Location of current script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PYDEPLOY=${DIR}/deploy.py

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Configuration: change this!

# Location of mxe install dir
MXE=${MXE:-/mxe/}

# Directory for build
BUILD_DIR=${PWD}/build-mxe
# Directory where the artifact will be saved
RELEASE_DIR=${PWD}/qfield-mxe-release

# Extra dependencies (not automatically identified by pydeploy)
EXTRA_QT5_DEPS="Qt5QuickTemplates2 Qt5QuickControls2 Qt5PositioningQuick"

# End configuration

# Windows 64 bit with posix threads support
TARGET=x86_64-w64-mingw32.shared.posix

# Set base path for all tools
export PATH=${PATH}:/mxe/usr/bin

# Fix CCACHE directory
export CCACHE_DIR=${PWD}/.ccache

if [ ! -e ${CCACHE_DIR} ]; then
  mkdir -p ${CCACHE_DIR}
fi

if [[ "$COMMAND" != *"package"* ]]; then
  [ -d ${BUILD_DIR} ]  && rm -rf ${BUILD_DIR}
  [ -d ${RELEASE_DIR} ] && rm -rf ${RELEASE_DIR}
  # Make sure dirs exist
  [ -d ${BUILD_DIR} ] || mkdir ${BUILD_DIR}
  [ -d ${RELEASE_DIR} ] || mkdir ${RELEASE_DIR}
fi

pushd .

cd ${BUILD_DIR}

# Build

if [[ "$COMMAND" != *"package"* ]]; then

    ${MXE}/usr/bin/${TARGET}-cmake .. \
        -D CMAKE_BUILD_TYPE=Release \
        -D CMAKE_INSTALL_PREFIX=${RELEASE_DIR} \
        -D MXE=ON \
        $ARGS

    make -j16 install
fi

# Move all targets to main folder
mv ${RELEASE_DIR}/bin/*.exe ${RELEASE_DIR}
mv ${RELEASE_DIR}/bin/*.dll ${RELEASE_DIR}
# Copy QMLs
cp -r ${MXE}/usr/${TARGET}/qt5/qml ${RELEASE_DIR}

# Copy QGIS modules (plugins)
cp -r ${MXE}/usr/${TARGET}/plugins ${RELEASE_DIR}

# No need to package these:
rm -rf ${RELEASE_DIR}/bin # now empty!

for _DEP in ${EXTRA_QT5_DEPS}; do
    cp ${MXE}/usr/${TARGET}/qt5/bin/${_DEP}.dll ${RELEASE_DIR};
done

# Collect deps
$PYDEPLOY --build=${RELEASE_DIR} --objdump=${MXE}/usr/bin/${TARGET}-objdump ${RELEASE_DIR}/qfield.exe
for dll in $(ls ${RELEASE_DIR}/*.dll); do
    echo "Checking DLL: ${dll} ..."
    $PYDEPLOY --build=${RELEASE_DIR} --objdump=${MXE}/usr/bin/${TARGET}-objdump $dll
done

for dll in $(ls ${RELEASE_DIR}/plugins/*.dll); do
    echo "Checking DLL: ${dll} ..."
    $PYDEPLOY --build=${RELEASE_DIR} --objdump=${MXE}/usr/bin/${TARGET}-objdump $dll
done

# Add QT plugins
cp -r ${MXE}/usr/${TARGET}/qt5/plugins ${RELEASE_DIR}/qt5plugins

# Add QGIS resources
cp -r ${MXE}/usr/${TARGET}/resources ${RELEASE_DIR}

# Add GDAL resources
cp -r ${MXE}/usr/${TARGET}/share/gdal ${RELEASE_DIR}/gdal

cat <<__TXT__ > ${RELEASE_DIR}/qt.conf
[Paths]
Plugins = qt5plugins
__TXT__

# Make the zip
cd ${RELEASE_DIR}/..
ZIP_NAME=qfield-mxe-release-$(date +%Y-%m-%d-%H-%M-%S).zip
zip -r ${ZIP_NAME} $(basename ${RELEASE_DIR})

# Cleanup
rm -rf ${RELEASE_DIR}

popd

echo "Release in $ZIP_NAME ready."

# vim: et ts=4 :
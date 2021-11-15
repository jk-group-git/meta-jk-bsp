# Copyright (C) 2019 Daniel Wagener <daniel.wagener@kernelconcepts.de>
# Released under the MIT license (see COPYING.MIT for the terms)

DESCRIPTION = "libzip is a C library for reading, creating, and modifying zip archives."
HOMEPAGE = "https://libzip.org/"
LICENSE = "BSD-3-Clause"
DEPENDS = "zlib bzip2"

SRC_URI = "https://libzip.org/download/libzip-${PV}.tar.xz"
LIC_FILES_CHKSUM = "file://LICENSE;md5=01f8b1b8da6403739094396e15b1e722"

PACKAGECONFIG[ssl] = "-DENABLE_OPENSSL=ON,-DENABLE_OPENSSL=OFF,openssl"

PACKAGECONFIG ?= "ssl"

inherit cmake

SRC_URI[md5sum] = "6fe665aa6d6bf3a99eb6fa9c553283fd"
SRC_URI[sha256sum] = "04ea35b6956c7b3453f1ed3f3fe40e3ddae1f43931089124579e8384e79ed372"

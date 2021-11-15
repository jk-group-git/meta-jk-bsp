# Copyright (C) 2018 Daniel Wagener <daniel.wagener@kernelconcepts.de>
# Released under the MIT license (see COPYING.MIT for the terms)

DESCRIPTION = "Update system (USB Delivery, systemd)"
HOMEPAGE = ""
LICENSE = "CLOSED"
SECTION = "none"
DEPENDS = "udev systemd"
RDEPENDS_${PN} = "bash"

COMPATIBLE_MACHINE="tx6u-8133"

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI =   "file://systemupdate.sh\
             file://update_confirm\
             file://update_confirm.service\
             file://boot.path\
             file://uImage\
             file://u-boot.bin\
             file://env\
             file://dtb\
             file://pl-test.pem\
             file://pl-161.pem\
             file://pl-900.pem\
            "

inherit systemd
SYSTEMD_SERVICE_${PN} = "boot.path"

do_configure() {
}
do_compile () {
}
do_install () {
    install -d ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/update_confirm.service ${D}${systemd_unitdir}/system/
    install -m 0644 ${WORKDIR}/boot.path ${D}${systemd_unitdir}/system/
    install -d ${D}${bindir}
    install -m 0744 ${WORKDIR}/systemupdate.sh ${D}${bindir}
    install -m 0744 ${WORKDIR}/update_confirm ${D}${bindir}
    install -d ${D}${datadir}/bootfiles
    install -m 0644 ${WORKDIR}/uImage ${D}${datadir}/bootfiles/
    install -m 0644 ${WORKDIR}/dtb ${D}${datadir}/bootfiles/
    install -m 0644 ${WORKDIR}/u-boot.bin ${D}${datadir}/bootfiles/
    install -m 0644 ${WORKDIR}/env ${D}${datadir}/bootfiles/
    install -d ${D}${datadir}/keys/update
}

do_install_append_pl-test () {
    install -m 0644 ${WORKDIR}/pl-900.pem ${D}${datadir}/keys/update/
    install -m 0644 ${WORKDIR}/pl-161.pem ${D}${datadir}/keys/update/
    install -m 0644 ${WORKDIR}/pl-test.pem ${D}${datadir}/keys/update/
}

do_install_append_pl-161 () {
    install -m 0644 ${WORKDIR}/pl-test.pem ${D}${datadir}/keys/update/
    install -m 0644 ${WORKDIR}/pl-161.pem ${D}${datadir}/keys/update/
}

do_install_append_pl-900 () {
    install -m 0644 ${WORKDIR}/pl-900.pem ${D}${datadir}/keys/update/
    install -m 0644 ${WORKDIR}/pl-test.pem ${D}${datadir}/keys/update/
}

FILES_${PN} +=   "${bindir}\
                  ${datadir}/bootfiles/\
                  ${datadir}/keys/update/\
                  ${systemd_unitdir}/system/update_confirm.service\
                 "

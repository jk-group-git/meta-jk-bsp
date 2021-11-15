LICENSE = "CLOSED"

PRIORITY= "optional"

SUMMARY = "JK pl-test udev rules"
DESCRIPTION = "udev rules for production test"

inherit bin_package

SRC_URI = "file://98-pltest.rules"

do_install_append () {
	install -d ${D}/lib/udev/rules.d/
	install -m 0644 ${WORKDIR}/98-pltest.rules ${D}/lib/udev/rules.d/98-pltest.rules
}



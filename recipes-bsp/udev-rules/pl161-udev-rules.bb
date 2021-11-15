LICENSE = "CLOSED"

PRIORITY= "optional"

SUMMARY = "JK pl-161 gui udev rules"
DESCRIPTION = "udev rules for pl161"

inherit bin_package

SRC_URI = "file://98-pl161.rules"

do_install_append () {
	install -d ${D}/lib/udev/rules.d/
	install -m 0644 ${WORKDIR}/98-pl161.rules ${D}/lib/udev/rules.d/98-pl161.rules
}


#
# toolchain configuration for u-boot
# since u-boot does not like gcc 7 and hardfloat
#
GCCVERSION = "5.4%"
DEFAULTTUNE_mx6 = "cortexa9-neon"
DEFAULTTUNE_mx6ul = "cortexa7-neon"

include conf/distro/include/tcmode-default.inc

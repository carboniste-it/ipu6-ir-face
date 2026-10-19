# SPDX-License-Identifier: GPL-2.0-only
# Out-of-tree build of: OV9234 IR sensor driver, Intel IPU bridge (+OVTI9234 entry) and IPU6 ISYS (+1-lane port-B PHY fix).
obj-m += ov9234.o
obj-m += ipu-bridge.o
obj-m += ipu6/
KDIR ?= /lib/modules/$(shell uname -r)/build
all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules
clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean

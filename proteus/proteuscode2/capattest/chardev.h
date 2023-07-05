#ifndef CHARDEV_H
#define CHARDEV_H

#define CHARDEV_ADDR 0x10000000
#define CHARDEV *(volatile char*)CHARDEV_ADDR
#define CHARDEV_EOT 4

#endif

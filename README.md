# Linux custom GPIO patches

This set of patches enables use of Device-Tree-configurable GPIO
drivers on custom GPIO pins for platforms with no native Device Tree
support.

## Motivation

A growing number of Linux kernel drivers depend on Device Tree
configuration for device discovery. In some embedded applications it's
beneficial to have said discovery configurable dynamically from user
space. Some platforms don't have proper Device Tree support in the
first place, requiring
[roundabout](https://github.com/digitalloggers/spi-gpio-custom)
[ways](https://github.com/digitalloggers/i2c-gpio-custom) of
configuring the drivers, whereas using the Device Tree provides a more
uniform interface for configuration.

## Disclaimer

This code is not intended for the faint of heart. The overlay loader
is not known for being forgiving, and there's a possible memory leak
when removing overlays. Don't use this on critical systems.

## Patch set structure and organization

Patches are organized in subdirectories, each of them containing files
or subdirectories named after stable Linux kernel versions the patch
(or, in case of a subdirectory, a patch series) is expected to be
applied. For each given kernel version, only one nearest-matching item
needs to be applied. Though some patches cover earlier kernel
versions, the whole set has not been tested with kernels before 4.15.

The patch set is based on the `configfs`-driven device tree overlay
support originally by [Pantelis
Antoniou](https://github.com/pantoniou) and now maintained by
Raspberry Pi folks to whom we owe our gratitude. Patches to enable the
support are in the [rpi-of-configfs](rpi-of-configfs) subdirectory,
named after respective commits in the [Raspberry Pi Linux fork
repository](https://github.com/raspberrypi/linux). This support is
unconditional and is believed to have security implications, which
seems to be the reason why it's not in the mainline kernel.

Platforms which are not usually based on Device Tree hardware
descriptions, like x86(-64), may not benefit solely from the above
patches, as there's nothing to attach overlays to. Additional code
needed includes creating a dummy Device Tree root to attach other
stuff to (patches in the [of-root-stub](of-root-stub) subdirectory),
and exposing the GPIO controllers as Device Tree nodes (patches in the
[of-gpio-stub](of-gpio-stub) subdirectory). These are conditional on
kernel command line arguments: to enable them, pass extra
`of_root_stub=1 of_gpio_stub=1` arguments to the kernel (if you pass
0, the functionality is deactivated, additionally, `of_gpio_stub=1`
has no effect if the platform has no Device Tree root of its own and
`of_root_stub` is not enabled).

Last but not least, the [of-chip-match](of-chip-match) subdirectory
contains a patch which makes GPIO chip matching slightly more
logical. It is unconditional, and required for proper handling nodes
created by the `of-gpio-stub` patch.

## Kernel configuration

You need to enable the stub patches explicitly in the kernel
config. In particular, the kernel config may contain:

    CONFIG_OF=y
    CONFIG_OF_DYNAMIC=y
    CONFIG_OF_OVERLAY=y
    CONFIG_OF_FLATTREE=y
    CONFIG_OF_CONFIGFS=y
    CONFIG_OF_GPIO_STUB=y
    CONFIG_OF_ROOT_STUB=y

You will additionally want to enable support for the actual GPIO
drivers you intend to use.

## Boot configuration

For `grub` users, configuring the kernel command line can be done
e.g. by creating a file `/etc/default/grub.d/100-stub.cfg` with
content:

    GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX of_root_stub=1 of_gpio_stub=1"

and doing a `sudo update-grub2`. Alternatively, you can break into
`grub` at boot, select a boot entry, use 'e' to edit it and add the
parameters for that boot only.

## Runtime configuration

After booting into that configuration, `/proc/device-tree/` should
appear with `/proc/device-tree/gpiochip-stub-N` nodes, where `N`
corresponds to the base GPIO number of each controller (compare with
`/sys/class/gpio/gpiochipN`). These nodes have symbolic aliases
`gpiochip_stub_N` which you may use in Device Tree overlays you
load.

Use the `dtc` Device Tree compiler (often located in
`/usr/src/linux-headers-$(uname -r)/scripts/dtc/dtc`) to compile
overlays (do use the `-@` flag to enable symbol processing).

Place device tree overlays into `.dto` files and compile with `dtc` to
obtain `.dtbo` files. One way to load those with the `configfs`
overlay patch is doing the following as root (you can choose
`my-overlay-name` at will):

    # mkdir /sys/kernel/config/device-tree/overlays/my-overlay-name/
    # cat my-file-name.dtbo > /sys/kernel/config/device-tree/overlays/my-overlay-name/dtbo

Refer to the `configfs` overlay patch documentation for details.

## Samples

Samples below contain device-specific GPIO chip bases and pin numbers;
they are intended as a demonstration, not to be copy/pasted and loaded
into the kernel as they are.

### Custom GPIO I2C bus

Consider an I2C bus connected to pins with global numbers `476` (SDA)
and `480` (SCL), corresponding to pins `62` and `66` in the GPIO
controller with base `414`; to reference the pins in a Device Tree
overlay, use `<&gpiochip_stub_414 62 6>` and `<&gpiochip_stub_414 66
6>` (the trailing `6` specifies flags for the pin configuration, and
corresponds to an open-drain pin; see Linux header
`include/dt-bindings/gpio/gpio.h` for details).

A sample overlay source for this configuration is:

    /dts-v1/;
    /plugin/;
    
    / {
      fragment@0 {
        target-path="/";
        __overlay__ {
          i2c: i2c {
             compatible = "i2c-gpio";
             #address-cells = <1>;
             #size-cells = <0>;
             sda-gpios = <&gpiochip_stub_414 62 6>;
             scl-gpios = <&gpiochip_stub_414 66 6>;
             i2c-gpio,delay-us = <2>;        /* ~100 kHz */
          };
        };
      };
    };

The resulting I2C bus will be assigned the next available bus number.

### Custom GPIO IR receiver

Consider an IR receiver connected to a pin with global number `335`
corresponding to pin `21` in the GPIO controller with base `314`; to
reference it in a Device Tree overlay, use `<&gpiochip_stub_314 21 0>`
(the trailing `0` specifies flags for the pin configuration, and
corresponds to a usual active-high bidirectional pin).

A sample overlay source for this configuration is:

    /dts-v1/;
    /plugin/;
    
    / {
      fragment@0 {
        target-path="/";
        __overlay__ {
          ir: ir-receiver {
            compatible = "gpio-ir-receiver";
            gpios = <&gpiochip_stub_314 21 0>;
            linux,rc-map-name = "rc-rc6-mce";
          };
        };
      };
    };


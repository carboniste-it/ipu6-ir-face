# ipu6-ir-face — Infrared (Windows Hello) camera and face login on Linux for Intel IPU6 + OmniVision OV9234

Tested hardware: Lenovo ThinkPad X1 Carbon Gen 11 (21HM), IR module OV9234 6BF115T2 (ACPI `OVTI9234`),
illuminator TI LM3643 (ACPI `INT347D`), Intel IPU6EP (PCI 8086:a75d), Linux Mint 22.3 / Ubuntu 24.04
HWE kernels 6.14 and 7.0. Other laptops with the same sensor on IPU6 are likely to work; report back.

**Status: working, unmaintained.** This repository is a finished one-off. It is published so others can use
it, fork it and upstream it. There is no support and no roadmap. Forks are welcome.

## What was broken and what fixes it
The Linux IPU6 driver programs a one-lane sensor on MIPI PHY port B with a register table the hardware
never produces frames from; the sensor streams, the receiver reports ready, no errors, no pictures.
Intel's Windows driver uses the two-lane port-B table for this case. Two small kernel changes
(`upstream-patches/`) fix it; `dkms/` packages them with an out-of-tree OV9234 sensor driver.

## Layout
| Path | Contents |
|---|---|
| `upstream-patches/` | 0001 PHY table fix, 0002 bridge entry — mailing-list form for linux-media |
| `dkms/` | DKMS package `ipu6-ir-ov9234` (ov9234, ipu-bridge, intel-ipu6-isys for 7.x kernels) |
| `userspace/` | `cloc-face-authd` (root service: capture, recognition, illuminator-blink liveness), PAM client and profile, LM3643 helper, optional loopback relay, `install.sh`, `ir-face.conf` |

## How face login works
1. PAM runs `cloc-face-auth-client` first (before fingerprint/password; it never blocks them).
2. The root service streams raw 10-bit IR frames, turns the illuminator on, finds the face and compares
   it with Howdy-format models (same dlib ResNet, same distance, default certainty 3.5).
3. Liveness: the illuminator is blinked off/on; the matched face must brighten far more than the
   background and show 3-D shading. A phone-screen photo emits no IR and fails earlier; a flat print
   fails this step. This is not depth sensing — treat it as strong convenience, not a vault.
4. Typical unlock: 1.3–2.3 s. Failures fall through to fingerprint/password.

## Safety and privacy notes
* Illuminator: torch mode at code 0x3F (~89 mA continuous) for at most a few seconds per attempt; the
  vendor Windows driver pulses the same LEDs at ~360 mA. No fault flags were observed. You use it at
  your own risk; keep the current at or below the vendor's.
* Face models live in `/usr/share/dlib/<user>.dat` (root-only). No frames are stored.
* The service accepts requests over a Unix socket; non-root callers may only authenticate themselves.
* SSH sessions and closed lids never trigger the camera.

## Licensing
Kernel files: GPL-2.0-only (headers kept from upstream). Userspace: MIT.
`ov9234.c` is research grade: its mode/initialisation register tables were recovered from the vendor
Windows driver's I²C traffic. It works, it is not an upstream-quality driver, and whoever upstreams a
proper OV9234 driver should re-derive the tables from the datasheet.

## Install (summary)
```
sudo apt install dkms v4l-utils gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-bad python3-opencv python3-numpy
# python3-dlib + dlib-models: the Slimbook PPA builds work on 24.04 (ppa:slimbook/slimbook); Howdy itself is optional
sudo cp -r dkms /usr/src/ipu6-ir-ov9234-1.0.0 && sudo dkms install ipu6-ir-ov9234/1.0.0 && sudo reboot
sudo ./userspace/install.sh
sudo /usr/local/libexec/cloc-face-auth-client --enroll $USER "first"
```
Known interaction: the Intel camera HAL used for the RGB webcam (icamerasrc / v4l2-relayd) resets all
media links when it starts, so never stream the IR sensor in the background; `cloc-ir-after` restarts the
RGB relay if a webcam open collided with an IR session.

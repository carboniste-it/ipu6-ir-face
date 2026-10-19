#!/bin/bash
# Installs the IR face-login userspace (authenticator service, PAM profile, illuminator helper, optional
# loopback relay). Run as root on Ubuntu 24.04 / Linux Mint 22 after the DKMS package is installed.
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
echo "== hardware check"
lspci -n | grep -qiE '8086:(a75d|462e|465d|7d19)' || { echo "no Intel IPU6 found (lspci)"; exit 1; }
grep -q OVTI9234 /sys/bus/acpi/devices/*/hid 2>/dev/null || { echo "no OVTI9234 (OV9234 IR sensor) in ACPI"; exit 1; }
grep -q INT347D /sys/bus/acpi/devices/*/hid 2>/dev/null || echo "warning: no INT347D illuminator in ACPI; face login will only work in daylight"
[ -e /sys/bus/i2c/devices/i2c-OVTI9234:00/driver ] || echo "warning: ov9234 not bound yet (install the DKMS package and reboot)"
for b in media-ctl v4l2-ctl gst-launch-1.0; do command -v $b >/dev/null || { echo "missing $b (apt install v4l-utils gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-bad)"; exit 1; }; done
python3 -c 'import dlib, cv2, numpy' 2>/dev/null || { echo "missing python3-dlib / python3-opencv / python3-numpy (see README: Howdy's dlib package)"; exit 1; }
[ -f /usr/share/dlib/dlib_face_recognition_resnet_model_v1.dat ] || { echo "missing dlib models (package dlib-models)"; exit 1; }
echo "== files"
[ -f /etc/ir-face.conf ] || install -m644 ir-face.conf /etc/ir-face.conf
install -m755 cloc-face-authd cloc-face-auth-client cloc-ir-led cloc-ir-after cloc-ir-convert.py cloc-ir-relay.sh /usr/local/libexec/
mv /usr/local/libexec/cloc-ir-convert.py /usr/local/libexec/cloc-ir-convert; mv /usr/local/libexec/cloc-ir-relay.sh /usr/local/libexec/cloc-ir-relay
install -m644 cloc-face-authd.service cloc-ir-relay.service /etc/systemd/system/
install -m644 pam-config-cloc-face /usr/share/pam-configs/cloc-face
systemctl daemon-reload; systemctl enable --now cloc-face-authd
echo "== PAM (adds face login before fingerprint/password; remove with: pam-auth-update --remove cloc-face)"
pam-auth-update --package
cat <<MSG
Done. Enroll with the room lit by the illuminator (it switches on automatically):
  sudo /usr/local/libexec/cloc-face-auth-client --enroll <user> "label"
Then lock the screen and test: face unlock, then covered camera -> fingerprint/password.
Optional webcam-style IR node for apps: echo 'options v4l2loopback devices=2 video_nr=42,43 exclusive_caps=1,1 card_label="Intel MIPI Camera,Intel IR Camera"' > /etc/modprobe.d/zz-ir-loopback.conf
MSG

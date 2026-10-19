#!/bin/bash
# Root. Configures the IPU6 IR pipeline (OV9234 -> CSI2 0 -> Capture 0) and relays 8-bit GREY frames to the IR loopback node.
set -euo pipefail
IR_TOOLS=/usr/bin; IR_CSI_ENTITY="Intel IPU6 CSI2 0"; IR_CAPTURE_ENTITY="Intel IPU6 ISYS Capture 0"; IR_FORMAT=Y10_1X10/644x364; IR_LOOPBACK=/dev/video43; RGB_LOOPBACK=/dev/video42
[ -r /etc/ir-face.conf ] && . /etc/ir-face.conf
T=$IR_TOOLS
OUT=$IR_LOOPBACK
for i in $(seq 1 100); do [ -e /sys/bus/i2c/devices/i2c-OVTI9234:00/driver ] && [ -e "$OUT" ] && break; sleep 0.2; done
node=$($T/media-ctl -e "$IR_CAPTURE_ENTITY")
$T/media-ctl -l "\"$IR_CSI_ENTITY\":1 -> \"$IR_CAPTURE_ENTITY\":0 [1]"
sensor=$($T/media-ctl -p | grep -oE 'ov9234 [0-9]+-0036' | head -1); [ -n "$sensor" ]
$T/media-ctl -V "\"$sensor\":0 [fmt:$IR_FORMAT field:none]"
$T/media-ctl -V "\"$IR_CSI_ENTITY\":0/0 [fmt:$IR_FORMAT field:none]"
$T/v4l2-ctl -d "$node" --set-fmt-video=width=644,height=364,pixelformat='Y10 ' >/dev/null
/usr/local/libexec/cloc-ir-led on || true
exec /bin/sh -c "$T/v4l2-ctl -d $node --stream-mmap=4 --stream-to=- 2>/dev/null | /usr/local/libexec/cloc-ir-convert | gst-launch-1.0 -q fdsrc fd=0 blocksize=234416 ! rawvideoparse format=gray8 width=644 height=364 framerate=30/1 ! videoconvert ! video/x-raw,format=YUY2 ! v4l2sink device=$OUT sync=false"

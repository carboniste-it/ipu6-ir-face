#!/usr/bin/python3 -I
# Raw Y10 (16-bit LE, 10-bit valid) frames on stdin -> 8-bit GRAY on stdout.
# Fixed tone curve (deterministic, so liveness can compare emitter-on vs off): subtract the sensor black
# level (~64), map 0..336 above black to 0..255 with gamma 0.6 (lifts dim skin, keeps lit face unclipped).
import sys, numpy as np
W, H, STRIDE = 644, 364, 1344
FRAME = STRIDE * H
x = np.clip((np.arange(1024, dtype=np.float32) - 64.0) / 336.0, 0.0, 1.0)
LUT = np.round(255.0 * x ** 0.6).astype(np.uint8)
inp = sys.stdin.buffer; out = sys.stdout.buffer
while True:
    buf = inp.read(FRAME)
    if len(buf) < FRAME: break
    a = np.frombuffer(buf, dtype=np.uint16).reshape(H, STRIDE // 2)[:, :W] & 0x3FF
    out.write(LUT[a].tobytes()); out.flush()

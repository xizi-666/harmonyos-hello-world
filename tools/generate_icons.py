# -*- coding: utf-8 -*-
"""
根据 AI 生成的应用图标主体图，合成 HarmonyOS 分层图标与 AGC 上架素材。

无任何第三方依赖（仅使用 Python 标准库），可重复运行：
    python tools/generate_icons.py

产出：
  AppScope/resources/base/media/{background,foreground}.png        1024x1024 分层图标
  entry/src/main/resources/base/media/{background,foreground}.png   1024x1024 分层图标
  entry/src/main/resources/base/media/startIcon.png                 152x152 启动图标（透明底）
  agc-assets/app_icon_1024.png / app_icon_216.png                   AGC 应用图标（官方规格）
  agc-assets/app_icon_512.png                                      通用备用尺寸
  agc-assets/icon_source.png                                        AI 生成的原始主体图（白底）
"""
import glob
import os
import shutil
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GEN_DIR = ROOT / "agc-assets"
ASSETS = ROOT / "agc-assets"
SOURCE = ASSETS / "icon_source.png"


# ---------- PNG 解码（支持 8bit RGB / RGBA / 灰度） ----------
def read_png(path):
    data = Path(path).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG: %s" % path
    pos, idat, w, h, depth, ctype = 8, [], 0, 0, 0, 0
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        pos += 12 + ln
        if typ == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", body[:10])
        elif typ == b"IDAT":
            idat.append(body)
        elif typ == b"IEND":
            break
    assert depth == 8, "only 8-bit PNG supported (got %s)" % depth
    channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(ctype)
    assert channels, "unsupported PNG color type %s" % ctype
    raw = zlib.decompress(b"".join(idat))
    stride = w * channels
    prev = bytearray(stride)
    rows = []
    p = 0
    for _ in range(h):
        ft = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        if ft == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 255
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ft == 3:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif ft == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        elif ft != 0:
            raise ValueError("unknown PNG filter %s" % ft)
        rows.append(line)
        prev = line
    # 统一转成 RGBA
    rgba = bytearray(w * h * 4)
    for y, line in enumerate(rows):
        o = y * w * 4
        if channels == 4:
            rgba[o:o + stride] = line
        elif channels == 3:
            for x in range(w):
                s = x * 3
                rgba[o + x * 4:o + x * 4 + 3] = line[s:s + 3]
                rgba[o + x * 4 + 3] = 255
        else:  # 灰度 / 灰度+alpha
            for x in range(w):
                s = x * channels
                v = line[s]
                rgba[o + x * 4:o + x * 4 + 3] = bytes((v, v, v))
                rgba[o + x * 4 + 3] = line[s + 1] if channels == 2 else 255
    return w, h, rgba


def write_png(path, w, h, rgba, drop_alpha=False):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpp = 3 if drop_alpha else 4
    scan = bytearray()
    for y in range(h):
        scan.append(0)  # filter None
        row = rgba[y * w * 4:(y + 1) * w * 4]
        if drop_alpha:
            for x in range(w):
                scan += row[x * 4:x * 4 + 3]
        else:
            scan += row

    def chunk(typ, body):
        return struct.pack(">I", len(body)) + typ + body + struct.pack(">I", zlib.crc32(typ + body) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2 if drop_alpha else 6, 0, 0, 0)
    out = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(bytes(scan), 9)) + chunk(b"IEND", b""))
    path.write_bytes(out)
    return len(out)


# ---------- 白底 -> 透明前景（含颜色反混合，消除白边） ----------
def extract_foreground(w, h, src):
    out = bytearray(w * h * 4)
    for i in range(w * h):
        s = i * 4
        r, g, b = src[s], src[s + 1], src[s + 2]
        mn = min(r, g, b)
        # 只有接近纯白的像素才变透明；彩色主体（含浅蓝横线）保持不透明
        a = max(0, min(255, int((255 - mn) / 40.0 * 255 + 0.5)))
        if a == 0:
            out[s:s + 4] = bytes((0, 0, 0, 0))
            continue
        af = a / 255.0
        # 源色是主体色与白底混合的结果，反推主体原色，避免透明边缘出现白晕
        cr = max(0, min(255, int((r - (1 - af) * 255) / af + 0.5)))
        cg = max(0, min(255, int((g - (1 - af) * 255) / af + 0.5)))
        cb = max(0, min(255, int((b - (1 - af) * 255) / af + 0.5)))
        out[s:s + 4] = bytes((cr, cg, cb, a))
    return out


def make_background(w, h):
    """对角柔和渐变：淡蓝白 -> 浅蓝，配合深蓝主体。"""
    c0, c1 = (237, 244, 255), (190, 216, 255)
    out = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            t = (x / (w - 1) * 0.55 + y / (h - 1) * 0.45)
            o = (y * w + x) * 4
            out[o] = int(c0[0] + (c1[0] - c0[0]) * t)
            out[o + 1] = int(c0[1] + (c1[1] - c0[1]) * t)
            out[o + 2] = int(c0[2] + (c1[2] - c0[2]) * t)
            out[o + 3] = 255
    return out


def composite(bg, fg, w, h):
    out = bytearray(w * h * 4)
    for i in range(w * h):
        o = i * 4
        a = fg[o + 3]
        if a == 255:
            out[o:o + 4] = fg[o:o + 4]
        elif a == 0:
            out[o:o + 4] = bg[o:o + 4]
        else:
            af = a / 255.0
            inv = 1 - af
            out[o] = int(fg[o] * af + bg[o] * inv)
            out[o + 1] = int(fg[o + 1] * af + bg[o + 1] * inv)
            out[o + 2] = int(fg[o + 2] * af + bg[o + 2] * inv)
            out[o + 3] = 255
    return out


def resize(src, w, h, tw, th):
    """面积平均下采样，alpha 加权，避免最近邻锯齿。"""
    out = bytearray(tw * th * 4)
    for ty in range(th):
        y0, y1 = ty * h // th, max(ty * h // th + 1, (ty + 1) * h // th)
        for tx in range(tw):
            x0, x1 = tx * w // tw, max(tx * w // tw + 1, (tx + 1) * w // tw)
            rs = gs = bs = aa = wt = 0
            for y in range(y0, y1):
                base = y * w * 4
                for x in range(x0, x1):
                    o = base + x * 4
                    a = src[o + 3]
                    if a:
                        af = a / 255.0
                        rs += src[o] * af
                        gs += src[o + 1] * af
                        bs += src[o + 2] * af
                        aa += af
                    else:
                        rs += src[o]
                        gs += src[o + 1]
                        bs += src[o + 2]
                    wt += 1
            o = (ty * tw + tx) * 4
            if aa > 0:  # 有主体像素：按 alpha 比例输出半透明
                out[o] = min(255, int(rs / aa))
                out[o + 1] = min(255, int(gs / aa))
                out[o + 2] = min(255, int(bs / aa))
                out[o + 3] = min(255, int(aa / wt * 255))
            else:
                out[o] = min(255, int(rs / wt))
                out[o + 1] = min(255, int(gs / wt))
                out[o + 2] = min(255, int(bs / wt))
                out[o + 3] = 0
    return out


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    if not SOURCE.exists():
        cands = sorted(glob.glob(str(GEN_DIR / "*.png")), key=os.path.getmtime, reverse=True)
        if not cands:
            sys.exit("找不到原始图标图，请把 AI 生成的图放到 agc-assets/icon_source.png")
        shutil.copy(cands[0], SOURCE)
        print("原始图标已归档:", SOURCE.name)

    w, h, src = read_png(SOURCE)
    print("源图: %dx%d" % (w, h))
    fg = extract_foreground(w, h, src)
    bg = make_background(w, h)
    full = composite(bg, fg, w, h)

    targets = [
        ROOT / "AppScope/resources/base/media/foreground.png",
        ROOT / "entry/src/main/resources/base/media/foreground.png",
    ]
    for p in targets:
        n = write_png(p, w, h, fg)
        print("  %-70s %7d B" % (str(p.relative_to(ROOT)), n))
    for p in [ROOT / "AppScope/resources/base/media/background.png",
              ROOT / "entry/src/main/resources/base/media/background.png"]:
        n = write_png(p, w, h, bg)
        print("  %-70s %7d B" % (str(p.relative_to(ROOT)), n))

    start = resize(fg, w, h, 152, 152)
    n = write_png(ROOT / "entry/src/main/resources/base/media/startIcon.png", 152, 152, start)
    print("  %-70s %7d B" % ("entry/src/main/resources/base/media/startIcon.png", n))

    n = write_png(ASSETS / "app_icon_1024.png", w, h, full, drop_alpha=True)
    print("  %-70s %7d B" % ("agc-assets/app_icon_1024.png", n))
    for size in (512, 216):
        small = resize(full, w, h, size, size)
        n = write_png(ASSETS / ("app_icon_%d.png" % size), size, size, small, drop_alpha=True)
        print("  %-70s %7d B" % ("agc-assets/app_icon_%d.png" % size, n))

    # 透明主体也留一份，便于做宣传图或调整启动图
    n = write_png(ASSETS / "icon_foreground_512.png", 512, 512, resize(fg, w, h, 512, 512))
    print("  %-70s %7d B" % ("agc-assets/icon_foreground_512.png", n))
    print("完成。")


if __name__ == "__main__":
    main()

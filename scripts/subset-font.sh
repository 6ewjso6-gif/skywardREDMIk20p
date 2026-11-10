#!/usr/bin/env bash
# 把小分区放不下的 MiSans 可变字体压成只含常用字符的静态字重。
# 需要 fonttools：pip install fonttools
set -euo pipefail
cd "$(dirname "$0")/.."

command -v pyftsubset >/dev/null 2>&1 || { echo "需要 fonttools：pip install fonttools" >&2; exit 1; }
mkdir -p target/font

python3 - <<'PY'
chars = set()
for c in range(0x20, 0x7F): chars.add(chr(c))        # ASCII
for c in range(0xA0, 0x100): chars.add(chr(c))       # 拉丁补充
for c in range(0x2000, 0x2070): chars.add(chr(c))    # 常用标点
for c in range(0x2190, 0x21A0): chars.add(chr(c))    # 箭头
for c in range(0x25A0, 0x2600): chars.add(chr(c))    # 几何图形
for c in range(0x3000, 0x3040): chars.add(chr(c))    # 中文标点
for c in range(0xFF00, 0xFFF0): chars.add(chr(c))    # 全角
for hi in range(0xA1, 0xF8):                          # GB2312 汉字
    for lo in range(0xA1, 0xFF):
        try: chars.add(bytes([hi, lo]).decode("gb2312"))
        except Exception: pass
open("target/font/chars.txt", "w", encoding="utf-8").write("".join(sorted(chars)))
print(f"字符集 {len(chars)} 个")
PY

fonttools varLib.instancer resources/fonts/MiSansVF.ttf wght=400 -o target/font/MiSans-400.ttf >/dev/null
pyftsubset target/font/MiSans-400.ttf \
  --text-file=target/font/chars.txt \
  --output-file=target/font/MiSans-sub.ttf \
  --layout-features='*' --no-hinting --desubroutinize

ls -lh target/font/MiSans-sub.ttf
echo "target/font/MiSans-sub.ttf"

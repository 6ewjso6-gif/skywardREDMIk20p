#!/usr/bin/env bash
# 构建 Redmi K20 Pro（raphael）的 Skyward recovery 镜像。
#
# 依赖：Rust stable（见 rust-toolchain.toml）、Android NDK r29、cargo-ndk、lz4。
# 用法：
#   ./scripts/build.sh                 # 用 stock/recovery.img，没有就自动从 MIUI 取
#   STOCK=/path/to/recovery.img ./scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE=raphael
# Android 9 起才有的接口够用，再高的平台版本对这台机器没有意义。
API=28
# recovery 分区大小，原厂镜像没有 AVB footer 时打包器需要它。
PARTITION_SIZE=134217728

STOCK=${STOCK:-stock/recovery.img}
OUT=${OUT:-out/skyward-$DEVICE.img}

need() { command -v "$1" >/dev/null 2>&1 || { echo "缺少 $1，请先安装" >&2; exit 1; }; }
need cargo
need cargo-ndk
need lz4
[ -n "${NDK_HOME:-}" ] || echo "提示：未设置 NDK_HOME，cargo-ndk 会自行查找 NDK" >&2

echo "==> 编译设备端 skyward（aarch64, API $API）"
cargo ndk -t arm64-v8a --platform "$API" build --release -p skyward

echo "==> 静态编译 skyward-system-init"
RUSTFLAGS="-C target-feature=+crt-static" \
  cargo ndk -t arm64-v8a --platform "$API" build --release -p skyward-system-init \
  --target-dir target/system-init

echo "==> 编译打包器 skyward-pack"
cargo build --release -p skyward-pack

if [ ! -f "$STOCK" ]; then
  echo "==> 取原厂 recovery（只读卡刷包里 recovery 分区那一段）"
  mkdir -p "$(dirname "$STOCK")"
  if ! target/release/skyward-pack stock --config "devices/$DEVICE.toml" --out "$STOCK"; then
    echo "无法自动获取原厂 recovery。请把 fastboot 包里的 images/recovery.img" >&2
    echo "放到 $STOCK，或用 STOCK=... 指定路径后重试。" >&2
    exit 1
  fi
fi

echo "==> 打包镜像"
mkdir -p "$(dirname "$OUT")"
target/release/skyward-pack recovery \
  --stock "$STOCK" \
  --binary target/aarch64-linux-android/release/skyward \
  --system-init target/system-init/aarch64-linux-android/release/system-init \
  --config "devices/$DEVICE.toml" \
  --font resources/fonts/MiSansVF.ttf \
  --mono resources/fonts/KirkMono-Regular.ttf \
  --mono-license resources/fonts/KirkMono-OFL.txt \
  --partition-size "$PARTITION_SIZE" \
  --out "$OUT"

echo
echo "完成：$OUT（$(stat -c%s "$OUT") 字节）"
echo "sha256：$(sha256sum "$OUT" | cut -d' ' -f1)"
echo
echo "刷入：fastboot flash recovery $OUT"

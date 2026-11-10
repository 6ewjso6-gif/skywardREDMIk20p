# Skyward for Redmi K20 Pro（raphael）

把 [kirklin/skyward](https://github.com/kirklin/skyward) 移植到 Redmi K20 Pro 的仓库：
A-only 分区适配、boot image v0–v2 与 gzip / LZ4 ramdisk 支持。

Skyward 是一个用 Rust 从零写的 recovery：解密 data、刷机、在线更新、备份、
文件管理、终端、adb / MTP，跑的是手机自己的内核驱动与原厂服务。

## 设备

| 项目 | 值 |
| --- | --- |
| 代号 | `raphael` |
| 机型 | Redmi K20 Pro |
| 平台 | 骁龙 855 |
| 分区方案 | A-only，单 boot / recovery，无 super、无 A/B 槽位 |
| 屏幕 | 1080 × 2340，440 dpi |
| recovery 分区 | 128 MiB |
| 原厂基线 | 待补（MIUI 12 / Android 11） |

## 当前状态

代码与 A-only 适配已完成，**还没有预编译镜像**：这台机器的原厂 recovery 在
MIUI fastboot 包的 `images/recovery.img` 里，而卡刷包里它排在数 GB 的
`system.img` 之后，自动按需取分区的下载会被官方 CDN 限速卡住，没能取全。

补上原厂镜像后，`scripts/build.sh` 或 GitHub Actions 就能产出可刷镜像。

## 取得原厂 recovery

从 MIUI 下载页找 `raphael` 的 **fastboot 线刷包**（`.tgz`），解压后取：

```
<包名>/images/recovery.img
```

放到本仓库的 `stock/recovery.img` 即可，不需要改名或转换。

如果手上只有卡刷包（`.zip`），也可以让打包器自己从包里切出 recovery 分区：

```sh
target/release/skyward-pack stock --config devices/raphael.toml --out stock/recovery.img
```

## 从源码构建

依赖：Rust stable（版本见 `rust-toolchain.toml`）、Android NDK r29、cargo-ndk、lz4。

```sh
rustup target add aarch64-linux-android
cargo install cargo-ndk
export NDK_HOME=$HOME/Android/Sdk/ndk/29.0.14206865   # 换成你的 NDK 路径
./scripts/build.sh
```

产物在 `out/skyward-raphael.img`（128 MiB 整分区镜像），脚本最后打印大小和
SHA-256。刷入：

```sh
fastboot flash recovery out/skyward-raphael.img
fastboot reboot recovery
```

镜像是在原厂 recovery 上盖出来的：原厂的 init、adbd、SELinux 策略、驱动库和
触摸固件都保留，只把 `sbin/recovery` 换成 Skyward。

> 需要先解 BL 锁。刷入会覆盖原厂 recovery，MIUI 系统更新可能把它换回去。

## CI

`.github/workflows/build.yml` 在每次 push 时跑 clippy、测试，并用 NDK 编译设备端
二进制，证明代码对这台机器编得过。它不产出镜像：原厂 recovery 不在这台机器的
卡刷包 payload 里，自动取不到，镜像用 `scripts/build.sh` 在本地构建。

## 这个移植改了什么

相对上游，为跑通 A-only 的老机器改了这些：

- **boot image**：读写 header v0 / v1 / v2，按 header 的 page size 切分，
  保留 second bootloader、DTB、DTBO，写回时重算 SHA-1 / SHA-256 digest。
- **ramdisk**：自动识别 gzip、LZ4 legacy framing 和未压缩三种格式，按原格式压回。
- **A-only 运行时**：新增 `Slot::None`（空后缀），`/dev/block/by-name` 回退到
  `/dev/block/bootdevice/by-name`，fstab 回退读 `/etc/recovery.fstab`，
  安装、备份、脚本刷机都按单分区处理，不再假设 super 和槽位。
- **打包器**：自动识别 `system/bin/recovery` 或 `sbin/recovery`、`prop.default`
  或 `default.prop`；原厂镜像没有 AVB footer 时用 `--partition-size` 指定分区大小。

## 已知限制

- 没有 payload OTA、fastbootd、A/B 切槽和双系统；K20 Pro 的 MIUI 用的是
  A-only + system-as-root，没有动态分区，这些功能对它本来也不适用。
- 尚未在真机上完整验证；SELinux 沿用原厂 cmdline 的 permissive。
- recovery 分区 128 MiB，镜像按原厂分区大小填满。

## 许可

[GPL-3.0-or-later](LICENSE)。上游项目：[kirklin/skyward](https://github.com/kirklin/skyward)。

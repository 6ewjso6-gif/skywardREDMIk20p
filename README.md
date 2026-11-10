# Skyward for Redmi K20 Pro（raphael）

把 [kirklin/skyward](https://github.com/kirklin/skyward) 移植到 Redmi K20 Pro 的仓库：
A-only 分区适配、boot image v0–v2 与 gzip / LZ4 ramdisk 支持，以及在原厂
MIUI recovery 上构建好的可刷镜像。

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
| recovery 分区 | 64 MiB（kernel 就占 42 MiB，ramdisk 只有 22 MiB 可用） |
| 原厂基线 | MIUI V12.5.6.0.RFKCNXM（Android 11） |

## 直接刷机

预编译镜像在 [Releases](../../releases/tag/raphael-v1) 里，是整分区镜像
（64 MiB，正好填满 recovery 分区），解压后在 fastboot 下写入：

```sh
sha256sum skyward-raphael-V12.5.6.0.RFKCNXM.img
fastboot flash recovery skyward-raphael-V12.5.6.0.RFKCNXM.img
fastboot reboot recovery
```

镜像是在原厂 recovery 上盖出来的：原厂的 init、adbd、SELinux 策略、驱动库和
触摸固件都保留，只把 `system/bin/recovery` 换成 Skyward，所以显示、触摸、解密
走的是这台手机自己的驱动。

> 需要先解 BL 锁。刷入会覆盖原厂 recovery，MIUI 系统更新可能把它换回去。

## 从源码构建

依赖：Rust stable（版本见 `rust-toolchain.toml`）、Android NDK r29、cargo-ndk、
lz4；压子集字体还要 fonttools（`pip install fonttools`）。

```sh
rustup target add aarch64-linux-android
cargo install cargo-ndk
export NDK_HOME=$HOME/Android/Sdk/ndk/29.0.14206865   # 换成你的 NDK 路径
./scripts/build.sh
```

脚本依次做四件事：

1. 用 `--platform 28` 编译设备端 `skyward`（Android 9 的接口足够，再高没有意义）；
2. 加 `crt-static` 静态编译 `skyward-system-init`；
3. 编译主机端打包器 `skyward-pack`；
4. 在原厂 recovery 上盖出 Skyward，填满 64 MiB 分区。

产物在 `out/skyward-raphael.img`，脚本最后打印大小和 SHA-256。

原厂镜像用 [raphael-v1 Release](../../releases/tag/raphael-v1) 里的
`raphael-stock-recovery.img`，放到 `stock/recovery.img`；也可以用
`STOCK=/path/to/recovery.img ./scripts/build.sh` 指定线刷包里的
`images/recovery.img`。

> 卡刷包（`.zip`）里没有 `recovery.img`：它不带 payload，更新时也不碰 recovery
> 分区。原厂镜像在线刷包的 `images/` 下。

### 64 MiB 的取舍

K20 Pro 的内核有 42 MiB，64 MiB 分区留给 ramdisk 的只有 22 MiB，而 20 MiB 的
MiSans 可变字体放不进去。因此打包时会先试完整字体，放不下就自动换成子集字体：

- 字重固定为 Regular；
- 只保留 ASCII、拉丁补充、常用标点、中文标点和 GB2312 的 6763 个汉字。

生僻字和繁体字会显示成方框。要换字符集，改 `scripts/subset-font.sh` 里的范围。

另外，原厂 recovery 的 `res/images/`（8.3 MiB 界面图片）在打包时会被丢掉：
Skyward 自己画界面，这 8 MiB 是白占的。

## CI

`.github/workflows/build.yml` 在每次 push 时跑 clippy、测试，并用 NDK 编译设备端
二进制，证明代码对这台机器编得过。它不产出镜像：原厂 recovery 不在这台机器的
卡刷包里，自动取不到，镜像用 `scripts/build.sh` 在本地构建。

## 这个移植改了什么

相对上游，为跑通 A-only 的老机器改了这些：

- **boot image**：读写 header v0 / v1 / v2，按 header 的 page size 切分，
  保留 second bootloader、DTB、DTBO，写回时重算 SHA-1 / SHA-256 digest。
- **ramdisk**：自动识别 gzip、LZ4 legacy framing 和未压缩三种格式，按原格式压回。
- **A-only 运行时**：新增 `Slot::None`（空后缀），`/dev/block/by-name` 回退到
  `/dev/block/bootdevice/by-name`，fstab 回退读 `/etc/recovery.fstab`，
  安装、备份、脚本刷机都按单分区处理，不再假设 super 和槽位。
- **打包器**：自动识别 `system/bin/recovery` 或 `sbin/recovery`、`prop.default`
  或 `default.prop`；原厂镜像没有 AVB footer 时用 `--partition-size` 指定分区大小；
  打包时丢掉原厂 UI 的 `res/images/`。

## 已知限制

- 没有 payload OTA、fastbootd、A/B 切槽和双系统；K20 Pro 的 MIUI 用的是
  A-only + system-as-root，没有动态分区，这些功能对它本来也不适用。
- 尚未在真机上完整验证；SELinux 沿用原厂 cmdline 的 permissive。
- 字体是子集，生僻字显示为方框。

## 许可

[GPL-3.0-or-later](LICENSE)。上游项目：[kirklin/skyward](https://github.com/kirklin/skyward)。

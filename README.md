# Rokid 无线投屏助手

[English](README.en.md)

Rokid 无线投屏助手是一款面向 Rokid 眼镜设备的桌面工具，支持 **Rokid Glasses、Rokid AR Lite、Rokid AR Studio** 的无线投屏功能，同时支持 ADB Shell 命令及常见的 ADB 操作。

## 主要功能

- Rokid Glasses 扫码连接并启动无线投屏
- Rokid AR Lite / Rokid AR Studio 通过设备 IP 启动无线投屏
- 无线 ADB 设备发现、连接与状态管理
- ADB Shell 命令执行及常用 ADB 操作
- 基于 scrcpy 的低延迟画面投屏
- 读取当前 Mac 的 Wi-Fi SSID，用于生成扫码连接二维码
- 支持中文和英文界面
- 支持 macOS 与 Windows

## 系统要求

- macOS 13.0 或更高版本
- Xcode Command Line Tools（包含 Swift 5.10 或兼容版本）
- 电脑与眼镜可通过局域网互相访问
- 使用扫码连接时，需要允许应用访问“本地网络”和“定位服务”；macOS 获取当前 Wi-Fi SSID 需要定位权限

## 快速开始

在终端中进入项目目录：

```bash
cd "$HOME/Desktop/Rokid无线投屏助手-完整源码"
```

构建 SwiftPM 可执行程序：

```bash
swift build
```

构建通用版 `.app` 并启动：

```bash
./script/build_and_run.sh run
```

仅构建和验证 `.app`：

```bash
./script/build_and_run.sh --build-only
```

生成安装 DMG：

```bash
./script/package_dmg.sh
```

构建产物位于 `dist/`：

- `dist/Rokid 无线投屏助手.app`
- `dist/Rokid-Wireless-Projection-2.0.4.dmg`

首次执行 DMG 打包脚本时，会在 `.codex/dmgbuild-venv/` 中创建 Python 虚拟环境并安装 `dmgbuild==1.6.5`。

## macOS 安装

1. 打开 DMG，将“Rokid 无线投屏助手.app”拖入“Applications”。
2. 如 macOS 阻止首次运行，请前往“系统设置 > 隐私与安全性”，在“安全性”区域点按“仍要打开”。
3. 前往“系统设置 > 隐私与安全性 > 本地网络”，允许 Rokid 无线投屏助手访问本地网络。
4. 完全退出并重新打开应用。

## 使用说明

- **Rokid Glasses 眼镜端**：通过 Rokid AI / Hi Rokid 中的“工具箱 > 眼镜应用管理 > 安装新应用”，安装发行版中的眼镜端扫码 APK。
- **Rokid Glasses 电脑端**：在“Rokid 无线投屏助手”中点击“扫码连接投屏”，填写 Wi-Fi 信息，然后使用眼镜扫描二维码。
- **Rokid AR Lite / Rokid AR Studio**：确认电脑和眼镜处于同一网络，填写设备 IP 后点击“开启无线投屏”。
- ADB 功能仅用于你拥有或已获授权的设备。

### macOS 权限

如果应用无法获取 SSID 或接收眼镜回调，请检查：

1. 前往“系统设置 > 隐私与安全性 > 本地网络”，允许“Rokid 无线投屏助手”访问本地网络。
2. 前往“系统设置 > 隐私与安全性 > 定位服务”，允许应用使用定位服务。
3. 完全退出应用后重新打开。

## 项目目录

```text
Rokid无线投屏助手-完整源码/
├── Package.swift                    # SwiftPM 包定义和 macOS 最低版本
├── README.md                        # 中文说明
├── README.en.md                     # English documentation
├── Sources/
│   └── RokidNative/
│       ├── App/
│       │   └── RokidNativeApp.swift # 应用入口与窗口配置
│       ├── Models/
│       │   └── AppModels.swift      # 设备、投屏和应用状态模型
│       ├── Services/
│       │   ├── ADBService.swift     # ADB 连接、命令与投屏控制
│       │   ├── CallbackServer.swift # 眼镜无线 ADB HTTP 回调服务
│       │   ├── CommandRunner.swift  # 本地进程和命令执行封装
│       │   ├── LocalNetworkPermissionService.swift
│       │   ├── LocationPermissionService.swift
│       │   ├── QRCodeService.swift  # 扫码协议 JSON 与二维码生成
│       │   └── SystemWifiService.swift # 当前 Wi-Fi/SSID 获取
│       ├── Stores/
│       │   └── AppStore.swift       # 全局状态和业务流程协调
│       ├── Support/
│       │   ├── Localization.swift   # 多语言文本支持
│       │   └── ResourceLocator.swift # 应用资源定位
│       └── Views/
│           ├── Components.swift     # 通用 SwiftUI 组件
│           ├── ContentView.swift    # 主界面
│           ├── DeviceDashboardView.swift
│           ├── HelpView.swift
│           ├── QRCastSheet.swift    # 扫码投屏弹窗
│           └── SettingsView.swift
├── Resources/
│   ├── Info.plist                   # 应用元数据和权限声明
│   ├── RokidNative.entitlements     # 应用签名权限
│   ├── icon.icns                    # macOS 应用图标
│   ├── 安装说明.txt                  # DMG 内安装指引
│   ├── en.lproj/                    # 英文本地化资源
│   ├── assets/                      # Logo、设备图片和 SVG 资源
│   └── bin/
│       ├── adb                      # arm64 + x86_64 通用 ADB
│       ├── scrcpy                   # arm64 + x86_64 通用 scrcpy
│       ├── scrcpy-server            # Android 端 scrcpy 服务
│       ├── rokid-adb-proxy.js       # ADB 兼容代理脚本
│       └── LICENSE.scrcpy           # scrcpy 许可文件
├── Tests/
│   └── RokidNativeTests/            # 回调、二维码协议和设备测试源码
└── script/
    ├── build_and_run.sh             # 构建通用版应用、签名与运行
    ├── package_dmg.sh               # 创建并验证 DMG
    ├── prepare_universal_scrcpy.sh  # 准备通用版 scrcpy
    ├── create_dmg_background.swift  # 生成 DMG 背景图
    └── dmg_settings.py              # DMG 窗口布局配置
```

以下目录由构建脚本自动创建，不属于源码：

- `.build/`：SwiftPM 构建缓存
- `dist/`：应用和 DMG 成品
- `.codex/signing/`：本地构建所用临时签名钥匙串
- `.codex/dmgbuild-venv/`：DMG 打包工具的 Python 虚拟环境

## 调试命令

```bash
# 使用 LLDB 启动
./script/build_and_run.sh --debug

# 查看进程日志
./script/build_and_run.sh --logs

# 查看应用 telemetry 日志
./script/build_and_run.sh --telemetry

# 启动并验证进程和签名
./script/build_and_run.sh --verify
```

## 安全说明

ADB Shell 和其他 ADB 功能只应对你拥有或已获得明确授权的设备使用。二维码可能包含 Wi-Fi 凭据，请勿将二维码截图或协议 JSON 分享给无关人员。

## 第三方组件

本项目随附 ADB 和 scrcpy。scrcpy 的许可信息见 `Resources/bin/LICENSE.scrcpy`。发布或再分发时，请同时遵守相关第三方组件的许可条款。

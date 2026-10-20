# NOTICE

本仓库**不随附** Frida 与 Android platform-tools 的二进制；请按 README 第 2.1 节自行下载并放置。以下是各组件来源与许可。

## 1. Q-Poll Lab（修改版源码与 APK）

- 来源: https://github.com/ZhaoGY-N/huawei-nfc-eink-android-app
- 许可: PolyForm Noncommercial 1.0.0
- 版权: 原作者 ZhaoGY-N 及贡献者
- 说明: `app/source` 与 `app/QPollLab-local.apk` 是面向本工具的修改版（前台 ReaderMode、UID 检查放宽、QTag best-effort、setReaderMode 4 参数回退）。仅限个人非商业用途，分发时请保留原许可与署名。

## 2. 协议研究参考

- 来源: https://gitee.com/kur0neko/huawei-epd-pn532
- 许可: PolyForm Noncommercial 1.0.0
- 版权: kur0neko
- 说明: 屏幕协议、图像编码、PN532 参考实现。本仓库未包含其源码，仅在文档中引用其结论。

## 3. Frida（需自行下载）

- 来源: https://frida.re / https://github.com/frida/frida
- 组件（放置路径见 README）:
  - `tools/frida-server-17.24.3-android-arm64`
  - `scripts/pylibs/`（`pip install --target scripts\pylibs -r requirements.txt`）
- 许可: LGPL-3.0
- 说明: 本仓库不包含其二进制；用户从官方发布页下载后放入对应目录。

## 4. Android SDK Platform-Tools（需自行下载，可选）

- 来源: https://developer.android.com/tools/releases/platform-tools
- 组件: `tools/platform-tools/adb.exe`、`AdbWinApi.dll`、`AdbWinUsbApi.dll`
- 许可: Apache License 2.0
- 说明: 本仓库不包含其二进制；也可以直接把 `adb` 加入系统 PATH，脚本会回退使用 PATH 中的 `adb`。

## 5. 本仓库自有脚本

- `start-hooks.bat`
- `stop-hooks.bat`
- `scripts/hooks_forever.py`

以 MIT License 提供，版权归本仓库作者所有。

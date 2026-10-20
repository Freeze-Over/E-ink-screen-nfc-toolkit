# 华为墨水屏手机壳 NFC 工具箱（非华为手机）

让 **非华为 Android 手机**（示例：Redmi Note 12 Turbo）通过 NFC 给 **华为 3.98 寸四色墨水屏手机壳** 刷图的一套工具、补丁与源码。

> 本仓库只包含脚本、APK 与源码；`adb`、`frida-server`、frida Python 客户端需要按下面的「放置目录」自行下载放入。
> 仅用于个人设备互操作研究，不包含华为官方软件，也不保证兼容所有批次屏幕。

---

## 1. 背景与原理

### 1.1 特殊唤醒帧

华为墨水屏壳不响应标准 NFC-A 的 `WUPA(0x52)`，而是等待一个 **7-bit 短帧 `0x7A`**（是 7 个 bit，不是 7 个字节；直接发 8-bit 的 `0x7A` 字节也无效）。

PN532 / Proxmark3 可以用 `InCommunicateThru` + `TxLastBits=7` 直接发出来，但手机 NFC 控制器没有"任意 7-bit 帧"接口。

### 1.2 NXP 的 Q-Poll

NXP SN100/SN220 系列控制器的固件里有一个私有寻卡模式 **Q-Poll**，NCI 中用 technology `0x71` 表示。控制器进入 Q-Poll 后会自己发出壳需要的那个 7-bit 唤醒帧。

问题在于：Android 的 NFC 栈（NFA）只会请求标准 NFC-A（`0x00`），且收到 `0x71` 的通知后不认识、不会建 Tag。

### 1.3 本工具做的事

运行期用 Frida 在两个进程里做双向字节映射：

| 进程 | 位置 | 改写 |
| --- | --- | --- |
| NFC HAL | `phNxpNciHal_write` | `RF_DISCOVER` 里的 technology `0x00` 改成 `0x71` |
| NFC 栈 | `libsn100nfc-nci.so` 的 `nfc_ncif_proc_discover_ntf` / `nfc_ncif_proc_activate` | 通知里的 `0x71` 改回 `0x00`，让 Android 正常建 Tag |

配套的前台 App（`app/QPollLab-local.apk`，基于开源项目 Q-Poll Lab 修改）负责：

- 以**前台 App 自己的 UID** 打开 ReaderMode（HyperOS 会拒绝 shell/root 后台进程调用 `setReaderMode`）；
- 通过 ISO-DEP 发送 `D1/D3/D4` 等 APDU，完成读屏、传图、刷新。

---

## 2. 目录结构与「放置目录」

```
huawei-epd-nfc-toolkit/
├─ start-hooks.bat                     # 一键：起 adb / frida-server / 两个 hook
├─ stop-hooks.bat                      # 停止 hooks 与 frida-server
├─ README.md
├─ NOTICE.md
├─ requirements.txt                    # 需要装到 scripts\pylibs 的 Python 包
├─ scripts/
│  ├─ hooks_forever.py                 # Frida hook 脚本
│  └─ pylibs/                          # 【自行放置】frida Python 客户端
├─ tools/
│  ├─ frida-server-17.24.3-android-arm64   # 【自行放置】frida-server
│  └─ platform-tools/                  # 【自行放置】adb.exe 等
└─ app/
   ├─ QPollLab-local.apk               # 已改好的前台模式 APK
   └─ source/                          # Q-Poll Lab 修改版源码（含 build_qpoll.ps1）
```

### 2.1 三个需要自行下载并放到指定位置的文件

| 放到哪里 | 下载地址 | 说明 |
| --- | --- | --- |
| `tools/platform-tools/` | https://developer.android.com/tools/releases/platform-tools | 下载 Windows 版 zip，把 `adb.exe`、`AdbWinApi.dll`、`AdbWinUsbApi.dll` 等解压到 `tools/platform-tools/` |
| `tools/frida-server-17.24.3-android-arm64` | https://github.com/frida/frida/releases/download/17.24.3/frida-server-17.24.3-android-arm64.xz | 解压 `.xz`，把得到的文件**重命名**为 `frida-server-17.24.3-android-arm64`，放进 `tools/` |
| `scripts/pylibs/` | `pip install --target scripts\pylibs -r requirements.txt` | 在工具箱根目录执行；`requirements.txt` 内容是 `frida==17.24.3` |

> GitHub 下载慢可以用镜像，例如把 `https://github.com/...` 换成 `https://ghproxy.net/https://github.com/...`。
> `platform-tools` 也可以不下载：把 `adb` 加进系统 PATH 即可；`start-hooks.bat` 在找不到 `tools\platform-tools\adb.exe` 时会回退到 PATH 里的 `adb`。

---

## 3. 环境要求

| 需要 | 说明 |
| --- | --- |
| Windows 10/11 | 一键脚本是 `.bat` |
| Python 3.8+ | 在 PATH 里；只用于跑 Frida 客户端（依赖装在 `scripts/pylibs`） |
| 手机已 root | `start-hooks.bat` 用 `su` 启动 frida-server |
| NFC 可用 | 手机需支持 NFC-A，Android 11+ |

> 不需要 NDK，不需要 Gradle。只有重新编译 APK 时才需要 Android SDK + JDK。

---

## 4. 使用步骤

1. 按第 2.1 节把 `platform-tools`、`frida-server`、`scripts/pylibs` 放好；
2. 手机用 USB 连接电脑，确认 `adb devices` 能看到设备；
3. **双击 `start-hooks.bat`**，等待出现：

   ```
   [2/4] frida-server
   [3/4] port forward
   [4/4] hooks - keep this window open while flashing
   [hook] attached vendor.nxp.hardware.nfc@2.0-service (pid ...)
   [hook] attached com.android.nfc (pid ...)
   ```

   **窗口必须一直开着**；关掉它，Q-Poll 映射就消失，壳会重新变得不可见。
4. 安装 `app/QPollLab-local.apk`（覆盖安装会保留数据）；
5. 打开「墨水屏」App：
   - 设备页 →「检查芯片 / NFC」→ 显示 `检查通过`；
   - 「测试 Q-Poll 能力」→ 应显示 `寻卡完成 / 已收到标签`；
   - 切到「图像与发送」→ 选图 → 选择屏幕类型（A0 / A1）→ 确认刷新。
6. 刷完后双击 **`stop-hooks.bat`**：结束 Frida 客户端、移除端口转发、停掉手机上的 frida-server；然后关掉 `start-hooks.bat` 窗口即可。

---

## 5. 重新构建 APK

源码在 `app/source/`，相对原项目做了 4 处修改：

1. worker 从 `su/Shizuku` 改为 App 前台进程内启动（`/system/bin/sh -c`，继承 App UID）；
2. 放宽 worker 的 UID 检查（允许 App UID）；
3. QTag 厂商命令改为 best-effort（App UID 无 `NFC_PRIVILEGED` 时不中断）；
4. `setReaderMode` 增加 4 参数回退（部分 ROM 无 5 参数重载）。

构建（无需 Gradle）：

```powershell
powershell -ExecutionPolicy Bypass -File .\build_qpoll.ps1 `
  -Sdk "D:\Android\Sdk" -JavaHome "C:\Program Files\Java\jdk-21" `
  -BuildTools "36.0.0" -Platform "android-37.0"
```

产物为 `QPollLab-local.apk`。脚本会：

- 解包 `libs/*.aar` → `classes.jar`；
- `aapt2 compile/link` → `javac` → `d8` → 打包 `classes.dex`；
- `zipalign` → `apksigner` 签名。

---

## 6. 常见问题

| 现象 | 处理 |
| --- | --- |
| `adb not found` / `Missing tools\frida-server` | 按第 2.1 节放到对应目录 |
| `Python package "frida" is missing` | 在根目录执行 `pip install --target scripts\pylibs -r requirements.txt` |
| `寻卡中` 但一直无标签 | 确认 `start-hooks.bat` 窗口还在、日志里有 `attached`；重新点一次「停止 → 开始寻卡」 |
| `NxpHal: write error 0x1ff / Standby Mode` | HAL 卡死，重启手机后重新运行 bat |
| `setReaderMode: Caller is not in foreground` | 说明跑的不是本仓库的前台模式 APK；重装 `QPollLab-local.apk` |
| `释放 ReaderMode 失败 / 恢复未确认` | 重启 NFC 开关或重启手机 |
| 刷图后画面方向不对 | 在 App 里用旋转/镜像调整后重刷 |
| 支付/公交卡异常 | 运行 `stop-hooks.bat` 并重启 NFC；hook 只在运行时生效 |

---

## 7. 许可与声明

- `app/source` 来自 [ZhaoGY-N/huawei-nfc-eink-android-app](https://github.com/ZhaoGY-N/huawei-nfc-eink-android-app)，采用 **PolyForm Noncommercial 1.0.0**，仅限个人非商业使用；修改版请保留原作者署名与许可。
- 参考协议研究：[kur0neko/huawei-epd-pn532](https://gitee.com/kur0neko/huawei-epd-pn532)（PolyForm Noncommercial 1.0.0）。
- 本仓库**不包含** Frida 与 Android platform-tools 的二进制，需要用户自行下载；二者分别适用 LGPL-3.0 与 Apache-2.0。
- 本仓库自有脚本（`start-hooks.bat`、`stop-hooks.bat`、`scripts/hooks_forever.py`）以 MIT 提供。

详见 [NOTICE.md](NOTICE.md)。

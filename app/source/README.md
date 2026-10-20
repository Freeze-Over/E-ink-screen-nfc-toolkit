# Huawei NFC E-Ink Android App

Android 墨水屏刷新工具，当前测试版本 **v2.10-test1**。通过 Shizuku 或 Root 调用兼容系统的 NXP Q-Poll，再通过 Android ISO-DEP 向 **552×768 四色华为 A0 / A1 墨水屏**传图刷新，使用板内已存驱动。

## 功能

- 设备与测试：授权连接、NFC 芯片配置识别、Q-Poll 能力测试、普通 NFC-A 对照。
- 图像与发送：选图、四色预览、旋转、裁切、黑白二值化、阈值、色块简化和抖动；支持全屏缩放与 1:1 像素查看。
- 预览和发送按钮位于页面上方，图片编辑选项位于下方；预览高度根据可用空间调整。
- 高级参数：上电等待时间、忙状态查询间隔；参数保存在本地。
- 保留屏幕规格和原厂扫描配置检查，不限制屏幕 UID；发送前确认，运行中可停止。

## 使用

1. 开启 NFC，保持手机解锁。启动 Shizuku 后，在“设备与测试”页授权连接；也可选择 Root 后端。
2. 点击“检查芯片 / NFC”，按需测试 Q-Poll。型号来自系统固件配置，能力以实际控制器响应和通信结果为准。
3. 在“图像与发送”页手动选择实物屏幕类型 A0 或 A1，再选择图片并调整预览，可先执行“只读检查屏幕”。选择会保存，更换屏幕时需重新核对；D1 无法自动判断 A0 / A1。
4. 点击“发送当前预览到墨水屏”，核对图片和参数后确认。持续贴合并保持应用在前台，直到操作结束。

仅适用于兼容 Q-Poll 的手机系统及相同原厂配置的目标屏；不能仅凭接口存在或型号名称判定兼容。刷新结果取决于实际供能与屏幕状态。中断可能留下不完整画面，程序不会自动重发刷新指令。

## 构建与验证

需要 Python 3、JDK 17、Android SDK platform android-34 和 build-tools 34.0.0。设置 `JAVA_HOME`、`ANDROID_HOME` 指向本机安装目录，然后在仓库根目录运行：

```sh
python3 tests/run_java.py
python3 build.py
```

脚本使用 Android SDK 的命令行工具构建，无 Gradle、无构建期下载。Shizuku API / provider / aidl / shared 13.1.5 依赖已固定在 `libs/`。构建脚本当前使用 Unix 工具路径；Windows 可在 WSL 中运行。

如安装了 `lzokay==2.1.0`，可独立检查解压与扫描打包：

```sh
python3 tests/check_fixtures.py build/<protocol-tests-directory>
```

APK 和 SHA-256 输出在 `dist/`。首次构建会在 `build/` 生成本地调试签名密钥；密钥、构建缓存和 APK 不纳入 Git。自行构建时需要保留自己的密钥，以支持后续覆盖安装。

```sh
adb install -r dist/QPollLab-2.10-test1.apk
```

## 隐私

本仓库仅包含 App 源码、测试、构建脚本、必要依赖与许可证。测试使用合成 UID，不包含原始手机日志、NFC 抓包或个人图片。

应用在运行时读取当前设备与标签信息，并在应用私有目录保存运行日志。日志可能包含设备型号、标签 UID 和本轮操作参数；分享日志前请自行检查。应用未申请网络权限。

## 参考逆向项目

本 App 的协议学习与实现参考了以下两个逆向仓库，感谢原作者公开研究成果：

- [kur0neko/huawei-epd-pn532](https://gitee.com/kur0neko/huawei-epd-pn532)：参考原厂图像扫描布局及 D3 传图、D4 刷新流程；对应代码遵循 PolyForm Noncommercial 1.0.0。
- [solar2ain/ink-nfc-fmsc-by-pn532](https://github.com/solar2ain/ink-nfc-fmsc-by-pn532)：参考公开的 D8/APDU 定义及 LZO1X literal-stream 格式；该项目采用 GPL-3.0-or-later。

具体参考提交、版权声明和许可说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 协议与许可

保留原厂驱动与扫描配置，无 DB/DA 配置写入。图像为 105984 字节，分块发送 D3，单次 D4 启动刷新，通过 DE 查询状态。

参考项目、第三方版权和许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。协议与扫描布局所参考代码使用 PolyForm Noncommercial 1.0.0，完整许可证及 Required Notice 保留在 `third-party/` 和 APK assets 中；请遵守其非商业条款。Shizuku 依赖遵循 MIT License。

## v2.9.1 配置诊断

配置校验失败时，日志逐项显示不匹配字段、期望值和实际十六进制值；缺失或长度异常也显示对应字段。D1 只检查首字节时明确标注。仍执行原有兼容性检查，校验失败后不会认证、传图或刷新，不改写 DB/DA。UID 不参与兼容性校验。

## v2.9.2-test1 连接测试版（Issue #1）

针对寻到标签后 ISO-DEP 连接失败，增加最多三次连接尝试：仅 `IsoDep.connect()` 抛出 IOException、尚未发送任何 APDU 时重新启动 ReaderMode，获取同一 UID 的新 Tag；重新寻卡超时、取消或遇到不同 UID 即停止。协议通信开始后不自动重试，保留原有屏幕规格校验。

日志增加 CONNECT_ATTEMPT、ISO_DEP、CONNECTED / CONNECT_FAILED、APDU_BEGIN / APDU_FAILED 和异常堆栈；不记录 PIN 或图像内容。升级后重新连接 Shizuku，先执行“只读检查屏幕”，反馈从本轮开始到结束的完整日志及手机、系统、屏幕型号。此版本是连接恢复尝试与诊断增强，尚未在 Issue 中的目标屏实测，不代表已支持该型号。

## v2.10-test1 手动选择 A0 / A1

- “图像与发送”页新增屏幕类型选项，首次使用必须明确选择；不根据 D1、UID 或旧版设置猜测型号。切换后重新生成发送快照，运行中不能更改；发送确认和日志显示所选类型。
- A1 保留原有线性控制器行布局，A0 使用参考仓库的奇偶行交错布局。预览按所选布局反解，显示逻辑画面，而非交错后的传输排列。
- 继续使用板内已存驱动，不发送 DB / DA。不负责将 A1 驱动板重配为 A0 或反向改装；实物与板内驱动必须对应。
- 接受已知的 `00120030FFFFFF` / `01120030FFFFFF` 扫描配置，并按读出的方向调整传输数据；其他规格校验仍然保留。写入前复核发现方向变化即停止，不传图。
- 预览快照 SHA-256 与实际发送 SHA-256 分别记录；扫描方向转换发生在 D1 校验之后。只读检查仍可在未选择型号时执行，但不能据此识别 A0 / A1。
- 全帧映射与参考打包函数逐字节比对通过，回归覆盖两种型号、两种扫描方向、实际 D3 数据、预览还原及未知选择拒绝；APK 构建和签名验证通过。尚未完成两种实物屏的刷新验证；此改动不解决 D1 返回 `6401` 的问题。

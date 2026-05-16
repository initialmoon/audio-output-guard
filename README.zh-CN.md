# audio-output-guard

[English](README.md) | 简体中文

一个轻量的 macOS 命令行小工具，用来防止“麦克风类蓝牙设备”抢走系统声音输出。

这个项目最初是为了解决一个很烦的小问题：当 DJI Mic Mini 2 重新连接 Mac 时，macOS 有时会把它当成输出设备。结果就是系统声音没有从耳机或 Mac 扬声器播放，而是被切到了麦克风接收端。

`audio-output-guard` 会监听 CoreAudio 音频设备变化，并把路由调整回更合理的状态：

- DJI 麦克风连接时，将它作为默认输入；
- 优先使用已连接的耳机作为输出；
- 没有耳机时，回退到 Mac 内建扬声器；
- 避免默认输出或系统提示音输出停留在 DJI 麦克风设备上。

## 工作原理

这个 watcher 是事件驱动的，不是轮询脚本。

登录时，用户级 LaunchAgent 会启动：

```text
audio-output-guard watch
```

进程会注册 CoreAudio listener，监听音频设备、默认输入、默认输出的变化。平时它会睡眠等待系统事件，只有 macOS 发出音频变化通知时才执行一次检查和修正。

## 系统要求

- macOS 13 或更新版本
- Swift 5.9 或更新版本
- 设备名称或 UID 中包含 `DJI`、`DJI Mic` 或 `DJI Mic Mini` 的音频设备

## 构建

```bash
git clone https://github.com/InitialMoon/audio-output-guard.git
cd audio-output-guard
swift build -c release
```

release 二进制文件会生成在：

```text
.build/release/audio-output-guard
```

## 查看音频设备

安装后台 watcher 之前，建议先看看 macOS 如何识别你的音频设备：

```bash
.build/release/audio-output-guard devices
```

常用列说明：

- `IN*`：当前默认输入
- `OUT*`：当前默认输出
- `SYS*`：当前默认系统提示音输出
- `IN` / `OUT`：设备是否暴露输入或输出通道
- `TRANSPORT`：built-in、Bluetooth、USB、HDMI、virtual 等设备类型

## 先 dry run 测试

```bash
.build/release/audio-output-guard once --dry-run
```

这会打印它准备做什么，但不会真的修改系统音频设置。

你也可以用 dry-run 模式测试事件监听：

```bash
.build/release/audio-output-guard watch --dry-run
```

## 安装为登录自启动

构建 release 二进制文件之后，安装用户级 LaunchAgent：

```bash
.build/release/audio-output-guard install
```

这会在当前用户的 `~/Library/LaunchAgents` 目录下写入一个 LaunchAgent plist，并在当前图形登录会话中启动 watcher。

查看状态：

```bash
.build/release/audio-output-guard status
```

查看日志：

```bash
.build/release/audio-output-guard logs
```

卸载：

```bash
.build/release/audio-output-guard uninstall
```

## 加入 PATH

可选：

```bash
mkdir -p ~/.local/bin
ln -s "$(pwd)/.build/release/audio-output-guard" ~/.local/bin/audio-output-guard
```

然后确认 `~/.local/bin` 已经在你的 shell `PATH` 中。

## 隐私与安全

这个工具不会录音，也不会打开麦克风音频流。它只读取 CoreAudio 设备元数据，并修改当前用户的默认输入/输出设备选择。

它不需要 sudo，不需要辅助功能权限，也不需要麦克风隐私权限。

注意：`devices` 命令会打印本机音频设备名称和 UID。如果你的设备名称包含个人信息，不建议直接把这段输出公开粘贴到网上。

## 开发

运行测试：

```bash
swift test
```

构建 release：

```bash
swift build -c release
```

测试套件里包含一个简单的隐私回归测试，用来避免不小心把本地开发者 home 路径提交到源码里。

## License

MIT License. See [LICENSE](LICENSE).

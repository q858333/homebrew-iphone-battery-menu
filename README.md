# ChargePeek

菜单栏查看 iPhone 和 Android 设备电量。

# 安装

一条命令安装：

```bash
brew install --cask q858333/iphone-battery-menu/iphone-battery-menu
```

也可以先添加 tap，再用短命令安装：

```bash
brew tap q858333/iphone-battery-menu
brew install --cask iphone-battery-menu
```

安装时会通过 Homebrew 一起安装 `libimobiledevice` 和 `android-platform-tools`。

# 运行
./run.sh

# 打包
./build-app.sh
open .build/release/ChargePeek.app

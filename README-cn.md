<div align="center">

# ScoopBridge

**[中文](README-cn.md) | [English](README.md)**

[![验证](https://github.com/nostalume/scoop-bridge/actions/workflows/verify.yml/badge.svg)](https://github.com/nostalume/scoop-bridge/actions/workflows/verify.yml)
[![自动更新](https://github.com/nostalume/scoop-bridge/actions/workflows/auto-update.yml/badge.svg)](https://github.com/nostalume/scoop-bridge/actions/workflows/auto-update.yml)

</div>

ScoopBridge 聚合常用 Scoop 软件源，并将指定下载地址改写为镜像友好的线路，适合访问上游软件源较慢或不稳定的用户。为保持兼容，本地软件源别名仍为 `spc`。

## 特性

- 聚合 `main`、`extras`、`versions`、`nirsoft`、`sysinternals`、`php`、
  `nerd-fonts`、`nonportable`、`java`、`games`、`charmbracelet`、`winspec`、
  `spx` 和 `shed`。
- 每四小时刷新生成的清单。
- 先在暂存目录生成并校验 JSON，全部成功后才发布。
- 已存在的软件源不会被删除，而是在原位置更新远端地址。
- 仅在明确请求时迁移已安装应用的元数据，并为原文件保留备份。

## 快速开始

如果已经安装 Scoop：

```powershell
scoop bucket add spc https://gh-proxy.org/https://github.com/nostalume/scoop-bridge
scoop install spc/<软件包名称>
```

也可以使用仓库提供的安装脚本安装或配置 ScoopBridge：

```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/nostalume/scoop-bridge/main/installer.ps1' -OutFile "$env:TEMP\scoop-bridge.ps1"
& "$env:TEMP\scoop-bridge.ps1" -UseProxy
```

使用 `-UseProxy:$false` 可直接连接上游；省略该选项时，安装脚本会交互询问。

### 安装参数

| 参数 | 用途 | 默认值 |
| --- | --- | --- |
| `-UseProxy` | 使用镜像友好线路 | 交互询问 |
| `-ScoopDir` | Scoop 安装目录 | `$env:USERPROFILE\scoop` |
| `-BucketName` | ScoopBridge 本地别名 | `spc` |
| `-MigrateInstalledApps` | 迁移受支持的软件源引用并保留备份 | 关闭 |
| `-WhatIf` | 预览安装脚本的更改 | 关闭 |

建议先预览迁移，再明确执行：

```powershell
& "$env:TEMP\scoop-bridge.ps1" -UseProxy -MigrateInstalledApps -WhatIf
& "$env:TEMP\scoop-bridge.ps1" -UseProxy -MigrateInstalledApps
```

## 开发

URL 替换规则位于 [`bin/config.ps1`](bin/config.ps1)，格式说明见
[`docs/configuration.md`](docs/configuration.md)。

```powershell
# 运行测试（需要 Pester 5 或更高版本）
.\tests\Run-Tests.ps1

# 完整执行聚合流程，但不发布生成结果
.\bin\auto-update.ps1 -DryRun
```

提交更改前，请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

ScoopBridge 使用 [MIT License](LICENSE)。

# ncm — 网易云音乐 API for CC:Tweaked

把 [NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi)（Node.js 版，377 个接口）
**完整移植为 CC:Tweaked（ComputerCraft: Tweaked）的纯 Lua 库**。

在游戏里的高级电脑上 `require("ncm")` 就能搜索、听歌、登录、拿歌单/歌词/评论……再用 CC 自带的
`speaker` / 磁盘 / 屏幕把音乐播放流接起来。

> A pure-Lua port of NeteaseCloudMusicApi (377 endpoints) for CC:Tweaked.

---

## 特性

- **377 个接口**：登录、搜索、歌曲/歌词、歌单、专辑、歌手、MV/视频、评论、用户、推荐、私人 FM、
  电台/DJ、云盘、歌词摘录、听歌打卡、音乐人、听歌识曲等。
- **完整加密**：`weapi`（AES-128-CBC ×2 + RSA-1024）、`eapi`（AES-128-ECB + MD5）、`linuxapi`，
  并支持 `aeapi` 的 **gzip 响应解密**。
- **纯 Lua**：无 C 扩展、无 FFI。MD5 / RSA / JSON / base64 / 二维码 / gzip 全部自带；
  AES 块原语依赖 `aeslua-cc`，安装时自动下载。
- **二维码**：既生成标准 PNG data URL，也能**直接渲染到 CC 终端**（ASCII / 半块 / 彩色块）。
- **与原版逐字段对齐**：所有模块都用「原版 Node 代码 vs Lua 移植」做差分对拍验证。

---

## 环境要求

| 项目 | 要求 |
|---|---|
| 电脑 | **Advanced Computer（高级电脑）** 或 Command Computer |
| HTTP | 必须开启（`http` API 可用） |
| 服务器白名单 | 放行 `music.163.com`、`interface.music.163.com`；安装时还需 `raw.githubusercontent.com`、`cdn.jsdelivr.net` 以及 **`git.liulikeji.cn`**（下载 `cc_big_http` / `cc_speakerlib` 用） |
| 磁盘 | 库约 400 KB（CC 电脑默认 1 MB，够用）；音频缓存另计 |
| 内存 | `computerSpaceLimit` 必须大于你要播放的最大音频文件（见下） |

### 磁盘占用（默认上限够用，无需改配置）

CC:Tweaked 的电脑磁盘上限在实例目录 `config/computercraft-server.toml`：

```toml
# The disk space limit for computers and turtles, in bytes.
computer_space_limit = 1000000     # 默认 1 MB
```

**默认的 1 MB 够用**：本库约 **440 KB / 400 个文件**，外部依赖（`ncm/lib/` 下的 aeslua-cc、
cc_big_http、speaker）约 **80 KB**，合计约 **520 KB**，实机安装验证通过（安装器会打印
`free space: N bytes` 与 `extracted 401 files`）。

> 只有在**同一台电脑上残留了上一次安装**（例如上次装到一半被中断、旧包没删净）时才可能报
> `Out of space`。此时**清空 `/ncm` 再重跑安装器**即可；确实想留余量再考虑调大
> `computer_space_limit`（改完需**重启世界**生效）。

> 注意两个平台的同名项含义不同：**CraftOS-PC** 的 `computerSpaceLimit`（`config/global.json`）
> 管的是 **Lua 内存**；**CC:Tweaked（Minecraft）** 的 `computer_space_limit` 管的是**磁盘**。

> **音频播放的内存**：本库的"全量下载 → 解码 → 播放"路径会把整首 FLAC 放进内存（磁盘放不下
> 几十 MB），所以真正需要余量的是**内存**而不是磁盘：几十 MB 的曲目要求 JVM 堆足够大。

> **为什么需要 `cc_big_http`**：CC:Tweaked 对**单次 HTTP 响应体**有硬上限
> `http_max_download`（默认 **16777216 字节 = 16 MiB**）。网易云的音频直链通常有 10–50 MB，
> 一次性 GET 会因为超过上限而失败。`cc_big_http` 用 HTTP `Range` 把一个大文件拆成 **15 MiB**
> 的分块依次下载再拼接，从而绕过这个单响应上限；本库的所有对外 GET 都经由它发出。

> **内存要求（重要，请务必调高）**：`cc_big_http` 会把所有分块**拼接成一个 Lua 字符串**，
> 所以**峰值内存 = 整个文件大小**。默认的 `computerSpaceLimit` 通常只有 1 MB，下载稍大的音频就会
> 因内存不足失败。请把服务器的 `computerSpaceLimit` 调到**大于你打算播放的最大音频文件**
> ——例如 CraftOS-PC 单机配置里设为 **64 MB**（`134217728` 字节），才能稳定播放 10–50 MB 的曲目。
> 这不是可选项：不改的话大文件一定播不了。

---

## 一键安装

在 CC 电脑的 shell 里执行：

```
wget run https://cdn.jsdelivr.net/gh/colorgarden/NeteaseCloudMusicApiLibCCT@main/install.lua
```

（备用地址，若 jsDelivr 不可用：把上面的 URL 换成
`https://raw.githubusercontent.com/colorgarden/NeteaseCloudMusicApiLibCCT/main/install.lua`。）

脚本会：

1. **交互式让你选择下载源**（jsDelivr / GitHub raw / ghproxy.net 加速 / 自定义 URL）；
2. 检测并**删除已安装的旧版本**（`/ncm/` 整棵树，以及旧版散落在根目录的 `/aeslua.lua`、`/aeslua/`、`/cc_big_http.lua`、`/speaker.lua`）；
3. 先用内置 `http` API **下载并加载分块下载库 `cc_big_http`**（约 8 KB；它无法用自己下载自己，
   所以这一步必须走原生 `http`，且固定使用上游地址 `git.liulikeji.cn`，与你选择的下载源无关）；
4. 之后所有下载都经由 `cc_big_http` 的 `Range` 分块：**流式下载并解包** `dist/ncm.tar`
   （边下边写，不占额外磁盘、不需要 gzip 库）；
5. **自动下载依赖** `aeslua-cc`（跟随所选源）；
6. 校验文件并打印用法。

安装时会看到：

```
请选择下载源 / Choose a download source:
  1) jsDelivr (推荐 / recommended)
  2) GitHub raw
  3) ghproxy.net (GitHub 加速)
  4) 自定义 (custom URL)
序号 [1]:
```

直接回车 = jsDelivr。无人值守（CI / 无 stdin）时自动使用 jsDelivr。

自定义镜像 / 自建源（非交互，跳过菜单）：

```
wget run <install.lua 的 URL> https://你的镜像/colorgarden/NeteaseCloudMusicApiLibCCT/main
```

第二个参数可选，用于单独指定 aeslua 依赖地址。

> **关于 `require` 路径**:CC 的 `require` 是**相对「程序所在目录」**解析的(不是当前工作目录)。
> 默认把库装到根目录 `/`,因此:
> - 程序放在 `/`(例如 `/myprog.lua`)→ 直接 `require("ncm")` 即可;
> - 程序放在子目录(例如 `/home/0/prog.lua`)→ 在程序开头加一行:
>
>   ```lua
>   package.path = "/?.lua;/?/init.lua;" .. package.path
>   local ncm = require("ncm")
>   ```
>
> 另外,用 `wget run install.lua` 安装时,脚本运行在 `/rom/programs/http`,所以**安装器自己**
> 无法 `require("ncm")`(它只做文件校验)——这是正常的,不影响安装结果。

---

## 快速开始

```lua
local ncm = require("ncm")

-- 搜索（返回结构 = 原版 { status, body, cookie }）
local r = ncm.search({ keywords = "周杰伦", type = 1, limit = 10 })
print(textutils.serialize(r.body.result.songs[1]))

-- 歌曲播放链接（拿到 URL 后可以用 CC 的方式去下载/播放）
local u = ncm.song_url_v1({ id = 186016, level = "standard" })
print(u.body.data[1].url)

-- 歌词
local l = ncm.lyric({ id = 186016 })
print(l.body.lrc.lyric)
```

> **错误处理**：与原版一致，HTTP 非 200 / 接口返回非 200 会**抛错**（Node 里是 Promise reject）。
> 用 `pcall` 包一层：
> ```lua
> local ok, res = pcall(ncm.search, { keywords = "test" })
> if not ok then print("失败: " .. tostring(res.body and res.body.msg)) end
> ```

---

## 登录

### 手机号 / 邮箱

```lua
local ncm = require("ncm")

local r = ncm.login_cellphone({ phone = "13800000000", password = "你的密码" })
local cookie = r.body.cookie           -- 之后所有需要登录的接口都带上它

local me = ncm.user_account({ cookie = cookie })
```

### 二维码登录（可直接扫终端上的码）

```lua
local ncm = require("ncm")
local qr  = require("ncm.util.qrcode")

-- 1) 申请二维码 key
local key = ncm.login_qr_key({}).body.data.unikey

-- 2) 生成登录二维码 URL
local q = ncm.login_qr_create({ key = key })
local url = q.body.data.qrurl

-- 3) 画到终端（half 模式 33 列 × 17 行，正好塞进默认 51×19 终端）
qr.draw(url, { style = "half", border = 1 })        -- 彩色块，最稳
-- qr.printASCII(url, { style = "half", border = 1 }) -- 纯字符

-- 4) 轮询扫码状态：801=待扫 802=已扫待确认 803=成功
while true do
  sleep(1)
  local s = ncm.login_qr_check({ key = key })
  if s.body.code == 803 then
    print("登录成功，cookie: " .. s.body.cookie)
    break
  end
end
```

---

## 二维码渲染 API（`ncm.util.qrcode`）

库只保留实际使用的那一个渲染器，避免死代码：

| 函数 | 用途 |
|---|---|
| `encode(text, opts)` | 生成模块矩阵（`{ version, size, modules }`），`opts.ecl` = L/M/Q/H，默认自动选版本 |
| `toDataURL(text, opts)` | 生成 PNG data URL（`login_qr_create` 的 `qrimg` 用它） |
| `printCC(text, opts)` | **主力渲染器**：用 CC 字体在字节 0x80–0x9F 的 3×2 子像素字形 + `term.blit` 上色，一个字符格放 6 个模块，33 模块的码只占 17 列 × 12 行，适配默认 51×19 终端。`opts.border` 默认 1 |
| `draw(text, opts)` | 兜底渲染器：一格一个模块、纯背景色，不依赖任何字形（终端太小时不适合） |

`printCC` 的打包启发式改写自 GMapiServer 的 `qr_bimg_utils.py`（GPL-2.0，见 [NOTICE](NOTICE)）。

```lua
local qr = require("ncm.util.qrcode")
qr.printCC("https://music.163.com/login?codekey=...", { border = 1 })
```
## 播放音乐(扬声器)

CC 的扬声器 `speaker.playAudio` 只接受 **8-bit PCM(振幅 −128..127,48kHz)**,而且 CC **无法解码
mp3/aac**。有两种可行方案:

### 方案 A:交给 speakerlib,用远程转码服务器(最省 CPU)

仓库里的 `ncm/lib/speaker.lua`（**cc_speakerlib**）自带一个 `-server` 远程转码接口，默认
`http://newgmapi.liulikeji.cn/api/ffmpeg`：把任意音频 URL（**mp3 / aac / flac 都行**）发给它，
服务器用 ffmpeg 转成 **DFPWM** 再回传，本地只做 DFPWM 解码（1 bit/样本，几乎不耗 CPU）。

- **mp3/aac 只有这条路能播**（纯 Lua 解不了 mp3）；
- FLAC 也走它最省事 —— 本地解码跟不上时，这是不动机器配置就能顺畅播放的办法；
- `ncm/cli` 已自动分流：`type == "flac"` 走本地解码，其余交给 speaker 程序；
- 它自带的 UI 有进度条 / 暂停 / 点击跳转（我们的 `ncm/cli` 直接沿用）。

```
-- 手动调用（也可以直接在 shell 里跑）
speaker "https://.../song.mp3" -id my_music
```

### 方案 B:纯 CC,本地流式解码 FLAC(内置,无外部工具)


`ncm.util.audio` 内置了一个**纯 Lua 流式 FLAC 解码器**(`ncm.util.flac`):FLAC 是逐帧的,可以
**边下载边解码边播放**,内存恒定。已与 ffmpeg 对拍,16/24-bit 解码**逐字节一致**。

前提:直链是 **FLAC**(用 `level = "lossless"`,需要 VIP/无损权限):

```lua
local ncm   = require("ncm")
local audio = require("ncm.util.audio")

local url = ncm.song_url_v1({ id = 186016, level = "lossless" }).body.data[1].url
audio.playFlacUrl(url, { volume = 1.0 })            -- 网络流式
-- audio.playFlacFile("song.flac", { volume = 1.0 })  -- 本地文件
```

> 纯 Lua 解码很吃 CPU,普通电脑上**可能达不到实时**(会卡顿);建议高级电脑 / 单声道 / 低采样率,
> 或改用方案 B。32-bit FLAC 不支持(实际文件都是 16/24-bit)。


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

### 方案 C:交给 speakerlib,用远程转码服务器(最省 CPU)

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

### 方案 A:纯 CC,流式解码 FLAC(内置,无外部工具)


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

### 方案 B:PC 预转 DFPWM(最省 CPU)

只有 mp3 直链、或想省 CPU 时:在 PC 上用 ffmpeg 转成 **DFPWM**(1 bit/样本,约 6KB/s),托管后
CC 直接播放(内置 `cc.audio.dfpwm` 解码,几乎不吃 CPU)。

```bash
pkg install ffmpeg nodejs-lts
tools/audio_to_dfpwm.sh "<歌曲直链>" song.dfpwm     # 任意格式 -> DFPWM
```

```lua
local audio = require("ncm.util.audio")
audio.playUrl("http://your-host/song.dfpwm", { volume = 1.0 })   -- 网络
audio.playFile("song.dfpwm", { volume = 1.0 })                   -- 本地文件
```

在线转换器:<https://music.madefor.cc/>

> 原理:PC 端 ffmpeg 解码并重采样为 mono/48kHz 8-bit PCM,再用 `tools/dfpwm_encode.js`
> (与 CC 解码器一致的算法)编码;CC 端流式下载播放。

---

## 命令行客户端 / CLI

仓库自带一个开箱即用的命令行客户端 `ncm/cli.lua`（安装后位于 `/ncm/cli.lua`）。
在 CC 电脑的 shell 里运行：

```
ncm/cli
```

启动时会自动读取 `/ncm_cookie` 里的登录 cookie；没有则提示先登录。菜单为英文
（CC 默认字体没有中文字形），功能：

| 菜单项 | 说明 |
|---|---|
| `Login (QR code)` | 申请二维码 key、生成二维码并**直接画到终端**（half 半块模式，适配默认 51×19 终端），轮询扫码状态（800 过期 / 801 待扫 / 802 已扫 / 803 成功）；成功后把 cookie（`MUSIC_U=...; __csrf=...`）写入 `/ncm_cookie`。 |
| `Search & Play` | 输入关键字，调用 `ncm.search({ type = 1, limit = 10 })`，列出序号 / 歌名 / 歌手，输入序号播放。 |
| `Play by ID` | 直接输入歌曲 ID 播放。 |
| `Play a .dfpwm` | 播放本地路径或 URL 的 `.dfpwm` 文件（只接受 `.dfpwm`）。 |
| `Show account` | 用已保存的 cookie 调用 `ncm.user_account` 显示昵称 / 用户 ID。 |
| `Logout` | 调用 `ncm.logout` 并删除本地 cookie 文件。 |
| `Quit` | 退出并恢复终端（清屏、光标归位）。 |

播放策略（**不做任何远程转码**）：

- **纯 CC 流式解码 FLAC（主用）**：`Search & Play` / `Play by ID` 用
  `ncm.song_url_v1({ level = "lossless" })` 取直链。若返回 `.flac`，客户端用
  `ncm.util.audio.playFlacUrl` 边下载边解码边播放（CPU 占用较高，建议高级电脑）。
  若返回的不是 FLAC（账号没有无损 / VIP 权限时通常是 mp3），终端会明确提示
  纯 CC 无法解码 mp3，并引导改用 DFPWM 方案。
- **DFPWM（可选）**：`Play a .dfpwm` 只接受 `.dfpwm` 目标。若目标是以
  `http(s)://` 开头的 URL 且系统里存在 `speaker` 程序，则调用
  `speaker <url> -id ncm_cli`（speakerlib 直接播放 DFPWM，不触发转码）；
  否则用内置解码器 `ncm.util.audio.playUrl` / `playFile` 本地播放。
  **绝不会把非 `.dfpwm` 的链接交给 `speaker`，也绝不使用任何远程转码服务
  （不使用 `-server`）。**

> 想听 mp3 歌曲：在 PC 上用 `tools/audio_to_dfpwm.sh "<歌曲直链>" song.dfpwm`
> 预转成 DFPWM，托管到 HTTP 后再用 `Play a .dfpwm` 播放。

> Ctrl+T 可随时终止；客户端用 `pcall` 捕获并恢复终端。

---

## 接口一览

全部 377 个接口 = `ncm/module/` 下的文件，调用方式为 **`ncm.<文件名>({ 参数 })`**，参数名与原版一致。

主要分类：

- **登录**：`login` `login_cellphone` `login_qr_key` `login_qr_create` `login_qr_check` `login_refresh` `logout` `register_*` `captcha_*`
- **搜索**：`search` `cloudsearch` `search_suggest` `search_hot` `search_match` `search_multimatch`
- **歌曲**：`song_url` `song_url_v1` `song_detail` `song_download_url` `song_like_check` `song_order_update` `check_music`
- **歌词**：`lyric` `lyric_new` `song_lyrics_mark*`
- **歌单**：`playlist_detail` `playlist_create` `playlist_subscribe` `playlist_track_add/delete` `playlist_tracks` `playlist_update` `top_playlist*`
- **专辑 / 歌手**：`album*` `artists` `artist_songs` `artist_album` `artist_top_song`
- **评论**：`comment` `comment_music` `comment_hot` `comment_floor` `comment_like` `comment_new`
- **用户**：`user_account` `user_detail` `user_playlist` `user_record` `user_subcount` `user_follow*`
- **推荐 / FM**：`personalized*` `recommend_songs` `personal_fm` `personal_fm_mode`
- **电台 / DJ**：`dj_detail` `dj_program` `dj_category_*` `radio_*`
- **视频 / MV**：`mv_url` `mv_detail` `video_url` `video_detail` `artist_mv`
- **云盘 / 上传**：`cloud` `cloud_import` `cloud_match` `voice_upload` `avatar_upload` `playlist_cover_update`
- **听歌打卡 / 音乐人**：`scrobble` `musician_*` `yunbei_*`

（完整清单见仓库 `ncm/module/` 目录；也可以 `ls /ncm/module` 查看。）

---

## 依赖与版权

| 组件 | 用途 | 许可 | 获取方式 |
|---|---|---|---|
| [aeslua-cc](https://github.com/AngusAU293/aeslua-cc) | AES 块原语 | LGPL | 安装脚本自动下载 |
| [cc_big_http](https://git.liulikeji.cn/xingluo/cc_big_http) | 分块 GET（绕过单响应上限） | **GPL-2.0** | 安装脚本自动下载，**不随本仓库分发** |
| [cc_speakerlib](https://git.liulikeji.cn/xingluo/cc_speakerlib) | `speaker` 播放程序（本地 DFPWM） | **MPL-2.0**（文件头 SPDX 声明；上游无 LICENSE 文件） | 安装脚本自动下载为 `/ncm/lib/speaker.lua`，**不随本仓库分发** |
| [GMapiServer](https://git.liulikeji.cn/xingluo/GMapiServer) | 二维码 3×2 子像素打包算法（`qr_bimg_utils.py`） | **GPL-2.0** | 已**改写**进 `ncm/util/qrcode.lua`（整仓因此改为 GPL-2.0） |
| [LibDeflate](https://github.com/SafeteeWoW/LibDeflate) | gzip 解压 | zlib | 已内置 `ncm/util/libdeflate.lua` |
| [NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi) | 原始 Node 实现 | MIT | 本移植的上游 |

**关于 `cc_big_http`（请务必阅读）**：它是本库的**硬运行时依赖**——库运行时的对外 GET 都经由
`ncm/util/httpx.lua` 交给它，用 HTTP `Range` 分块下载来绕过 `http_max_download`（默认 16 MiB）
的单响应上限。它采用 **GNU GPL-2.0** 许可，与本项目（现同为 **GPL-2.0**）兼容。为尊重其许可，
本项目**不复制、不内置** `cc_big_http.lua`（仓库目录和 `dist/ncm.tar` 里都没有它），而是由安装脚本
在安装时从其上游 <https://git.liulikeji.cn/xingluo/cc_big_http> 现场下载到 `/ncm/lib/cc_big_http.lua`。

**关于 `cc_speakerlib`**：它是 `ncm/cli` 用来播放本地 `.dfpwm` 的 `speaker` 程序，安装为
`/ncm/lib/speaker.lua`。它**自身会去同目录查找 `cc_big_http.lua`**（两者同装在 `/ncm/lib/` 下，天然配合）。
其源码头部声明 `SPDX-License-Identifier: MPL-2.0`（衍生自 CC:Tweaked 的 `speaker` 程序），
但**上游仓库没有 LICENSE 文件**。同样地，本项目**不内置**它，由安装脚本从上游现场下载。
它默认带一个远程转码接口（`-server`，默认 `http://newgmapi.liulikeji.cn/api/ffmpeg`）。
`ncm/cli` 在两种情况下启动它：播放**本地 `.dfpwm` 直通**，以及播放 **mp3/aac 链接**时
通过该服务远程转码成 DFPWM（纯 Lua 解码器解不了 mp3；远程转码后播放几乎不耗 CPU）。

本移植自身以 **GPL-2.0** 许可发布，详见 [LICENSE](LICENSE)。
（原为 MIT；因为二维码渲染借鉴了 GPL-2.0 的 GMapiServer，整仓已按 GPL-2.0 发布。）

---

## 已知限制

- 需要**高级电脑**且服务器开启 HTTP；CC 的 `http` 是同步的（无并发、无代理、无 gzip 请求体）。
- **单次 HTTP 响应上限**：`http_max_download` 默认 **16 MiB**（`16777216`）。网易云音频直链常为
  10–50 MB，必须依赖 `cc_big_http` 的 HTTP `Range` 分块下载；若服务器/上游禁用了 `Range`，
  超过上限的文件将无法获取。
- **jsDelivr 的 gzip 会破坏 Range 校验（已自动规避）**：jsDelivr 对 `dist/ncm.tar` 强制 gzip，
  而 CraftOS 会透明解压响应体，导致 `cc_big_http` 的字节区间校验失败
  （`Invalid chunk size for bytes=...`）。安装器遇到这种情况会**自动回退到原生 GET**
  （bundle 仅约 700 KB，远低于 16 MiB 上限）。**网易云音频直链不受影响**：音频本身已压缩，
  CDN 不会再 gzip，因此仍走 `Range` 分块。
- **内存**：`cc_big_http` 会把整个响应拼接成一个 Lua 字符串，**峰值内存 = 文件大小**。必须把
  `computerSpaceLimit` 调高到大于最大音频文件（例如 CraftOS-PC 下 64 MB），否则大曲目会失败。
- 上传类接口（`cloud` / `voice_upload` / `avatar_upload` / `playlist_cover_update`）：
  文件从 CC 文件系统读取；原版用 `music-metadata` 读 ID3 标签，CC 上不可用，
  需通过 `songName` / `album` / `artist` 等参数传入元数据。
- 二维码编码器是独立实现，**与 npm `qrcode` 不逐字节一致**（掩码可能不同），但都是合法、可扫的二维码
  （已用真实解码器验证）。
- 与原版一致：非 200 抛错；`cookie` 需自行在请求间传递。
- 部分接口需要登录 / VIP / 特定账号权限。

---

## 项目结构

```
ncm/
  init.lua             -- require("ncm") 入口，聚合全部 module
  manifest.lua         -- 模块清单
  cli.lua              -- 命令行客户端（ncm/cli：二维码登录 + 搜索 + 播放）
  module/              -- 377 个接口模块
  util/
    crypto.lua         -- weapi / eapi / linuxapi 加解密
    request.lua        -- CC http 封装、cookie、状态码归一
    httpx.lua          -- GET 网关：硬依赖 cc_big_http（Range 分块），缺失即报错（不回退原生 http）
    aes.lua md5.lua rsa.lua base64.lua json.lua
    qrcode.lua         -- 二维码编码 + PNG + 终端渲染
    gzip.lua libdeflate.lua  -- gzip 解压
    config.lua option.lua index.lua js.lua
  lib.lua              -- 依赖目录定位器：把 ncm/lib 加入 package.path
  lib/                 -- 全部第三方依赖都装在这里（安装时下载，不在本仓库内）
    aeslua.lua         --   LGPL    · aeslua-cc
    aeslua/            --   LGPL    · aeslua-cc 子模块
    cc_big_http.lua    --   GPL-2.0 · 分块 GET
    speaker.lua        --   MPL-2.0 · cc_speakerlib
install.lua            -- 一键安装脚本
dist/ncm.tar           -- 预打包的库（安装脚本下载用）
tools/build_dist.js    -- 重新生成 dist/ncm.tar
```

---

## 开发

```bash
# 重新打包库（修改 ncm/ 后执行，install.lua 会下载这个 tar）
node tools/build_dist.js
```

---

## 免责声明

本项目仅供学习与技术研究，所有音乐内容版权归网易云音乐及相关权利人所有。
请勿用于商业用途，并遵守网易云音乐的服务条款。

## License

本项目以 **MIT** 许可发布，见 [LICENSE](LICENSE)；第三方组件与署名见 [NOTICE](NOTICE)。

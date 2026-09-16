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
| 服务器白名单 | 放行 `music.163.com`、`interface.music.163.com`；安装时还需 `raw.githubusercontent.com`、`cdn.jsdelivr.net` |
| 磁盘 | 库约 400 KB（CC 电脑默认 1 MB，够用） |

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
2. 检测并**删除已安装的旧版本**（`/ncm`、`/aeslua.lua`、`/aeslua`）；
3. 从所选源**流式下载并解包** `dist/ncm.tar`（边下边写，不占额外磁盘、不需要 gzip 库）；
4. **自动下载依赖** `aeslua-cc`（跟随所选源）；
5. 校验文件并打印用法。

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

```lua
local qr = require("ncm.util.qrcode")

qr.toDataURL(text)            -- "data:image/png;base64,..."（标准 PNG）
qr.encode(text)               -- 模块矩阵 { version, size, modules[y][x]=dark }
qr.toLines(text, opts)        -- 返回多行字符串（自行排版）
qr.printASCII(text, opts)     -- 直接打印到终端
qr.draw(text, opts)           -- 用终端背景色绘制（CC 上最可靠）

-- 纠错等级 L/M/Q/H（默认 M，等级越高越抗损但码更大）
qr.toDataURL(text, "H")                       -- 字符串简写
qr.encode(text, { ecl = "Q" })                -- 也可用 errorCorrectionLevel / level
qr.toLines(text, { style = "braille", ecl = "H" })
```

`opts.style`：

| style | 效果 | 宽度 | 行数 |
|---|---|---|---|
| `text`（默认） | 每模块 2 格 `██`/空格 | 2N | N |
| `compact` | 每模块 1 格 `█`/空格 | N | N |
| `ascii` | `#`/空格（纯 ASCII） | N | N |
| `half` | 半块 `█▀▄`，两行模块压一行 | N | ⌈N/2⌉ |
| `braille` | Unicode 盲文，2×4 模块压 1 格（**密度最高**） | ⌈N/2⌉ | ⌈N/4⌉ |

其它选项：`border`（静默区，默认 2）、`invert`（反色）。

> `braille` 密度最高，但要**终端字体包含 Unicode 盲文块**（U+2800–U+28FF）才能正常显示；
> 普通 CC 字体可能没有该字形。不确定时用 `half` 或 `compact`。

---

## 播放音乐(扬声器)

CC 的扬声器 `speaker.playAudio` 只接受 **8-bit PCM(振幅 −128..127,48kHz)**,而且 CC **无法解码
mp3/aac**。有两种可行方案:

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
| [LibDeflate](https://github.com/SafeteeWoW/LibDeflate) | gzip 解压 | zlib | 已内置 `ncm/util/libdeflate.lua` |
| [NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi) | 原始 Node 实现 | MIT | 本移植的上游 |

本移植自身以 **MIT** 许可发布，详见 [LICENSE](LICENSE)。

---

## 已知限制

- 需要**高级电脑**且服务器开启 HTTP；CC 的 `http` 是同步的（无并发、无代理、无 gzip 请求体）。
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
    aes.lua md5.lua rsa.lua base64.lua json.lua
    qrcode.lua         -- 二维码编码 + PNG + 终端渲染
    gzip.lua libdeflate.lua  -- gzip 解压
    config.lua option.lua index.lua js.lua
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

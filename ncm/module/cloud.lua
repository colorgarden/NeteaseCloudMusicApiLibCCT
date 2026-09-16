-- 云盘上传 (song upload to the cloud drive)
-- Port of NeteaseCloudMusicApi@4.32.0 module/cloud.js (plus its
-- plugins/songUpload.js dependency) onto CC:Tweaked.
--
-- The Node original uses `music-metadata` to read ID3 tags, `md5` to hash the
-- buffer and axios to push the bytes to Netease's NOS object store. CC:Tweaked
-- has none of those, so:
--   * md5 -> `require("ncm.util.md5").sumhexa`;
--   * the NOS upload (plugins/songUpload.js) is inlined here and uses the global
--     `http` API with a binary body (a POST, so it stays on `httpApi`);
--   * the lbs lookup GET goes through `ncm.util.httpx` (cc_big_http Range
--     chunks) because NetEase responses can exceed the 16 MiB
--     (`http_max_download`) built-in single-response cap;
--   * `music-metadata` tag parsing is not available. Callers may still pass
--     `query.songName`/`query.title`, `query.album`, `query.artist`, which the
--     original would otherwise have read from the file; when absent the same
--     fallbacks are used (`filename`, "未知专辑", "未知艺术家").
--
-- NOTE: the original reinterprets the filename with
-- `Buffer.from(name, 'latin1').toString('utf-8')` (express-fileupload hands it
-- over as latin1-decoded bytes). That is reproduced here byte-for-byte, so a CC
-- caller should pass the *raw* byte string, not an already UTF-8 decoded one.
--
-- Upload bytes are read from the CC `fs` API: `query.songFile.path` is opened
-- with fs.open(path, "rb"), read with readAll() and closed. Raw bytes already
-- in `query.songFile.data` are accepted as-is.
--
-- LIMITATION: CC:Tweaked cannot throw/reject; failures return a
-- `{ status, body = { code, msg } }` table instead of raising. Every JS
-- `request(uri, data, options)` call is otherwise identical.

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")
local md5 = require("ncm.util.md5")
local httpx = require("ncm.util.httpx")

-- Read the upload file's bytes: either raw `file.data`, or `file.path` read via
-- fs.open(path, "rb") / readAll() / close().
local function readUploadFile(file)
  if type(file) ~= "table" then
    return nil, nil, "missing upload file"
  end
  local name = file.name
  local data = file.data
  if data == nil and file.path ~= nil then
    local fsApi = rawget(_G, "fs")
    if not fsApi then
      return nil, name, "fs API unavailable"
    end
    local handle = fsApi.open(file.path, "rb")
    if not handle then
      return nil, name, "cannot open " .. tostring(file.path)
    end
    data = handle.readAll()
    handle.close()
    if name == nil then
      name = tostring(file.path):match("([^/\\]+)$")
    end
  end
  if data == nil then
    return nil, name, "upload file has no bytes (need .data or .path)"
  end
  return data, name, nil
end

-- Buffer.from(name, 'latin1').toString('utf-8'): re-encode every byte 0..255 as
-- a UTF-8 code point (< 0x80 passes through, high bytes become 2-byte UTF-8).
local function latin1ToUtf8(s)
  if not s:find("[\128-\255]") then
    return s
  end
  local out = {}
  for i = 1, #s do
    local b = s:byte(i)
    if b < 0x80 then
      out[#out + 1] = string.char(b)
    else
      out[#out + 1] = string.char(0xC0 + math.floor(b / 0x40), 0x80 + b % 0x40)
    end
  end
  return table.concat(out)
end

-- Inlined plugins/songUpload.js: allocate a NOS token, look up the upload node
-- via the lbs service, then PUT the whole file with axios/`http`.
local function uploadSongFile(query, request, data)
  local songFile = query.songFile
  local name = songFile.name
  local ext = "mp3"
  -- if (query.songFile.name.indexOf('flac') > -1) { ext = 'flac' }
  if name and name:find(".", 1, true) then
    ext = name:match("%.([^.]*)$") or ""
  end
  local filename = js.replace(name, "." .. ext, "")
  filename = filename:gsub("%s", "")
  filename = filename:gsub("%.", "_")
  local bucket = "jd-musicrep-privatecloud-audio-public"
  --   获取key和token
  local tokenRes = request(
    "/api/nos/token/alloc",
    {
      bucket = bucket,
      ext = ext,
      filename = filename,
      ["local"] = false,
      nos_product = 3,
      type = "audio",
      md5 = songFile.md5,
    },
    createOption(query, "weapi")
  )

  -- 上传
  local objectKey = js.replace(tokenRes.body.result.objectKey, "/", "%2F")
  local httpApi = rawget(_G, "http")
  if not httpApi then
    return nil, "http API unavailable (need an advanced computer with HTTP enabled)"
  end
  -- try { ... } catch (error) { console.log('error', error.response); throw error.response }
  local lbsRes, lbsErr = httpx.get(
    "https://wanproxy.127.net/lbs?version=1.0&bucketname=" .. bucket
  )
  if not lbsRes then
    return nil, lbsErr or "request failed"
  end
  local lbsRaw = lbsRes.readAll()
  lbsRes.close()
  local ok, lbs = pcall(json.decode, lbsRaw)
  if not ok or type(lbs) ~= "table" or type(lbs.upload) ~= "table" then
    return nil, "cannot parse lbs response"
  end
  local uploadUrl = tostring(lbs.upload[1]) .. "/" .. bucket .. "/" .. objectKey
    .. "?offset=0&complete=true&version=1.0"
  local upRes, upErr = httpApi.post({
    url = uploadUrl,
    headers = {
      ["x-nos-token"] = tokenRes.body.result.token,
      ["Content-MD5"] = songFile.md5,
      ["Content-Type"] = "audio/mpeg",
      ["Content-Length"] = tostring(songFile.size),
    },
    body = data,
    binary = true,
  })
  if not upRes then
    return nil, upErr or "request failed"
  end
  upRes.close()
  return tokenRes
end

return function(query, request)
  local songFile = query.songFile
  local data, songFileName = readUploadFile(songFile)
  if data == nil then
    return {
      status = 500,
      body = {
        msg = "请上传音乐文件",
        code = 500,
      },
    }
  end

  local ext = "mp3"
  -- if (query.songFile.name.indexOf('flac') > -1) { ext = 'flac' }
  if songFileName and songFileName:find(".", 1, true) then
    ext = songFileName:match("%.([^.]*)$") or ""
  end
  -- query.songFile.name = Buffer.from(query.songFile.name, 'latin1').toString('utf-8')
  songFile.name = latin1ToUtf8(songFileName or "")
  local name = songFile.name
  local filename = js.replace(name, "." .. ext, "")
  filename = filename:gsub("%s", "")
  filename = filename:gsub("%.", "_")
  local bitrate = 999000
  if js.falsy(songFile.md5) then
    -- 命令行上传没有md5和size信息,需要填充
    songFile.md5 = md5.sumhexa(data)
    songFile.size = #data
  end
  local res = request(
    "/api/cloud/upload/check",
    {
      bitrate = tostring(bitrate),
      ext = "",
      length = songFile.size,
      md5 = songFile.md5,
      songId = "0",
      version = 1,
    },
    createOption(query)
  )
  -- music-metadata is unavailable on CC:Tweaked: optional query overrides stand
  -- in for metadata.common.{title,album,artist}; otherwise the same defaults.
  local songName = js.or_(js.or_(query.songName, query.title), "")
  local album = js.or_(js.or_(query.albumName, query.album), "")
  local artist = js.or_(js.or_(query.artistName, query.artist), "")
  local tokenRes = request(
    "/api/nos/token/alloc",
    {
      bucket = "",
      ext = ext,
      filename = filename,
      ["local"] = false,
      nos_product = 3,
      type = "audio",
      md5 = songFile.md5,
    },
    createOption(query)
  )

  if res.body.needUpload then
    local _, uploadErr = uploadSongFile(query, request, data)
    if uploadErr then
      return { status = 500, body = { code = 500, msg = uploadErr } }
    end
  end
  local res2 = request(
    "/api/upload/cloud/info/v2",
    {
      md5 = songFile.md5,
      songid = res.body.songId,
      filename = songFile.name,
      song = js.or_(songName, filename),
      album = js.or_(album, "未知专辑"),
      artist = js.or_(artist, "未知艺术家"),
      bitrate = tostring(bitrate),
      resourceId = tokenRes.body.result.resourceId,
    },
    createOption(query)
  )
  local res3 = request(
    "/api/cloud/pub/v2",
    {
      songid = res2.body.songId,
    },
    createOption(query)
  )
  return {
    status = 200,
    body = js.assign({}, res.body, res3.body),
    cookie = res.cookie,
  }
end

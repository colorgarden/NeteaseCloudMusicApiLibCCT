-- 播客上传声音 (voice upload)
-- Port of NeteaseCloudMusicApi@4.32.0 module/voice_upload.js onto CC:Tweaked.
--
-- The Node original stores the audio in Netease's NOS object store with axios
-- (multipart upload of 10 MB blocks), parses the initiate response with xml2js
-- and then registers the voice through the shared `request` helper. CC:Tweaked
-- has neither axios nor xml2js, so:
--   * the NOS POST/PUT calls use the global `http` API with binary bodies;
--   * the initiate XML is read with a small Lua pattern. Only
--     `res2.InitiateMultipartUploadResult.UploadId[0]` is consumed, so a full
--     xml2js parse is unnecessary: `xml:match("<UploadId>([^<]*)</UploadId>")`;
--   * upload bytes come from the CC `fs` API. `query.songFile.path` is opened
--     with fs.open(path, "rb"), read with readAll() and closed; raw bytes in
--     `query.songFile.data` are accepted as-is (handy for callers/tests).
--
-- LIMITATION: CC:Tweaked cannot throw/reject, so failures return a
-- `{ status = <n>, body = { code, msg } }` table instead of raising. The
-- original's `Promise.reject({status:500,...})` for a missing file is kept, but
-- every JS `request(uri, data, options)` call is otherwise identical.

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

local NOS_HOST = "https://ymusic.nos-hz.163yun.com"

-- Query the upload file's bytes. Either the raw bytes (`file.data`) or a CC
-- filesystem path (`file.path`, read with fs.open/readAll/close) may be given.
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

-- Case-insensitive response header lookup (CC lower-cases most header names).
local function headerGet(headers, name)
  local want = name:lower()
  for k, v in pairs(headers) do
    if type(k) == "string" and k:lower() == want then
      return v
    end
  end
  return nil
end

-- JS `query.x == 1` (loose): 1, "1" and true all compare equal.
local function isOne(v)
  return v == true or tonumber(v) == 1
end

-- createDupkey(): the original builds a UUID-ish string from Math.random().
-- 格式:3b443c7c-a87f-468d-ba38-46d407aaf23a
local HEX_DIGITS = "0123456789abcdef"
local function createDupkey()
  -- JS array indices 0..35; store 1-based so table.concat covers every char.
  local s = {}
  for i = 0, 35 do
    local idx = math.floor(math.random() * 0x10) + 1
    s[i + 1] = HEX_DIGITS:sub(idx, idx)
  end
  s[14 + 1] = "4" -- bits 12-15 of the time_hi_and_version field to 0010
  -- s[19] = hexDigits.substr((s[19] & 0x3) | 0x8, 1)
  -- JS bitwise-AND on a non-digit char is NaN -> 0, so a-f map to 8.
  local d = tonumber(s[19 + 1])
  local nib = (d and (d % 4) or 0) + 8
  s[19 + 1] = HEX_DIGITS:sub(nib + 1, nib + 1)
  s[8 + 1] = "-"
  s[13 + 1] = "-"
  s[18 + 1] = "-"
  s[23 + 1] = "-"
  return table.concat(s)
end

-- `voiceData: JSON.stringify([{...}])` for the preCheck / v2 bodies. `nil`
-- fields are dropped by json.encode exactly as JSON.stringify drops undefined.
local function buildVoiceData(query, filename, docId)
  local composedSongs
  if js.falsy(query.composedSongs) then
    composedSongs = js.array({})
  else
    composedSongs = js.split(query.composedSongs, ",")
  end
  local item = {
    name = filename,
    autoPublish = isOne(query.autoPublish),
    autoPublishText = js.or_(query.autoPublishText, ""),
    description = query.description,
    voiceListId = query.voiceListId,
    coverImgId = query.coverImgId,
    dfsId = docId,
    categoryId = query.categoryId,
    secondCategoryId = query.secondCategoryId,
    composedSongs = composedSongs,
    privacy = isOne(query.privacy),
    publishTime = js.or_(query.publishTime, 0),
    orderNo = js.or_(query.orderNo, 1),
  }
  return json.encode(js.array({ item }))
end

return function(query, request)
  local data, songFileName = readUploadFile(query.songFile)
  if data == nil then
    return {
      status = 500,
      body = {
        msg = "请上传音频文件",
        code = 500,
      },
    }
  end

  local ext = "mp3"
  if songFileName and songFileName:find("flac", 1, true) then
    ext = "flac"
  end
  local basename = songFileName and js.replace(songFileName, "." .. ext, "") or nil
  if basename then
    basename = basename:gsub("%s", "")
    basename = basename:gsub("%.", "_")
  end
  local filename = js.or_(query.songName, basename)

  local tokenRes = request(
    "/api/nos/token/alloc",
    {
      bucket = "ymusic",
      ext = ext,
      filename = filename,
      ["local"] = false,
      nos_product = 0,
      type = "other",
    },
    createOption(query, "weapi")
  )

  local result = tokenRes and tokenRes.body and tokenRes.body.result
  if not result then
    return { status = 500, body = { code = 500, msg = "nos/token/alloc failed" } }
  end
  local objectKey = js.replace(result.objectKey, "/", "%2F")
  local docId = result.docId
  local token = result.token

  local httpApi = rawget(_G, "http")
  if not httpApi then
    return {
      status = 502,
      body = { code = 502, msg = "http API unavailable (need an advanced computer with HTTP enabled)" },
    }
  end

  -- return xml
  local res, initErr = httpApi.post({
    url = NOS_HOST .. "/" .. objectKey .. "?uploads",
    headers = {
      ["x-nos-token"] = token,
      ["X-Nos-Meta-Content-Type"] = "audio/mpeg",
    },
    body = "",
    binary = true,
  })
  if not res then
    return { status = 502, body = { code = 502, msg = initErr or "request failed" } }
  end
  local initXml = res.readAll()
  res.close()
  local uploadId = initXml and initXml:match("<UploadId>([^<]*)</UploadId>")
  if not uploadId then
    return {
      status = 502,
      body = { code = 502, msg = "cannot parse InitiateMultipartUploadResult/UploadId" },
    }
  end

  local fileSize = #data
  local blockSize = 10 * 1024 * 1024 -- 10MB
  local offset = 0
  local blockIndex = 1

  local etags = {}

  while offset < fileSize do
    local chunk = data:sub(offset + 1, math.min(offset + blockSize, fileSize))

    local putRes, putErr = httpApi.request({
      url = NOS_HOST .. "/" .. objectKey
        .. "?partNumber=" .. tostring(blockIndex)
        .. "&uploadId=" .. uploadId,
      method = "PUT",
      headers = {
        ["x-nos-token"] = token,
        ["Content-Type"] = "audio/mpeg",
      },
      body = chunk,
      binary = true,
    })
    if not putRes then
      return { status = 502, body = { code = 502, msg = putErr or "request failed" } }
    end
    -- get etag
    local putHeaders = putRes.getResponseHeaders() or {}
    putRes.close()
    local etag = headerGet(putHeaders, "etag")
    etags[#etags + 1] = etag or ""
    offset = offset + blockSize
    blockIndex = blockIndex + 1
  end

  local completeStr = "<CompleteMultipartUpload>"
  for i = 1, #etags do
    completeStr = completeStr
      .. "<Part><PartNumber>" .. tostring(i) .. "</PartNumber><ETag>"
      .. tostring(etags[i]) .. "</ETag></Part>"
  end
  completeStr = completeStr .. "</CompleteMultipartUpload>"

  -- 文件处理
  local completeRes, completeErr = httpApi.post({
    url = NOS_HOST .. "/" .. objectKey .. "?uploadId=" .. uploadId,
    headers = {
      ["Content-Type"] = "text/plain;charset=UTF-8",
      ["X-Nos-Meta-Content-Type"] = "audio/mpeg",
      ["x-nos-token"] = token,
    },
    body = completeStr,
    binary = true,
  })
  if not completeRes then
    return { status = 502, body = { code = 502, msg = completeErr or "request failed" } }
  end
  completeRes.close()

  -- preCheck
  request(
    "/api/voice/workbench/voice/batch/upload/preCheck",
    {
      dupkey = createDupkey(),
      voiceData = buildVoiceData(query, filename, docId),
    },
    js.assign({}, createOption(query), {
      headers = {
        ["x-nos-token"] = token,
      },
    })
  )
  local resultRes = request(
    "/api/voice/workbench/voice/batch/upload/v2",
    {
      dupkey = createDupkey(),
      voiceData = buildVoiceData(query, filename, docId),
    },
    js.assign({}, createOption(query), {
      headers = {
        ["x-nos-token"] = token,
      },
    })
  )
  return {
    status = 200,
    body = {
      code = 200,
      data = resultRes.body.data,
    },
  }
end

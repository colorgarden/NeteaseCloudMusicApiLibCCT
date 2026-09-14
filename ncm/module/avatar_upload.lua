-- 更新头像 (avatar upload)
-- Port of NeteaseCloudMusicApi@4.32.0 module/avatar_upload.js plus its
-- plugins/upload.js dependency onto CC:Tweaked.
--
-- The Node original (plugins/upload.js) allocates a NOS token with the shared
-- `request` helper, then POSTs the image bytes with axios. CC:Tweaked has no
-- axios, so that POST uses the global `http` API with a binary body; every
-- `request(uri, data, options)` call is identical to the original.
--
-- Upload bytes come from the CC `fs` API: `query.imgFile.path` is opened with
-- fs.open(path, "rb"), read with readAll() and closed. Raw bytes already in
-- `query.imgFile.data` are accepted as-is.
--
-- LIMITATION: CC:Tweaked cannot throw/reject; failures return a
-- `{ status, body = { code, msg } }` table instead of raising.

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

-- Inlined plugins/upload.js. Returns `uploadInfo` or `nil, err`.
local function uploadImage(query, request)
  local imgFile = query.imgFile
  if type(imgFile) ~= "table" then
    return nil, "missing imgFile"
  end
  local data = imgFile.data
  local name = imgFile.name
  if data == nil and imgFile.path ~= nil then
    local fsApi = rawget(_G, "fs")
    if not fsApi then
      return nil, "fs API unavailable"
    end
    local handle = fsApi.open(imgFile.path, "rb")
    if not handle then
      return nil, "cannot open " .. tostring(imgFile.path)
    end
    data = handle.readAll()
    handle.close()
    if name == nil then
      name = tostring(imgFile.path):match("([^/\\]+)$")
    end
  end
  if data == nil then
    return nil, "imgFile has no bytes (need .data or .path)"
  end
  imgFile.name = name
  imgFile.data = data

  local allocData = {
    bucket = "yyimgs",
    ext = "jpg",
    filename = imgFile.name,
    ["local"] = false,
    nos_product = 0,
    return_body = '{"code":200,"size":"$(ObjectSize)"}',
    type = "other",
  }
  --   获取key和token
  local res = request(
    "/api/nos/token/alloc",
    allocData,
    createOption(query, "weapi")
  )
  --   上传图片
  local httpApi = rawget(_G, "http")
  if not httpApi then
    return nil, "http API unavailable (need an advanced computer with HTTP enabled)"
  end
  local result = res.body.result
  local objectKey = result.objectKey
  local response, reqErr = httpApi.post({
    url = "https://nosup-hz1.127.net/yyimgs/" .. objectKey
      .. "?offset=0&complete=true&version=1.0",
    headers = {
      ["x-nos-token"] = result.token,
      ["Content-Type"] = "image/jpeg",
    },
    body = data,
    binary = true,
  })
  if not response then
    return nil, reqErr or "request failed"
  end
  response.close()

  return {
    url_pre = "https://p1.music.126.net/" .. objectKey,
    imgId = result.docId,
  }
end

return function(query, request)
  local uploadInfo, uploadErr = uploadImage(query, request)
  if not uploadInfo then
    return { status = 500, body = { code = 500, msg = uploadErr } }
  end
  local res = request(
    "/api/user/avatar/upload/v1",
    {
      imgid = uploadInfo.imgId,
    },
    createOption(query)
  )
  return {
    status = 200,
    body = {
      code = 200,
      data = js.assign({}, uploadInfo, res.body),
    },
  }
end

-- Port of NeteaseCloudMusicApi module/login_qr_create.js
--
-- Unlike a normal request module this one takes only `query` and resolves a
-- synthetic response (no HTTP call). It builds the login URL and optionally
-- renders it as a QR data URL. `request` is accepted for the uniform module
-- signature but is intentionally unused.

local generateChainId = require("ncm.util.index").generateChainId
local js = require("ncm.util.js")
local qrcode = require("ncm.util.qrcode")

return function(query)
  local platform = js.or_(query.platform, "pc")
  local cookie = js.or_(query.cookie, "")

  -- 构建基础URL
  local url = "https://music.163.com/login?codekey=" .. js.tostr(query.key)

  -- 如果是web平台，则添加chainId参数
  if platform == "web" then
    local chainId = generateChainId(cookie)
    url = url .. "&chainId=" .. js.tostr(chainId)
  end

  -- Short-circuit so the QR is only rendered when requested (mirrors `await`).
  local qrimg = query.qrimg and qrcode.toDataURL(url) or ""

  return {
    code = 200,
    status = 200,
    body = {
      code = 200,
      data = {
        qrurl = url,
        qrimg = qrimg,
      },
    },
  }
end

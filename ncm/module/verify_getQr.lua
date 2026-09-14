-- Port of NeteaseCloudMusicApi module/verify_getQr.js

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")
local qrcode = require("ncm.util.qrcode")

return function(query, request)
  local params = json.encode({ event_id = query.evid, sign = query.sign })

  local data = {
    verifyConfigId = query.vid,
    verifyType = query.type,
    token = query.token,
    params = params,
    size = 150,
  }

  local res = request(
    "/api/frontrisk/verify/getqrcode",
    data,
    createOption(query, "weapi")
  )
  local result = "https://st.music.163.com/encrypt-pages?qrCode="
    .. js.tostr(res.body.data.qrCode)
    .. "&verifyToken=" .. js.tostr(query.token)
    .. "&verifyId=" .. js.tostr(query.vid)
    .. "&verifyType=" .. js.tostr(query.type)
    .. "&params=" .. params
  return {
    status = 200,
    body = {
      code = 200,
      data = {
        qrCode = res.body.data.qrCode,
        qrurl = result,
        qrimg = qrcode.toDataURL(result),
      },
    },
  }
end

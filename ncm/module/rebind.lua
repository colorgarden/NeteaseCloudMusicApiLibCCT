-- 更换手机

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    captcha = query.captcha,
    phone = query.phone,
    oldcaptcha = query.oldcaptcha,
    ctcode = js.or_(query.ctcode, "86"),
  }
  return request(
    "/api/user/replaceCellphone",
    data,
    createOption(query, "weapi")
  )
end

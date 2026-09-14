local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    phone = query.phone,
    captcha = query.captcha,
    oldcaptcha = query.oldcaptcha,
    countrycode = js.or_(query.countrycode, "86"),
  }
  return request(
    "/api/user/replaceCellphone",
    data,
    createOption(query, "weapi")
  )
end

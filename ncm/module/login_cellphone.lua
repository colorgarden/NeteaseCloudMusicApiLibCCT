-- 手机登录

local md5 = require("ncm.util.md5")

local createOption = require("ncm.options")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local data = {
    type = "1",
    https = "true",
    phone = query.phone,
    countrycode = js.or_(query.countrycode, "86"),
    captcha = query.captcha,
    remember = "true",
  }
  if js.falsy(query.captcha) then
    data.password = js.or_(query.md5_password, md5.sumhexa(js.md5in(query.password)))
  else
    data.captcha = query.captcha
  end
  local result = request(
    "/api/w/login/cellphone",
    data,
    createOption(query, "weapi")
  )

  if result.body.code == 200 then
    local body = json.decode(
      js.replaceAll(json.encode(result.body), "avatarImgId_str", "avatarImgIdStr")
    )
    result = {
      status = 200,
      body = js.assign({}, body, { cookie = js.join(result.cookie, ";") }),
      cookie = result.cookie,
    }
  end
  return result
end

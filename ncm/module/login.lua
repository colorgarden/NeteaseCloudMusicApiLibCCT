-- 邮箱登录

local md5 = require("ncm.util.md5")

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local data = {
    type = "0",
    https = "true",
    username = query.email,
    password = js.or_(query.md5_password, md5.sumhexa(js.md5in(query.password))),
    rememberLogin = "true",
  }
  local result = request("/api/w/login", data, createOption(query))
  if result.body.code == 502 then
    return {
      status = 200,
      body = {
        msg = "账号或密码错误",
        code = 502,
        message = "账号或密码错误",
      },
    }
  end
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

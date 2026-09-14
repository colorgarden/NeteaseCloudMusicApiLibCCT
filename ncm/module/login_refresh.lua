-- 登录刷新

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local result = request(
    "/api/login/token/refresh",
    {},
    createOption(query)
  )
  if result.body.code == 200 then
    result = {
      status = 200,
      body = js.assign({}, result.body, { cookie = js.join(result.cookie, ";") }),
      cookie = result.cookie,
    }
  end
  return result
end

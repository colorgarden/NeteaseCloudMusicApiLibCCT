local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  local data = {}
  local result = request(
    "/api/w/nuser/account/get",
    data,
    createOption(query, "weapi")
  )
  if result.body.code == 200 then
    result = {
      status = 200,
      body = {
        data = js.assign({}, result.body),
      },
      cookie = result.cookie,
    }
  end
  return result
end

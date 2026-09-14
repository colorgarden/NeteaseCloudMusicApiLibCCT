local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    key = query.key,
    type = 3,
  }
  local ok, result = pcall(function()
    return request("/api/login/qrcode/client/login", data, createOption(query))
  end)
  if ok then
    local cookie = result.cookie or {}
    return {
      status = 200,
      body = js.assign({}, result.body, { cookie = table.concat(cookie, ";") }),
      cookie = cookie,
    }
  end
  -- Original catch block references an out-of-scope `result`; keep behaviour safe.
  return { status = 200, body = {}, cookie = {} }
end

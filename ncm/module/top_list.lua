-- 排行榜
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  if not js.falsy(query.idx) then
    return {
      status = 500,
      body = {
        code = 500,
        msg = "不支持此方式调用,只支持id调用",
      },
    }
  end

  local data = {
    id = query.id,
    n = "500",
    s = "0",
  }
  return request("/api/playlist/v4/detail", data, createOption(query))
end

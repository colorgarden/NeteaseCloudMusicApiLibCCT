-- 获取客户端歌曲下载链接

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    id = query.id,
    br = math.floor(tonumber(js.or_(query.br, 999000))),
  }
  return request("/api/song/enhance/download/url", data, createOption(query))
end

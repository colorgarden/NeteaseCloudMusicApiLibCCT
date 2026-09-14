-- 搜索歌手
-- 可传关键字或者歌手id
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    keyword = query.keyword,
    limit = js.or_(query.limit, 40),
  }
  return request("/api/rep/ugc/artist/search", data, createOption(query))
end

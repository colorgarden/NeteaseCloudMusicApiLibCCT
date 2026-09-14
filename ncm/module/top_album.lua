-- 新碟上架

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local date = os.date("*t", js.now() / 1000)

  local data = {
    area = js.or_(query.area, "ALL"), -- //ALL:全部,ZH:华语,EA:欧美,KR:韩国,JP:日本
    limit = js.or_(query.limit, 50),
    offset = js.or_(query.offset, 0),
    type = js.or_(query.type, "new"),
    year = js.or_(query.year, date.year),
    month = js.or_(query.month, date.month),
    total = false,
    rcmd = true,
  }
  return request(
    "/api/discovery/new/albums/area",
    data,
    createOption(query, "weapi")
  )
end

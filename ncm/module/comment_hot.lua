local cfg = require("ncm.util.config")
-- 热门评论

local createOption = require("ncm.options")
local js = require("ncm.util.js")

return function(query, request)
  query.type = cfg.resourceTypeMap[js.tostr(query.type)]
  local data = {
    rid = query.id,
    limit = js.or_(query.limit, 20),
    offset = js.or_(query.offset, 0),
    beforeTime = js.or_(query.before, 0),
  }
  return request(
    "/api/v1/resource/hotcomments/"
      .. js.tostr(query.type)
      .. js.tostr(query.id),
    data,
    createOption(query, "weapi")
  )
end

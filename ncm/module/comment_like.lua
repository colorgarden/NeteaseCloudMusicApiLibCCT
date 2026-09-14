local cfg = require("ncm.util.config")
-- 点赞与取消点赞评论

local createOption = require("ncm.options")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  query.t = js.ternary(js.tonum(query.t) == 1, "like", "unlike")
  query.type = cfg.resourceTypeMap[js.tostr(query.type)]
  local data = {}
  if query.type == nil then
    -- JS: undefined + query.id === NaN, and JSON.stringify(NaN) === null
    data.threadId = json.null
  else
    data.threadId = query.type .. js.tostr(query.id)
  end
  data.commentId = query.cid
  if query.type == "A_EV_2_" then
    data.threadId = query.threadId
  end
  return request(
    "/api/v1/comment/" .. js.tostr(query.t),
    data,
    createOption(query, "weapi")
  )
end

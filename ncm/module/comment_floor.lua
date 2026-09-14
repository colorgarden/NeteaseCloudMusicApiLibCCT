local cfg = require("ncm.util.config")
local createOption = require("ncm.options")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  query.type = cfg.resourceTypeMap[js.tostr(query.type)]
  local threadId
  if query.type == nil then
    -- JS: undefined + query.id === NaN, and JSON.stringify(NaN) === null
    threadId = json.null
  else
    threadId = query.type .. js.tostr(query.id)
  end
  local data = {
    parentCommentId = query.parentCommentId,
    threadId = threadId,
    time = js.or_(query.time, -1),
    limit = js.or_(query.limit, 20),
  }
  return request(
    "/api/resource/comment/floor/get",
    data,
    createOption(query, "weapi")
  )
end

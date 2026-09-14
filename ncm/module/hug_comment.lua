local cfg = require("ncm.util.config")
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  query.type = cfg.resourceTypeMap[js.tostr(js.or_(query.type, 0))]
  local threadId
  if type(query.type) == "string" or type(query.sid) == "string" then
    threadId = js.tostr(query.type) .. js.tostr(query.sid)
  elseif type(query.type) == "number" and type(query.sid) == "number" then
    threadId = query.type + query.sid
  else
    -- JS `undefined + undefined` is NaN, which JSON serialises as null.
    threadId = json.null
  end
  local data = {
    targetUserId = query.uid,
    commentId = query.cid,
    threadId = threadId,
  }
  return request(
    "/api/v2/resource/comments/hug/listener",
    data,
    createOption(query)
  )
end

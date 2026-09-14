-- 私人FM - 模式选择

-- aidj, DEFAULT, FAMILIAR, EXPLORE, SCENE_RCMD ( EXERCISE, FOCUS, NIGHT_EMO  )
-- 来不及解释这几个了

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    mode = query.mode,
    subMode = query.submode,
    limit = js.or_(query.limit, 3),
  }
  return request("/api/v1/radio/get", data, createOption(query))
end

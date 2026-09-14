-- 歌曲链接 - v1
-- 此版本不再采用 br 作为音质区分的标准
-- 而是采用 standard, exhigh, lossless, hires, jyeffect(高清环绕声), sky(沉浸环绕声), jymaster(超清母带) 进行音质判断
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    ids = "[" .. js.tostr(query.id) .. "]",
    level = query.level,
    encodeType = "flac",
  }
  if data.level == "sky" then
    data.immerseType = "c51"
  end
  return request("/api/song/enhance/player/url/v1", data, createOption(query))
end

-- 歌词摘录 - 添加/修改摘录歌词

local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    songId = query.id,
    markId = js.or_(query.markId, ""),
    data = js.or_(query.data, "[]"),
    -- "[{\"translateType\":1,\"startTimeStamp\":800,\"translateLyricsText\":\"让我逃走吧、声音已经枯萎\",\"originalLyricsText\":\"逃がしてくれって声を枯らした\"},{\"translateType\":1,\"startTimeStamp\":4040,\"translateLyricsText\":\"我的愿望究竟会实现吗\",\"originalLyricsText\":\"あたしの願いなど叶うでしょうか\"}]"
  }
  return request("/api/song/play/lyrics/mark/add", data, createOption(query))
end

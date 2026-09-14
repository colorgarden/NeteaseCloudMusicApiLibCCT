-- 示例：搜索歌曲并打印结果
-- 用法：把它放到 ncm/ 所在目录(默认 /)，然后 `search 周杰伦`
local ncm = require("ncm")

local keyword = ...
if not keyword or keyword == "" then keyword = "周杰伦" end

local ok, res = pcall(ncm.search, { keywords = keyword, type = 1, limit = 5 })
if not ok then
  print("请求失败: " .. tostring(res.body and res.body.msg or res))
  return
end

local songs = (res.body.result and res.body.result.songs) or {}
print(("找到 %d 首：「%s」"):format(#songs, keyword))
for i, s in ipairs(songs) do
  local artist = (s.artists and s.artists[1] and s.artists[1].name) or "未知"
  print(("%d. %s - %s"):format(i, s.name, artist))
end

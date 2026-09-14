-- 首页-发现 block page
-- 这个接口为移动端接口，首页-发现页，数据结构可以参考 https://github.com/hcanyz/flutter-netease-music-api/blob/master/lib/src/api/uncategorized/bean.dart#L259 HomeBlockPageWrap
-- query.refresh 是否刷新数据
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = { refresh = js.or_(query.refresh, false), cursor = query.cursor }
  -- ncm.util.option 用 Lua `or` 合并 crypto, 空串被当作真值; 先归一空值以走默认参数.
  if js.falsy(query.crypto) then query.crypto = nil end
  return request("/api/homepage/block/page", data, createOption(query, "weapi"))
end

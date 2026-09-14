-- 用户贡献内容
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")

return function(query, request)
  local data = {
    auditStatus = js.or_(query.auditStatus, ""),
    -- 待审核:0 未采纳:-5 审核中:1 部分审核通过:4 审核通过:5
    -- WAIT:0 REJECT:-5 AUDITING:1 PARTLY_APPROVED:4 PASS:5
    limit = js.or_(query.limit, 10),
    offset = js.or_(query.offset, 0),
    order = js.or_(query.order, "desc"), -- asc
    sortBy = js.or_(query.sortBy, "createTime"),
    type = js.or_(query.type, 1),
    -- 曲库纠错 ARTIST:1 ALBUM:2 SONG:3 MV:4 LYRIC:5 TLYRIC:6
    -- 曲库补充 ALBUM:101 MV:103
  }
  return request("/api/rep/ugc/detail", data, createOption(query, "weapi"))
end

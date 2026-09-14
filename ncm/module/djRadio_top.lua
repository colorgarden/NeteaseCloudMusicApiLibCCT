--电台排行榜获取
local createOption = require("ncm.util.option")
local js = require("ncm.util.js")
local json = require("ncm.util.json")

return function(query, request)
  local data = {
    djRadioId = js.or_(query.djRadioId, json.null), -- 电台id
    sortIndex = js.or_(query.sortIndex, 1), -- 排序 1:播放数 2:点赞数 3：评论数 4：分享数 5：收藏数
    dataGapDays = js.or_(query.dataGapDays, 7), -- 天数 7:一周 30:一个月 90:三个月
    dataType = js.or_(query.dataType, 3), -- 未知
  }
  return request(
    "/api/expert/worksdata/works/top/get",
    data,
    createOption(query)
  )
end

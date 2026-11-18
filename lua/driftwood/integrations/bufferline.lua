--- bufferline 整合：把 tabline 上的分頁（buffer）當拖曳來源。
---
--- 位置對應沿用 bufferline 自己 hover 的算法：從左側 offset 起，依序累加可見元件的寬度。
--- 沒有安裝 bufferline 或在 tabpage 模式時不提供來源；單擊切換分頁仍由 bufferline 的 click handler 處理。
local M = {}

local attached = false

---@param actions table driftwood.actions
---@return boolean
function M.attach(actions)
  if attached then
    return true
  end
  if not pcall(require, "bufferline.state") then
    return false
  end
  attached = true
  actions.register(M)
  return true
end

local function buffer_at(screencol)
  local state = require("bufferline.state")
  if require("bufferline.config"):is_tabline() then
    return nil
  end
  local col = screencol - 1 -- 0-based
  local from = state.left_offset_size or 0
  for _, item in ipairs(state.visible_components or {}) do
    if col >= from and col < from + item.length then
      return item.id and vim.api.nvim_buf_is_valid(item.id) and item.id or nil
    end
    from = from + item.length
  end
end

---@param pos table getmousepos()
---@param h table hit.classify()
function M.drag_source(pos, h)
  if h.kind ~= "tabline" then
    return nil
  end
  local ok, buf = pcall(buffer_at, pos.screencol)
  local name = ok and buf and vim.api.nvim_buf_get_name(buf) or ""
  if name == "" or vim.bo[buf].buftype ~= "" then
    return nil
  end
  return {
    inside = function(p)
      return p.screenrow == 1
    end,
    path = function()
      return name
    end,
  }
end

return M

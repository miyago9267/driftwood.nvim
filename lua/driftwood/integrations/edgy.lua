--- edgy.nvim 整合：讓拖曳出來的 dock 大小保留下來，並支援雙擊還原。
---
--- edgy 每次 WinResized 都會把 dock 拉回設定尺寸。拖曳進行中改成把目前大小寫進
--- edgy 認得的 `vim.w[win].edgy_width` / `edgy_height`，之後的重排就沿用。
--- 沒有安裝 edgy 時 `attach()` 回傳 false，什麼都不做。
local M = {}

local attached = false

---@param actions table driftwood.actions
---@return boolean
function M.attach(actions)
  if attached then
    return true
  end
  local ok, Window = pcall(require, "edgy.window")
  if not ok then
    return false
  end
  attached = true
  actions.register(M)

  local apply_size = Window.apply_size
  Window.apply_size = function(self)
    if actions.is_resizing() and self:is_valid() then
      local dim = self.view.edgebar.vertical and "width" or "height"
      local size = vim.api["nvim_win_get_" .. dim](self.win)
      vim.w[self.win]["edgy_" .. dim] = size
      self[dim] = size
    end
    return apply_size(self)
  end
  return true
end

---@param win integer
---@return boolean
function M.is_dock(win)
  local ok, editor = pcall(require, "edgy.editor")
  return ok and vim.api.nvim_win_is_valid(win) and editor.get_win(win) ~= nil
end

--- wins 中有 edgy 管理的 dock 就清掉記住的大小並重排，回傳是否有處理。
---@param wins integer[]
---@return boolean
function M.restore(wins)
  local ok, editor = pcall(require, "edgy.editor")
  if not ok then
    return false
  end
  local found = false
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) and editor.get_win(win) then
      vim.w[win].edgy_width = nil
      vim.w[win].edgy_height = nil
      found = true
    end
  end
  if found then
    require("edgy.layout").update()
  end
  return found
end

return M

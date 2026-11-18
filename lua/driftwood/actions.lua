--- 滑鼠操作的實際動作與狀態。核心不依賴任何第三方插件；
--- 版面管理器等整合模組透過 `register()` 掛進來。
---
--- 整合模組介面（皆為選填）：
---   restore(wins) -> boolean   wins 中有它管理的 dock 就還原並回傳 true
---   is_dock(win) -> boolean    win 是否為它管理的 dock（dock 不參與拖曳交換）
---   drag_source(pos, h) -> { inside, path } | nil
---                              按下的位置是它的檔案來源（tree 節點、分頁）就回傳：
---                              inside(pos) 表示滑鼠還在來源內（仍交還原生行為），
---                              path() 取得要開的檔案路徑（資料夾或沒有檔案回傳 nil）
local M = {}

---@class driftwood.State
---@field pressed boolean 按下時落在分隔線上
---@field dragging boolean 分隔線拖曳進行中
M.state = { pressed = false, dragging = false }

M.integrations = {}

---@param integration table
function M.register(integration)
  if not vim.tbl_contains(M.integrations, integration) then
    table.insert(M.integrations, integration)
  end
end

--- 分隔線拖曳是否進行中（整合模組用來決定要不要記住目前大小）。
---@return boolean
function M.is_resizing()
  return M.state.dragging
end

function M.press(h)
  M.state.pressed = h.kind == "separator"
  M.state.dragging = false
end

function M.drag()
  if M.state.pressed then
    M.state.dragging = true
  end
end

function M.release()
  M.state.pressed = false
  M.state.dragging = false
end

local function equalize(a, b, orient)
  local get = orient == "vertical" and vim.api.nvim_win_get_width or vim.api.nvim_win_get_height
  local set = orient == "vertical" and vim.api.nvim_win_set_width or vim.api.nvim_win_set_height
  local total = get(a) + get(b)
  set(a, math.ceil(total / 2))
end

--- 雙擊分隔線：dock 回到設定大小；沒有 dock 時只平均分配分隔線兩側的視窗。
---@param h { win: integer, other?: integer, orient: string }
function M.reset(h)
  local wins = { h.win }
  if h.other then
    table.insert(wins, h.other)
  end
  for _, integration in ipairs(M.integrations) do
    if integration.restore and integration.restore(wins) then
      return
    end
  end
  if h.other and vim.api.nvim_win_is_valid(h.win) and vim.api.nvim_win_is_valid(h.other) then
    equalize(h.win, h.other, h.orient)
  end
end

--- 按下位置若是某個整合的檔案來源，回傳它的拖曳來源。
---@param pos table getmousepos()
---@param h table hit.classify() 的結果
function M.drag_source(pos, h)
  for _, integration in ipairs(M.integrations) do
    local source = integration.drag_source and integration.drag_source(pos, h)
    if source then
      return source
    end
  end
end

--- 視窗是否為版面管理器管理的 dock。
---@param win integer
---@return boolean
function M.is_dock(win)
  for _, integration in ipairs(M.integrations) do
    if integration.is_dock and integration.is_dock(win) then
      return true
    end
  end
  return false
end

--- 交換兩個視窗的 buffer 與 view（游標、捲動位置），視窗本身的位置與大小不變。
---@param a integer
---@param b integer
function M.swap(a, b)
  if a == b or not (vim.api.nvim_win_is_valid(a) and vim.api.nvim_win_is_valid(b)) then
    return
  end
  local function save(win)
    return { buf = vim.api.nvim_win_get_buf(win), view = vim.api.nvim_win_call(win, vim.fn.winsaveview) }
  end
  local function restore(win, s)
    vim.api.nvim_win_set_buf(win, s.buf)
    vim.api.nvim_win_call(win, function()
      vim.fn.winrestview(s.view)
    end)
  end
  local sa, sb = save(a), save(b)
  restore(a, sb)
  restore(b, sa)
  vim.api.nvim_set_current_win(a)
end

--- 把 src 搬到 target 的某一側，成為新的分割。
---@param src integer
---@param target integer
---@param side "left"|"right"|"top"|"bottom"
function M.move(src, target, side)
  if src == target or not (vim.api.nvim_win_is_valid(src) and vim.api.nvim_win_is_valid(target)) then
    return
  end
  vim.fn.win_splitmove(src, target, {
    vertical = side == "left" or side == "right",
    rightbelow = side == "right" or side == "bottom",
  })
  vim.api.nvim_set_current_win(src)
end

--- 在 target 視窗開檔；side 為 nil 時直接在該視窗開，否則在該側開新分割。
---@param path string
---@param target integer
---@param side? "left"|"right"|"top"|"bottom"
function M.open(path, target, side)
  if not vim.api.nvim_win_is_valid(target) then
    return
  end
  vim.api.nvim_set_current_win(target)
  local cmd = { cmd = side and "split" or "edit", args = { path } }
  if side then
    cmd.mods = {
      vertical = side == "left" or side == "right",
      split = (side == "left" or side == "top") and "aboveleft" or "belowright",
    }
  end
  vim.cmd(cmd)
end

return M

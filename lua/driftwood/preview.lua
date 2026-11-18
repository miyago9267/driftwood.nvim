--- 拖曳中的放置區域高亮：一個不可聚焦的半透明浮動視窗。
local M = {}

local buf, win

vim.api.nvim_set_hl(0, "DriftwoodDrop", { link = "PmenuSel", default = true })

---@return integer? win 目前的高亮視窗
function M.win()
  return win and vim.api.nvim_win_is_valid(win) and win or nil
end

---@param rect { row: integer, col: integer, width: integer, height: integer } 螢幕座標（0-based）
function M.show(rect)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
  end
  local cfg = {
    relative = "editor",
    row = rect.row,
    col = rect.col,
    width = math.max(rect.width, 1),
    height = math.max(rect.height, 1),
    style = "minimal",
    focusable = false,
    zindex = 250,
  }
  if M.win() then
    vim.api.nvim_win_set_config(win, cfg)
  else
    cfg.noautocmd = true
    win = vim.api.nvim_open_win(buf, false, cfg)
    vim.wo[win].winhighlight = "Normal:DriftwoodDrop,NormalFloat:DriftwoodDrop"
    vim.wo[win].winblend = 60
  end
end

function M.hide()
  if M.win() then
    vim.api.nvim_win_close(win, true)
  end
  win = nil
  buf = nil
end

return M

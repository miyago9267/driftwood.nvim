--- 把 getmousepos() 的結果分類成插件關心的區域。
--- 只做判斷，不改任何狀態。
---
--- 分類結果 `{ kind = "separator" | "winbar" | "tabline" | "body", win, orient, other }`：
---   separator：垂直分隔線（wincol > 寬度）或水平分隔線／statusline（winrow > 高度）。
---              `win` 是分隔線左側或上方的視窗，`other` 是另一側的視窗（可能為 nil）。
---   winbar：視窗頂端的 winbar 那一列（視窗有 winbar 時才成立），`win` 是該視窗。
---   tabline：最上面的 tabline 那一列（winrow 為 0）。
---   body：其餘一律交還原生行為。
local M = {}

local function winbar_height(win)
  return vim.wo[win].winbar ~= "" and 1 or 0
end

--- 找出螢幕座標（1-based）所在的非浮動視窗。
---@param row integer
---@param col integer
---@return integer? win
function M.win_at(row, col)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      local pos = vim.fn.win_screenpos(win)
      local height = vim.api.nvim_win_get_height(win) + winbar_height(win)
      local width = vim.api.nvim_win_get_width(win)
      if row >= pos[1] and row < pos[1] + height and col >= pos[2] and col < pos[2] + width then
        return win
      end
    end
  end
end

---@param pos table getmousepos() 的回傳值
---@return { kind: string, win?: integer, orient?: string, other?: integer }
function M.classify(pos)
  local win = pos.winid
  if pos.winrow == 0 and pos.screenrow == 1 then
    return { kind = "tabline" }
  end
  if win == 0 or not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= "" then
    return { kind = "body" }
  end
  if pos.wincol > vim.api.nvim_win_get_width(win) then
    return { kind = "separator", win = win, orient = "vertical", other = M.win_at(pos.screenrow, pos.screencol + 1) }
  end
  if pos.winrow > vim.api.nvim_win_get_height(win) + winbar_height(win) then
    return { kind = "separator", win = win, orient = "horizontal", other = M.win_at(pos.screenrow + 1, pos.screencol) }
  end
  if pos.winrow == 1 and pos.line == 0 and winbar_height(win) == 1 then
    return { kind = "winbar", win = win }
  end
  return { kind = "body" }
end

return M

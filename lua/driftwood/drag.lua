--- 拖曳狀態機：按下 → 拖曳 → 放開（執行）/ Esc（取消）。
--- 來源有兩種：winbar（交換、搬移視窗），或整合模組提供的檔案來源（nvim-tree 節點、bufferline 分頁，開檔）。
---
--- 按下時事件仍交還原生行為；一旦開始拖曳（檔案來源要拖出來源範圍）就吞掉 drag 與 release 事件，
--- 並用 preview 高亮放置區域。zone 為 `swap`（目標中央）或 `left/right/top/bottom`（邊緣 1/4）。
local hit = require("driftwood.hit")
local actions = require("driftwood.actions")
local preview = require("driftwood.preview")

local M = {}

---@class driftwood.Drag
---@field src? integer 來源視窗（winbar 拖曳）
---@field source? { inside: fun(pos: table): boolean, path: fun(): string? } 檔案來源
---@field path? string|false 檔案來源解析出的路徑；false 表示不能拖
---@field active boolean 已開始拖曳
---@field cancelled boolean 已按 Esc 取消，等放開後重置
---@field zone? { kind: string, target: integer, rect: table }
local state

local ns = vim.api.nvim_create_namespace("driftwood_drag")

local function editable(win)
  return vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
end

--- 計算螢幕座標（1-based）對應的放置區域；不能放的位置回傳 nil。
---@param src? integer
---@param row integer
---@param col integer
function M.zone(src, row, col)
  local target = hit.win_at(row, col)
  if not target or target == src or actions.is_dock(target) or not editable(target) then
    return nil
  end
  local pos = vim.fn.win_screenpos(target)
  local w = vim.api.nvim_win_get_width(target)
  local h = vim.api.nvim_win_get_height(target) + (vim.wo[target].winbar ~= "" and 1 or 0)
  local rx, ry = (col - pos[2] + 0.5) / w, (row - pos[1] + 0.5) / h
  -- 到各邊的距離（正規化後），最近且在 1/4 內的邊勝出；都不在就是中央
  local best, kind = 0.25, "swap"
  for k, d in pairs({ left = rx, right = 1 - rx, top = ry, bottom = 1 - ry }) do
    if d < best then
      best, kind = d, k
    end
  end
  local r = { row = pos[1] - 1, col = pos[2] - 1, width = w, height = h }
  if kind == "left" then
    r.width = math.ceil(w / 2)
  elseif kind == "right" then
    r.col, r.width = r.col + math.floor(w / 2), w - math.floor(w / 2)
  elseif kind == "top" then
    r.height = math.ceil(h / 2)
  elseif kind == "bottom" then
    r.row, r.height = r.row + math.floor(h / 2), h - math.floor(h / 2)
  end
  return { kind = kind, target = target, rect = r }
end

local function reset()
  state = nil
  vim.on_key(nil, ns)
  vim.schedule(preview.hide)
end

--- Esc 取消：視窗與 buffer 都不動，放開後才重置。
function M.cancel()
  if state then
    state.cancelled, state.zone = true, nil
    vim.schedule(preview.hide)
  end
end

---@param h table hit.classify() 的結果
---@param pos table getmousepos()
function M.press(h, pos)
  if state then
    reset()
  end
  if h.kind == "winbar" then
    if not actions.is_dock(h.win) then
      state = { src = h.win, active = false, cancelled = false }
    end
    return
  end
  local source = actions.drag_source(pos, h)
  if source then
    state = { source = source, active = false, cancelled = false }
  end
end

-- 檔案來源是在原生拖曳（Visual 選取）中被拖出來的，開始接管時把 Visual 收掉
local leaving = false
local function leave_visual()
  vim.schedule(function()
    if vim.fn.mode():find("[vV\22]") then
      leaving = true -- 這顆 Esc 是我們送的，不是取消
      vim.cmd("normal! \27")
      leaving = false
    end
  end)
end

--- 拖曳事件；回傳 true 表示事件已由本模組處理（要吞掉）。
---@param pos table getmousepos()
---@return boolean
function M.drag(pos)
  if not state then
    return false
  end
  if state.source and state.path == nil then
    -- 第一個拖曳事件時游標還停在按下的節點上，趁此時解析路徑
    state.path = state.source.path() or false
  end
  if state.path == false then
    state = nil
    return false
  end
  if state.source and not state.active and state.source.inside(pos) then
    return false
  end
  if not state.active then
    state.active = true
    if state.source then
      leave_visual()
    end
    vim.on_key(function(key)
      if key == "\27" and not leaving then
        M.cancel()
      end
    end, ns)
  end
  if state.cancelled then
    return true
  end
  state.zone = M.zone(state.src, pos.screenrow, pos.screencol)
  local zone = state.zone
  vim.schedule(function()
    if zone and state and state.zone == zone then
      preview.show(zone.rect)
    else
      preview.hide()
    end
  end)
  return true
end

--- 放開事件；回傳 true 表示事件已由本模組處理（要吞掉）。
---@param pos table getmousepos()
---@return boolean
function M.release(pos)
  if not (state and state.active) then
    state = nil
    return false
  end
  local zone = not state.cancelled and M.zone(state.src, pos.screenrow, pos.screencol) or nil
  local src, path = state.src, state.path
  local file = state.source ~= nil
  reset()
  if file then
    leave_visual()
  end
  if zone then
    -- expr 映射內不能改視窗，排到下一輪再執行
    vim.schedule(function()
      if file then
        actions.open(path, zone.target, zone.kind ~= "swap" and zone.kind or nil)
      elseif zone.kind == "swap" then
        actions.swap(src, zone.target)
      else
        actions.move(src, zone.target, zone.kind)
      end
    end)
  end
  return true
end

return M

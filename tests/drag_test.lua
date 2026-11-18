local T = dofile("tests/helper.lua")
require("driftwood").setup({})
local actions = require("driftwood.actions")
local preview = require("driftwood.preview")

local L, R, bufL, bufR -- 左右兩個視窗與各自的 buffer

local function scenario()
  vim.cmd("only | enew")
  vim.cmd("silent! %bwipeout!")
  vim.cmd("enew | vsplit | enew")
  local wins = vim.api.nvim_tabpage_list_wins(0)
  table.sort(wins, function(a, b) return vim.fn.win_screenpos(a)[2] < vim.fn.win_screenpos(b)[2] end)
  L, R = wins[1], wins[2]
  bufL, bufR = vim.api.nvim_win_get_buf(L), vim.api.nvim_win_get_buf(R)
  vim.api.nvim_buf_set_lines(bufL, 0, -1, false, { "left 1", "left 2", "left 3" })
  vim.api.nvim_buf_set_lines(bufR, 0, -1, false, { "right 1", "right 2", "right 3" })
  vim.api.nvim_win_set_cursor(R, { 3, 2 })
  for _, w in ipairs(wins) do vim.wo[w].winbar = "%t" end
  vim.api.nvim_set_current_win(L)
end

local function float_count()
  local n = 0
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative ~= "" then n = n + 1 end
  end
  return n
end

local function pos(win) return vim.fn.win_screenpos(win) end

-- 一個拖曳案例：從 from 視窗的 winbar 拖到 (row, col)，中途檢查高亮，放開後檢查 check()
local function case(name, from, row, col, check, opts)
  opts = opts or {}
  local src_col = from == "L" and 5 or 60
  return {
    scenario,
    function() T.mouse("press", 0, src_col) end,
    function() T.mouse("drag", 0, src_col + 3) end,
    function() T.mouse("drag", row, col) end,
    function()
      if opts.preview == false then
        T.eq(float_count(), 0, name .. ": no preview")
      else
        T.ok(preview.win() ~= nil and float_count() == 1, name .. ": preview shown")
      end
      if opts.esc then vim.api.nvim_input("<Esc>") end
    end,
    function()
      if opts.esc then T.eq(float_count(), 0, name .. ": preview hidden after Esc") end
      T.mouse("release", row, col)
    end,
    function()
      T.eq(float_count(), 0, name .. ": preview removed")
      T.eq(preview.win(), nil, name .. ": preview handle cleared")
      check()
    end,
  }
end

local steps = {}
local function add(list) for _, s in ipairs(list) do table.insert(steps, s) end end

-- 拖到右視窗中央 -> 交換 buffer 與游標
add(case("swap", "L", 10, 60, function()
  T.eq(vim.api.nvim_win_get_buf(L), bufR, "L has R's buffer")
  T.eq(vim.api.nvim_win_get_buf(R), bufL, "R has L's buffer")
  T.eq(vim.api.nvim_win_get_cursor(L), { 3, 2 }, "view travels with buffer")
  T.ok(pos(L)[2] < pos(R)[2], "windows keep their positions")
end))

-- 邊緣 -> 搬移成分割
add(case("left", "R", 10, 3, function()
  T.eq(vim.api.nvim_win_get_buf(R), bufR, "src keeps buffer")
  T.ok(pos(R)[2] < pos(L)[2] and pos(R)[1] == pos(L)[1], "src moved to left of target")
end))
add(case("right", "L", 10, 77, function()
  T.ok(pos(L)[2] > pos(R)[2] and pos(L)[1] == pos(R)[1], "src moved to right of target")
end))
add(case("top", "R", 3, 20, function()
  T.ok(pos(R)[1] < pos(L)[1] and pos(R)[2] == pos(L)[2], "src moved above target")
end))
add(case("bottom", "L", 21, 60, function()
  T.ok(pos(L)[1] > pos(R)[1] and pos(L)[2] == pos(R)[2], "src moved below target")
end))

-- 拖回自己 -> 沒有高亮、什麼都不動
add(case("self", "L", 10, 10, function()
  T.eq(vim.api.nvim_win_get_buf(L), bufL, "L unchanged")
  T.eq(vim.api.nvim_win_get_buf(R), bufR, "R unchanged")
  T.ok(pos(L)[2] < pos(R)[2], "layout unchanged")
end, { preview = false }))

-- Esc 取消 -> 放開後也不動
add(case("esc", "L", 10, 60, function()
  T.eq(vim.api.nvim_win_get_buf(L), bufL, "L unchanged after esc")
  T.eq(vim.api.nvim_win_get_buf(R), bufR, "R unchanged after esc")
end, { esc = true }))

-- 目標是 terminal 等非編輯視窗 -> 不動
add({
  function()
    scenario()
    vim.api.nvim_set_current_win(R)
    vim.cmd("terminal")
    vim.cmd("stopinsert")
    bufR = vim.api.nvim_win_get_buf(R)
  end,
})
local c = case("nonedit", "L", 10, 60, function()
  T.eq(vim.api.nvim_win_get_buf(L), bufL, "L unchanged vs terminal")
  T.eq(vim.api.nvim_win_get_buf(R), bufR, "terminal unchanged")
end, { preview = false })
table.remove(c, 1)
add(c)

-- dock（整合模組宣告）不當來源也不當目標
add({ scenario, function() actions.register({ is_dock = function(w) return w == R end }) end })
local c1 = case("dock-target", "L", 10, 60, function()
  T.eq(vim.api.nvim_win_get_buf(L), bufL, "dock target: L unchanged")
  T.eq(vim.api.nvim_win_get_buf(R), bufR, "dock target: R unchanged")
end, { preview = false })
table.remove(c1, 1)
add(c1)
local c2 = case("dock-source", "R", 10, 10, function()
  T.eq(vim.api.nvim_win_get_buf(L), bufL, "dock source: L unchanged")
  T.eq(vim.api.nvim_win_get_buf(R), bufR, "dock source: R unchanged")
end, { preview = false })
table.remove(c2, 1)
add(c2)

-- winbar = true：只補空的 winbar，不覆蓋別人的，也不動浮動視窗與非檔案 buffer
add({
  function()
    vim.cmd("only | enew | vsplit | enew")
    local wins = vim.api.nvim_tabpage_list_wins(0)
    vim.wo[wins[1]].winbar = "custom"
    local float = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false,
      { relative = "editor", row = 2, col = 2, width = 10, height = 3 })
    vim.cmd("vsplit | terminal")
    vim.cmd("stopinsert")
    require("driftwood").setup({ winbar = true })
    local term_win = vim.api.nvim_get_current_win()
    wins.float, wins.term = float, term_win
    L = wins
  end,
  function()
    local wins = L
    T.eq(vim.wo[wins[1]].winbar, "custom", "foreign winbar kept")
    T.ok(vim.wo[wins[2]].winbar:find("%%t"), "plain window gets filename winbar")
    T.eq(vim.wo[wins.float].winbar, "", "float untouched")
    T.eq(vim.wo[wins.term].winbar, "", "terminal untouched")
  end,
})

T.run("driftwood-drag", steps)

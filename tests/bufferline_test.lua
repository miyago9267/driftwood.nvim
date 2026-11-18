local T = dofile("tests/helper.lua")
vim.opt.rtp:prepend(T.root .. "/.deps/bufferline.nvim")
vim.o.termguicolors = true
vim.o.showtabline = 2
require("bufferline").setup({ options = { always_show_bufferline = true } })
require("driftwood").setup({})
local state = require("bufferline.state")

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local files = {}
for _, n in ipairs({ "one.txt", "two.txt", "three.txt" }) do
  vim.fn.writefile({ n }, dir .. "/" .. n)
  files[n] = dir .. "/" .. n
end

local function scenario()
  vim.cmd("silent! tabonly | only | silent! %bwipeout!")
  vim.cmd("edit " .. files["one.txt"] .. " | badd " .. files["two.txt"] .. " | badd " .. files["three.txt"])
  vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true }) -- 讓 bufferline 算出各分頁位置
end

-- 分頁的螢幕 col（0-based），取該分頁寬度的中間
local function tab_col(name)
  local from = state.left_offset_size or 0
  for _, item in ipairs(state.visible_components) do
    if vim.api.nvim_buf_get_name(item.id):find(name, 1, true) then
      return from + math.floor(item.length / 2)
    end
    from = from + item.length
  end
  error("no tab " .. name)
end

local function nwins()
  return #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == "" end, vim.api.nvim_list_wins())
end
local function floats()
  return #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative ~= "" end, vim.api.nvim_list_wins())
end
local function name(win) return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)), ":t") end

local win
T.run("driftwood-bufferline", {
  function() scenario(); win = vim.api.nvim_get_current_win() end,
  -- 拖到邊緣 -> 在右側開新分割
  function() T.mouse("press", 0, tab_col("two.txt")) end,
  function() T.mouse("drag", 0, tab_col("two.txt") + 2) end, -- 仍在 tabline 內
  function() T.eq(floats(), 0, "no preview inside tabline"); T.mouse("drag", 10, 77) end,
  function() T.eq(floats(), 1, "preview shown") end,
  function() T.mouse("release", 10, 77) end,
  function()
    T.eq(floats(), 0, "preview removed")
    T.eq(nwins(), 2, "new split")
    local cur = vim.api.nvim_get_current_win()
    T.eq(name(cur), "two.txt", "opened in new split")
    T.ok(vim.fn.win_screenpos(cur)[2] > vim.fn.win_screenpos(win)[2], "split is on the right")
  end,
  -- 拖到中央 -> 在該視窗開
  function() scenario(); win = vim.api.nvim_get_current_win(); T.mouse("press", 0, tab_col("three.txt")) end,
  function() T.mouse("drag", 10, 40) end,
  function() T.mouse("release", 10, 40) end,
  function()
    T.eq(nwins(), 1, "no split")
    T.eq(name(win), "three.txt", "opened in target window")
  end,
  -- 單擊分頁仍會切換
  function() scenario(); T.click(0, tab_col("two.txt")) end,
  function() T.eq(name(0), "two.txt", "click switches buffer"); T.eq(nwins(), 1, "no split") end,
  -- 在 tabline 內水平拖曳：不開檔、不吞事件
  function() scenario(); T.mouse("press", 0, tab_col("two.txt")) end,
  function() T.mouse("drag", 0, tab_col("three.txt")) end,
  function() T.mouse("release", 0, tab_col("three.txt")) end,
  function() T.eq(nwins(), 1, "drag inside tabline opens nothing") end,
})

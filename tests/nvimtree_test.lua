local T = dofile("tests/helper.lua")
vim.opt.rtp:prepend(T.root .. "/.deps/nvim-tree.lua")
require("nvim-tree").setup({ view = { width = 30 }, actions = { open_file = { window_picker = { enable = false } } } })
require("driftwood").setup({})
local api = require("nvim-tree.api")

local dir = vim.fn.tempname()
vim.fn.mkdir(dir .. "/sub", "p")
vim.fn.writefile({ "a" }, dir .. "/a.txt")
vim.fn.writefile({ "b" }, dir .. "/b.txt")

local tree, editor

local function scenario()
  api.tree.close()
  vim.cmd("only | enew")
  editor = vim.api.nvim_get_current_win()
  api.tree.open({ path = dir })
  tree = api.tree.winid()
  vim.api.nvim_set_current_win(editor)
end

-- 節點所在的螢幕列（0-based）；tree 的行號從 buffer 內容找
local function row_of(name)
  for i, l in ipairs(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(tree), 0, -1, false)) do
    if l:find(name, 1, true) then
      return vim.fn.win_screenpos(tree)[1] - 1 + i - 1
    end
  end
  error("no node " .. name)
end

local function nwins()
  return #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative == "" end, vim.api.nvim_list_wins())
end
local function name(win) return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)), ":t") end
local function floats()
  return #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative ~= "" end, vim.api.nvim_list_wins())
end
local function menu_enabled(item)
  return not vim.fn.execute("nmenu PopUp." .. item):find("n%*%s+%-")
end

local function drag_case(file, row, col, check, mid)
  return {
    scenario,
    function() T.mouse("press", row_of(file), 4) end,
    function() T.mouse("drag", row_of(file), 8) end, -- 仍在 tree 內
    function() T.mouse("drag", row, col) end,
    function() mid() end,
    function() T.mouse("release", row, col) end,
    function() T.eq(floats(), 0, "preview removed"); check() end,
  }
end

local steps = {}
local function add(list) for _, s in ipairs(list) do table.insert(steps, s) end end

-- 拖到編輯視窗中央 -> 在該視窗開
add(drag_case("a.txt", 10, 60, function()
  T.eq(nwins(), 2, "no new split")
  T.eq(name(editor), "a.txt", "opened in target")
  T.ok(vim.fn.mode() == "n", "back in normal mode")
end, function() T.eq(floats(), 1, "preview shown") end))

-- 拖到右邊緣 -> 開新分割
add(drag_case("b.txt", 10, 77, function()
  T.eq(nwins(), 3, "new split")
  local cur = vim.api.nvim_get_current_win()
  T.eq(name(cur), "b.txt", "opened in new split")
  T.ok(vim.fn.win_screenpos(cur)[2] > vim.fn.win_screenpos(editor)[2], "split is on the right")
end, function() T.eq(floats(), 1, "preview shown") end))

-- 資料夾不能拖：什麼都不開、沒有高亮
add(drag_case("sub", 10, 60, function()
  T.eq(nwins(), 2, "no split")
  T.eq(name(editor), "", "editor untouched")
end, function() T.eq(floats(), 0, "no preview for folder") end))

-- Esc 取消
add({
  scenario,
  function() T.mouse("press", row_of("a.txt"), 4) end,
  function() T.mouse("drag", 10, 60) end,
  function() vim.api.nvim_input("<Esc>") end,
  function() T.mouse("release", 10, 60) end,
  function() T.eq(name(editor), "", "esc cancels"); T.eq(floats(), 0, "no preview") end,
})

-- 只在 tree 內拖曳：不開檔
add({
  scenario,
  function() T.mouse("press", row_of("a.txt"), 4) end,
  function() T.mouse("drag", row_of("b.txt"), 6) end,
  function() T.mouse("release", row_of("b.txt"), 6) end,
  function() T.eq(name(editor), "", "in-tree drag opens nothing"); T.eq(nwins(), 2, "no split") end,
})

-- 單擊：游標移到節點，不開檔
add({
  scenario,
  function() T.click(row_of("b.txt"), 6) end,
  function()
    T.eq(vim.api.nvim_get_current_win(), tree, "tree focused")
    T.eq(vim.api.nvim_get_current_line():find("b.txt", 1, true) ~= nil, true, "cursor on clicked node")
    T.eq(name(editor), "", "single click opens nothing")
    T.eq(floats(), 0, "no preview")
  end,
})

-- 雙擊：nvim-tree 原本的開檔
add({
  scenario,
  function() T.click(row_of("a.txt"), 6); T.click(row_of("a.txt"), 6) end,
  function() T.eq(name(editor), "a.txt", "double click opens file via nvim-tree") end,
})

-- 右鍵選單：檔案上有四項，資料夾沒有；dotfile 那種別人加的項目不受影響
local function trigger(file)
  vim.api.nvim_set_current_win(tree)
  for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if l:find(file, 1, true) then vim.api.nvim_win_set_cursor(0, { i, 0 }) end
  end
  vim.api.nvim_exec_autocmds("MenuPopup", {})
end
local items = { "Open", "Open\\ to\\ the\\ Right", "Open\\ Below", "Open\\ in\\ New\\ Tab" }
add({
  scenario,
  function()
    -- 模擬 dotfile：自己的項目與自己的 MenuPopup autocmd
    vim.cmd([[nnoremenu PopUp.Mine <Cmd>echo 1<CR>]])
    vim.api.nvim_create_autocmd("MenuPopup", {
      callback = function() vim.cmd(("nmenu %s PopUp.Mine"):format(vim.bo.filetype == "NvimTree" and "enable" or "disable")) end,
    })
    trigger("a.txt")
    for _, i in ipairs(items) do T.ok(menu_enabled(i), i .. " enabled on file") end
    T.ok(menu_enabled("Mine"), "other menu item coexists")
    trigger("sub")
    for _, i in ipairs(items) do T.ok(not menu_enabled(i), i .. " disabled on folder") end
    T.ok(menu_enabled("Mine"), "other menu item still enabled")
    vim.api.nvim_set_current_win(editor)
    vim.api.nvim_exec_autocmds("MenuPopup", {})
    for _, i in ipairs(items) do T.ok(not menu_enabled(i), i .. " disabled outside tree") end
    -- 項目真的會開檔
    trigger("a.txt")
    require("driftwood.integrations.nvim-tree").open("vertical_no_picker")
  end,
  function()
    T.eq(nwins(), 3, "Open to the Right splits")
    T.eq(name(vim.api.nvim_get_current_win()), "a.txt", "opened file")
    trigger("b.txt")
    require("driftwood.integrations.nvim-tree").open("tab")
  end,
  function() T.eq(#vim.api.nvim_list_tabpages(), 2, "Open in New Tab"); T.eq(name(0), "b.txt", "opened in tab") end,
})

T.run("driftwood-nvim-tree", steps)

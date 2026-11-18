local T = dofile("tests/helper.lua")

local function open_text()
  vim.cmd("only | enew")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world foo bar", "second line here", "third" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

local wins
T.run("driftwood", {
  -- R8：沒有 edgy / nvim-tree / bufferline 時 setup 不報錯，核心不載入第三方插件
  function()
    local ok, err = pcall(require("driftwood").setup, {})
    T.ok(ok, "setup failed: " .. tostring(err))
    T.ok(package.loaded["edgy"] == nil, "edgy should not be loaded")
    for _, f in ipairs({ "init", "hit", "actions" }) do
      for _, line in ipairs(vim.fn.readfile(T.root .. "/lua/driftwood/" .. f .. ".lua")) do
        local mod = line:match('require%("([^"]+)"%)')
        T.ok(not mod or mod:match("^driftwood") or line:match("pcall"), f .. " requires " .. tostring(mod))
      end
    end
    open_text()
  end,

  -- R7：一般文字單擊移動游標
  function() T.click(1, 6) end,
  function()
    T.eq(vim.api.nvim_win_get_cursor(0), { 2, 6 }, "click moves cursor")
    T.eq(vim.fn.mode(), "n", "still normal mode")
  end,

  -- R7：拖曳產生 visual 選取
  function() T.mouse("press", 0, 1) end,
  function() T.mouse("drag", 0, 5) end,
  function() T.mouse("drag", 0, 9) end,
  function()
    T.eq(vim.fn.mode(), "v", "drag starts visual")
    T.mouse("release", 0, 9)
  end,
  function()
    T.eq(vim.fn.mode(), "v", "visual survives release")
    T.eq(vim.fn.getpos("v")[3], 2, "visual anchor")
    T.eq(vim.fn.getpos(".")[3], 10, "visual end")
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  end,

  -- R7：插入模式點擊行為不變
  function()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("startinsert")
  end,
  function() T.click(2, 3) end,
  function()
    T.eq(vim.fn.mode(), "i", "stay in insert mode")
    T.eq(vim.api.nvim_win_get_cursor(0), { 3, 3 }, "insert click moves cursor")
    vim.cmd("stopinsert")
  end,

  -- R2：雙擊垂直分隔線只平均分配兩側視窗
  function()
    vim.cmd("only | enew | vsplit | vsplit")
    wins = vim.api.nvim_tabpage_list_wins(0)
    -- 三欄由左到右；把第一欄調窄、第三欄維持原樣
    table.sort(wins, function(a, b) return vim.fn.win_screenpos(a)[2] < vim.fn.win_screenpos(b)[2] end)
    vim.api.nvim_win_set_width(wins[1], 10)
  end,
  function()
    local w3 = vim.api.nvim_win_get_width(wins[3])
    wins.w3 = w3
    T.ok(vim.api.nvim_win_get_width(wins[1]) == 10, "pre: narrow")
    -- 第一欄與第二欄之間的分隔線：col = 10（0-based）
    T.click(3, 10)
    T.click(3, 10)
  end,
  function()
    local a, b = vim.api.nvim_win_get_width(wins[1]), vim.api.nvim_win_get_width(wins[2])
    T.ok(math.abs(a - b) <= 1, "equalized " .. a .. "/" .. b)
    T.eq(vim.api.nvim_win_get_width(wins[3]), wins.w3, "third column untouched")
  end,

  -- R2：水平分隔線
  function()
    vim.cmd("only | enew | split")
    wins = vim.api.nvim_tabpage_list_wins(0)
    table.sort(wins, function(a, b) return vim.fn.win_screenpos(a)[1] < vim.fn.win_screenpos(b)[1] end)
    vim.api.nvim_win_set_height(wins[1], 4)
  end,
  function()
    T.eq(vim.api.nvim_win_get_height(wins[1]), 4, "pre: short")
    -- 上方視窗高 4，分隔線在螢幕第 5 列（0-based 4）
    T.click(4, 5)
    T.click(4, 5)
  end,
  function()
    local a, b = vim.api.nvim_win_get_height(wins[1]), vim.api.nvim_win_get_height(wins[2])
    T.ok(math.abs(a - b) <= 1, "equalized h " .. a .. "/" .. b)
  end,
})

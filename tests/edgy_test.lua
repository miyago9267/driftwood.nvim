local T = dofile("tests/helper.lua")
vim.opt.rtp:prepend(T.root .. "/.deps/edgy.nvim")
vim.o.splitkeep = "screen"

require("edgy").setup({ animate = { enabled = false }, left = { { ft = "dwtree" } } })
require("driftwood").setup({})

local dock, dock_buf, main_buf
local function dock_width() return vim.api.nvim_win_get_width(dock) end

T.run("driftwood-edgy", {
  function()
    vim.cmd("vsplit | enew")
    dock = vim.api.nvim_get_current_win()
    vim.bo.filetype = "dwtree"
  end,
  function() end,
  function() end,
  function()
    dock = vim.fn.win_getid(vim.fn.bufwinnr(vim.api.nvim_get_current_buf()))
    T.eq(dock_width(), 30, "dock starts at configured width")
    -- R1：拖曳分隔線（0-based col 30）到 col 45
    T.mouse("press", 5, 30)
  end,
  function() T.mouse("drag", 5, 38) end,
  function() T.mouse("drag", 5, 45) end,
  function() T.mouse("release", 5, 45) end,
  function()
    T.eq(dock_width(), 45, "dragged width kept")
    require("edgy.layout").update()
  end,
  function()
    T.eq(dock_width(), 45, "dragged width survives relayout")
    T.eq(vim.w[dock].edgy_width, 45, "recorded in vim.w")
    -- R2：雙擊還原
    T.click(5, 45)
    T.click(5, 45)
  end,
  function()
    T.eq(dock_width(), 30, "double click restores dock width")
    T.ok(vim.w[dock].edgy_width == nil, "vim.w cleared")
  end,
  -- 雙擊 dock 與編輯視窗之間的分隔線後，編輯視窗拿到剩餘空間，不去動 dock
  function()
    local main = vim.tbl_filter(function(w) return w ~= dock end, vim.api.nvim_tabpage_list_wins(0))[1]
    T.eq(vim.api.nvim_win_get_width(main) + 30 + 1, vim.o.columns, "editor takes the rest")
  end,
  -- R3：edgy dock 不當來源也不當目標
  function()
    local main = vim.tbl_filter(function(w) return w ~= dock end, vim.api.nvim_tabpage_list_wins(0))[1]
    dock_buf, main_buf = vim.api.nvim_win_get_buf(dock), vim.api.nvim_win_get_buf(main)
    vim.wo[dock].winbar, vim.wo[main].winbar = "%t", "%t"
    T.ok(require("driftwood.actions").is_dock(dock), "dock detected")
    T.ok(not require("driftwood.actions").is_dock(main), "main is not dock")
    -- 編輯視窗拖到 dock 中央
    T.mouse("press", 0, 60)
  end,
  function() T.mouse("drag", 0, 63) end,
  function() T.mouse("drag", 10, 10) end,
  function() T.mouse("release", 10, 10) end,
  function()
    local main = vim.tbl_filter(function(w) return w ~= dock end, vim.api.nvim_tabpage_list_wins(0))[1]
    T.eq(vim.api.nvim_win_get_buf(dock), dock_buf, "dock buffer unchanged")
    T.eq(vim.api.nvim_win_get_buf(main), main_buf, "main buffer unchanged as target")
    -- 從 dock 的 winbar 拖到編輯視窗中央
    T.mouse("press", 0, 5)
  end,
  function() T.mouse("drag", 0, 8) end,
  function() T.mouse("drag", 10, 60) end,
  function() T.mouse("release", 10, 60) end,
  function()
    local main = vim.tbl_filter(function(w) return w ~= dock end, vim.api.nvim_tabpage_list_wins(0))[1]
    T.eq(vim.api.nvim_win_get_buf(dock), dock_buf, "dock buffer unchanged as source")
    T.eq(vim.api.nvim_win_get_buf(main), main_buf, "main unchanged")
    T.eq(#vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative ~= "" end, vim.api.nvim_list_wins()), 0, "no preview")
  end,
})

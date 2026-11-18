-- R8：沒有 nvim-tree、bufferline（也沒有 edgy）時，其餘功能照常、不報錯
local T = dofile("tests/helper.lua")
vim.o.showtabline = 2
require("driftwood").setup({})
local actions = require("driftwood.actions")

T.run("driftwood-optional", {
  function()
    T.eq(#actions.integrations, 0, "no integration attached")
    T.ok(not pcall(vim.cmd, "nmenu PopUp.Open"), "no tree menu")
    vim.cmd("vsplit | enew")
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do vim.wo[w].winbar = "%t" end
    -- tabline 上按下、拖出、放開
    T.mouse("press", 0, 5)
  end,
  function() T.mouse("drag", 0, 9) end,
  function() T.mouse("drag", 10, 60) end,
  function() T.mouse("release", 10, 60) end,
  function()
    T.eq(vim.v.errmsg, "", "no error")
    T.eq(#vim.api.nvim_tabpage_list_wins(0), 2, "layout unchanged")
    -- winbar 交換照常
    T.mouse("press", 1, 5)
  end,
  function() T.mouse("drag", 1, 8) end,
  function() T.mouse("drag", 10, 60) end,
  function() T.mouse("release", 10, 60) end,
  function() T.eq(vim.v.errmsg, "", "no error after winbar drag") end,
})

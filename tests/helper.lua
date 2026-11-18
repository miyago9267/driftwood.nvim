-- 測試共用工具。用 `nvim --headless -u NONE -c "luafile tests/xxx_test.lua"` 執行：
-- nvim_input_mouse 送出的事件要回到 main loop 才會處理，所以每一步用 defer_fn 分段推進。
local T = {}

T.root = vim.fn.getcwd()
vim.opt.rtp:prepend(T.root)
vim.o.mouse = "a"
vim.o.laststatus = 3
vim.o.swapfile = false

-- 保險：腳本在頂層出錯或卡住時，不讓 headless nvim 永遠掛著
vim.defer_fn(function()
  io.stderr:write("FAIL timeout or top-level error\n")
  vim.cmd("cquit 1")
end, 15000)

function T.eq(actual, expected, msg)
  if not vim.deep_equal(actual, expected) then
    error(string.format("%s: expected %s, got %s", msg or "assert", vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

function T.ok(cond, msg)
  if not cond then
    error(msg or "assertion failed", 2)
  end
end

-- 滑鼠事件，座標用 0-based 螢幕位置
function T.mouse(action, row, col, button)
  vim.api.nvim_input_mouse(button or "left", action, "", 0, row, col)
end

function T.click(row, col)
  T.mouse("press", row, col)
  T.mouse("release", row, col)
end

-- 依序執行 steps，每步之間留給 main loop 處理輸入；任何錯誤都以 exit 1 結束
function T.run(name, steps)
  local i = 0
  local function step()
    i = i + 1
    local fn = steps[i]
    if not fn then
      print("ok  " .. name)
      vim.cmd("qa!")
      return
    end
    local ok, err = pcall(fn)
    if not ok then
      io.stderr:write("FAIL " .. name .. " (step " .. i .. "): " .. tostring(err) .. "\n")
      vim.cmd("cquit 1")
      return
    end
    vim.defer_fn(step, 40)
  end
  vim.defer_fn(step, 40)
end

return T

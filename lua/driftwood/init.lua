--- driftwood.nvim：VSCode 式的滑鼠視窗操作。
---
--- 用 expr 映射攔截滑鼠鍵：屬於插件的區域（分隔線）自己處理，
--- 其餘一律回傳原本的按鍵，讓 Neovim 照原生行為處理（點擊、選取、捲動都不變）。
local hit = require("driftwood.hit")
local actions = require("driftwood.actions")
local drag = require("driftwood.drag")

local M = {}

M.config = {
  integrations = { edgy = true, ["nvim-tree"] = true, bufferline = true },
  -- 幫一般編輯視窗設只顯示檔名的 winbar（拖曳的手把）；不覆蓋已有的 winbar
  winbar = false,
}

local keys = { "<LeftMouse>", "<LeftDrag>", "<LeftRelease>", "<2-LeftMouse>" }

local function handle(key)
  local pos = vim.fn.getmousepos()
  local h = hit.classify(pos)
  if key == "<LeftMouse>" then
    actions.press(h)
    drag.press(h, pos)
  elseif key == "<LeftDrag>" then
    if drag.drag(pos) then
      return ""
    end
    actions.drag()
  elseif key == "<LeftRelease>" then
    actions.release()
    if drag.release(pos) then
      return ""
    end
  elseif key == "<2-LeftMouse>" and h.kind == "separator" then
    -- expr 映射內不能改視窗，排到下一輪再還原
    vim.schedule(function()
      actions.reset(h)
    end)
    return ""
  end
  return key
end

local function attach_integrations()
  for _, name in ipairs({ "edgy", "nvim-tree", "bufferline" }) do
    if M.config.integrations[name] then
      local ok, integration = pcall(require, "driftwood.integrations." .. name)
      if ok then
        integration.attach(actions)
      end
    end
  end
end

local WINBAR = " %t%m"

local function owned(win)
  return vim.w[win].driftwood_winbar == true
end

-- 只動「空的」或自己設過的 winbar，且不碰浮動視窗、非檔案 buffer 與 dock
local function sync_winbar(win)
  if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= "" then
    return
  end
  local plain = vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" and not actions.is_dock(win)
  if plain and vim.wo[win].winbar == "" then
    vim.wo[win].winbar = WINBAR
    vim.w[win].driftwood_winbar = true
  elseif not plain and owned(win) then
    vim.wo[win].winbar = ""
    vim.w[win].driftwood_winbar = nil
  end
end

local function setup_winbar()
  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew", "WinEnter" }, {
    group = vim.api.nvim_create_augroup("driftwood_winbar", { clear = true }),
    callback = function()
      sync_winbar(vim.api.nvim_get_current_win())
    end,
  })
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    sync_winbar(win)
  end
end

---@param opts? { integrations?: { edgy?: boolean, ["nvim-tree"]?: boolean, bufferline?: boolean }, winbar?: boolean }
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  for _, key in ipairs(keys) do
    vim.keymap.set({ "n", "i", "v", "t" }, key, function()
      return handle(key)
    end, { expr = true, noremap = true, silent = true, desc = "driftwood: mouse" })
  end

  attach_integrations()
  if M.config.winbar then
    setup_winbar()
  end
  -- 版面管理器可能比本插件晚載入，載入後再試一次
  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("driftwood", { clear = true }),
    pattern = "LazyLoad",
    callback = attach_integrations,
  })
end

return M

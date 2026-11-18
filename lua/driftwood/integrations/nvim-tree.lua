--- nvim-tree 整合：把檔案節點當拖曳來源，並在檔案上的右鍵選單加入開啟選項。
---
--- 只在 nvim-tree 已安裝時生效；沒有時 `attach()` 回傳 false，什麼都不做。
--- 選單項目掛在 PopUp 並由 MenuPopup 依游標下的節點開關，不碰其他人加進 PopUp 的項目。
local M = {}

local attached = false

local menu = {
  { "Open", "edit" },
  { "Open\\ to\\ the\\ Right", "vertical_no_picker" },
  { "Open\\ Below", "horizontal_no_picker" },
  { "Open\\ in\\ New\\ Tab", "tab" },
}

local function is_tree(buf)
  return vim.bo[buf].filetype == "NvimTree"
end

-- 游標下的檔案節點；資料夾、根節點與沒有節點都回傳 nil
local function file_node(api)
  local ok, node = pcall(api.tree.get_node_under_cursor)
  if not ok or not node or not node.absolute_path then
    return nil
  end
  if node.type == "file" or (node.type == "link" and vim.fn.isdirectory(node.absolute_path) == 0) then
    return node
  end
end

--- 選單項目呼叫：對游標下的檔案節點執行 nvim-tree 的開啟動作。
---@param action string api.node.open 的函式名稱
function M.open(action)
  local api = require("nvim-tree.api")
  local node = file_node(api)
  if node then
    api.node.open[action](node)
  end
end

---@param actions table driftwood.actions
---@return boolean
function M.attach(actions)
  if attached then
    return true
  end
  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then
    return false
  end
  attached = true
  actions.register(M)

  for _, item in ipairs(menu) do
    vim.cmd(("nnoremenu PopUp.%s <Cmd>lua require('driftwood.integrations.nvim-tree').open('%s')<CR>"):format(item[1], item[2]))
  end
  vim.api.nvim_create_autocmd("MenuPopup", {
    group = vim.api.nvim_create_augroup("driftwood_nvim_tree_menu", { clear = true }),
    callback = function()
      local state = is_tree(vim.api.nvim_get_current_buf()) and file_node(api) and "enable" or "disable"
      for _, item in ipairs(menu) do
        vim.cmd(("nmenu %s PopUp.%s"):format(state, item[1]))
      end
    end,
  })
  return true
end

---@param pos table getmousepos()
function M.drag_source(pos)
  local win = pos.winid
  if win == 0 or pos.line == 0 or not is_tree(vim.api.nvim_win_get_buf(win)) then
    return nil
  end
  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then
    return nil
  end
  return {
    inside = function(p)
      return p.winid == win
    end,
    path = function()
      local node = file_node(api)
      return node and node.absolute_path
    end,
  }
end

return M

---
id: spec-mouse-windows
title: driftwood.nvim：VSCode 式的滑鼠視窗操作
status: approved
created: 2026-11-18
updated: 2026-11-18
author: Miyago
tags: [neovim, plugin, mouse]
priority: medium
---

# driftwood.nvim：VSCode 式的滑鼠視窗操作

## Background

Neovim 開了 `mouse=a` 之後可以點、可以拖分隔線，但 VSCode 使用者習慣的視窗操作大多做不到：

- 用 edgy 這類版面管理器時，拖出來的大小會在下一次重排被拉回設定值。
- 沒辦法雙擊分隔線還原大小、拖視窗標題換位置、把檔案從 tree 拖到右邊開成分割。
- file tree 的右鍵選單沒有「在右邊開啟」這類選項。

Miyago 的日常環境是 Ghostty，本機直接開或經 tmux（`mouse on`）開都有，SSH 遠端也會用。
目標是公開發布：不依賴特定版面管理器，有 edgy、nvim-tree、bufferline 時自動整合。

2026-11-18 在 nvim 0.12 headless 用 `nvim_input_mouse` 實測：分隔線上的單擊與雙擊、
winbar 上的按下與拖曳、拖曳跨視窗、放開位置，都能用 `getmousepos()` 分辨
（分隔線：`wincol` 大於視窗寬度且 `line=0`；winbar：`winrow=1` 且 `line=0`）。

## Requirements (EARS)

- **R1**：When 使用者拖曳兩個視窗之間的分隔線，the plugin shall 讓新大小保留下來，
  包含 edgy 管理的 dock（不被下一次重排拉回）。
- **R2**：When 使用者雙擊分隔線，the plugin shall 還原大小：dock 回到設定大小，
  一般分割則平均分配相鄰視窗。
- **R3**：When 使用者按住某個視窗的 winbar 拖到另一個視窗中央後放開，the plugin shall
  交換兩個視窗的內容；放在目標視窗的上下左右邊緣區時，shall 把來源視窗搬到該側成為分割。
- **R4**：When 使用者從 nvim-tree 的檔案或 bufferline 的分頁拖到某個編輯視窗後放開，
  the plugin shall 在目標視窗開啟該檔案；放在邊緣區時，shall 在該側開新分割來開啟。
- **R5**：While 拖曳進行中，the plugin shall 用浮動視窗高亮目前的放置區域
  （整個視窗或上下左右其中一半），放開或取消時移除。
- **R6**：When 使用者在 nvim-tree 的檔案上按右鍵，the plugin shall 在右鍵選單加入
  「開啟」「在右側開啟」「在下方開啟」「在新分頁開啟」。
- **R7**：If 滑鼠事件不屬於上述任何操作，then the plugin shall 交還原生行為
  （點擊、選取文字、捲動、terminal 裡的滑鼠都和沒裝插件時一樣）。
- **R8**：If 沒有安裝 edgy、nvim-tree 或 bufferline，then the plugin shall 照常提供
  其餘功能，不報錯。
- **R9**：Where 使用者在 tmux（`mouse on`）裡或直接在 terminal 裡執行 nvim，
  the plugin shall 提供相同的行為。

## Non-goals

- 不做 bufferline 分頁之間的拖曳排序（bufferline 自己有排序指令）。
- 不改 terminal mode 裡的滑鼠行為；agent 視窗內部的滑鼠交給它自己的程式。
- 不做浮動視窗的拖曳搬移。
- 不支援 Neovim 0.10 以前的版本。

## Alternatives Considered

### 方案 A：只修 edgy（發 PR 給上游）

能解決 R1，但 R2 到 R6 都不在 edgy 的範圍內。拖曳記住大小仍可以另外發 PR 給 edgy，
插件裡的 edgy 整合在上游修好後就能拿掉。

### 方案 B：用 `vim.on_key` 監聽所有滑鼠事件，不建立映射

完全不搶原生行為，但 on_key 無法吞掉事件，拖曳 winbar 時 nvim 仍會做原生的處理
（例如拖動 statusline 改高度）。不選。

## Rabbit Holes

1. 不要自己重算 edgy 的版面；只在拖曳時寫入它認得的 `vim.w.edgy_width` / `edgy_height`。
2. 映射 `<LeftMouse>` 這類鍵之後，非目標區域一定要用 `nvim_feedkeys(key, "n")` 交還原生行為，
   否則選取文字、點擊定位都會壞掉（R7）。
3. 視覺模式、插入模式、terminal mode 的映射要分開處理；terminal mode 只處理 winbar，
   其他一律交還。
4. tmux 的 `DoubleClick1Pane` 預設綁定只在程式沒要求滑鼠時生效；要實測 nvim 在 tmux 裡
   是否收得到雙擊（R9）。

## Architecture

```
lua/driftwood/
  init.lua            setup()、設定預設值、註冊各模式的滑鼠映射
  hit.lua             把 getmousepos() 分類成 separator / winbar / tabline / tree_node / body
  drag.lua            拖曳狀態機：按下 → 拖曳 → 放開 / 取消，決定放置區域
  preview.lua         放置區域的浮動高亮
  actions.lua         resize 記錄、還原、交換、搬移、開檔
  integrations/
    edgy.lua          寫入 edgy 的 per-window 尺寸、還原 dock 大小
    nvim-tree.lua     取得拖曳中的檔案路徑、右鍵選單項目
    bufferline.lua    從 tabline 位置取得 buffer
tests/                headless + nvim_input_mouse 模擬滑鼠，plain asserts（同 archipelago）
doc/driftwood.txt
```

滑鼠事件流程：映射觸發 → `hit.lua` 分類 → 屬於插件的區域就交給 `drag.lua` / `actions.lua`，
否則用 `nvim_feedkeys` 交還原生行為。

## ADR

### ADR-1：用滑鼠鍵映射攔截事件，而不是 `vim.on_key`

- 決策：映射 `<LeftMouse>`、`<LeftDrag>`、`<LeftRelease>`、`<2-LeftMouse>`，非目標區域再交還。
- 原因：on_key 只能觀察不能攔截，做不到拖曳 winbar 時阻止原生行為。

### ADR-2：整合模組只在對應插件存在時載入

- 決策：`integrations/*` 用 `pcall(require, ...)` 偵測，核心模組不 require 任何第三方插件。
- 原因：公開發布要滿足 R8；Miyago 的 dotfile 目前在 `layout.lua` 寫的 edgy patch 會搬進
  `integrations/edgy.lua`，dotfile 那段刪掉。

### ADR-3：拖曳的手把用 winbar

- 決策：視窗沒有 winbar 時不提供拖曳；`setup({ winbar = true })` 可讓插件幫編輯視窗加上
  只顯示檔名的 winbar。
- 原因：`laststatus=3` 時沒有每個視窗各自的 statusline，winbar 是唯一穩定的標題列。

## Phase 計畫

### Phase 1：骨架與分隔線（R1、R2、R7、R8）

- repo 骨架、hit-test、交還原生行為、edgy 整合，dotfile 改用本插件。

### Phase 2：拖 winbar 交換與搬移（R3、R5）

- 拖曳狀態機、放置區域判斷、浮動高亮。

### Phase 3：從 tree 與分頁拖檔、右鍵選單（R4、R6）

- nvim-tree 與 bufferline 整合。

### Phase 4：發布（R9）

- tmux 與 Ghostty 實機驗證、README、vimdoc、GitHub Actions、第一個 tag。

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| 攔截滑鼠鍵後原生行為交還不完整 | 選字、點擊定位壞掉，最傷日常使用 | Phase 1 先寫交還的測試，每個模式都測 |
| tmux 或某些 terminal 不送雙擊、拖曳事件 | R2、R3 在某些環境失效 | Phase 4 實機測 Ghostty 直開與 tmux，README 寫支援表 |
| edgy 內部 API 改版 | dock 大小又被拉回 | 整合只碰 `vim.w.edgy_*`；同時發 PR 給 edgy |
| 名稱已被其他插件使用 | 發布時要改名 | 發布前查 GitHub 與 awesome-neovim |

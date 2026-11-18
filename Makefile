test: test-unit test-drag test-edgy test-nvim-tree test-bufferline test-optional

test-unit:
	nvim --headless -u NONE -c "luafile tests/driftwood_test.lua"

test-drag:
	nvim --headless -u NONE -c "luafile tests/drag_test.lua"

.deps/edgy.nvim:
	git clone --depth 1 https://github.com/folke/edgy.nvim .deps/edgy.nvim

test-edgy: .deps/edgy.nvim
	nvim --headless -u NONE -c "luafile tests/edgy_test.lua"

.deps/nvim-tree.lua:
	git clone --depth 1 https://github.com/nvim-tree/nvim-tree.lua .deps/nvim-tree.lua

test-nvim-tree: .deps/nvim-tree.lua
	nvim --headless -u NONE -c "luafile tests/nvimtree_test.lua"

.deps/bufferline.nvim:
	git clone --depth 1 https://github.com/akinsho/bufferline.nvim .deps/bufferline.nvim

test-bufferline: .deps/bufferline.nvim
	nvim --headless -u NONE -c "luafile tests/bufferline_test.lua"

test-optional:
	nvim --headless -u NONE -c "luafile tests/optional_test.lua"

.PHONY: test test-unit test-drag test-edgy test-nvim-tree test-bufferline test-optional

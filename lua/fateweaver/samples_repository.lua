---@type fateweaver.Logger
local logger = require("fateweaver.logger")

---@class fateweaver.SamplesRepository
---@field save_sample fun(completions: Completion[], file_content: string, changes: Changes): nil
local M = {}

function M.save_sample(completions, file_content, changes)
  local sample = "Test sample\nTODO:\nReplace"
  local buffer = vim.api.nvim_create_buf(false, true)

  local lines = vim.split(sample, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)

  vim.api.nvim_set_option_value('modifiable', true, { buf = buffer })
  vim.api.nvim_set_option_value('buftype', 'acwrite', { buf = buffer })
  vim.api.nvim_set_option_value('filetype', "text", { buf = buffer })

  local default_width = math.floor(vim.o.columns * 0.9)
  local default_height = math.floor(vim.o.lines * 0.9)

  local window_config = {
    relative = "editor",
    width = default_width,
    height = default_height,
    style = "minimal",
    row = math.floor((vim.o.lines - default_height) / 2),
    col = math.floor((vim.o.columns - default_width) / 2),
  }

  local win = vim.api.nvim_open_win(buffer, true, window_config)
  vim.api.nvim_set_option_value('wrap', false, { win = win })
  vim.api.nvim_set_option_value('cursorline', true, { win = win })

  vim.keymap.set("n", "<leader>x", function()
    vim.api.nvim_buf_delete(buffer, { force = true })
  end)
  vim.keymap.set("n", "<leader>s", function()
    local saved_lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    local saved_content = table.concat(saved_lines, "\n")

    logger.debug("Saving sameple with content:\n" .. saved_content)

    vim.api.nvim_buf_delete(buffer, { force = true })
  end)
end

return M

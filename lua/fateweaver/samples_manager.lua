---@type fateweaver.Logger
local logger = require("fateweaver.logger")

---@type fateweaver.Config
local config = require("fateweaver.config")

---@class fateweaver.SamplesManager
---@field save_sample fun(completions: Completion[], file_content: string, changes: Changes): nil
local M = {}

local code_excerpt_template = [[```%s
%s
```]]

local completion_template = [[<<<<<<< SEARCH
%s
=======
%s
>>>>>>> REPLACE]]

local delimiter = "\n----------------------------------------\n"

function M.save_sample(completions, file_content, changes)
  local samples_dir = config.get().samples_file_path
  if not samples_dir or samples_dir == "" then
    logger.info("Samples directory is not configured - skipping sample save.")
    return
  end
  local code_excerpt = string.format(code_excerpt_template, changes.filename, file_content)
  local completion_blocks = {}
  for _, completion in ipairs(completions) do
    local block = string.format(completion_template, completion.search, completion.replace)
    table.insert(completion_blocks, block)
  end
  local completion_content = table.concat(completion_blocks, "\n")

  local content_blocks = {
    code_excerpt,
    changes.diff,
    completion_content,
  }
  local content = table.concat(content_blocks, delimiter)
  content = content .. delimiter .. "<Put expected result here>"

  local buffer = vim.api.nvim_create_buf(false, true)

  local lines = vim.split(content, "\n", { plain = true })
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

  vim.api.nvim_set_current_win(win)

  local line_count = vim.api.nvim_buf_line_count(buffer)

  local last_line = vim.api.nvim_buf_get_lines(buffer, line_count - 1, line_count, false)[1] or ""

  vim.api.nvim_win_set_cursor(win, { line_count, #last_line })

  vim.keymap.set("n", "<leader>x", function()
    vim.api.nvim_buf_delete(buffer, { force = true })
  end)
  vim.keymap.set("n", "<leader>s", function()
    local saved_lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    local saved_content = table.concat(saved_lines, "\n")
    local sections = vim.split(saved_content, delimiter, { plain = true })

    if #sections ~= 4 then
      logger.warn("Exectly 4 sections are expected in the sample content.")
      return
    end

    logger.debug("Saving sameple with content:\n" .. saved_content)

    local dto = {
      excrept = sections[1],
      diff = sections[2],
      rejected = sections[3],
      changes = sections[4],
    }

    local file = io.open(samples_dir, "a")

    if not file then
      logger.error("Failed to open samples file for writing: " .. samples_dir)
      return
    end

    file:write(vim.json.encode(dto) .. "\n")
    file:close()

    vim.api.nvim_buf_delete(buffer, { force = true })
  end)
end

return M

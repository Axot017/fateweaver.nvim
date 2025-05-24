local changes = require("fateweaver.changes")
local client = require("fateweaver.client")
local logger = require("fateweaver.logger")
local prompt_manager = require("fateweaver.prompt_manager")

local function get_editable_region()
  local win_top = vim.fn.line('w0')
  local win_bottom = vim.fn.line('w$')
  local editable_region = { start_line = win_top, end_line = win_bottom }
  return editable_region
end

local function get_editable_region_lines(bufnr, editable_region)
  local lines = vim.api.nvim_buf_get_lines(bufnr, editable_region.start_line, editable_region.end_line, false)

  return lines
end

local function get_completion_lines(completions_str)
  local completions = vim.split(completions_str, "\n")

  -- remove first and last line - editable region tokens
  table.remove(completions, 1)
  table.remove(completions, #completions)

  return completions
end

local request_bufnr = -1

local M = {}

function M.propose_completions(bufnr)
  request_bufnr = bufnr
  local diffs = changes.get_buffer_diffs(bufnr)
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local editable_region = get_editable_region()

  local prompt = prompt_manager.get_prompt(bufnr, editable_region, cursor_pos, diffs)

  local editable_region_lines = get_editable_region_lines(bufnr, editable_region)
  local editable_region_lines_str = table.concat(editable_region_lines, "\n")
  logger.debug("Editable region lines:\n\n" .. editable_region_lines_str)

  client.request_completion(prompt, function(completions)
    if request_bufnr ~= bufnr then
      return
    end

    local proposed_completions = get_completion_lines(completions)
    local proposed_completions_str = table.concat(proposed_completions, "\n")
    logger.debug("Proposed completions:\n\n" .. proposed_completions_str)

    local diff = vim.diff(editable_region_lines_str, proposed_completions_str, {
      result_type = "indices"
    })

    if diff == nil or #diff == 0 then
      return
    end

    logger.debug("Diff:\n\n" .. vim.inspect(diff))
  end)
end

function M.clear()
end

return M

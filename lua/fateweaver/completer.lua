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
  local lines = vim.api.nvim_buf_get_lines(bufnr, editable_region.start_line - 1, editable_region.end_line, false)

  return lines
end

local function get_completion_lines(completion_str)
  local start_marker = "<|editable_region_start|>"
  local end_marker = "<|editable_region_end|>"

  local start_pos = string.find(completion_str, start_marker, 1, true)
  local end_pos = string.find(completion_str, end_marker, 1, true)

  if not start_pos or not end_pos then
    return {}
  end

  local content_start = start_pos + string.len(start_marker)

  completion_str = string.sub(completion_str, content_start, end_pos - 1)

  if completion_str:sub(1, 1) == "\n" then
    completion_str = completion_str:sub(2)
  end

  if completion_str:sub(-1) == "\n" then
    completion_str = completion_str:sub(1, -2)
  end

  local completions = vim.split(completion_str, "\n")

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
    if #proposed_completions == 0 then
      return
    end

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

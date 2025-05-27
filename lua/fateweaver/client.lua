local config = require("fateweaver.config")
local logger = require("fateweaver.logger")
local curl_ok, curl = pcall(require, "plenary.curl")

if not curl_ok then
  vim.notify("Failed to load plenary.curl", vim.log.levels.ERROR)
  return
end

local start_file_token = "<|start_of_file|>"
local end_file_token = "<|end_of_file|>"
local start_editable_region_token = "<|editable_region_start|>"
local end_editable_region_token = "<|editable_region_end|>"
local user_cursor_token = "<|user_cursor_is_here|>"

local function get_completion_lines(completion_str)
  local start_pos = string.find(completion_str, start_editable_region_token, 1, true)
  local end_pos = string.find(completion_str, end_editable_region_token, 1, true)

  if not start_pos or not end_pos then
    return {}
  end

  local content_start = start_pos + string.len(start_editable_region_token)

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


local prompt_template =
"### Instruction:\nYou are a code completion assistant and your task is to analyze user edits and then rewrite an excerpt that the user provides, suggesting the appropriate edits within the excerpt, taking into account the cursor location.\n\n### User Edits:\n\n%s### User Excerpt:\n\n```%s\n%s\n```\n\n### Response:\n\n"

local edit_template = "User edited \"%s\":\n```diff\n%s\n```"

local function get_buffer_with_tokens(bufnr, editable_region, cursor_pos)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local cursor_line = cursor_pos[1]
  local cursor_col = cursor_pos[2]

  local cursor_line_text = lines[cursor_line]
  if cursor_line_text then
    lines[cursor_line] = string.sub(cursor_line_text, 1, cursor_col) ..
        user_cursor_token ..
        string.sub(cursor_line_text, cursor_col + 1)
  end

  local context_offet = config.get().context_offset

  local start_line = math.max(1, cursor_line - context_offet)
  local end_line = math.min(#lines, cursor_line + context_offet)
  local included_lines = {}

  for i = start_line, end_line do
    table.insert(included_lines, lines[i])
  end

  local result = {}

  if start_line == 1 then
    table.insert(result, start_file_token)
  end

  if start_line > editable_region.start_line then
    table.insert(result, start_editable_region_token)
  end

  for i, line in ipairs(included_lines) do
    local actual_line_num = start_line + i - 1

    if actual_line_num == editable_region.start_line then
      table.insert(result, start_editable_region_token)
    end

    table.insert(result, line)

    if actual_line_num == editable_region.end_line then
      table.insert(result, end_editable_region_token)
    end
  end

  if end_line < editable_region.end_line then
    table.insert(result, end_editable_region_token)
  end

  if end_line == #lines then
    table.insert(result, end_file_token)
  end

  return table.concat(result, "\n")
end

local function get_prompt(bufnr, editable_region, cursor_pos, changes)
  local formatted_changes = ""
  for index, _ in ipairs(changes) do
    local change = changes[#changes - index + 1]
    formatted_changes = formatted_changes .. string.format(edit_template, change.filename, change.diff) .. "\n\n"
  end

  local buffer_text = get_buffer_with_tokens(bufnr, editable_region, cursor_pos)

  local prompt = string.format(prompt_template, formatted_changes, vim.api.nvim_buf_get_name(bufnr), buffer_text)

  logger.debug("Prompt:\n\n" .. prompt)

  return prompt
end

local request_job = nil

local M = {}

function M.request_completion(bufnr, editable_region, cursor_pos, changes, callback)
  local url = config.get().endpoint
  local model = config.get().model
  local body = {
    model = model,
    prompt = get_prompt(bufnr, editable_region, cursor_pos, changes),
    stream = false,
    options = {
      num_predict = 100
    },
  }

  logger.debug("Requesting completion")

  if request_job ~= nil then
    request_job:shutdown()
  end

  request_job = curl.post(url, {
    body = vim.json.encode(body),
    headers = {
      content_type = "application/json",
    },
    callback = function(res)
      if res.status ~= 200 then
        logger.warn("Received error: " .. vim.inspect(res))
      end

      local reponse_body = vim.json.decode(res.body)
      local response = reponse_body["response"]
      local proposed_completions = get_completion_lines(response)

      request_job = nil
      vim.schedule(function()
        callback(proposed_completions)
      end)
    end,
    on_error = function(err)
      if err.exit ~= 0 then
        logger.warn("Received error: " .. vim.inspect(err))
      end
      logger.debug("Request previous cancelled")
      request_job = nil
    end
  })
end

return M

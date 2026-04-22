---@type fateweaver.Logger
local logger = require("fateweaver.logger")
---@type fateweaver.Config
local config = require("fateweaver.config")

local curl_ok, curl = pcall(require, "plenary.curl")
if not curl_ok then
  vim.notify("Failed to load plenary.curl", vim.log.levels.ERROR)
  return
end

---@type table|nil Current request job
local request_job = nil
---@type integer Unique ID for tracking request jobs
local job_id = 0

local SYSTEM_PROMPT = "You are a code completion assistant. Your task is to analyze code excerpt and recent edits, then suggest edits to that code using search/replace blocks"

local USER_PROMPT_TEMPLATE = [[### Recent Edits:

%s

### Code Excerpt:

%s]]

local CODE_EXCERPT_TEMPLATE = [[```%s
%s
```]]

---@param bufnr integer
---@return string excerpt
local function get_excerpt(bufnr)
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor_pos[1]

  local context_opts = config.get().context_opts
  local context_before_cursor = context_opts.context_before_cursor
  local context_after_cursor = context_opts.context_after_cursor

  local first_line = math.max(0, cursor_line - context_before_cursor)
  local last_line = math.min(vim.api.nvim_buf_line_count(bufnr) - 1, cursor_line + context_after_cursor)

  local lines = vim.api.nvim_buf_get_lines(bufnr, first_line, last_line + 1, false)
  local buffer_name = vim.api.nvim_buf_get_name(bufnr)

  return string.format(CODE_EXCERPT_TEMPLATE, buffer_name, table.concat(lines, "\n"))
end

---@param bufnr integer
---@param changes Changes
---@return table[] messages
local function get_messages(bufnr, changes)
  local diff = changes.diff
  local excerpt = get_excerpt(bufnr)
  local user_prompt = string.format(USER_PROMPT_TEMPLATE, diff, excerpt)
  local messages = {
    {
      role = "system",
      content = SYSTEM_PROMPT,
    },
    {
      role = "user",
      content = user_prompt,
    },
  }

  logger.debug("Messages:\n\n" .. vim.inspect(messages))

  return messages
end

---@param content any
---@return string
local function content_to_string(content)
  if type(content) == "string" then
    return content
  end

  if type(content) ~= "table" then
    return ""
  end

  local parts = {}
  for _, part in ipairs(content) do
    if type(part) == "string" then
      table.insert(parts, part)
    elseif type(part) == "table" and type(part.text) == "string" then
      table.insert(parts, part.text)
    end
  end

  return table.concat(parts, "")
end

---@param endpoint string
---@param model string
---@param messages table[]
---@return table body
local function build_request_body(endpoint, model, messages)
  local is_ollama_chat_endpoint = endpoint:match("/api/chat/?$") ~= nil
  local is_chat_endpoint = is_ollama_chat_endpoint or endpoint:match("/chat/completions/?$") ~= nil

  if is_ollama_chat_endpoint then
    return {
      model = model,
      messages = messages,
      stream = false,
      options = {
        temperature = 0,
      },
    }
  end

  if is_chat_endpoint then
    return {
      model = model,
      messages = messages,
      stream = false,
      temperature = 0,
    }
  end

  local prompt = string.format("%s\n\n%s", messages[1].content, messages[2].content)

  return {
    model = model,
    prompt = prompt,
    stream = false,
    temperature = 0,
  }
end

---@param response_body table
---@return string
local function extract_response_text(response_body)
  if type(response_body) ~= "table" then
    return ""
  end

  if response_body.message and response_body.message.content then
    return content_to_string(response_body.message.content)
  end

  if response_body.choices and response_body.choices[1] then
    local choice = response_body.choices[1]

    if choice.message and choice.message.content then
      return content_to_string(choice.message.content)
    end

    if type(choice.text) == "string" then
      return choice.text
    end
  end

  if type(response_body.response) == "string" then
    return response_body.response
  end

  return ""
end

---@param response string
---@return Completion[]
local function response_to_completions(response)
  local blocks = {}
  local pattern = "<<<<<<< SEARCH\n(.-)\n=======\n(.-)\n>>>>>>> REPLACE"

  for search_block, replace_block in string.gmatch(response, pattern) do
    if search_block ~= replace_block then
      table.insert(blocks, {
        search = search_block,
        replace = replace_block,
      })
      logger.debug("Found block:\n<<<<<<< SEARCH\n"
        .. search_block .. "\n=======\n" .. replace_block .. "\n>>>>>>> REPLACE")
    else
      logger.info("Ignoring block with identical search and replace: " .. search_block)
    end
  end

  return blocks
end

---@class fateweaver.Client
---@field request_completion fun(bufnr: integer, changes: Changes, callback: fun(completions: Completion[])): nil
---@field cancel_request fun(): nil
local M = {}

---@param bufnr integer
---@param changes Changes
---@param callback fun(completions: string[])
---@return nil
function M.request_completion(bufnr, changes, callback)
  local url = config.get().completion_endpoint
  local model = config.get().model_name
  local messages = get_messages(bufnr, changes)
  local body = build_request_body(url, model, messages)

  logger.debug("Requesting completion - Endpoint: " .. url .. " Model: " .. model)
  logger.debug("Request body:\n" .. vim.inspect(body))

  if request_job ~= nil then
    request_job:shutdown()
    request_job = nil
  end

  job_id = job_id + 1
  local current_job_id = job_id
  local headers = {}
  headers["Content-Type"] = "application/json"

  local api_key = config.get().api_key
  if api_key then
    if type(api_key) == "string" then
      headers["Authorization"] = api_key
    elseif type(api_key) == "function" then
      headers["Authorization"] = api_key()
    end
  end

  request_job = curl.post(url, {
    body = vim.json.encode(body),
    headers = headers,
    callback = function(res)
      if res.status ~= 200 then
        logger.warn("Received error: " .. vim.inspect(res))
      end

      local ok, response_body = pcall(vim.json.decode, res.body)
      if not ok then
        logger.warn("Failed to decode response body: " .. tostring(res.body))

        if current_job_id == job_id then
          request_job = nil
        end

        vim.schedule(function()
          callback({})
        end)
        return
      end

      local response = extract_response_text(response_body)
      logger.debug("Response:\n" .. response)
      local proposed_completions = response_to_completions(response)

      if current_job_id == job_id then
        request_job = nil
      end
      vim.schedule(function()
        callback(proposed_completions)
      end)
    end,
    on_error = function(err)
      if err.exit ~= 0 then
        logger.warn("Received error: " .. vim.inspect(err))
      end
      logger.debug("Request previous cancelled")
    end,
  })
end

--- Cancels any in-flight completion request
---@return nil
function M.cancel_request()
  if request_job ~= nil then
    logger.debug("Cancelling in-flight request")
    request_job:shutdown()
    request_job = nil
  end
end

return M

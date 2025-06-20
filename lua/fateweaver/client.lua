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

local prompt_template = [[### Instruction:
You are a code completion assistant. Your task is to analyze code excerpt and recent edits, then suggest edits to that code using search/replace blocks

### Code Excerpt:

```%s
%s
```

### Recent Edits:

%s

### Suggestions:

]]

---@param changes Change[]
local function formatted_diff(changes)
  local diffs = {}
  for _, change in ipairs(changes) do
    table.insert(diffs, change.diff)
  end
  return table.concat(diffs, "\n")
end

--- Constructs the full prompt for the LLM
---@param bufnr integer The buffer number
---@param changes Change[] Array of recorded changes to provide as context
---@return string prompt The complete prompt for the LLM
local function get_prompt(bufnr, changes)
  local diff = formatted_diff(changes)

  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor_pos[1]

  local context_opts = config.get().context_opts
  local context_before_cursor = context_opts.context_before_cursor
  local context_after_cursor = context_opts.context_after_cursor

  local first_line = math.max(0, cursor_line - context_before_cursor)
  local last_line = math.min(vim.api.nvim_buf_line_count(bufnr) - 1, cursor_line + context_after_cursor)

  local lines = vim.api.nvim_buf_get_lines(bufnr, first_line, last_line + 1, false)

  local buffer_name = vim.api.nvim_buf_get_name(bufnr)
  local prompt = string.format(prompt_template, buffer_name, table.concat(lines, "\n"), diff)

  logger.debug("Prompt:\n\n" .. prompt)

  return prompt
end

---@param response string
---@return Completion[]
local function response_to_completions(response)
  local blocks = {}
  local pattern = "<<<<<<< SEARCH\n(.-)\n=======\n(.-)\n>>>>>>> REPLACE"

  for search_block, replace_block in string.gmatch(response, pattern) do
    -- Ignore blocks where search and replace are the same
    if search_block ~= replace_block then
      table.insert(blocks, {
        search = search_block,
        replace = replace_block
      })
      logger.debug("Found block:\n<<<<<<< SEARCH\n" ..
        search_block .. "\n=======\n" .. replace_block .. "\n>>>>>>> REPLACE")
    else
      logger.info("Ignoring block with identical search and replace: " .. search_block)
    end
  end

  return blocks
end

local M = {}

---Makes a request to the completion API
---@param bufnr integer The buffer number to get completion for
---@param changes Change[] Array of recorded changes to provide as context
---@param callback fun(completions: string[]) Function to call with completion results
---@return nil
function M.request_completion(bufnr, changes, callback)
  local url = config.get().completion_endpoint
  local model = config.get().model_name
  local body = {
    model = model,
    prompt = get_prompt(bufnr, changes),
    stream = false,
    temperature = 0,
  }

  logger.debug("Requesting completion")

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
    if type(api_key) == 'string' then
      headers["Authorization"] = api_key
    elseif type(api_key) == 'function' then
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
      local reponse_body = vim.json.decode(res.body)
      local response = reponse_body.choices[1].text
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
    end
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

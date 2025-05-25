local config = require("fateweaver.config")

local M = {}

M.levels = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}


local function format_message(level, msg)
  return string.format("[%s] %s", level, msg)
end

function M.log(level_name, msg)
  local level = M.levels[level_name]
  local configured_level = M.levels[config.get().log_level]
  if level >= configured_level then
    local formatted = format_message(level_name, msg)
    config.get().logger_fn(formatted)
  end
end

function M.debug(msg)
  M.log("DEBUG", msg)
end

function M.info(msg)
  M.log("INFO", msg)
end

function M.warn(msg)
  M.log("WARN", msg)
end

function M.error(msg)
  M.log("ERROR", msg)
end

function M.file_logger(filename)
  return function(msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = string.format("[%s] %s\n", timestamp, msg)

    local file = io.open(filename, "a")

    if file then
      file:write(log_entry)
      file:close()
    else
      vim.notify("Failed to write to log file: " .. filename, vim.log.levels.ERROR)
    end
  end
end

return M

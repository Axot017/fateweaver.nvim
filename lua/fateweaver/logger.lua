local config = require("fateweaver.config")

---@class fateweaver.Logger
---@field levels table<string, integer> Log level constants
---@field log fun(level_name: string, msg: string): nil
---@field debug fun(msg: string): nil
---@field info fun(msg: string): nil
---@field warn fun(msg: string): nil
---@field error fun(msg: string): nil
---@field file_logger fun(filename: string): fun(msg: string): nil
local M = {}

---@enum fateweaver.LogLevel
M.levels = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}


---Formats a log message with its level
---@param level string The log level name
---@param msg string The message to log
---@return string formatted The formatted log message
local function format_message(level, msg)
  return string.format("[%s] %s", level, msg)
end

---Logs a message at the specified level
---@param level_name string The name of the log level
---@param msg string The message to log
---@return nil
function M.log(level_name, msg)
  local level = M.levels[level_name]
  local configured_level = M.levels[config.get().log_level]
  if level >= configured_level then
    local formatted = format_message(level_name, msg)
    config.get().logger_fn(formatted)
  end
end

---Logs a message at DEBUG level
---@param msg string The message to log
---@return nil
function M.debug(msg)
  M.log("DEBUG", msg)
end

---Logs a message at INFO level
---@param msg string The message to log
---@return nil
function M.info(msg)
  M.log("INFO", msg)
end

---Logs a message at WARN level
---@param msg string The message to log
---@return nil
function M.warn(msg)
  M.log("WARN", msg)
end

---Logs a message at ERROR level
---@param msg string The message to log
---@return nil
function M.error(msg)
  M.log("ERROR", msg)
end

---Creates a file logger function
---@param filename string The path to the log file
---@return fun(msg: string): nil logger A function that logs messages to the specified file
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

local M = {}

local FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

--- Create a new floating-window spinner.
---@param message string  text shown after the spinning frame
function M.new(message)
  local s = {
    _message = message,
    _frame   = 1,
    _timer   = vim.uv.new_timer(),
    _buf     = nil,
    _win     = nil,
  }
  return setmetatable(s, { __index = M })
end

function M:start()
  local text  = FRAMES[1] .. " " .. self._message
  local width = vim.fn.strdisplaywidth(text) + 2  -- side padding

  self._buf = vim.api.nvim_create_buf(false, true)

  self._win = vim.api.nvim_open_win(self._buf, false, {
    relative = "editor",
    width    = width,
    height   = 1,
    row      = math.floor((vim.o.lines   - 1) / 2),
    col      = math.floor((vim.o.columns - width) / 2),
    style    = "minimal",
    border   = "rounded",
    zindex   = 200,
  })

  self._timer:start(0, 80, vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_valid(self._buf) then return end
    local line = " " .. FRAMES[self._frame] .. " " .. self._message .. " "
    vim.api.nvim_buf_set_lines(self._buf, 0, -1, false, { line })
    self._frame = (self._frame % #FRAMES) + 1
  end))
end

function M:stop()
  self._timer:stop()
  if not self._timer:is_closing() then
    self._timer:close()
  end
  if self._win and vim.api.nvim_win_is_valid(self._win) then
    vim.api.nvim_win_close(self._win, true)
  end
  if self._buf and vim.api.nvim_buf_is_valid(self._buf) then
    vim.api.nvim_buf_delete(self._buf, { force = true })
  end
end

return M

local M = {}

--- Open a centered floating input prompt.
---@param prompt   string            title shown above the input field
---@param callback fun(string|nil)   called with the trimmed input, or nil on cancel
function M.open(prompt, callback)
  local width = 60

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    width     = width,
    height    = 1,
    row       = math.floor((vim.o.lines   - 1) / 2),
    col       = math.floor((vim.o.columns - width) / 2),
    style     = "minimal",
    border    = "rounded",
    title     = " " .. prompt .. " ",
    title_pos = "center",
  })

  vim.cmd("startinsert")

  local function confirm()
    local text = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    vim.api.nvim_win_close(win, true)
    vim.schedule(function()
      vim.cmd("stopinsert")
      callback(text ~= "" and text or nil)
    end)
  end

  local function cancel()
    vim.api.nvim_win_close(win, true)
    vim.schedule(function()
      vim.cmd("stopinsert")
      callback(nil)
    end)
  end

  vim.keymap.set("i", "<CR>",  confirm, { buffer = buf, nowait = true })
  vim.keymap.set("i", "<Esc>", cancel,  { buffer = buf, nowait = true })
  vim.keymap.set("i", "<C-c>", cancel,  { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", cancel,  { buffer = buf, nowait = true })
end

return M

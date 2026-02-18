local M = {}

local api          = require("dblp.api")
local pickers      = require("telescope.pickers")
local finders      = require("telescope.finders")
local actions      = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf         = require("telescope.config").values

local FRAMES    = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local TITLE_MAX = 50

local function truncate(s)
  if #s <= TITLE_MAX then return s end
  return s:sub(1, TITLE_MAX - 1) .. "…"
end

local function make_display(paper)
  local author_str = table.concat(paper.authors, ", ")
  local parts = { truncate(paper.title) }
  if paper.year  ~= "" then table.insert(parts, "(" .. paper.year .. ")") end
  if paper.venue ~= "" then table.insert(parts, "- " .. paper.venue) end
  if author_str  ~= "" then table.insert(parts, "- " .. author_str) end
  return table.concat(parts, " ")
end

local function make_loading_finder(frame)
  return finders.new_table({
    results = { frame .. " Searching DBLP…" },
    entry_maker = function(line)
      return { value = { _loading = true }, display = line, ordinal = line }
    end,
  })
end

local function make_results_finder(results)
  for i, paper in ipairs(results) do
    paper.index = i
  end
  return finders.new_table({
    results = results,
    entry_maker = function(paper)
      local display = paper.index .. ": " .. make_display(paper)
      return { value = paper, display = display, ordinal = display }
    end,
  })
end

--- Open the DBLP Telescope picker.
--- Displays an animated loading entry while the search runs, then swaps in results.
---
---@param query string  search string sent to the DBLP API
---@param opts  table   merged config (bibtex_format, results_count, search_url, …)
function M.open(query, opts)
  opts = opts or {}
  local bibtex_format = opts.bibtex_format or 1
  local results_count = opts.results_count or 20
  local search_url    = opts.search_url

  local frame_idx = 1

  local picker = pickers.new(opts, {
    prompt_title = "DBLP Results",
    finder       = make_loading_finder(FRAMES[frame_idx]),
    sorter       = conf.generic_sorter(opts),
    previewer    = false,

    attach_mappings = function(prompt_bufnr, _map)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        if not entry or entry.value._loading then return end
        actions.close(prompt_bufnr)

        local spinner = require("dblp.spinner").new("Fetching BibTeX…")
        spinner:start()

        api.fetch_bibtex_async(entry.value.url, bibtex_format, function(bibtex)
          spinner:stop()

          if not bibtex then
            vim.notify("dblp: could not fetch BibTeX", vim.log.levels.WARN)
            return
          end

          local lines = vim.split(bibtex, "\n", { plain = true })
          while #lines > 0 and lines[#lines]:match("^%s*$") do
            table.remove(lines)
          end
          table.insert(lines, "")

          local target_row = vim.api.nvim_win_get_cursor(0)[1] + 1
          vim.api.nvim_put(lines, "l", true, true)
          vim.api.nvim_win_set_cursor(0, { target_row, 0 })
        end)
      end)
      return true
    end,
  })

  -- Open the picker first so prompt_bufnr is available.
  picker:find()

  -- Animate the loading entry while the search is in flight.
  local timer = vim.uv.new_timer()
  timer:start(80, 80, vim.schedule_wrap(function()
    frame_idx = (frame_idx % #FRAMES) + 1
    if not (picker.prompt_bufnr and vim.api.nvim_buf_is_valid(picker.prompt_bufnr)) then
      timer:stop()
      if not timer:is_closing() then timer:close() end
      return
    end
    picker:refresh(make_loading_finder(FRAMES[frame_idx]), { reset_prompt = false })
  end))

  api.search_async(query, results_count, search_url, function(results)
    timer:stop()
    if not timer:is_closing() then timer:close() end

    -- Picker may have been closed by the user before results arrived.
    if not (picker.prompt_bufnr and vim.api.nvim_buf_is_valid(picker.prompt_bufnr)) then
      return
    end

    if #results == 0 then
      vim.notify("dblp: no results for: " .. query, vim.log.levels.INFO)
      actions.close(picker.prompt_bufnr)
      return
    end

    picker:refresh(make_results_finder(results), { reset_prompt = false })
  end)
end

return M

local M = {}

M.config = {
    bibtex_format = 1, -- 0=condensed, 1=standard, 2=with_crossref
    results_count = 50,
    search_url    = "https://dblp.org/search/publ/api",
}

--- Merge user options into the plugin config.
---@param opts table|nil
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

--- Search DBLP for *query*, then open a Telescope picker over the results.
--- The picker does fuzzy filtering locally; no further HTTP requests are made.
---
---@param query string   search string sent to the DBLP API
---@param opts  table|nil  per-call overrides merged on top of M.config
function M.search(query, opts)
    if not query or query == "" then
        vim.notify("dblp: no query provided", vim.log.levels.WARN)
        return
    end

    local merged = vim.tbl_deep_extend("force", M.config, opts or {})

    require("dblp.picker").open(query, merged)
end

return M

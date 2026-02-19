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

--- Search DBLP for a DOI, fetch its BibTeX, and insert it into the buffer.
---
---@param doi  string   DOI to look up
---@param opts table|nil  per-call overrides merged on top of M.config
function M.search_doi(doi, opts)
    if not doi or doi == "" then
        vim.notify("dblp: no DOI provided", vim.log.levels.WARN)
        return
    end

    local merged = vim.tbl_deep_extend("force", M.config, opts or {})
    local api     = require("dblp.api")
    local spinner = require("dblp.spinner").new("Fetching BibTeX for DOI…")
    spinner:start()

    api.search_doi_async(doi, merged.search_url, function(url, err)
        if err then
            spinner:stop()
            vim.notify("dblp: " .. err, vim.log.levels.WARN)
            return
        end
        if not url then
            spinner:stop()
            vim.notify("dblp: no results found for DOI: " .. doi, vim.log.levels.WARN)
            return
        end

        api.fetch_bibtex_async(url, merged.bibtex_format, function(bibtex)
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
end

return M

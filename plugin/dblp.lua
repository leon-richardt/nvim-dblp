if vim.g.loaded_dblp then return end
vim.g.loaded_dblp = true

-- Require Neovim 0.8+ for vim.tbl_get and vim.json.decode.
if vim.fn.has("nvim-0.8") == 0 then
    vim.notify("nvim-dblp requires Neovim 0.8 or later", vim.log.levels.ERROR)
    return
end

-- Open a floating input for `prompt`, then call `action` with the user's text.
local function with_input(prompt, action)
    require("dblp.input").open(prompt, function(text)
        if text then action(text) end
    end)
end

-- General search
local GENERAL_SEARCH_TITLE = "DBLP general search"
local GENERAL_SEARCH_DESC = "Search DBLP and insert a BibTeX entry"

-- :DBLPSearch [query words...]
vim.api.nvim_create_user_command("DBLPSearch", function(cmd_args)
    if cmd_args.args ~= "" then
        require("dblp").search(cmd_args.args)
    else
        with_input(GENERAL_SEARCH_TITLE, require("dblp").search)
    end
end, {
    nargs = "*",
    desc  = GENERAL_SEARCH_DESC,
})

-- <Plug>(dblp-search) – always opens the floating input first.
vim.keymap.set("n", "<Plug>(dblp-search)", function()
    with_input(GENERAL_SEARCH_TITLE, require("dblp").search)
end, { desc = GENERAL_SEARCH_DESC .. " (nvim-dblp)" })


-- DOI-specific search
local DOI_SEARCH_TITLE = "DBLP DOI search"
local DOI_SEARCH_DESC = "Search DBLP by DOI and insert a BibTeX entry"

-- :DBLPSearchDOI [doi]
vim.api.nvim_create_user_command("DBLPSearchDOI", function(cmd_args)
    if cmd_args.args ~= "" then
        require("dblp").search_doi(cmd_args.args)
    else
        with_input(DOI_SEARCH_TITLE, require("dblp").search_doi)
    end
end, {
    nargs = "*",
    desc  = DOI_SEARCH_DESC,
})

-- <Plug>(dblp-search-doi) – always opens the floating input first.
vim.keymap.set("n", "<Plug>(dblp-search-doi)", function()
    with_input(DOI_SEARCH_TITLE, require("dblp").search_doi)
end, { desc = DOI_SEARCH_DESC .. " (nvim-dblp)" })

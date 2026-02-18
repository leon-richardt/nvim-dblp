if vim.g.loaded_dblp then return end
vim.g.loaded_dblp = true

-- Require Neovim 0.8+ for vim.tbl_get and vim.json.decode.
if vim.fn.has("nvim-0.8") == 0 then
  vim.notify("nvim-dblp requires Neovim 0.8 or later", vim.log.levels.ERROR)
  return
end

-- :DBLPSearch [query words...]
--   With arguments : uses them as the search query directly.
--   Without arguments : opens a floating input window for the query.
vim.api.nvim_create_user_command("DBLPSearch", function(cmd_args)
  if cmd_args.args ~= "" then
    require("dblp").search(cmd_args.args)
  else
    require("dblp.input").open("DBLP query", function(query)
      if query then require("dblp").search(query) end
    end)
  end
end, {
  nargs = "*",
  desc  = "Search DBLP and insert a BibTeX entry",
})

-- <Plug>(dblp-search) – opens a floating input, then the picker.
vim.keymap.set("n", "<Plug>(dblp-search)", function()
  require("dblp.input").open("DBLP query", function(query)
    if query then require("dblp").search(query) end
  end)
end, { desc = "Search DBLP (nvim-dblp)" })

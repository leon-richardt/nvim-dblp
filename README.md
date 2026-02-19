# 📚 nvim-dblp

Search the [DBLP](https://dblp.org) computer-science bibliography without leaving Neovim, and insert BibTeX entries directly into your buffer.

https://github.com/user-attachments/assets/519d42ea-0188-4da7-aa3f-2ecc684b82ba

## ✨ Features

- 🔍 Query DBLP from Neovim
- ⚡️ Select matching results in a **Telescope picker** with fuzzy filtering
- 📋 Press `<CR>` to fetch and insert the selected entry's **BibTeX**
- 🌐 Configurable [API](https://dblp.org/faq/How+to+use+the+dblp+search+API.html) endpoint — point at any DBLP mirror or instance

## ⚡️ Requirements

- Neovim ≥ 0.8
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "leon-richardt/nvim-dblp",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  opts = {},
}
```

## 🚀 Usage

### Commands

| Command | Description |
|---|---|
| `:DBLPSearch {query}` | Search DBLP for `{query}` and open the picker |
| `:DBLPSearch` | Open a prompt to enter the query, then open the picker |

### Mappings

`nvim-dblp` ships a `<Plug>` mapping but does not bind any keys by default:

```lua
vim.keymap.set("n", "<leader>db", "<Plug>(dblp-search)")
```

### Workflow

1. Run `:DBLPSearch computing machinery and intelligence` (or leave the argument out to be prompted).
2. A Telescope picker opens with fetched results.
3. Type to fuzzy-filter within the results; or escape to normal mode and use `j`/`k` to navigate.
4. Press `<CR>` — the BibTeX entry is fetched and inserted after the cursor.

## ⚙️ Configuration

```lua
require("dblp").setup({
  -- BibTeX format: 0 = condensed, 1 = standard, 2 = with crossref
  bibtex_format = 1,

  -- Maximum number of results to fetch per query
  results_count = 50,

  -- DBLP search API endpoint (change to use a mirror)
  search_url = "https://dblp.org/search/publ/api",
})
```

## ⚠️ Disclaimer
This plugin was pretty heavily vibecoded with Claude Code.

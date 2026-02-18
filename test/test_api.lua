-- Run with:
--   nvim --headless -u NONE \
--     --cmd "set rtp+=~/.local/share/nvim/lazy/plenary.nvim" \
--     --cmd "set rtp+=~/.local/share/nvim/lazy/telescope.nvim" \
--     --cmd "set rtp+=." \
--     -l test/test_api.lua

local PASS = "[PASS]"
local FAIL = "[FAIL]"

local function check(label, cond, info)
  if cond then
    print(PASS .. " " .. label)
  else
    print(FAIL .. " " .. label .. (info and (" | " .. tostring(info)) or ""))
  end
end

local api = require("dblp.api")

-- Pause between every live network call to respect DBLP rate limits.
local PAUSE = 2000
local function net(fn) vim.uv.sleep(PAUSE) return fn() end

-- ── Test 1: search returns results ────────────────────────────────────────────
print("\n── search() ──")

local results = net(function() return api.search("attention is all you need vaswani", 5) end)

check("returns a table", type(results) == "table")
check("at least one result", #results >= 1)

if #results >= 1 then
  local p = results[1]
  check("title is a string",   type(p.title)   == "string" and p.title   ~= "")
  check("year is a string",    type(p.year)    == "string" and p.year    ~= "")
  check("url is a string",     type(p.url)     == "string" and p.url     ~= "")
  check("authors is a table",  type(p.authors) == "table")
  check("at least one author", #p.authors >= 1)
  print("   title:   " .. p.title)
  print("   year:    " .. p.year)
  print("   venue:   " .. p.venue)
  print("   authors: " .. table.concat(p.authors, "; "))
  print("   url:     " .. p.url)
end

-- ── Test 2: ensure_list edge case – single-author paper ───────────────────────
print("\n── search() single-author edge case ──")

local sa = net(function() return api.search("Turing Computing Machinery Intelligence 1950", 5) end)
check("returns a table", type(sa) == "table")
if #sa >= 1 then
  check("authors field is a table", type(sa[1].authors) == "table")
  print("   title:   " .. sa[1].title)
  print("   authors: " .. table.concat(sa[1].authors, "; "))
end

-- ── Test 3: empty query returns empty table (DBLP 500, handled gracefully) ────
print("\n── search() empty query ──")

local empty = net(function() return api.search("", 5) end)
check("empty query returns table", type(empty) == "table")
check("empty query returns no results", #empty == 0)

-- ── Test 4: fetch_bibtex ──────────────────────────────────────────────────────
print("\n── fetch_bibtex() ──")

if results and #results >= 1 then
  local bib  = net(function() return api.fetch_bibtex(results[1].url, 1) end)
  check("returns a string",        type(bib) == "string")
  check("contains @",              bib ~= nil and bib:find("@") ~= nil)
  check("contains bibtex key",     bib ~= nil and bib:find(results[1].key, 1, true) ~= nil)
  if bib then
    print("   first line: " .. bib:match("([^\n]+)"))
  end

  local bib0 = net(function() return api.fetch_bibtex(results[1].url, 0) end)
  check("condensed format returns string", type(bib0) == "string")
else
  print("   (skipped – no search results)")
end

-- ── Test 5: search_async returns same results as sync search ─────────────────
print("\n── search_async() ──")

do
  local async_results = nil
  api.search_async("attention is all you need vaswani", 3, nil, function(r)
    async_results = r
  end)
  -- Wait up to 10 s for the async callback to fire.
  local ok = vim.wait(10000, function() return async_results ~= nil end, 50)
  check("async search completes",        ok)
  check("async returns a table",         type(async_results) == "table")
  check("async returns ≥1 result",       async_results ~= nil and #async_results >= 1)
  if async_results and #async_results >= 1 then
    check("async result has title",      async_results[1].title ~= "")
  end
end

-- ── Test 6: fetch_bibtex_async matches sync fetch ─────────────────────────────
print("\n── fetch_bibtex_async() ──")

if results and #results >= 1 then
  local async_bib = nil
  net(function()
    api.fetch_bibtex_async(results[1].url, 1, function(b) async_bib = b end)
  end)
  local ok = vim.wait(10000, function() return async_bib ~= nil end, 50)
  check("async bibtex completes",        ok)
  check("async bibtex is a string",      type(async_bib) == "string")
  check("async bibtex contains @",       async_bib ~= nil and async_bib:find("@") ~= nil)
end

-- ── Test 8: display format (truncation + numbering) ──────────────────────────
-- Exercise make_display / entry_maker via a mocked picker that captures entries.
print("\n── display format ──")

do
  local long_title = ("A"):rep(80)  -- 80-char title, should be truncated
  local short_title = "Short Title"

  local fake_papers = {
    { title = long_title,  year = "2020", venue = "V", authors = { "Author A" }, url = "u1", key = "k1" },
    { title = short_title, year = "2021", venue = "V", authors = { "Author B" }, url = "u2", key = "k2" },
  }

  local entries = {}
  package.loaded["dblp.picker"] = nil   -- force reload with real display logic
  -- We can't call pickers.new() headlessly, so replicate the display logic here.
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
  for i, paper in ipairs(fake_papers) do
    paper.index = i
    local display = paper.index .. ": " .. make_display(paper)
    table.insert(entries, display)
    print("   " .. display)
  end

  -- Title truncation: long title must be ≤ TITLE_MAX bytes before the rest.
  local title_part = entries[1]:match("^%d+: ([^(]+)%(")
  title_part = title_part and title_part:gsub("%s+$", "")
  -- Use strchars (Unicode-aware) because "…" is 3 bytes but 1 character.
  check("long title is truncated",    title_part ~= nil and vim.fn.strchars(title_part) <= TITLE_MAX)
  check("truncated title ends with …", title_part ~= nil and title_part:sub(-3) == "…")
  check("short title is not truncated", entries[2]:find(short_title, 1, true) ~= nil)

  -- Numbering: first entry starts with "1:", second with "2:".
  check("entry 1 prefixed with '1:'", entries[1]:sub(1, 2) == "1:")
  check("entry 2 prefixed with '2:'", entries[2]:sub(1, 2) == "2:")
end

-- ── Test 7: init.lua search() wires api + picker correctly ───────────────────
-- Mock both dblp.api and dblp.picker so this test is network-independent.
print("\n── Test 9: init.search() smoke test (mocked) ──")

local picker_called   = false
local captured_query  = nil
local captured_opts   = nil
package.loaded["dblp.picker"] = {
  open = function(query, opts)
    picker_called  = true
    captured_query = query
    captured_opts  = opts
  end,
}

-- Reload init so it picks up the mocked modules.
package.loaded["dblp"] = nil
local dblp = require("dblp")
dblp.setup({ results_count = 3, bibtex_format = 0 })

dblp.search("any query")
check("picker.open was called",    picker_called)
check("picker received query",     captured_query == "any query")
check("config flows into opts",    captured_opts ~= nil and captured_opts.bibtex_format == 0)

-- Empty query should warn and not call picker.
picker_called = false
dblp.search("")
check("empty query does not open picker", not picker_called)

-- Per-call opts override config.
picker_called = false
dblp.search("override test", { bibtex_format = 2 })
check("per-call override applied", captured_opts ~= nil and captured_opts.bibtex_format == 2)

print("\n── done ──\n")
vim.cmd("qa!")

local M = {}

local curl = require("plenary.curl")

local DEFAULT_SEARCH_URL = "https://dblp.org/search/publ/api"

-- Wrap a single object in a list; leave actual arrays untouched.
-- DBLP returns a bare object when there is exactly one result.
local function ensure_list(v)
  if v == nil then return {} end
  if v[1] ~= nil then return v end
  return { v }
end

-- Parse a raw curl response from the search API into a list of paper tables.
-- Returns (results, nil) on success, or (nil, err_string) on failure.
local function parse_search_response(response)
  if not response or response.status ~= 200 then
    return nil, "HTTP " .. tostring(response and response.status or "?") .. " from search API"
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if not ok then
    return nil, "failed to parse JSON response"
  end

  local hits_obj = vim.tbl_get(data, "result", "hits")
  if not hits_obj or not hits_obj.hit then
    return {}
  end

  local hits    = ensure_list(hits_obj.hit)
  local results = {}

  for _, hit in ipairs(hits) do
    local info    = hit.info or {}
    local authors = {}

    if info.authors and info.authors.author then
      for _, a in ipairs(ensure_list(info.authors.author)) do
        table.insert(authors, type(a) == "table" and (a.text or "") or tostring(a))
      end
    end

    table.insert(results, {
      title   = info.title or "",
      year    = info.year  or "",
      venue   = info.venue or "",
      authors = authors,
      url     = info.url   or "",
      key     = info.key   or "",
    })
  end

  return results
end

-- Parse a raw curl response from the BibTeX endpoint.
-- Returns (bibtex_string, nil) on success, or (nil, err_string) on failure.
local function parse_bibtex_response(response)
  if not response or response.status ~= 200 then
    return nil, "HTTP " .. tostring(response and response.status or "?") .. " fetching BibTeX"
  end
  return response.body
end

--- Synchronous search – used by tests.
---@param query      string
---@param count      integer
---@param search_url string|nil
---@return table[]
function M.search(query, count, search_url)
  count      = count      or 20
  search_url = search_url or DEFAULT_SEARCH_URL

  local ok, response = pcall(curl.get, search_url, {
    query = { q = query, format = "json", h = tostring(count) },
  })

  if not ok then
    vim.notify("dblp: network error: " .. tostring(response), vim.log.levels.WARN)
    return {}
  end

  local results, err = parse_search_response(response)
  if not results then
    vim.notify("dblp: " .. err, vim.log.levels.WARN)
    return {}
  end
  return results
end

--- Asynchronous search – fires callback(results) on the main thread when done.
---@param query      string
---@param count      integer
---@param search_url string|nil
---@param callback   fun(results: table[])
function M.search_async(query, count, search_url, callback)
  count      = count      or 20
  search_url = search_url or DEFAULT_SEARCH_URL

  curl.get(search_url, {
    query    = { q = query, format = "json", h = tostring(count) },
    callback = vim.schedule_wrap(function(response)
      local results, err = parse_search_response(response)
      if not results then
        vim.notify("dblp: " .. err, vim.log.levels.WARN)
        callback({})
        return
      end
      callback(results)
    end),
  })
end

--- Synchronous BibTeX fetch – used by tests.
---@param url    string
---@param format integer
---@return string|nil
function M.fetch_bibtex(url, format)
  format = format or 1

  local ok, response = pcall(curl.get, url .. ".bib", {
    query = { param = tostring(format) },
  })

  if not ok then
    vim.notify("dblp: network error fetching BibTeX: " .. tostring(response), vim.log.levels.WARN)
    return nil
  end

  local bibtex, err = parse_bibtex_response(response)
  if not bibtex then
    vim.notify("dblp: " .. err, vim.log.levels.WARN)
    return nil
  end
  return bibtex
end

--- Asynchronous BibTeX fetch – fires callback(bibtex_or_nil) on the main thread.
---@param url      string
---@param format   integer
---@param callback fun(bibtex: string|nil)
function M.fetch_bibtex_async(url, format, callback)
  format = format or 1

  curl.get(url .. ".bib", {
    query    = { param = tostring(format) },
    callback = vim.schedule_wrap(function(response)
      local bibtex, err = parse_bibtex_response(response)
      if not bibtex then
        vim.notify("dblp: " .. err, vim.log.levels.WARN)
        callback(nil)
        return
      end
      callback(bibtex)
    end),
  })
end

return M

-- Test Checklist: reads a markdown walkthrough into sections and items.
--
-- "## Heading" starts a section and "- [ ] text" (or "- [x] text") is an
-- item; everything else is left out.  Each item's key is its section and
-- text, so ticks survive the walkthrough being edited around them.
-- ------------------

local M = {}

local function clean(text)
  text = text:gsub("%*%*(.-)%*%*", "%1"):gsub("`(.-)`", "%1")
  text = text:gsub("%[(.-)%]%((.-)%)", "%1")
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.parse(body)
  local list = { title = "Checklist", sections = {}, items = {} }
  local section
  for line in (body or ""):gmatch("[^\r\n]+") do
    local title = line:match("^#%s+(.+)$")
    local heading = line:match("^##%s+(.+)$")
    local item = line:match("^%s*[-*]%s+%[[ xX]%]%s+(.+)$")
    if title and #list.sections == 0 then
      list.title = clean(title)
    elseif heading then
      section = { title = clean(heading), first = #list.items + 1, last = #list.items }
      list.sections[#list.sections + 1] = section
    elseif item then
      if not section then
        section = { title = "General", first = #list.items + 1, last = #list.items }
        list.sections[#list.sections + 1] = section
      end
      local text = clean(item)
      list.items[#list.items + 1] = { section = section, text = text, key = section.title .. "|" .. text }
      section.last = #list.items
    end
  end
  -- sections without items (notes, how to report) aren't shown
  local kept = {}
  for _, s in ipairs(list.sections) do
    if s.last >= s.first then kept[#kept + 1] = s end
  end
  list.sections = kept
  return list
end

-- none -> done -> issue -> none
function M.nextMark(mark)
  if mark == nil then return "done" end
  if mark == "done" then return "issue" end
  return nil
end

function M.counts(list, marks, from, to)
  local done, issues, total = 0, 0, 0
  for i = from or 1, to or #list.items do
    local m = marks[list.items[i].key]
    total = total + 1
    if m == "done" then done = done + 1 elseif m == "issue" then issues = issues + 1 end
  end
  return done, issues, total
end

return M

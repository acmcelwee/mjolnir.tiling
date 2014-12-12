local tiling = {}

local application = require "mjolnir.application"
local window = require "mjolnir.window"
local screen = require "mjolnir.screen"
local fnutils = require "mjolnir.fnutils"
local geometry = require "mjolnir.geometry"
local alert = require "mjolnir.alert"
local layouts = require "mjolnir.tiling.layouts"
local spaces = {}
local settings = { layouts = {} }

local excluded = {}
function tiling.togglefloat(floatfn)
  local win = window:focusedwindow()
  local id = win:id()
  excluded[id] = not excluded[id]

  if excluded[id] then
    if floatfn then floatfn(win) end
    alert.show("Excluding " .. win:title() .. " from tiles")
  else
    alert.show("Adding " .. win:title() .. " to tiles")
  end

  local space = getspace()
  apply(space.windows, space.layout)
end

function tiling.addlayout(name, layout)
  layouts[name] = layout
  setlayouts(layouts)
end

function tiling.set(name, value)
  settings[name] = value
end

function tiling.cycle(direction)
  local space = getspace()
  local windows = space.windows
  local win = window:focusedwindow() or windows[1]
  local direction = direction or 1
  local currentindex = fnutils.indexof(windows, win)
  local layout = space.layout
  if not currentindex then return end
  nextindex = currentindex + direction
  if nextindex > #windows then
    nextindex = 1
  elseif nextindex < 1 then
    nextindex = #windows
  end

  windows[nextindex]:focus()
end

function tiling.cyclelayout()
  local space = getspace()
  space.layout = space.layoutcycle()
  alert.show(space.layout, 1)
  apply(space.windows, space.layout)
end

function tiling.promote()
  local space = getspace()
  local windows = space.windows
  local win = window:focusedwindow() or windows[1]
  local i = fnutils.indexof(windows, win)
  if not i then return end

  local current = table.remove(windows, i)
  table.insert(windows, 1, current)
  win:focus()
  apply(windows, space.layout)
end

function tiling.resizevertical(direction, interval, limit)
  direction = direction or 1
  interval = interval or 5
  limit = limit or 200
  local space = getspace()
  local windows = space.windows
  local win = window:focusedwindow() or windows[1]
  local wincount = #windows
  local focused_frame = win:frame()
  local primary_screen = screen.mainscreen()
  local max_frame = primary_screen:frame()
  local available_left_border = 0
  local available_right_border = max_frame.w
  local delta = direction * interval

  -- TODO: Resizing the vertical quadrants of the main-horizontal layout will take some more time
  if wincount == 1 then
    return
  end

  -- Is this window aligned to the left side?
  if focused_frame.x < 1 then
    local targetright = math.max(limit, focused_frame.w + delta)
    focused_frame.w = targetright

    -- Just in case it's been shifted off the screen a bit
    focused_frame.x = 0

    available_left_border = targetright
  -- Is this the right half that we're working with?
  elseif (focused_frame.x + focused_frame.w) == max_frame.w then
    local targetleft = math.min(math.max(limit, focused_frame.x + delta), max_frame.w)
    focused_frame.x = targetleft
    available_right_border = targetleft
  end

  if available_left_border > 0 or available_right_border < max_frame.w then
    win:setframe(focused_frame)

    for index, win in pairs(windows) do
      if index ~= 1 then
        local frame = win:frame()
        local deltax = frame.x - available_left_border

        frame.x = available_left_border
        frame.w = available_right_border - frame.x

        win:setframe(frame)
      end
    end
  end
end

function apply(windows, layout)
  layouts[layout](windows)
end

function iswindowincluded(win)
  onscreen = win:screen() == screen.mainscreen()
  standard = win:isstandard()
  hastitle = #win:title() > 0
  istiling = not excluded[win:id()]
  return onscreen and standard and hastitle and istiling
end

-- Infer a 'space' from our existing spaces
function getspace()
  local windows = fnutils.filter(window.visiblewindows(), iswindowincluded)

  fnutils.each(spaces, function(space)
    local matches = 0
    fnutils.each(space.windows, function(win)
      if fnutils.contains(windows, win) then matches = matches + 1 end
    end)
    space.matches = matches
  end)

  table.sort(spaces, function(a, b)
    return a.matches > b.matches
  end)

  local space = {}

  if #spaces == 0 or spaces[1].matches == 0 then
    space.windows = windows
    space.layoutcycle = fnutils.cycle(settings.layouts)
    space.layout = settings.layouts[1]
    table.insert(spaces, space)
  else
    space = spaces[1]
  end

  space.windows = syncwindows(space.windows, windows)
  return space
end

function syncwindows(windows, newwindows)
  -- Remove any windows no longer around
  windows = fnutils.filter(windows, function(win)
    return fnutils.contains(newwindows, win)
  end)

  -- Add any new windows since
  fnutils.each(newwindows, function(win)
    if fnutils.contains(windows, win) == false then
      table.insert(windows, win)
    end
  end)

  -- Remove any bad windows
  windows = fnutils.filter(windows, function(win)
    return win:isstandard()
  end)

  return windows
end

function setlayouts(layouts)
  local n = 0
  for k, v in pairs(layouts) do
    n = n + 1
    settings.layouts[n] = k
  end
end

setlayouts(layouts)

return tiling

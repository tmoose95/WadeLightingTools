local pluginName = select(1, ...) or "Auto Color Picker"
local componentName = select(2, ...) or "Main"
local signalTable, myHandle = select(3, ...)

signalTable = signalTable or {}

------------------------------------------------------------------------------
-- Auto Color Picker v5.0.3
-- Zero-setup grandMA3 color-picker builder for software 2.4.x.
--
-- What it does:
--   * Reads Groups and Color presets from the CURRENT Data Pool.
--   * Creates/reuses its own Layout automatically.
--   * Creates its own idle/selected Appearances automatically if the packaged
--     resources are missing.
--   * Creates one Macro per Group/Color cell; no fixed user object numbers.
--   * Makes each row mutually exclusive so only its latest color is marked.
--   * Remembers the last Group/Color selection for each Data Pool.
------------------------------------------------------------------------------

local VERSION = "5.0.3"
local MANAGED_MARKER = "[AutoColorPicker v5 managed object]"
local LAYOUT_BASE_NAME = "Auto Color Picker"
local IDLE_APPEARANCE_NAME = "AutoColorPicker_Idle"
local ACTIVE_APPEARANCE_NAME = "AutoColorPicker_Selected"
local PREF_KEY_PREFIX = "AutoColorPicker_v5_"
local MAX_LAYOUT_ELEMENTS = 10000
local PREFERRED_MACRO_START = 9001
local PREFERRED_RESOURCE_START = 9001

local SIG_GROUP_TOGGLE = "ACP5_GroupToggle"
local SIG_COLOR_TOGGLE = "ACP5_ColorToggle"
local SIG_GROUP_ALL = "ACP5_GroupAll"
local SIG_GROUP_NONE = "ACP5_GroupNone"
local SIG_COLOR_ALL = "ACP5_ColorAll"
local SIG_COLOR_NONE = "ACP5_ColorNone"
local SIG_BUILD = "ACP5_Build"
local SIG_CANCEL = "ACP5_Cancel"

local activePopup = nil
local activeProgress = nil
local activeUndo = nil

------------------------------------------------------------------------------
-- General helpers
------------------------------------------------------------------------------

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function oneLine(value)
    local text = tostring(value or "")
    text = text:gsub("[\r\n\t]+", " ")
    text = text:gsub("%s%s+", " ")
    return trim(text)
end

local function truncate(value, maxLength)
    local text = oneLine(value)
    if #text <= maxLength then return text end
    return text:sub(1, math.max(1, maxLength - 3)) .. "..."
end

local function startsWith(text, prefix)
    text, prefix = tostring(text or ""), tostring(prefix or "")
    return text:sub(1, #prefix) == prefix
end

local function contains(text, needle)
    return tostring(text or ""):find(tostring(needle or ""), 1, true) ~= nil
end

local function safeChildren(handle)
    if handle == nil then return {} end
    local ok, children = pcall(function() return handle:Children() end)
    if ok and type(children) == "table" then return children end
    return {}
end

-- grandMA3 exposes both physical child indexes and command-line pool indexes.
-- Pool numbers such as Macro 9001 must be resolved with CmdlineIndex/Ptr; using
-- Index or bracket lookup can address the physical child order in a sparse pool.
local function safeIndex(handle)
    if handle == nil then return nil end

    local ok, value = pcall(function() return handle:CmdlineIndex() end)
    value = ok and tonumber(value) or nil
    if value ~= nil then return value end

    ok, value = pcall(function() return handle:Index() end)
    if ok then return tonumber(value) end
    return nil
end

local function safeChildIndex(handle)
    if handle == nil then return nil end
    local ok, value = pcall(function() return handle:Index() end)
    if ok then return tonumber(value) end
    return nil
end

local function safeName(handle, fallback)
    if handle == nil then return fallback or "Unnamed" end
    local ok, value = pcall(function() return handle.Name end)
    if ok and value ~= nil and tostring(value) ~= "" then return tostring(value) end
    return fallback or "Unnamed"
end

local function safeGet(collection, index)
    if collection == nil or index == nil then return nil end
    index = tonumber(index)
    if index == nil then return nil end

    local ok, value = pcall(function() return collection:CmdlinePtr(index) end)
    if ok and value ~= nil then return value end

    -- Reliable fallback for software/object classes that do not expose
    -- CmdlinePtr: compare every existing child's command-line index.
    for _, child in ipairs(safeChildren(collection)) do
        if safeIndex(child) == index then return child end
    end

    -- Compatibility fallbacks for collections whose physical and visible
    -- indexes are intentionally identical.
    ok, value = pcall(function() return collection[index] end)
    if ok and value ~= nil then return value end

    ok, value = pcall(function() return collection:Ptr(index) end)
    if ok and value ~= nil then return value end
    return nil
end

local function canYield()
    if type(coroutine) ~= "table" or type(coroutine.yield) ~= "function" then return false end
    if type(coroutine.isyieldable) == "function" then return coroutine.isyieldable() end
    return true
end

local function yieldUI()
    if canYield() then coroutine.yield({ui = 1}) end
end

local function safeIsEmpty(handle)
    if handle == nil then return true end
    local ok, value = pcall(function() return handle:IsEmpty() end)
    if ok then return value == true end
    return false
end

local function safeAddr(handle)
    if handle == nil then return nil end

    local ok, value = pcall(function() return handle:AddrNative() end)
    if ok and value ~= nil and tostring(value) ~= "" then return tostring(value) end

    ok, value = pcall(function() return ToAddr(handle, false, true) end)
    if ok and value ~= nil and tostring(value) ~= "" then return tostring(value) end

    return nil
end

local function handleKey(handle)
    if handle == nil then return nil end

    if type(HandleToInt) == "function" then
        local ok, value = pcall(HandleToInt, handle)
        if ok and value ~= nil then return "H:" .. tostring(value) end
    end

    local address = safeAddr(handle)
    if address ~= nil then return "A:" .. address end
    return "T:" .. tostring(handle)
end

local function setProperty(handle, propertyName, value)
    if handle == nil then return false end

    local stringValue = tostring(value)
    local ok = pcall(function() handle:Set(propertyName, stringValue) end)
    if ok then return true end

    ok = pcall(function() handle[propertyName] = value end)
    return ok
end

local function setFirstProperty(handle, names, value)
    for _, propertyName in ipairs(names) do
        if setProperty(handle, propertyName, value) then return true end
    end
    return false
end

local function isValid(handle)
    if handle == nil then return false end
    if type(IsObjectValid) == "function" then
        local ok, value = pcall(IsObjectValid, handle)
        if ok then return value == true end
    end
    local ok, value = pcall(function() return handle:IsValid() end)
    return ok and value == true
end

local function findByName(collection, name)
    for _, child in ipairs(safeChildren(collection)) do
        if safeName(child, "") == name then return child end
    end
    return nil
end

local function collectionMax(collection, fallback)
    local ok, value = pcall(function() return collection:MaxCount() end)
    value = ok and tonumber(value) or nil
    if value == nil or value < 1 then return fallback end
    return math.min(value, fallback)
end

local function slotIsFree(collection, index)
    local object = safeGet(collection, index)
    return object == nil or safeIsEmpty(object)
end

local function findFreeSlot(collection, preferredStart, maxIndex)
    maxIndex = collectionMax(collection, maxIndex or 99999)
    preferredStart = math.max(1, math.min(tonumber(preferredStart) or 1, maxIndex))

    for index = preferredStart, maxIndex do
        if slotIsFree(collection, index) then return index end
    end
    for index = 1, preferredStart - 1 do
        if slotIsFree(collection, index) then return index end
    end
    return nil
end

local function findContiguousFreeRange(collection, count, preferredStart, maxIndex)
    if count < 1 then return nil end

    maxIndex = collectionMax(collection, maxIndex or 99999)
    preferredStart = math.max(1, math.min(tonumber(preferredStart) or 1, maxIndex))

    local function scan(firstIndex, lastIndex)
        local runStart, runLength = nil, 0
        for index = firstIndex, lastIndex do
            if slotIsFree(collection, index) then
                if runStart == nil then runStart = index end
                runLength = runLength + 1
                if runLength >= count then return runStart end
            else
                runStart, runLength = nil, 0
            end
        end
        return nil
    end

    local result = scan(preferredStart, maxIndex)
    if result ~= nil then return result end
    if preferredStart > 1 then return scan(1, preferredStart - 1) end
    return nil
end

local function poolAddress(keyword, index, dataPoolIndex)
    if dataPoolIndex ~= nil and (keyword == "Macro" or keyword == "Layout") then
        return string.format("DataPool %d %s %d", dataPoolIndex, keyword, index)
    end
    return string.format("%s %d", keyword, index)
end

local function lookupPoolObject(collection, keyword, index, dataPoolIndex)
    local object = safeGet(collection, index)
    if object ~= nil then return object end

    local address = poolAddress(keyword, index, dataPoolIndex)
    if type(GetObject) == "function" then
        local ok, value = pcall(GetObject, address)
        if ok and value ~= nil then return value end
    end

    if type(ObjectList) == "function" then
        local ok, values = pcall(ObjectList, address)
        if ok and type(values) == "table" and values[1] ~= nil then return values[1] end
    end
    return nil
end

local function waitForPoolObject(collection, keyword, index, dataPoolIndex)
    for attempt = 1, 5 do
        local object = lookupPoolObject(collection, keyword, index, dataPoolIndex)
        if object ~= nil then return object end
        if attempt < 5 then yieldUI() end
    end
    return nil
end

local function createPoolObject(collection, keyword, index, undo, dataPoolIndex)
    local existing = safeGet(collection, index)
    if existing ~= nil and not safeIsEmpty(existing) then
        -- Collision safety: never overwrite an occupied user object.
        return nil
    end

    -- The command-line Store operation is proven to create the object on the
    -- console. The v5.0.2 failure happened only because it then used physical
    -- bracket indexing to retrieve sparse Macro 9001.
    local command
    if keyword == "Layout" then
        command = string.format("Assign Layout %d", index)
    else
        command = string.format("Store %s %d /NoConfirmation", keyword, index)
    end

    local result = Cmd(command, undo)
    if result ~= "Ok" then
        -- Some empty pool slots already expose a usable handle; keep that as a
        -- final fallback without ever claiming a non-empty object.
        if existing ~= nil and safeIsEmpty(existing) then return existing end
        return nil
    end

    local object = waitForPoolObject(collection, keyword, index, dataPoolIndex)
    if object ~= nil then return object end
    if existing ~= nil and safeIsEmpty(existing) then return existing end
    return nil
end

local function deletePoolObject(collection, keyword, index, undo, dataPoolIndex)
    if collection == nil or index == nil then return false end

    local object = safeGet(collection, index)
    if object == nil or safeIsEmpty(object) then return true end

    local address = safeAddr(object) or poolAddress(keyword, index, dataPoolIndex)
    local result = Cmd("Delete " .. address .. " /NoConfirmation", undo)
    if result == "Ok" then
        yieldUI()
        if slotIsFree(collection, index) then return true end
    end

    -- Object-API fallback must use the physical child index expected by Delete,
    -- not the command-line pool number.
    local childIndex = safeChildIndex(object)
    if childIndex ~= nil then
        local ok = pcall(function() collection:Delete(childIndex, undo) end)
        if ok and slotIsFree(collection, index) then return true end
    end

    result = Cmd(string.format("Delete %s %d /NoConfirmation", keyword, index), undo)
    if result == "Ok" then yieldUI() end
    return slotIsFree(collection, index)
end

local function showAlert(title, message)
    if type(MessageBox) == "function" then
        pcall(function()
            MessageBox({
                title = title,
                message = message,
                backColor = "Window.Plugins",
                icon = "object_smart",
                commands = {{value = 1, name = "OK"}},
            })
        end)
    else
        ErrPrintf("%s: %s", tostring(title), tostring(message))
    end
end

local function stopProgress()
    if activeProgress ~= nil then
        if type(StopProgress) == "function" then pcall(StopProgress, activeProgress) end
        activeProgress = nil
    end
end

local function startProgress(name, maximum)
    if type(StartProgress) ~= "function" then return nil end

    local ok, progress = pcall(StartProgress, name)
    if not ok or progress == nil then return nil end

    activeProgress = progress
    if type(SetProgressRange) == "function" then pcall(SetProgressRange, progress, 0, math.max(1, maximum or 1)) end
    if type(SetProgress) == "function" then pcall(SetProgress, progress, 0) end
    return progress
end

local function updateProgress(value, text)
    if activeProgress == nil then return end
    if value ~= nil and type(SetProgress) == "function" then pcall(SetProgress, activeProgress, value) end
    if text ~= nil and type(SetProgressText) == "function" then pcall(SetProgressText, activeProgress, text) end
end

local function closeUndo()
    if activeUndo ~= nil then
        pcall(CloseUndo, activeUndo)
        activeUndo = nil
    end
end

local function closePopup()
    if activePopup ~= nil and isValid(activePopup) then
        pcall(function() activePopup:Close() end)
    end
    activePopup = nil
end

local function clearSignals()
    signalTable[SIG_GROUP_TOGGLE] = nil
    signalTable[SIG_COLOR_TOGGLE] = nil
    signalTable[SIG_GROUP_ALL] = nil
    signalTable[SIG_GROUP_NONE] = nil
    signalTable[SIG_COLOR_ALL] = nil
    signalTable[SIG_COLOR_NONE] = nil
    signalTable[SIG_BUILD] = nil
    signalTable[SIG_CANCEL] = nil
end

------------------------------------------------------------------------------
-- Preferences
------------------------------------------------------------------------------

local function getPrefs()
    -- GetVar/SetVar require a Variables-derived handle. UserVars() is the
    -- documented per-user variable set and works on grandMA3 2.4 consoles.
    if type(UserVars) ~= "function" then return nil end
    local ok, prefs = pcall(UserVars)
    if ok and prefs ~= nil then return prefs end
    return nil
end

local function preferenceKey(key)
    return PREF_KEY_PREFIX .. tostring(key or "")
end

local function getPref(prefs, key)
    if prefs == nil or type(GetVar) ~= "function" then return nil end
    local ok, value = pcall(GetVar, prefs, preferenceKey(key))
    if ok then return value end
    return nil
end

local function setPref(prefs, key, value)
    if prefs == nil or type(SetVar) ~= "function" then return false end
    local ok, result = pcall(SetVar, prefs, preferenceKey(key), value)
    return ok and result ~= false
end

local function parseNumberSet(value)
    local set = {}
    for token in tostring(value or ""):gmatch("[^,]+") do
        local number = tonumber(trim(token))
        if number ~= nil then set[number] = true end
    end
    return set
end

local function serializeSelected(items, selected)
    local numbers = {}
    for row, item in ipairs(items) do
        if selected[row] then numbers[#numbers + 1] = tostring(item.index) end
    end
    return table.concat(numbers, ",")
end

local function restoreSelection(items, savedValue)
    local selected = {}
    local savedSet = parseNumberSet(savedValue)
    local hasSavedValues = next(savedSet) ~= nil
    local matched = 0

    for row, item in ipairs(items) do
        if hasSavedValues then
            selected[row] = savedSet[item.index] == true
        else
            selected[row] = true
        end
        if selected[row] then matched = matched + 1 end
    end

    if hasSavedValues and matched == 0 then
        for row = 1, #items do selected[row] = true end
    end

    return selected
end

------------------------------------------------------------------------------
-- Collect current Data Pool content
------------------------------------------------------------------------------

local function collectGroups(dataPool)
    local items = {}
    local groups = dataPool and dataPool.Groups

    for _, group in ipairs(safeChildren(groups)) do
        local index = safeIndex(group)
        if index ~= nil and not safeIsEmpty(group) then
            items[#items + 1] = {
                handle = group,
                index = index,
                name = safeName(group, "Group " .. tostring(index)),
            }
        end
    end

    table.sort(items, function(a, b)
        if a.index == b.index then return a.name < b.name end
        return a.index < b.index
    end)

    return items
end

local function findColorPresetPool(dataPool)
    local presetPools = dataPool and dataPool.PresetPools
    if presetPools == nil then return nil, nil end

    local standardColor = safeGet(presetPools, 4)
    if standardColor ~= nil then return standardColor, safeIndex(standardColor) or 4 end

    for _, pool in ipairs(safeChildren(presetPools)) do
        local name = safeName(pool, ""):lower()
        if name == "color" or name == "colour" or name:find("color", 1, true) or name:find("colour", 1, true) then
            return pool, safeIndex(pool)
        end
    end

    return nil, nil
end

local function collectColorPresets(dataPool)
    local items = {}
    local colorPool, featureGroupIndex = findColorPresetPool(dataPool)
    if colorPool == nil then return items, nil, nil end

    for _, preset in ipairs(safeChildren(colorPool)) do
        local index = safeIndex(preset)
        if index ~= nil and not safeIsEmpty(preset) then
            items[#items + 1] = {
                handle = preset,
                index = index,
                name = safeName(preset, "Color " .. tostring(index)),
            }
        end
    end

    table.sort(items, function(a, b)
        if a.index == b.index then return a.name < b.name end
        return a.index < b.index
    end)

    return items, colorPool, featureGroupIndex
end

local function selectedItems(items, selected)
    local result = {}
    for row, item in ipairs(items) do
        if selected[row] then result[#result + 1] = item end
    end
    return result
end

local function selectedCount(selected)
    local count = 0
    for _, value in ipairs(selected) do
        if value then count = count + 1 end
    end
    return count
end

------------------------------------------------------------------------------
-- Single-window Group/Color selector
------------------------------------------------------------------------------

local function displayListLabel(item, checked)
    return string.format("[%s]  %d  %s", checked and "X" or " ", item.index, truncate(item.name, 42))
end

local function showBuilderWindow(preferredDisplay, dataPool, dataPoolIndex, groupItems, colorItems, groupSelected, colorSelected, rebuilding)
    local focusDisplay = preferredDisplay
    local hasOverlay = false
    if focusDisplay ~= nil then pcall(function() hasOverlay = focusDisplay.ScreenOverlay ~= nil end) end
    if not hasOverlay then focusDisplay = GetFocusDisplay() end
    if focusDisplay == nil then focusDisplay = GetDisplayByIndex(1) end
    if focusDisplay == nil then return nil end

    local overlay = focusDisplay.ScreenOverlay
    if overlay == nil then return nil end

    local displayW = tonumber(focusDisplay.W) or 1920
    local displayH = tonumber(focusDisplay.H) or 1080
    local width = math.max(700, math.min(1220, math.floor(displayW * 0.90)))
    local height = math.max(460, math.min(820, math.floor(displayH * 0.88)))

    if width > displayW then width = math.floor(displayW * 0.96) end
    if height > displayH then height = math.floor(displayH * 0.94) end

    local popup = overlay:Append("Popup")
    activePopup = popup
    popup.Name = "AutoColorPickerWindow"
    popup.Columns = 1
    popup.Rows = 3
    popup.W = width
    popup.H = height
    popup.MaxSize = string.format("%d,%d", math.floor(displayW * 0.98), math.floor(displayH * 0.98))
    popup.AlignmentH = "Center"
    popup.AlignmentV = "Center"
    popup.AutoClose = "No"
    popup.CloseOnEscape = "Yes"
    popup[1][1].SizePolicy = "Fixed"
    popup[1][1].Size = "56"
    popup[1][2].SizePolicy = "Stretch"
    popup[1][3].SizePolicy = "Fixed"
    popup[1][3].Size = "70"

    local titleBar = popup:Append("TitleBar")
    titleBar.Anchors = "0,0"
    titleBar.Columns = 3
    titleBar.Rows = 1
    titleBar.Texture = "corner2"
    titleBar[2][2].SizePolicy = "Fixed"
    titleBar[2][2].Size = "220"
    titleBar[2][3].SizePolicy = "Fixed"
    titleBar[2][3].Size = "54"

    local title = titleBar:Append("TitleButton")
    title.Anchors = "0,0"
    title.Text = "AUTO COLOR PICKER"
    title.Texture = "corner1"

    local subTitle = titleBar:Append("Button")
    subTitle.Anchors = "1,0"
    subTitle.Text = string.format("v%s  |  Data Pool %d: %s", VERSION, dataPoolIndex, truncate(safeName(dataPool, "Current"), 20))
    subTitle.Enabled = "No"

    local closeButton = titleBar:Append("CloseButton")
    closeButton.Anchors = "2,0"
    closeButton.Texture = "corner2"

    local content = popup:Append("DialogFrame")
    content.Anchors = "0,1"
    content.Columns = 2
    content.Rows = 1
    content.ExpandContent = "Yes"
    content[1][1].SizePolicy = "Stretch"
    content[2][1].SizePolicy = "Stretch"
    content[2][2].SizePolicy = "Stretch"

    local groupPanel = content:Append("DialogFrame")
    groupPanel.Anchors = "0,0"
    groupPanel.Columns = 1
    groupPanel.Rows = 3
    groupPanel[1][1].SizePolicy = "Fixed"
    groupPanel[1][1].Size = "44"
    groupPanel[1][2].SizePolicy = "Stretch"
    groupPanel[1][3].SizePolicy = "Fixed"
    groupPanel[1][3].Size = "48"

    local groupHeader = groupPanel:Append("Button")
    groupHeader.Anchors = "0,0"
    groupHeader.Text = string.format("GROUPS  |  %d available", #groupItems)
    groupHeader.Enabled = "No"

    local groupList = groupPanel:Append("ScrollableItemList")
    groupList.Anchors = "0,1"
    groupList.Name = "Groups"
    groupList.H = "100%"
    groupList.ContentDriven = "Yes"
    groupList.ForceContentMin = "Yes"
    groupList.AllowBlocks = "No"
    groupList.ItemType = "ListItemButton"
    groupList.ShowLeftIcon = "No"
    groupList.ShowRightIcon = "No"
    groupList.PluginComponent = myHandle
    groupList.OnSelectedItem = SIG_GROUP_TOGGLE

    local groupScroll = groupPanel:Append("ScrollBarV")
    groupScroll.ScrollTarget = groupList
    groupScroll.W = "20"
    groupScroll.ScrollOpposite = "No"
    groupScroll.Visible = "Yes"
    groupScroll.AlignmentH = "Right"

    local groupActions = groupPanel:Append("DialogFrame")
    groupActions.Anchors = "0,2"
    groupActions.Columns = 2
    groupActions.Rows = 1

    local groupAll = groupActions:Append("Button")
    groupAll.Anchors = "0,0"
    groupAll.Text = "Select All"
    groupAll.PluginComponent = myHandle
    groupAll.Clicked = SIG_GROUP_ALL
    groupAll.Texture = "corner2"

    local groupNone = groupActions:Append("Button")
    groupNone.Anchors = "1,0"
    groupNone.Text = "Clear"
    groupNone.PluginComponent = myHandle
    groupNone.Clicked = SIG_GROUP_NONE
    groupNone.Texture = "corner2"

    local colorPanel = content:Append("DialogFrame")
    colorPanel.Anchors = "1,0"
    colorPanel.Columns = 1
    colorPanel.Rows = 3
    colorPanel[1][1].SizePolicy = "Fixed"
    colorPanel[1][1].Size = "44"
    colorPanel[1][2].SizePolicy = "Stretch"
    colorPanel[1][3].SizePolicy = "Fixed"
    colorPanel[1][3].Size = "48"

    local colorHeader = colorPanel:Append("Button")
    colorHeader.Anchors = "0,0"
    colorHeader.Text = string.format("COLOR PRESETS  |  %d available", #colorItems)
    colorHeader.Enabled = "No"

    local colorList = colorPanel:Append("ScrollableItemList")
    colorList.Anchors = "0,1"
    colorList.Name = "Colors"
    colorList.H = "100%"
    colorList.ContentDriven = "Yes"
    colorList.ForceContentMin = "Yes"
    colorList.AllowBlocks = "No"
    colorList.ItemType = "ListItemButton"
    colorList.ShowLeftIcon = "No"
    colorList.ShowRightIcon = "No"
    colorList.PluginComponent = myHandle
    colorList.OnSelectedItem = SIG_COLOR_TOGGLE

    local colorScroll = colorPanel:Append("ScrollBarV")
    colorScroll.ScrollTarget = colorList
    colorScroll.W = "20"
    colorScroll.ScrollOpposite = "No"
    colorScroll.Visible = "Yes"
    colorScroll.AlignmentH = "Right"

    local colorActions = colorPanel:Append("DialogFrame")
    colorActions.Anchors = "0,2"
    colorActions.Columns = 2
    colorActions.Rows = 1

    local colorAll = colorActions:Append("Button")
    colorAll.Anchors = "0,0"
    colorAll.Text = "Select All"
    colorAll.PluginComponent = myHandle
    colorAll.Clicked = SIG_COLOR_ALL
    colorAll.Texture = "corner2"

    local colorNone = colorActions:Append("Button")
    colorNone.Anchors = "1,0"
    colorNone.Text = "Clear"
    colorNone.PluginComponent = myHandle
    colorNone.Clicked = SIG_COLOR_NONE
    colorNone.Texture = "corner2"

    local footer = popup:Append("DialogFrame")
    footer.Anchors = "0,2"
    footer.Columns = 4
    footer.Rows = 1
    footer[2][3].SizePolicy = "Fixed"
    footer[2][3].Size = "150"
    footer[2][4].SizePolicy = "Fixed"
    footer[2][4].Size = "210"

    local summary = footer:Append("Button")
    summary.Anchors = "0,0,1,0"
    summary.Enabled = "No"

    local cancel = footer:Append("Button")
    cancel.Anchors = "2,0"
    cancel.Text = "Close"
    cancel.PluginComponent = myHandle
    cancel.Clicked = SIG_CANCEL
    cancel.Texture = "corner2"

    local build = footer:Append("Button")
    build.Anchors = "3,0"
    build.Text = rebuilding and "Rebuild Picker" or "Build Picker"
    build.PluginComponent = myHandle
    build.Clicked = SIG_BUILD
    build.Texture = "corner2"

    local function refreshList(listHandle, items, selected)
        for row, item in ipairs(items) do
            pcall(function()
                listHandle:SetListItemName(row, displayListLabel(item, selected[row]))
            end)
        end
        pcall(function() listHandle:Changed() end)
    end

    local function refreshSummary()
        local groups = selectedCount(groupSelected)
        local colors = selectedCount(colorSelected)
        local cells = groups * colors
        local elements = cells + groups + colors
        summary.Text = string.format("%d groups x %d colors = %d picker buttons  |  Layout created automatically", groups, colors, cells)
        local enabled = groups > 0 and colors > 0 and elements <= MAX_LAYOUT_ELEMENTS
        build.Enabled = enabled and "Yes" or "No"
        if elements > MAX_LAYOUT_ELEMENTS then
            summary.Text = string.format("Selection creates %d layout elements; grandMA3 limit is %d", elements, MAX_LAYOUT_ELEMENTS)
        end
        pcall(function() summary:Changed() end)
        pcall(function() build:Changed() end)
    end

    pcall(function() content:WaitInit() end)

    for row, item in ipairs(groupItems) do
        groupList:AddListObjectItem(item.handle, displayListLabel(item, groupSelected[row]), {appearance = false})
        if row % 100 == 0 then coroutine.yield({ui = 1}) end
    end
    for row, item in ipairs(colorItems) do
        colorList:AddListObjectItem(item.handle, displayListLabel(item, colorSelected[row]), {appearance = false})
        if row % 100 == 0 then coroutine.yield({ui = 1}) end
    end

    local finished = false
    local action = "cancel"

    signalTable[SIG_GROUP_TOGGLE] = function(caller)
        local row = caller:GetListSelectedItemIndex()
        if row ~= nil and groupItems[row] ~= nil then
            groupSelected[row] = not groupSelected[row]
            caller:SetListItemName(row, displayListLabel(groupItems[row], groupSelected[row]))
            caller:Changed()
            refreshSummary()
        end
    end

    signalTable[SIG_COLOR_TOGGLE] = function(caller)
        local row = caller:GetListSelectedItemIndex()
        if row ~= nil and colorItems[row] ~= nil then
            colorSelected[row] = not colorSelected[row]
            caller:SetListItemName(row, displayListLabel(colorItems[row], colorSelected[row]))
            caller:Changed()
            refreshSummary()
        end
    end

    signalTable[SIG_GROUP_ALL] = function()
        for row = 1, #groupItems do groupSelected[row] = true end
        refreshList(groupList, groupItems, groupSelected)
        refreshSummary()
    end

    signalTable[SIG_GROUP_NONE] = function()
        for row = 1, #groupItems do groupSelected[row] = false end
        refreshList(groupList, groupItems, groupSelected)
        refreshSummary()
    end

    signalTable[SIG_COLOR_ALL] = function()
        for row = 1, #colorItems do colorSelected[row] = true end
        refreshList(colorList, colorItems, colorSelected)
        refreshSummary()
    end

    signalTable[SIG_COLOR_NONE] = function()
        for row = 1, #colorItems do colorSelected[row] = false end
        refreshList(colorList, colorItems, colorSelected)
        refreshSummary()
    end

    signalTable[SIG_BUILD] = function()
        local groups = selectedCount(groupSelected)
        local colors = selectedCount(colorSelected)
        if groups > 0 and colors > 0 and (groups * colors + groups + colors) <= MAX_LAYOUT_ELEMENTS then
            action = "build"
            finished = true
        end
    end

    signalTable[SIG_CANCEL] = function()
        action = "cancel"
        finished = true
    end

    popup:Changed()
    groupList:Changed()
    colorList:Changed()
    refreshSummary()
    coroutine.yield({ui = 2})

    repeat
        coroutine.yield({ui = 1})
        if not isValid(popup) then
            action = "cancel"
            finished = true
        end
    until finished

    clearSignals()
    closePopup()

    if action ~= "build" then return nil end
    return {
        groups = selectedItems(groupItems, groupSelected),
        colors = selectedItems(colorItems, colorSelected),
        groupSelected = groupSelected,
        colorSelected = colorSelected,
    }
end

------------------------------------------------------------------------------
-- Managed resources
------------------------------------------------------------------------------

local function ensureAppearance(name, backR, backG, backB, foregroundColor, undo)
    local showData = ShowData()
    local appearances = showData and showData.Appearances
    if appearances == nil then return nil end

    local appearance = findByName(appearances, name)
    if appearance == nil then
        local index = findFreeSlot(appearances, PREFERRED_RESOURCE_START, 99999)
        if index == nil then return nil end
        appearance = createPoolObject(appearances, "Appearance", index, undo)
        if appearance == nil then return nil end
    end

    setProperty(appearance, "Name", name)
    setProperty(appearance, "BackR", backR)
    setProperty(appearance, "BackG", backG)
    setProperty(appearance, "BackB", backB)
    setProperty(appearance, "BackAlpha", 255)
    setProperty(appearance, "Color", foregroundColor)
    setProperty(appearance, "Note", MANAGED_MARKER)
    return appearance
end

local function isManagedObject(handle)
    local name = safeName(handle, "")
    local note = ""
    pcall(function() note = tostring(handle.Note or "") end)
    return contains(note, MANAGED_MARKER) or startsWith(name, "ACP5 ")
end

local function removeManagedMacros(macros, dataPoolIndex, undo)
    local indexes = {}
    for _, macro in ipairs(safeChildren(macros)) do
        if isManagedObject(macro) then
            local index = safeIndex(macro)
            if index ~= nil then indexes[#indexes + 1] = index end
        end
    end

    table.sort(indexes, function(a, b) return a > b end)
    for _, index in ipairs(indexes) do
        deletePoolObject(macros, "Macro", index, undo, dataPoolIndex)
    end
end

local function clearLayoutChildren(layout, dataPoolIndex, undo)
    local layoutIndex = safeIndex(layout)
    local children = safeChildren(layout)

    for index = #children, 1, -1 do
        local child = children[index]
        local childIndex = safeChildIndex(child)
        local deleted = false

        if childIndex ~= nil then
            deleted = pcall(function() layout:Delete(childIndex, undo) end)
        end

        if not deleted then
            local address = safeAddr(child)
            if address ~= nil then
                Cmd("Delete " .. address .. " /NoConfirmation", undo)
            end
        end
    end

    if #safeChildren(layout) == 0 then return layout end

    -- Fallback: this Layout is plugin-owned, so recreate the pool object in place.
    local dataPool = DataPool()
    local layouts = dataPool and dataPool.Layouts
    if layouts == nil or layoutIndex == nil then return nil end

    deletePoolObject(layouts, "Layout", layoutIndex, undo, dataPoolIndex)
    local replacement = createPoolObject(layouts, "Layout", layoutIndex, undo, dataPoolIndex)
    return replacement
end

local function layoutIsManaged(layout)
    if layout == nil then return false end
    local note = ""
    pcall(function() note = tostring(layout.Note or "") end)
    return contains(note, MANAGED_MARKER)
end

local function findOrCreateManagedLayout(dataPool, dataPoolIndex, prefs, undo)
    local layouts = dataPool and dataPool.Layouts
    if layouts == nil then return nil end

    local prefKey = "LayoutIndex_DP" .. tostring(dataPoolIndex)
    local savedIndex = tonumber(getPref(prefs, prefKey))
    local layout = savedIndex and safeGet(layouts, savedIndex) or nil
    if layout ~= nil and not layoutIsManaged(layout) then layout = nil end

    if layout == nil then
        for _, candidate in ipairs(safeChildren(layouts)) do
            if layoutIsManaged(candidate) then
                layout = candidate
                break
            end
        end
    end

    if layout == nil then
        local layoutName = LAYOUT_BASE_NAME
        local suffix = 2
        while findByName(layouts, layoutName) ~= nil do
            layoutName = string.format("%s %d", LAYOUT_BASE_NAME, suffix)
            suffix = suffix + 1
        end

        local index = findFreeSlot(layouts, 1, 99999)
        if index == nil then return nil end
        layout = createPoolObject(layouts, "Layout", index, undo, dataPoolIndex)
        if layout == nil then return nil end
        setProperty(layout, "Name", layoutName)
    end

    local managedLayoutName = safeName(layout, LAYOUT_BASE_NAME)
    layout = clearLayoutChildren(layout, dataPoolIndex, undo)
    if layout == nil then return nil end

    setProperty(layout, "Name", managedLayoutName)
    setProperty(layout, "Note", MANAGED_MARKER .. " Current Data Pool " .. tostring(dataPoolIndex))
    setProperty(layout, "ViewPosActive", "Yes")
    setPref(prefs, prefKey, safeIndex(layout) or "")
    return layout
end

------------------------------------------------------------------------------
-- Macro and Layout creation
------------------------------------------------------------------------------

local function appendMacroLine(macro, undo)
    local line = nil

    local ok, result = pcall(function() return macro:Append("MacroLine", undo) end)
    if ok then line = result end

    if line == nil then
        ok, result = pcall(function() return macro:Append("MacroLine") end)
        if ok then line = result end
    end

    if line == nil then
        ok, result = pcall(function() return macro:Append() end)
        if ok then line = result end
    end

    return line
end

local function configureMacroLine(line, command)
    if line == nil then return false end

    local commandSet = setProperty(line, "Command", command)
    setProperty(line, "Wait", "Follow")
    setProperty(line, "Enabled", "Yes")
    setFirstProperty(line, {"AddToCmdline", "AddToCmdl"}, "No")
    setProperty(line, "Execute", "Yes")
    return commandSet
end

local function escapeForCommandLine(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub('"', '\\"')
    return text
end

local function configureMacroLineFallback(macroIndex, command, undo)
    local insertResult = Cmd(string.format("Insert Macro %d.1", macroIndex), undo)
    if insertResult ~= "Ok" then
        Cmd("ChangeDestination Macro " .. tostring(macroIndex), undo)
        insertResult = Cmd("Insert", undo)
        Cmd("ChangeDestination Root", undo)
    end

    if insertResult ~= "Ok" then return false end

    local result = Cmd(string.format('Set Macro %d.1 Property "Command" "%s"', macroIndex, escapeForCommandLine(command)), undo)
    Cmd(string.format('Set Macro %d.1 Property "Wait" "Follow"', macroIndex), undo)
    Cmd(string.format('Set Macro %d.1 Property "Enabled" "Yes"', macroIndex), undo)
    Cmd(string.format('Set Macro %d.1 Property "AddToCmdline" "No"', macroIndex), undo)
    Cmd(string.format('Set Macro %d.1 Property "Execute" "Yes"', macroIndex), undo)
    return result == "Ok"
end

local function createCellMacro(macros, macroIndex, macroName, command, idleAppearanceIndex, dataPoolIndex, undo)
    local macro = createPoolObject(macros, "Macro", macroIndex, undo, dataPoolIndex)
    if macro == nil then return nil, "Could not create Macro " .. tostring(macroIndex) end

    setProperty(macro, "Name", truncate(macroName, 60))
    setProperty(macro, "Note", MANAGED_MARKER)
    setProperty(macro, "CLI", "No")

    local line = appendMacroLine(macro, undo)
    local configured = configureMacroLine(line, command)
    if not configured then configured = configureMacroLineFallback(macroIndex, command, undo) end
    if not configured then return nil, "Could not create command line for Macro " .. tostring(macroIndex) end

    local appearanceResult = Cmd(string.format("Assign Appearance %d At DataPool %d Macro %d", idleAppearanceIndex, dataPoolIndex, macroIndex), undo)
    if appearanceResult ~= "Ok" then
        pcall(function() macro.Appearance = safeGet(ShowData().Appearances, idleAppearanceIndex) end)
    end

    return macro, nil
end

local function assignAndLocateElement(objectHandle, layoutHandle, undo)
    local objectAddress = safeAddr(objectHandle)
    local layoutAddress = safeAddr(layoutHandle)
    if objectAddress == nil or layoutAddress == nil then return nil, "Object address unavailable" end

    local before = {}
    for _, child in ipairs(safeChildren(layoutHandle)) do
        local key = handleKey(child)
        if key ~= nil then before[key] = true end
    end

    local result = Cmd("Assign " .. objectAddress .. " At " .. layoutAddress, undo)
    if result ~= "Ok" then return nil, result end

    local assignedKey = handleKey(objectHandle)
    for attempt = 1, 5 do
        local children = safeChildren(layoutHandle)
        for _, child in ipairs(children) do
            local key = handleKey(child)
            if key ~= nil and before[key] ~= true then return child, "Ok" end
        end

        -- Fallback for builds where a Layout child's address is delayed.
        for _, child in ipairs(children) do
            local ok, assigned = pcall(function() return child:GetAssignedObj() end)
            if ok and assigned ~= nil and handleKey(assigned) == assignedKey then
                return child, "Ok"
            end
        end

        if attempt < 5 then yieldUI() end
    end

    return nil, "Assigned, but the new Layout element could not be identified"
end

local function positionElement(element, x, y, width, height, customText, action)
    if element == nil then return false end

    local ok = true
    ok = setProperty(element, "PositionX", x) and ok
    ok = setProperty(element, "PositionY", y) and ok
    ok = setProperty(element, "DimensionW", width) and ok
    ok = setProperty(element, "DimensionH", height) and ok

    if customText ~= nil then setFirstProperty(element, {"CustomText", "Custom Text"}, customText) end
    if action ~= nil then setProperty(element, "Action", action) end
    setFirstProperty(element, {"BorderSize", "Border Size"}, 1)
    return ok
end

local function buildPicker(dataPool, dataPoolIndex, featureGroupIndex, selection, prefs)
    local groups = selection.groups
    local colors = selection.colors
    local groupCount, colorCount = #groups, #colors
    local cellCount = groupCount * colorCount
    local elementCount = cellCount + groupCount + colorCount

    if elementCount > MAX_LAYOUT_ELEMENTS then
        error(string.format("The selected picker needs %d Layout elements; the maximum is %d.", elementCount, MAX_LAYOUT_ELEMENTS))
    end

    local macros = dataPool.Macros
    if macros == nil then error("The current Data Pool does not expose a Macro pool.") end

    if type(CreateUndo) == "function" then
        local undoOk, undoHandle = pcall(CreateUndo, "Auto Color Picker build")
        if undoOk then activeUndo = undoHandle end
    end
    local undo = activeUndo

    startProgress("Auto Color Picker", elementCount + cellCount + 4)
    updateProgress(0, "Preparing resources")
    local progressValue = 0

    local idleAppearance = findByName(ShowData().Appearances, IDLE_APPEARANCE_NAME)
    if idleAppearance == nil then
        idleAppearance = ensureAppearance(IDLE_APPEARANCE_NAME, 24, 26, 30, "0.8500000000,0.8500000000,0.8500000000,1.0000000000", undo)
    end

    local activeAppearance = findByName(ShowData().Appearances, ACTIVE_APPEARANCE_NAME)
    if activeAppearance == nil then
        activeAppearance = ensureAppearance(ACTIVE_APPEARANCE_NAME, 255, 184, 0, "0.0500000000,0.0500000000,0.0500000000,1.0000000000", undo)
    end

    if idleAppearance == nil or activeAppearance == nil then
        error("The plugin could not create its picker Appearances.")
    end

    local idleAppearanceIndex = safeIndex(idleAppearance)
    local activeAppearanceIndex = safeIndex(activeAppearance)
    if idleAppearanceIndex == nil or activeAppearanceIndex == nil then
        error("The plugin could not resolve its Appearance numbers.")
    end

    progressValue = progressValue + 2
    updateProgress(progressValue, "Cleaning previous picker")

    local layout = findOrCreateManagedLayout(dataPool, dataPoolIndex, prefs, undo)
    if layout == nil then error("The plugin could not create its managed Layout.") end
    local layoutIndex = safeIndex(layout)
    if layoutIndex == nil then error("The plugin could not resolve the managed Layout number.") end

    removeManagedMacros(macros, dataPoolIndex, undo)
    progressValue = progressValue + 2
    updateProgress(progressValue)

    local savedBase = tonumber(getPref(prefs, "MacroBase_DP" .. tostring(dataPoolIndex)))
    local preferredBase = savedBase or PREFERRED_MACRO_START
    local macroBase = findContiguousFreeRange(macros, cellCount, preferredBase, 99999)
    if macroBase == nil then
        error(string.format("No contiguous block of %d free Macros is available in the current Data Pool.", cellCount))
    end

    setPref(prefs, "MacroBase_DP" .. tostring(dataPoolIndex), macroBase)
    setPref(prefs, "MacroCount_DP" .. tostring(dataPoolIndex), cellCount)

    updateProgress(nil, "Creating picker Macros")

    local macroMatrix = {}
    for groupRow, group in ipairs(groups) do
        macroMatrix[groupRow] = {}
        local rowStart = macroBase + (groupRow - 1) * colorCount
        local rowEnd = rowStart + colorCount - 1

        for colorColumn, color in ipairs(colors) do
            local macroIndex = rowStart + colorColumn - 1
            local command = string.format(
                "Assign Appearance %d At DataPool %d Macro %d Thru %d; Assign Appearance %d At DataPool %d Macro %d; DataPool %d Group %d At DataPool %d Preset %d.%d",
                idleAppearanceIndex, dataPoolIndex, rowStart, rowEnd,
                activeAppearanceIndex, dataPoolIndex, macroIndex,
                dataPoolIndex, group.index, dataPoolIndex, featureGroupIndex, color.index
            )

            local macroName = string.format("ACP5 %d.%d | %s / %s", group.index, color.index, truncate(group.name, 22), truncate(color.name, 24))
            local macro, macroError = createCellMacro(macros, macroIndex, macroName, command, idleAppearanceIndex, dataPoolIndex, undo)
            if macro == nil then error(macroError) end
            macroMatrix[groupRow][colorColumn] = macro

            progressValue = progressValue + 1
            updateProgress(progressValue)
            if progressValue % 20 == 0 then coroutine.yield({ui = 1}) end
        end
    end

    updateProgress(nil, "Building Layout")

    -- Automatic geometry. The canvas grows with the selection; no tuning needed.
    local cellW = colorCount > 16 and 86 or 104
    local cellH = 72
    local gapX = 8
    local gapY = 8
    local rowLabelW = 170
    local headerH = 52
    local originX = rowLabelW + gapX
    local originY = headerH + gapY

    -- Column headers: the Color presets themselves.
    for colorColumn, color in ipairs(colors) do
        local x = originX + (colorColumn - 1) * (cellW + gapX)
        local y = 0
        local element, result = assignAndLocateElement(color.handle, layout, undo)
        if element == nil then error("Color header failed: " .. tostring(result)) end
        if not positionElement(element, x, y, cellW, headerH, truncate(color.name, 24), "None") then
            error("Color header could not be positioned: " .. color.name)
        end
        progressValue = progressValue + 1
        updateProgress(progressValue)
    end

    -- Row headers: the Groups themselves.
    for groupRow, group in ipairs(groups) do
        local x = 0
        local y = originY + (groupRow - 1) * (cellH + gapY)
        local element, result = assignAndLocateElement(group.handle, layout, undo)
        if element == nil then error("Group header failed: " .. tostring(result)) end
        if not positionElement(element, x, y, rowLabelW, cellH, truncate(group.name, 30), "None") then
            error("Group header could not be positioned: " .. group.name)
        end
        progressValue = progressValue + 1
        updateProgress(progressValue)
    end

    -- Picker cells.
    for groupRow, group in ipairs(groups) do
        for colorColumn, color in ipairs(colors) do
            local x = originX + (colorColumn - 1) * (cellW + gapX)
            local y = originY + (groupRow - 1) * (cellH + gapY)
            local macro = macroMatrix[groupRow][colorColumn]
            local element, result = assignAndLocateElement(macro, layout, undo)
            if element == nil then error("Picker cell failed: " .. tostring(result)) end
            if not positionElement(element, x, y, cellW, cellH, truncate(color.name, 24), nil) then
                error(string.format("Picker cell could not be positioned: %s / %s", group.name, color.name))
            end
            progressValue = progressValue + 1
            updateProgress(progressValue)
            if progressValue % 20 == 0 then coroutine.yield({ui = 1}) end
        end
    end

    local totalWidth = originX + colorCount * cellW + math.max(0, colorCount - 1) * gapX
    local totalHeight = originY + groupCount * cellH + math.max(0, groupCount - 1) * gapY
    setProperty(layout, "PositionX", 0)
    setProperty(layout, "PositionY", 0)
    setProperty(layout, "DimensionW", totalWidth)
    setProperty(layout, "DimensionH", totalHeight)
    setProperty(layout, "Note", string.format("%s %d groups x %d colors, built by v%s", MANAGED_MARKER, groupCount, colorCount, VERSION))

    setPref(prefs, "Groups_DP" .. tostring(dataPoolIndex), serializeSelected(selection.allGroups, selection.groupSelected))
    setPref(prefs, "Colors_DP" .. tostring(dataPoolIndex), serializeSelected(selection.allColors, selection.colorSelected))
    setPref(prefs, "LastVersion", VERSION)

    stopProgress()
    closeUndo()

    -- Select/call the Layout so any Layout Viewer that follows selection updates immediately.
    Cmd(string.format("DataPool %d Layout %d", dataPoolIndex, layoutIndex))
    if type(SelectionNotifyObject) == "function" then pcall(SelectionNotifyObject, layout) end
    Printf("Auto Color Picker v%s ready: Data Pool %d, Layout %d, %d groups x %d colors.", VERSION, dataPoolIndex, layoutIndex, groupCount, colorCount)

    return layoutIndex, groupCount, colorCount
end

------------------------------------------------------------------------------
-- Main
------------------------------------------------------------------------------

local function Main(displayHandle, argument)
    local ok, errorMessage = xpcall(function()
        pcall(function() Cmd("ChangeDestination Root") end)

        local dataPool = DataPool()
        if dataPool == nil then error("No current Data Pool is available.") end

        local dataPoolIndex = safeIndex(dataPool) or 1
        local groups = collectGroups(dataPool)
        local colors, colorPool, featureGroupIndex = collectColorPresets(dataPool)

        if #groups == 0 then
            showAlert("Auto Color Picker", "No non-empty Groups were found in the current Data Pool.")
            return
        end
        if colorPool == nil or featureGroupIndex == nil or #colors == 0 then
            showAlert("Auto Color Picker", "No non-empty Color presets were found in the current Data Pool.")
            return
        end

        local prefs = getPrefs()
        local groupSelected = restoreSelection(groups, getPref(prefs, "Groups_DP" .. tostring(dataPoolIndex)))
        local colorSelected = restoreSelection(colors, getPref(prefs, "Colors_DP" .. tostring(dataPoolIndex)))

        local existingLayout = nil
        local savedLayoutIndex = tonumber(getPref(prefs, "LayoutIndex_DP" .. tostring(dataPoolIndex)))
        if savedLayoutIndex ~= nil then
            existingLayout = safeGet(dataPool.Layouts, savedLayoutIndex)
            if not layoutIsManaged(existingLayout) then existingLayout = nil end
        end

        local selection = showBuilderWindow(
            displayHandle,
            dataPool,
            dataPoolIndex,
            groups,
            colors,
            groupSelected,
            colorSelected,
            existingLayout ~= nil
        )
        if selection == nil then return end

        selection.allGroups = groups
        selection.allColors = colors
        buildPicker(dataPool, dataPoolIndex, featureGroupIndex, selection, prefs)
    end, debug.traceback)

    clearSignals()
    closePopup()
    stopProgress()
    closeUndo()
    pcall(function() Cmd("ChangeDestination Root") end)

    if not ok then
        local message = tostring(errorMessage or "Unknown error")
        ErrPrintf("Auto Color Picker v%s: %s", VERSION, message)
        showAlert("Auto Color Picker - Build Failed", message)
    end
end

local function Cleanup()
    clearSignals()
    closePopup()
    stopProgress()
    closeUndo()
end

return Main, Cleanup

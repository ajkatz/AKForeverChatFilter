-- Stand-in for the WoW client, enough to run AKForeverChatFilter under a plain Lua interpreter. Same
-- design as the other addons' mocks. What it models of Blizzard's side:
--
--  * chat: ChatFrameUtil.AddMessageEventFilter as this build's ChatFrameFilters.lua has it - the callback
--    is skipped when any of the line's values is secret (canaccessvalue), its first result discards the
--    line, and every chat window that shows the channel runs the filters for the same line, with the same
--    line id. Mock.chat(...) sends a line through it and tells whether the windows showed it;
--  * frames, buttons, font strings and a scrolling message frame, as far as the window uses them;
--  * events, one-shot timers, the slash command table, saved variables, the clock;
--  * secret values: chosen values can be made secret.
--
-- The addon's files run in an environment with the game's Lua 5.1 table library (no table.unpack, a
-- global unpack), so that a 5.4-only call fails here before it fails in the game.
-- Not loaded by the game (not in the .toc).
local Mock = {}

local REAL_PRINT = print
local unpack = table.unpack or unpack
local ADDON = "AKForeverChatFilter"

Mock.SECRET = setmetatable({}, { __tostring = function() return "<SECRET>" end })

local function isSecret(value)
    return value == Mock.SECRET
end

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
local methods = {}
local newWidget

function methods.GetObjectType(self) return self.__kind end
function methods.SetSize(self, w, h) self.__width, self.__height = w, h end
function methods.SetWidth(self, w) self.__width = w end
function methods.SetHeight(self, h) self.__height = h end
function methods.GetWidth(self) return self.__width or 0 end
function methods.GetHeight(self) return self.__height or 0 end
function methods.SetPoint(self, point, relativeTo, relativePoint, x, y)
    if type(relativeTo) == "number" then
        relativeTo, relativePoint, x, y = self.__parent, point, relativeTo, relativePoint
    end
    self.__points[#self.__points + 1] = { point, relativeTo, relativePoint or point, x or 0, y or 0 }
end
function methods.ClearAllPoints(self) self.__points = {} end
function methods.GetPoint(self, index)
    local p = self.__points[index or 1]
    if p then
        return p[1], p[2], p[3], p[4], p[5]
    end
end
function methods.Show(self) self.__shown = true end
function methods.Hide(self) self.__shown = false end
function methods.SetShown(self, shown) self.__shown = shown and true or false end
function methods.IsShown(self) return self.__shown end
function methods.SetParent(self, parent) self.__parent = parent end
function methods.GetParent(self) return self.__parent end
function methods.GetName(self) return self.__name end
function methods.SetFrameStrata(self, s) self.__strata = s end
function methods.SetClampedToScreen(self, c) self.__clamped = c end
function methods.SetMovable(self, m) self.__movable = m end
function methods.EnableMouse(self, e) self.__mouse = e end
function methods.EnableMouseWheel(self, e) self.__wheel = e end
function methods.RegisterForDrag(self, ...) self.__drag = { ... } end
function methods.StartMoving(self) self.__moving = true end
function methods.StopMovingOrSizing(self) self.__moving = false end
function methods.SetScript(self, name, fn) self.__scripts[name] = fn end
function methods.GetScript(self, name) return self.__scripts[name] end
function methods.SetBackdrop(self, backdrop) self.__backdrop = backdrop end
function methods.SetBackdropColor(self, r, g, b, a) self.__backdropColor = { r, g, b, a } end
function methods.SetText(self, t) self.__text = t end
function methods.SetAutoFocus(self, a) self.__autoFocus = a end
function methods.SetMaxLetters(self, n) self.__maxLetters = n end
function methods.SetFocus(self) self.__focused = true end
function methods.ClearFocus(self) self.__focused = false end
function methods.HasFocus(self) return self.__focused == true end
function methods.GetText(self) return self.__text end
function methods.SetJustifyH(self, j) self.__justify = j end
function methods.SetJustifyV(self, j) self.__justifyV = j end
function methods.SetWordWrap(self, w) self.__wrap = w end
function methods.SetFontObject(self, f) self.__font = f end
function methods.Enable(self) self.__enabled = true end
function methods.Disable(self) self.__enabled = false end
function methods.IsEnabled(self) return self.__enabled ~= false end
function methods.SetFading(self, f) self.__fading = f end
function methods.SetMaxLines(self, n) self.__maxLines = n end
function methods.SetIndentedWordWrap(self, w) self.__indented = w end
function methods.SetHyperlinksEnabled(self, e) self.__hyperlinks = e end
function methods.AddMessage(self, text) self.__messages[#self.__messages + 1] = text end
function methods.Clear(self) self.__messages = {} end
function methods.ScrollUp(self) self.__scrolled = (self.__scrolled or 0) - 1 end
function methods.ScrollDown(self) self.__scrolled = (self.__scrolled or 0) + 1 end
function methods.ScrollToBottom(self) self.__scrolled = 0 end
function methods.GetNumMessages(self) return #self.__messages end
function methods.RegisterEvent(self, event)
    self.__events[event] = true
end
function methods.UnregisterEvent(self, event)
    self.__events[event] = nil
end
function methods.CreateFontString(self, name, layer, font)
    local fs = newWidget("FontString", name, self)
    fs.__font = font
    return fs
end

function newWidget(kind, name, parent)
    local w = setmetatable({
        __kind = kind, __name = name, __parent = parent, __points = {}, __scripts = {}, __events = {},
        __shown = true, __messages = {}, __children = {},
    }, { __index = methods })
    if parent and parent.__children then
        parent.__children[#parent.__children + 1] = w
    end
    if name then
        _G[name] = w
    end
    Mock.frames[#Mock.frames + 1] = w
    return w
end

------------------------------------------------------------------------
-- Install: a fresh client
------------------------------------------------------------------------
function Mock.install(options)
    options = options or {}
    Mock.frames = {}
    Mock.printed = {}
    Mock.timers = {}
    Mock.filters = {}
    Mock.state = {
        now = 1000, clock = 1700000000, secretApis = {}, lineID = 100,
        windows = {}, -- the chat windows and what they showed
    }
    local state = Mock.state

    for name in pairs(Mock.globals or {}) do
        _G[name] = nil
    end
    local G = {}
    local function global(name, value)
        G[name] = value
        _G[name] = value
    end
    Mock.globals = G

    global("print", function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        Mock.printed[#Mock.printed + 1] = table.concat(parts, " ")
    end)
    global("issecretvalue", isSecret)
    global("GetTime", function() return state.now end)
    global("time", function() return state.clock end)
    global("date", function(format, t)
        if format == "%H:%M" then
            return "12:34"
        end
        return "2026-09-30 12:34:56"
    end)
    global("InCombatLockdown", function() return false end)
    global("geterrorhandler", function() return function(err) Mock.errors[#Mock.errors + 1] = err end end)
    global("C_AddOns", { GetAddOnMetadata = function() return options.version or "0.1.0-test" end })
    global("GetBuildInfo", function() return "1.60.1", "70009", "Sep 23 2026", 16001 end)
    global("UnitFullName", function() return "Purrdee", "ClassicBetaPvE" end)
    global("UnitName", function() return "Purrdee" end)
    global("GetRealmName", function() return "Classic Beta PvE" end)
    global("SlashCmdList", {})
    global("BackdropTemplateMixin", {})
    global("TOOLTIP_DEFAULT_BACKGROUND_COLOR", { r = 0.09, g = 0.09, b = 0.19 })
    global("ChatFontNormal", { name = "ChatFontNormal" })
    global("ChatFontSmall", { name = "ChatFontSmall" })
    global("GameFontHighlightSmall", { name = "GameFontHighlightSmall" })
    global("CreateFrame", function(kind, name, parent, template)
        local w = newWidget(kind, name, parent)
        w.__template = template
        if template == "UIPanelButtonTemplate" or template == "UIPanelCloseButton" then
            w.__enabled = true
        end
        if template ~= "BackdropTemplate" then
            -- only the template brings the backdrop methods; the addon checks before it calls them
            w.SetBackdrop, w.SetBackdropColor = nil, nil
        end
        return w
    end)
    global("C_Timer", { After = function(seconds, fn)
        Mock.timers[#Mock.timers + 1] = { at = state.now + seconds, fn = fn }
    end })
    Mock.errors = {}

    global("UIParent", newWidget("Frame", "UIParent"))

    -- the chat windows: two show Trade, the third General only
    local function chatWindow(name, channels)
        local w = newWidget("Frame", name)
        w.__channels, w.__lines = channels, {}
        state.windows[#state.windows + 1] = w
        return w
    end
    chatWindow("ChatFrame1", { trade = true, general = true })
    chatWindow("ChatFrame2", { trade = true })
    chatWindow("ChatFrame3", { general = true })

    -- this build's message event filter registry, as ChatFrameFilters.lua has it: a callback is skipped
    -- when any value of the line is secret, and its first result discards the line
    local filtersByEvent = {}
    local function canaccess(...)
        for i = 1, select("#", ...) do
            if isSecret((select(i, ...))) then
                return false
            end
        end
        return true
    end
    local function addFilter(event, callback)
        filtersByEvent[event] = filtersByEvent[event] or {}
        table.insert(filtersByEvent[event], callback)
        Mock.filters[#Mock.filters + 1] = event
    end
    local function process(chatFrame, event, ...)
        for _, callback in ipairs(filtersByEvent[event] or {}) do
            if canaccess(...) then
                local discard = callback(chatFrame, event, ...)
                if discard then
                    return true
                end
            end
        end
        return false
    end
    Mock.processFilters = process
    if options.noFilterApi then
        -- a client with neither API
    elseif options.legacyFilterApi then
        global("ChatFrame_AddMessageEventFilter", addFilter)
    else
        global("ChatFrameUtil", { AddMessageEventFilter = addFilter, ProcessMessageEventFilters = process })
    end

    if options.db then
        global("AKForeverChatFilterDB", options.db)
    else
        global("AKForeverChatFilterDB", nil)
    end

    -- the addon's files, in the TOC's order, in a 5.1-shaped environment
    local ns = {}
    local root = options.root or "."
    local gameTable = {}
    for key, value in pairs(table) do
        gameTable[key] = value
    end
    gameTable.unpack, gameTable.pack = nil, nil
    local gameEnv = setmetatable({ table = gameTable, unpack = table.unpack }, {
        __index = _G,
        __newindex = function(_, key, value)
            _G[key] = value
        end,
    })
    for _, file in ipairs({ "Core.lua", "Terms.lua", "Rules.lua", "Filter.lua", "Review.lua", "Diagnostics.lua" }) do
        local chunk, err = loadfile(root .. "/" .. file, "t", gameEnv)
        if not chunk then
            error(err)
        end
        chunk(ADDON, ns)
    end
    Mock.ns = ns
    return ns, state
end

------------------------------------------------------------------------
-- Events and time
------------------------------------------------------------------------
function Mock.fire(event, ...)
    for _, frame in ipairs(Mock.frames) do
        if frame.__events[event] and frame.__scripts.OnEvent then
            frame.__scripts.OnEvent(frame, event, ...)
        end
    end
end

function Mock.login()
    Mock.fire("ADDON_LOADED", ADDON)
    Mock.fire("PLAYER_LOGIN")
end

function Mock.advance(seconds)
    local state = Mock.state
    state.now = state.now + seconds
    state.clock = state.clock + seconds
    local due = {}
    for index = #Mock.timers, 1, -1 do
        if Mock.timers[index].at <= state.now then
            table.insert(due, 1, table.remove(Mock.timers, index))
        end
    end
    for _, timer in ipairs(due) do
        timer.fn()
    end
end

function Mock.nextFrame()
    Mock.advance(0)
end

------------------------------------------------------------------------
-- Chat: one line through the client's filters into every window that shows the channel
------------------------------------------------------------------------
-- opts: text, sender ("Bob"), channel ("trade" | "general" | a custom name), secret (a field name to
-- make secret: "text" | "sender" | "lineID"). Returns shown (true when the windows showed it), lineID.
function Mock.chat(opts)
    local state = Mock.state
    state.lineID = state.lineID + 1
    local kind = opts.channel or "trade"
    local zoneID, baseName
    if kind == "trade" then
        zoneID, baseName = 2, "Trade - City"
    elseif kind == "general" then
        zoneID, baseName = 1, "General - Durotar"
    elseif kind == "LocalDefense" then
        zoneID, baseName = 22, "LocalDefense - Orgrimmar" -- (a channel of the game's own: it has a number)
    else
        zoneID, baseName = 0, kind
    end
    local text, sender, lineID = opts.text, opts.sender or "Bob", state.lineID
    if opts.secret == "text" then text = Mock.SECRET end
    if opts.secret == "sender" then sender = Mock.SECRET end
    if opts.secret == "lineID" then lineID = Mock.SECRET end
    local index = (zoneID > 0 and zoneID < 10) and zoneID or 5
    local channelName = index .. ". " .. baseName
    local args = { text, sender, "Common", channelName, "", "", zoneID, index, baseName, 0, lineID, "Player-1-000ABC" }
    -- the event, to every frame that listens (the addon counts these)
    Mock.fire("CHAT_MSG_CHANNEL", unpack(args, 1, 12))
    local shown = false
    for _, window in ipairs(state.windows) do
        if window.__channels[kind] or (kind ~= "trade" and kind ~= "general" and window.__channels.general) then
            local discard = Mock.processFilters(window, "CHAT_MSG_CHANNEL", unpack(args, 1, 12))
            if not discard then
                window.__lines[#window.__lines + 1] = text
                shown = true
            end
        end
    end
    return shown, lineID
end

function Mock.shownIn(windowName)
    return _G[windowName].__lines
end

------------------------------------------------------------------------
-- Clicks
------------------------------------------------------------------------
function Mock.click(button)
    local fn = button.__scripts.OnClick
    if fn then
        fn(button, "LeftButton")
    end
end

-- type into an edit box and press Enter
function Mock.enter(editBox, text)
    editBox.__text = text
    local fn = editBox.__scripts.OnEnterPressed
    if fn then
        fn(editBox)
    end
end

function Mock.clickLink(frame, link, mouseButton)
    local fn = frame.__scripts.OnHyperlinkClick
    if fn then
        fn(frame, link, link, mouseButton or "LeftButton")
    end
end

Mock.realPrint = REAL_PRINT

return Mock

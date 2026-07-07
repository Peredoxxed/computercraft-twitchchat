-- twitchchat.lua
local mon = peripheral.find("monitor")
mon.setTextScale(0.5)
local w, h = mon.getSize()
 
local ws = nil
local currentChannel = nil
local line = 1
 
-- === CC 16-color palette (approx RGB) for nearest-match lookup ===
local ccPalette = {
    {colors.white,     0xF0F0F0},
    {colors.orange,    0xF2B233},
    {colors.magenta,   0xE57FD8},
    {colors.lightBlue, 0x99B2F2},
    {colors.yellow,    0xDEDE6C},
    {colors.lime,      0x7FCC19},
    {colors.pink,      0xF2B2CC},
    {colors.lightGray, 0x999999},
    {colors.cyan,      0x4C99B2},
    {colors.purple,    0xB266E5},
    {colors.blue,      0x3366CC},
    {colors.green,     0x57A64E},
    {colors.red,       0xCC4C4C},
	-- Black and grey have been deleted because they can't be seen on CC monitors
}
 
-- Twitch's default fallback palette for users with no custom color set
local twitchDefaultColors = {
    "#FF0000","#0000FF","#00FF00","#B22222","#FF7F50",
    "#9ACD32","#FF4500","#2E8B57","#DAA520","#D2691E",
    "#5F9EA0","#1E90FF","#FF69B4","#8A2BE2","#00FF7F"
}
 
local function hexToColor(hex)
    local r = tonumber(hex:sub(2,3), 16)
    local g = tonumber(hex:sub(4,5), 16)
    local b = tonumber(hex:sub(6,7), 16)
    if not r or not g or not b then return colors.white end
 
    local best, bestDist = colors.white, math.huge
    for _, entry in ipairs(ccPalette) do
        local pr = bit32.band(bit32.rshift(entry[2], 16), 0xFF)
        local pg = bit32.band(bit32.rshift(entry[2], 8), 0xFF)
        local pb = bit32.band(entry[2], 0xFF)
 
        -- weighted distance: green matters most, then red, then blue
        local dr, dg, db = r-pr, g-pg, b-pb
        local dist = (dr*dr)*2 + (dg*dg)*4 + (db*db)*3
 
        if dist < bestDist then
            bestDist = dist
            best = entry[1]
        end
    end
    return best
end
 
local function fallbackColor(username)
    local hash = 0
    for i = 1, #username do
        hash = (hash + username:byte(i)) % #twitchDefaultColors
    end
    return twitchDefaultColors[hash + 1]
end
 
local function getUserColor(tags, username)
    local hex = tags["color"]
    if not hex or hex == "" then
        hex = fallbackColor(username)
    end
    return hexToColor(hex)
end
 
-- === Monitor helpers ===
local function clearMon()
    mon.clear()
    mon.setCursorPos(1,1)
    line = 1
end
 
local function newLine()
    if line > h then
        mon.scroll(1)
        line = h
    end
    mon.setCursorPos(1, line)
end
 
local function printLine(text)
    newLine()
    mon.setTextColor(colors.white)
    mon.write(text)
    line = line + 1
end
 
local function getBadges(tags)
    local badges = {}
    if tags["badges"] and tags["badges"]:find("broadcaster") then
        table.insert(badges, {letter = "H", color = colors.red})
    end
    if tags["mod"] == "1" then
        table.insert(badges, {letter = "M", color = colors.green})
    end
    if tags["subscriber"] == "1" then
        table.insert(badges, {letter = "S", color = colors.purple})
    end
    return badges
end
 
-- writes badges (colored), then colored name, then white message text, wrapping as needed
local function printChat(tags, badges, name, text)
    newLine()
 
    for _, b in ipairs(badges) do
        mon.setTextColor(b.color)
        mon.write(b.letter)
    end
    if #badges > 0 then
        mon.setTextColor(colors.white)
        mon.write(" ")
    end
 
    mon.setTextColor(getUserColor(tags, name))
    mon.write(name .. ": ")
 
    mon.setTextColor(colors.white)
    local full = text
    while #full > 0 do
        local avail = w - select(1, mon.getCursorPos()) + 1
        if avail <= 0 then
            line = line + 1
            newLine()
            avail = w
        end
        local chunk = full:sub(1, avail)
        mon.write(chunk)
        full = full:sub(avail + 1)
        if #full > 0 then
            line = line + 1
            newLine()
        end
    end
    line = line + 1
end
 
-- === Tag parsing ===
local function parseTags(tagString)
    local tags = {}
    for pair in tagString:gmatch("[^;]+") do
        local k, v = pair:match("([^=]+)=(.*)")
        if k then tags[k] = v end
    end
    return tags
end
 
-- === Connection handling ===
local function joinChannel(channel)
    if ws then
        ws.close()
        ws = nil
    end
 
    local newWs, err = http.websocket("wss://irc-ws.chat.twitch.tv:443")
    if not newWs then
        print("Connection failed: " .. tostring(err))
        return
    end
 
    newWs.send("CAP REQ :twitch.tv/tags")
    newWs.send("NICK justinfan" .. math.random(10000,99999))
    newWs.send("JOIN #" .. channel)
 
    ws = newWs
    currentChannel = channel
    clearMon()
    printLine("== Watching #" .. channel .. " ==")
    print("Now watching: " .. channel)
end
 
local function chatLoop()
    while true do
        if ws then
            local msg = ws.receive()
            if msg then
                if msg:find("PING") then
                    ws.send("PONG :tmi.twitch.tv")
                else
                    local tagString, rest = msg:match("^@(.-) :(.*)$")
                    if tagString and rest and currentChannel then
                        local tags = parseTags(tagString)
                        local user, text = rest:match("(%w+)!.-PRIVMSG #" .. currentChannel .. " :(.*)")
                        if user and text then
                            local displayName = tags["display-name"]
                            if not displayName or displayName == "" then displayName = user end
                            printChat(tags, getBadges(tags), displayName, text)
                        end
                    end
                end
            end
        else
            os.pullEvent("channel_switch")
        end
    end
end
 
local function commandLoop()
    print("Commands: 'watch <channel>' to switch, 'stop' to disconnect")
    while true do
        write("> ")
        local input = read()
        local cmd, arg = input:match("^(%S+)%s*(.*)$")
        if cmd == "watch" and arg ~= "" then
            joinChannel(arg:lower())
            os.queueEvent("channel_switch")
        elseif cmd == "stop" then
            if ws then ws.close(); ws = nil end
            currentChannel = nil
            print("Disconnected.")
        else
            print("Unknown command. Try: watch <channel>")
        end
    end
end
 
parallel.waitForAny(chatLoop, commandLoop)

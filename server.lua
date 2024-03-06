local function a(b)
    local c
    if _CC_VERSION then
        c = b <= _CC_VERSION
    elseif not _HOST then
        c = b <= os.version():gsub("CraftOS ", "")
    elseif _HOST:match("ComputerCraft 1%.1%d+") ~= b:match("1%.1%d+") then
        b = b:gsub("(1%.)([02-9])", "%10%2")
        local d = _HOST:gsub("(ComputerCraft 1%.)([02-9])", "%10%2")
        c = b <= d:match("ComputerCraft ([0-9%.]+)")
    else
        c = b <= _HOST:match("ComputerCraft ([0-9%.]+)")
    end
    assert(c, "This program requires ComputerCraft " .. b .. " or later.")
end
a "1.85.0"
local e = "wss://remote.craftos-pc.cc/"
if not string.pack then
    if not fs.exists("string_pack.lua") then
        --print("Downloading string.pack polyfill...")
        local f, g = http.get(e:gsub("^ws", "http") .. "string_pack.lua")
        if not f then
            error("Could not download string.pack polyfill: " .. g)
        end
        local h, g = fs.open(".system/string_pack.lua", "w")
        if not h then
            f.close()
            error("Could not open string_pack.lua for writing: " .. g)
        end
        h.write(f.readAll())
        f.close()
        h.close()
    end
    local i = dofile "string_pack.lua"
    for j, k in pairs(i) do
        string[j] = k
    end
end
local l
if not fs.exists("rawterm.lua") or fs.getSize("rawterm.lua") ~= (31339) then
    --print("Downloading rawterm API...")
    local f, g = http.get(e:gsub("^ws", "http") .. "rawterm.lua")
    if not f then
        error("Could not download rawterm API: " .. g)
    end
    local m = f.readAll()
    f.close()
    if fs.getFreeSpace("/") >= #m + 4096 then
        local h, g = fs.open(".system/rawterm.lua", "w")
        if not h then
            error("Could not open rawterm.lua for writing: " .. g)
        end
        h.write(m)
        h.close()
    else
        l = assert(load(m, "@rawterm.lua", "t"))()
    end
end
l = l or dofile "rawterm.lua"
local n, o = ...
--print("Connecting to " .. e .. "...")
local p, g = l.wsDelegate(e .. n, {["X-Rawterm-Is-Server"] = "Yes"})
if not p then
    error("Could not connect to server: " .. g)
end
local q, r, s = p.close, p.receive, p.send
local t = true
function p:close()
    t = false
    return q(self)
end
function p:receive(...)
    if not t then
        return nil
    end
    local u, c, v = ""
    repeat
        repeat
            c = table.pack(pcall(r, self, ...))
        until not (not c[1] and c[2]:match("Terminated$"))
        if not c[1] then
            error(c[2])
        elseif not c[2] then
            return nil
        end
        if not v then
            v = tonumber(c[2]:match "!CPC(%x%x%x%x)" or c[2]:match("!CPD(" .. ("%x"):rep(12) .. ")") or "", 16)
        end
        if v then
            u = u .. c[2]:gsub("\n", "")
        end
    until v and #u >= v + 16 + (u:match "^!CPD" and 8 or 0)
    return u .. "\n"
end
function p:send(m)
    if t then
        for w = 1, #m, 65530 do
            s(self, m:sub(w, math.min(w + 65529, #m)))
        end
    end
end
local x, y = term.getSize()
local z =
    l.server(
    p,
    x,
    y,
    0,
    "ComputerCraft Remote Terminal: " .. (os.computerLabel() or "Computer " .. os.computerID()),
    term.current()
)
z.setVisible(false)
local A, B = {}, {[0] = true}
local C = peripheral.call
for w, k in ipairs {peripheral.find "monitor"} do
    local D, E = k.getSize()
    local F = peripheral.getName(k)
    local G = peripheral.getMethods(F)
    local H = {}
    for I, k in ipairs(G) do
        H[k] = function(...)
            return C(F, k, ...)
        end
    end
    A[F] = {id = w, win = l.server(p, D, E, w, "ComputerCraft Remote Terminal: Monitor " .. F, H, nil, nil, nil, true)}
    A[F].win.setVisible(false)
    B[w] = true
end
function peripheral.call(J, K, ...)
    if A[J] then
        return A[J].win[K](...)
    else
        return C(J, K, ...)
    end
end
local L = term.redirect(z)
local M, N
M, g =
    pcall(
    parallel.waitForAny,
    function()
        local O = coroutine.create(shell.run)
        local M, P = coroutine.resume(O, o or (settings.get("bios.use_multishell") and "multishell" or "shell"))
        while M and coroutine.status(O) == "suspended" do
            local Q = {}
            local R = {function()
                    Q = table.pack(z.pullEvent(P, true, true))
                end}
            for j, k in pairs(A) do
                R[#R + 1] = function()
                    Q = table.pack(k.win.pullEvent(P, true, true))
                    if Q[1] == "mouse_click" then
                        Q = {"monitor_touch", j, Q[3], Q[4]}
                    elseif Q[1] == "mouse_up" or Q[1] == "mouse_drag" or Q[1] == "mouse_scroll" or Q[1] == "mouse_move" then
                        Q = {}
                    end
                end
            end
            R[#R + 1] = function()
                repeat
                    Q = table.pack(os.pullEventRaw(P))
                until not (Q[1] == "websocket_message" and Q[2] == e .. n) and not (Q[1] == "timer" and Q[2] == N)
            end
            parallel.waitForAny(table.unpack(R))
            if Q[1] then
                M, P = coroutine.resume(O, table.unpack(Q, 1, Q.n))
            end
        end
        if not M then
            g = P
        end
    end,
    function()
        while t do
            z.setVisible(true)
            z.setVisible(false)
            for I, k in pairs(A) do
                k.win.setVisible(true)
                k.win.setVisible(false)
            end
            N = os.startTimer(0.05)
            repeat
                local Q, H = os.pullEventRaw("timer")
            until H == N
        end
    end,
    function()
        while true do
            local Q, J = os.pullEventRaw()
            if Q == "peripheral" and peripheral.getType(J) == "monitor" and not A[J] then
                local S = #B + 1
                local D, E = C(J, "getSize")
                local G = peripheral.getMethods(J)
                for I, k in ipairs(G) do
                    G[k] = true
                end
                local H =
                    setmetatable(
                    {},
                    {__index = function(I, T)
                            if G[T] then
                                return function(...)
                                    return C(J, T, ...)
                                end
                            end
                        end}
                )
                A[J] = {
                    id = S,
                    win = l.server(p, D, E, S, "ComputerCraft Remote Terminal: Monitor " .. J, H, nil, nil, nil, true)
                }
                A[J].win.setVisible(false)
                B[S] = true
            elseif Q == "peripheral_detach" and A[J] then
                A[J].win.close(true)
                B[A[J].id] = nil
                A[J] = nil
            elseif Q == "term_resize" then
                z.reposition(nil, nil, term.getSize())
            elseif Q == "monitor_resize" and A[J] then
                A[J].win.reposition(nil, nil, C(J, "getSize"))
            elseif Q == "websocket_closed" and J == e .. n then
                t = false
            end
        end
    end
)
term.redirect(L)
for I, k in pairs(A) do
    k.win.close(true)
end
z.close()
peripheral.call = C
shell.run("clear")
if type(g) == "string" and not g:match("attempt to use closed file") then
    printError(g)
end

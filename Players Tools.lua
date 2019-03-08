-- Player Tools - useful tools to get information about players.
-- Copyright (C) 2019  Ranx

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

script_name('Players Tools')
script_author('Ranx')
script_description('Useful tools to get information about players')
script_version('1.1.0-alpha')

require 'lib.moonloader'
require 'lib.sampfuncs'

local inicfg = require 'inicfg'
local useInspect, inspect = pcall(require, 'lib.inspect')

local pMarkers = {}
local cfgPath = 'playertools.ini'

-- Default config
local cfg = {
    detector = {
        state = true,
        interval = 2500,
        disconnectOnDetect = false,
        trackOnDetect = false,
    },
    detectingPlayers = {},
}

-- Possible implementation: replace `markers` with `currentTODPlayers`

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    cfg = inicfg.load(cfg, cfgPath)

    sampRegisterChatCommand('pthelp', cmdPTHelp)
    sampRegisterChatCommand('ptreload', cmdPTReload)
    sampRegisterChatCommand('det', cmdDet)
    sampRegisterChatCommand('undet', cmdUndet)
    sampRegisterChatCommand('detectlist', cmdDetectList)
    sampRegisterChatCommand('dod', cmdDod)
    sampRegisterChatCommand('tod', cmdTod)
    sampRegisterChatCommand('track', cmdTrack)
    sampRegisterChatCommand('si', cmdSI)
    if useInspect then
        sampRegisterChatCommand('dbgm', function() sampAddChatMessage(string.format('Markers: {AAAAAA}%s', inspect(pMarkers, {newline = '', indent = ''})), 0xEADE3A) end)
    end

    while true do
        local instreamChars = getAllChars()
        if cfg.detector.state and sampIsLocalPlayerSpawned() then
            for _, pHandle in pairs(instreamChars) do
                local result, pId = sampGetPlayerIdByCharHandle(pHandle)
                if result then
                    local pName = sampGetPlayerNickname(pId)
                    if arrayContains(cfg.detectingPlayers, pName) then
                        if cfg.detector.trackOnDetect and not setContains(pMarkers, pHandle) then
                            track(pHandle)
                        end
                        if cfg.detector.disconnectOnDetect then
                            sampDisconnectWithReason(0)
                        end
                        printStringNow(string.format('~r~WARNING! ~y~%s[%d]~r~ detected!', pName, pId), 2000)
                    end
                end
            end
        end
        -- Clean tracking players, that got out of stream
        for pHandle, pMarker in pairs(pMarkers) do
            if not arrayContains(instreamChars, pHandle) then
                removeBlip(pMarker)
                -- sampAddChatMessage(string.format('Marker {DBD76F}%d{AAAAAA} removed {DB816F}by GC', pMarker), 0xAAAAAA)
                pMarkers[pHandle] = nil
            end
        end
        wait(cfg.detector.interval)
    end
end

function cmdDet(params)
    if string.len(params) > 0 then
        local pName = getPlayerNameByParams(params)
        if not pName then
            printStringNow('~r~Wrong player ID/name', 1500)
            return
        end
        if not arrayContains(cfg.detectingPlayers, pName) then
            cfg.detectingPlayers[#cfg.detectingPlayers + 1] = pName
            inicfg.save(cfg, cfgPath)
            printStringNow(string.format('~w~Added ~b~%s', pName), 1500)
        else
            printStringNow('~w~Already in detect list', 1500)
        end
    else
        cfg.detector.state = not cfg.detector.state
        inicfg.save(cfg, cfgPath)
        printStringNow(string.format('Detect %s', cfg.detector.state and '~g~activated' or '~r~deactived'), 1500)
    end
end

function cmdUndet(params)
    local pName = getPlayerNameByParams(params)
    if not pName then
        printStringNow('~r~Wrong player ID/name', 1500)
        return
    end
    if not arrayContains(cfg.detectingPlayers, pName) then
        printStringNow('~w~Not in detect list', 1500)
    else
        for index, value in ipairs(cfg.detectingPlayers) do
            if value == pName then
                table.remove(cfg.detectingPlayers, index)
            end
        end
        inicfg.save(cfg, cfgPath)
        printStringNow(string.format('~w~Removed ~b~%s', pName), 1500)
    end
end

function cmdDetectList()
    sampShowDialog(
        1337763,
        string.format('{43C7CF}Detect List{AAAAAA} - %d player(s)', #cfg.detectingPlayers),
        table.concat(cfg.detectingPlayers, '\n'),
        'Close',
        '',
        DIALOG_STYLE_LIST
    )
end

function cmdDod()
    cfg.detector.disconnectOnDetect = not cfg.detector.disconnectOnDetect
    inicfg.save(cfg, cfgPath)
    printStringNow(string.format('DOD %s', cfg.detector.disconnectOnDetect and '~g~activated' or '~r~deactived'), 1500)
end

function cmdTod()
    cfg.detector.trackOnDetect = not cfg.detector.trackOnDetect
    inicfg.save(cfg, cfgPath)
    printStringNow(string.format('TOD %s', cfg.detector.trackOnDetect and '~g~activated' or '~r~deactived'), 1500)
end

function cmdTrack(params)
    if string.len(params) > 0 then
        local pId = string.match(params, '%d+')
        local result, pHandle = sampGetCharHandleBySampPlayerId(pId)
        if not result then
            printStringNow('~r~Player not found', 1500)
            return
        end
        track(pHandle)
        printStringNow(string.format('~w~Tracking ~b~%s', sampGetPlayerNickname(pId)), 1500)
    elseif next(pMarkers) ~= nil then
        for pHandle, pMarker in pairs(pMarkers) do
            removeBlip(pMarker)
            -- sampAddChatMessage(string.format('Marker {DBD76F}%d{AAAAAA} removed {DB816F}by /track', pMarker), 0xAAAAAA)
            pMarkers[pHandle] = nil
        end
        printStringNow('~r~Tracking stopped', 1500)
    else
        printStringNow('~w~Using: /track <id>', 1500)
    end
end

function cmdSI()
    if not sampIsLocalPlayerSpawned() then
        printStringNow('~r~You are not spawned!', 1500)
        return
    end
    local data = {}
    for _, pHandle in pairs(getAllChars()) do
        local result, pId = sampGetPlayerIdByCharHandle(pHandle)
        if result then
            local pName = sampGetPlayerNickname(pId)
            local pColor = string.format('%06X', bitAnd(0xFFFFFF, sampGetPlayerColor(pId)))
            data[#data + 1] = string.format('{%s}%s [%d]', pColor, pName, pId)
        end
    end
    sampShowDialog(
        1337762,
        string.format('{43C7CF}Stream Info{AAAAAA} - %d player(s)', #data),
        table.concat(data, '\n'),
        'Close',
        '',
        DIALOG_STYLE_LIST
    )
end

function cmdPTHelp()
    local helpText =
    [[
{4DA6FF}/pthelp{66FF66} - помощь по скрипту
{4DA6FF}/ptreload{66FF66} - перезагрузить настройки
{4DA6FF}/det <id/nickname>{66FF66} - детектировать игрока
{4DA6FF}/undet <id/nickname>{66FF66} - перестать детектировать игрока
{4DA6FF}/detectlist{66FF66} - список детектируемых игроков
{4DA6FF}/dod{66FF66} - отключиться при нахождении игрока
{4DA6FF}/tod{66FF66} - отслеживать игрока при нахождении
{4DA6FF}/track <id>{66FF66} - отследить игрока (поставить на него метку)
    {FFCC66}Для удаления всех меток используйте /track без параметров
{4DA6FF}/si{66FF66} - список игроков в зоне прорисовки]]
    sampShowDialog(1337761, '{FFCC00}Player Tools', helpText, 'Закрыть', '', DIALOG_STYLE_MSGBOX)
end

function cmdPTReload()
    cfg = inicfg.load(cfg, cfgPath)
    printStringNow('~w~Config reloaded', 1500)
end

function track(pHandle)
    local pMarker = addBlipForChar(pHandle)
    changeBlipColour(pMarker, bit.tobit(0xFF00FFFF))
    pMarkers[pHandle] = pMarker
    return pMarker
end

-- Utility functions
-- =================

function getPlayerNameByParams(params)
    local pId = tonumber(params)
    if pId == nil then
        return string.len(params) > 0 and params or nil
    elseif sampIsPlayerConnected(pId) then
        return sampGetPlayerNickname(pId)
    else
        return nil
    end
end

function isKeyCheckAvailable()
	if not isSampLoaded() then
		return true
	end
	return not sampIsChatInputActive() and not sampIsDialogActive() and not (isSampfuncsLoaded and isSampfuncsConsoleActive())
end

function arrayContains(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function setContains(set, key)
    return set[key] ~= nil
end

function bitAnd(a, b)
    local result = 0
    local bitVal = 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then -- test the rightmost bits
            result = result + bitVal      -- set the current bit
        end
        bitVal = bitVal * 2 -- shift left
        a = math.floor(a / 2) -- shift right
        b = math.floor(b / 2)
    end
    return result
end

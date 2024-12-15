ESX = exports['es_extended']:getSharedObject() 

local webhookURL = "https://discord.com/api/webhooks/1317904224797065267/gnksOWbtztoOrgUR18gTXy72LxWbsSKZT5jLapOFhGLDcrbS6H-kY7WDMG4ydNx8LtPu" 

function sendToDiscord(title, description, color)
    local embed = {
        {
            title = title,
            description = description,
            color = color,
            footer = {
                text = os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }
    PerformHttpRequest(webhookURL, function(err, text, headers) end, 'POST', json.encode({ username = "AddCar Logger", embeds = embed }), { ['Content-Type'] = 'application/json' })
end

function getDiscordIdentifier(player)
    local identifiers = GetPlayerIdentifiers(player)
    for _, id in pairs(identifiers) do
        if id:match("^discord:(%d+)") then
            return "<@" .. id:match("^discord:(%d+)") .. ">"
        end
    end
    return "<@Neznámo>"
end

RegisterCommand('addcar', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer.getGroup() ~= 'admin' and xPlayer.getGroup() ~= 'owner' then
        TriggerClientEvent('okokNotify:Alert', source, "Error", "Nemáš oprávnění použít tento příkaz!", 5000, 'error')
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        TriggerClientEvent('okokNotify:Alert', source, "Error", "Zadej platné server ID hráče!", 5000, 'error')
        return
    end

    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        TriggerClientEvent('okokNotify:Alert', source, "Error", "Hráč s tímto ID není online!", 5000, 'error')
        return
    end

    local vehicle = GetVehiclePedIsIn(GetPlayerPed(source), false)
    if vehicle == 0 then
        TriggerClientEvent('okokNotify:Alert', source, "Error", "Nejsi v žádném vozidle!", 5000, 'error')
        return
    end

    local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
    local model = GetEntityModel(vehicle) 
    local vehicleData = json.encode({ model = model, plate = plate })

    local identifier = targetPlayer.getIdentifier()
    MySQL.Async.fetchScalar('SELECT 1 FROM owned_vehicles WHERE owner = @owner AND plate = @plate', {
        ['@owner'] = identifier,
        ['@plate'] = plate
    }, function(result)
        if result then
            TriggerClientEvent('okokNotify:Alert', source, "Error", "Toto vozidlo už je v garáži tohoto hráče!", 5000, 'error')
        else
            MySQL.Async.execute('INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (@owner, @plate, @vehicle)', {
                ['@owner'] = identifier,
                ['@plate'] = plate,
                ['@vehicle'] = vehicleData
            }, function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerClientEvent('okokNotify:Alert', source, "Success", "Vozidlo bylo úspěšně přidáno do garáže!", 5000, 'success')
                    
                    local adminDiscordID = getDiscordIdentifier(xPlayer.source)
                    local targetDiscordID = getDiscordIdentifier(targetPlayer.source)

                    local plateLog = string.format(
                        "**Admin Discord:** %s\n\n**Target Discord:** %s\n\n**SPZ:** %s\n\n**Vozidlo:** %s",
                        adminDiscordID, targetDiscordID, plate, model
                    )
                    sendToDiscord("AddCar Akce", plateLog, 65280)

                else
                    TriggerClientEvent('okokNotify:Alert', source, "Error", "Nepodařilo se přidat vozidlo do garáže!", 5000, 'error')
                end
            end)
        end
    end)
end, false)

ESX.RegisterServerCallback('esx:getPlayerGroup', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    cb(xPlayer.getGroup())
end)

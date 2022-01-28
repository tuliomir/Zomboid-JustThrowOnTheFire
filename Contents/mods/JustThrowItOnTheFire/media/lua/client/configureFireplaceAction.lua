require 'Camping/ISUI/ISCampingMenu'
require 'Camping/CCampfireSystem'

-- This function calculats the amount of fuel in each item inside the container
-- If the "removeFuelItems" parameter is passed, it means the fuel items must also be removed from container
local function getContainerFuelAmount(container, removeFuelItems)
    local items = container:getItems()
    local totalFuel = 0

    -- Since we may remove items, we must iterate the list backwards
    -- Otherwise we would have an array out of index exception
    for i=items:size()-1, 0, -1 do
        local item = items:get(i)
        local itemFuel = ISCampingMenu.getFuelDurationForItem(item)
        -- print("Fuel for " .. item:getName() .. ": " .. itemFuel)
        
        -- Only if this item has a fuel value, we add it to the result
        if itemFuel ~= nil then
            totalFuel = totalFuel + itemFuel

            -- We informed a removeFuelItems parameter. Remove the items.
            if removeFuelItems ~= nil then
                container:Remove(item)
            end
        end
    end

    return totalFuel
end

local function getZombieInventoriesAroundPlayer(playerNumber)
    local inventoryList = {}

    -- TODO: these direct member references are bad; is there an interface to get what I need here?
    local availableBackpacks = getPlayerLoot(playerNumber).inventoryPane.inventoryPage.backpacks
    local totalFuel = 0

    local currentIndex = 1
    for i,backpack in ipairs(availableBackpacks) do
        local inventory = backpack.inventory
        local inventoryType = inventory:getType()

        -- In case this is a zombie inventory
        if (inventoryType == "inventorymale" or inventoryType == "inventoryfemale") then
            local zombieFuelObj = {
                inventory = backpack.inventory,
                fuelAmt = 0
            }
            zombieFuelObj.fuelAmt = getContainerFuelAmount(backpack.inventory)
            totalFuel = totalFuel + zombieFuelObj.fuelAmt
            inventoryList[currentIndex] = zombieFuelObj
            currentIndex = currentIndex + 1
        end
    end

    local returnTable = { 
        zombiesFound = currentIndex-1,
        zombiesInventories = inventoryList, 
        totalFuel = totalFuel 
    }
    return returnTable
end

local function addFuelCallback(worldobjects, container, campfire, playerNumber)
    -- Get the amount of fuel that will be added
    local fuelAmt = getContainerFuelAmount(container, campfire)

    -- Build a command to add fuel. Code extacted from ISAddFuelAction
    local args = { x = campfire.x, y = campfire.y, z = campfire.z, fuelAmt = fuelAmt }
    local playerObj = getSpecificPlayer(playerNumber)
    CCampfireSystem.instance:sendCommand(playerObj, 'addFuel', args)
end

local function kickZombiesIntoFireCallback(worldobjects, zombieInventories, playerNumber)

end

-- This function will be run at Events.OnFillWorldObjectContextMenu , basically at any right button
-- click on the game. It must be fast to identify if it is not needed and return.
ISWorldObjectContextMenu.AssignExpressFuelingAction = function(playerNumber, context, worldobjects, test)
    local container = nil

    -- Iterating all worldobjects to find the one that has a container
    for _,containerIsoObj in ipairs(worldobjects) do
        container = containerIsoObj:getItemContainer()
        if container ~= nil then
            break
        end
    end

    -- If no container was found, do nothing
    if container == nil then 
        return
    end

    -- We are only interested in this container if its parent IsoObject is a Campfire.
    local parentIsoObj = container:getParent()
    if (not CCampfireSystem:isValidIsoObject(parentIsoObj)) then
        return
    end

    -- Retrieving the actual Campfire instance
    ISCampingMenu.campfire = CCampfireSystem.instance:getLuaObjectOnSquare(parentIsoObj:getSquare())
    local campfire = ISCampingMenu.campfire
    local fuelAmount = campfire.fuelAmt
    local fuelToAdd = getContainerFuelAmount(container)

    -- If there is no fuel to add, no need to mess with the Context Menu
    if fuelToAdd == 0 then return end

    -- Add the "add fuel" option to the Context Menu ( todo: translate this )
    local friendlyAmount = ""
    if fuelToAdd > 60 then
        friendlyAmount = "about " .. math.floor(fuelToAdd/60) .. " hours"
    else
        friendlyAmount = fuelToAdd .. " minutes"
    end
    -- Add a tooltip with better information about the fuel, improve this label
    local labelToShow = "Add " .. friendlyAmount .. " of fuel from container"
    context:addOption(labelToShow, worldobjects, addFuelCallback, container, campfire, playerNumber)
end
Events.OnFillWorldObjectContextMenu.Add(ISWorldObjectContextMenu.AssignExpressFuelingAction)

ISWorldObjectContextMenu.AssignKickZombiesIntoCampfireAction = function (playerNumber, context, worldobjects)
    local zombieFuelObj = getZombieInventoriesAroundPlayer(playerNumber, {})
    local amountOfZombies = zombieFuelObj.zombiesFound

    if amountOfZombies == 0 then
        return -- No zombies found. Do nothing.
    end

    local totalFuel = zombieFuelObj.totalFuel
    local labelToShow = "Found " .. amountOfZombies .. " zombies: " .. totalFuel
    context:addOption(labelToShow, worldobjects, nil)
end
Events.OnFillWorldObjectContextMenu.Add(ISWorldObjectContextMenu.AssignKickZombiesIntoCampfireAction)
if not Config.BossManagedOutfits then return end

if not Management.IsQBX() then return end

function Management.AddItems()
    if GetResourceState(Management.ResourceName) ~= "started" then return end
    if Management.ItemIDs.Boss and Management.ItemIDs.Gang then return end
    local menuItem = {
        title = _L("outfitManagement.title"),
        icon = "fa-solid fa-shirt",
        event = "illenium-appearance:client:OutfitManagementMenu",
        args = {}
    }
    menuItem.description = _L("outfitManagement.jobText")
    menuItem.args.type = "Job"
    Management.ItemIDs.Boss = exports[Management.ResourceName]:AddBossMenuItem(menuItem)

    menuItem.description = _L("outfitManagement.gangText")
    menuItem.args.type = "Gang"
    Management.ItemIDs.Gang = exports[Management.ResourceName]:AddGangMenuItem(menuItem)
end

-- Re-register when Qbox management starts or restarts independently.
AddEventHandler("onClientResourceStart", function(resource)
    if resource ~= "qbx_management" then return end

    Management.ItemIDs.Boss = nil
    Management.ItemIDs.Gang = nil
    Management.AddItems()
end)
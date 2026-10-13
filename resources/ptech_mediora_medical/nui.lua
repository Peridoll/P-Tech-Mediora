-- Stand-alone resource: no shared NUI host required.
function MedicalNuiSend(_, data)
    SendNUIMessage({ action = data.action, data = data.data })
end

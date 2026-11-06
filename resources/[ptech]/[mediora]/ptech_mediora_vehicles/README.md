# ptech_mediora_vehicles

Medical vehicle systems and the vehicle assets that use them. Shared systems live in `main/`; each vehicle's model data and features live in `assets/<asset-id>/`.

## Included

- Automatically grant the configured EMS vehicle key when an EMS employee takes its driver seat.
- Show GPS blips for configured vehicles to players who hold that vehicle's key, and hide the blip for the vehicle the player is currently using.
- Configure rear vehicle callouts in the vehicle asset that provides the callout vehicle. The current Blazer asset allows the `ambulance` model as a carrier.
- Record Blazer deployment in JG Advanced Garages' outside-vehicle tracking when that resource is running.
- Open an ox_inventory shop from the rear of configured vehicles. This remains disabled until the vehicle asset defines its stock and prices.
- Moor the EMS Blazer in water and disable its weapon while driven.
- Report driving, fuel and repair activity through a server-side event for a future Core aggregator.

## Add a vehicle asset

Create `assets/<asset-id>/config.lua` and assign a `VehicleAssets.<asset-id>` table. Add each model to `models`; the shared systems use these entries to build model and hash lookups at resource start. To let a vehicle call out the Blazer, add its model name to `assets/ptech_ems_blazer/config.lua` under `callout.carrierModels`.

Vehicle model names are spawn names. Keep custom names namespaced (for example, `pemsblazer`) so they do not replace a base-game model.

## Activity event for Core

Vehicles emits a local server event after a validated activity report:

```lua
AddEventHandler('ptech_mediora_vehicles:server:activity', function(source, record)
    -- record.type: vehicle_drive_meters | vehicle_fuel_added | vehicle_repaired
    -- record.citizenid, record.plate, record.amount, record.unit, record.timestamp
end)
```

The event is intentionally local to the server. Core should subscribe and aggregate it; this resource does not write ranking data or maintain a leaderboard. Medical treatment activity belongs to the medical workflow and should be sent by that resource to Core.

## External integrations and open items

- JG Advanced Garages tracks Blazers spawned by this resource as outside vehicles. Normal garage checkout/store actor history must be added through the garage's configured hooks; it cannot be inferred from this resource.
- Transfer discounts are configured in JG Advanced Garages v4, outside this resource. Set the EMS rate in that resource's settings.
- The trunk shop implementation is ready, but stock and prices need to be supplied in the vehicle asset config before it becomes available.
- Core is not included in this repository version, so activity aggregation and rankings need the Core-side listener.

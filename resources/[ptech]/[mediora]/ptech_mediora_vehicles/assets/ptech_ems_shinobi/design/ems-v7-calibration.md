# Shinobi v7 calibration — 2026-11-14

User screenshots show the actual pems_shinobi with coarse and fine diagnostic liveries.

Observed mapping:
- Left fairing: F02/F03 at middle height, G02/G03/G04 towards the belly.
- Right fairing: C02/C03 and B02/B03/B04, with text inverted in the atlas. Branding is rotated 180 degrees on this side.
- The diagonal black trim / panel break crosses the previous wide logo footprint. The new compact mark occupies x=278..540, left y=1395..1469 and right y=579..653.
- The diagnostic body wrap does not cover the box marking panel; it uses its separate chassis mod texture.

v7 design:
- White base, red lower fairings rising toward the rear, thin black boundary.
- Original supplied logo retained, reduced and shifted towards the front of the side fairing.
- White tank with narrow red sweeps; red tail and subdued supplied dragon motif.
- Box marking changed to red with white EMS and a medical star.

These are screenshot-based placement estimates, not a recovered mesh UV template. The updated logo boundary, tank seam and tail placement require an in-game check from both sides.

Runtime update files, relative to ptech_mediora_vehicles:
- stream/mods/liveries/pems_shinobi_livery_ems.yft
- stream/mods/liveries/pems_shinobi_box_ems.yft

Existing coarse/fine diagnostic choices and command remain unchanged. Use /pemsuv off then /pemslivery to select the EMS body and box mods. Resource/server refresh and client asset reload may be needed to see replaced streamed files. No remote operation was performed for v7.
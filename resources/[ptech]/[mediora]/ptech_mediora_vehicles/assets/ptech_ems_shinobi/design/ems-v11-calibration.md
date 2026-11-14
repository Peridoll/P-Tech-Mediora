# v11 — 2026-11-14

The new overhead fine-grid screenshot (codex-clipboard-5b381d5e-de92-4d70-8871-374555f6cf21.png) identifies E14 on the tail. E14 covers atlas x=1664..1792 and y=512..640. The prior x>=1280,y>=1024 tail guess was incorrect. The red field now covers E14 and its neighboring tail cells; the old field is removed. The border of the full island is still estimated from screenshots, not an extracted main-model UV mesh.

The main side graphics and medical-star artwork are unchanged for comparison. Box geometry uses vehicle_badges (name/file hashes confirmed), intended for vehicle badges according to https://docs.sollumz.org/documentation/fragments.yft/vehicle-shaders . For the washed-out red, this iteration reduces specularIntensityMult from 1 to 0.12 and specularFresnel from 0.75 to 0.08. This is an appearance trial, not a confirmed fix; no shader-type swap was performed.

Runtime files: stream/mods/liveries/pems_shinobi_livery_ems.yft and stream/mods/liveries/pems_shinobi_box_ems.yft.
Backups: backups/shinobi-before-v11-20261114.
No WinSCP, remote, manifest, command or qbx_core changes.
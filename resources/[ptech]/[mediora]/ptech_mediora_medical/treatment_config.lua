TreatmentConfig = {
 -- Only plans and read-only examination catalogue. Patient mutation disabled until Wasabi adapter verified.
 Examinations = {
  xray = { label = 'X線', suggestedFor = { 'fracture', 'blunt_trauma' }, duration = 7000 },
  ultrasound = { label = '超音波検査', suggestedFor = { 'internal_injury' }, duration = 8000 },
 },
 Treatments = {
  bandage = { label = '包帯処置', item = 'bandage', suggestedFor = { 'bleeding' } },
  immobilize = { label = '固定処置', item = 'splint', suggestedFor = { 'fracture' } },
 },
}

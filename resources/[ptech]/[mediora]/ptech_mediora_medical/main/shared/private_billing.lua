-- 個人医専用の請求。EMSのカルテ請求とは独立。
Config.PrivateBilling = {
    Job = 'private_medic',
    RequireDuty = true,
    ManagerGrade = 1, -- 現行の「代表」。統括のランクを変更する場合はここを変更。
    DefaultAmount = 1200000,
    MaxAmount = 100000000,
    Bonus = 3600000,
    Distance = 3.0,
    PaymentPollMs = 15000,
    HistoryCommand = 'privatebonus',
}

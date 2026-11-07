Config = {}

Config.Tablet = {
    item = 'pmediora_tablet',
    -- Optional dedicated permission; existing Qbox admin/god ACEs also work.
    adminAce = 'mediora.admin',
    adminAces = { 'admin', 'god' },
}

Config.Points = {
    identifier = 'ptech_mediora_work_points',
    label = 'Mediora Points',
    abbreviation = 'MP',

    -- The ACE permission command.mediorapoints is required.
    manualGrantCommand = 'mediorapoints',

    -- Maximum points accepted in a single grant or spend.
    maxChangePerTransaction = 1000000,
}

Config.DutyTracking = {
    -- Add the job names whose on-duty time should be tracked.
    jobs = {
        ambulance = true,
    },

    -- Save the current duty session at this interval, in seconds.
    saveIntervalSeconds = 60,
}

Config.ActivityTracking = {
    -- Maximum length of activity metric keys sent by other resources.
    maxKeyLength = 64,

    -- Maximum value accepted in one activity record.
    maxAmount = 1000000,
}

Config.ActionPanel = {
    switchKey = 'Z',
}

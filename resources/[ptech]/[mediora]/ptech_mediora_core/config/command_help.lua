-- Suggestions use FiveM's chat events; add compatible custom chat resource names here.
Config.CommandHelp = {
    enabled = true,
    chatResources = { 'chat' },
    commands = {
        {
            name = 'mediorahelp',
            help = 'Mediora Coreのコマンド一覧と使い方を確認します。',
            usage = '/mediorahelp [コマンド名]',
            example = '/mediorahelp mediora_tablet_close',
            params = {
                { name = 'コマンド名', help = '省略すると一覧を表示。指定すると使い方と例を表示します。' },
            },
        },
        {
            name = 'mediora_tablet_close',
            help = '開いているMedioraタブレットを閉じます。',
            usage = '/mediora_tablet_close',
            example = '/mediora_tablet_close',
            params = {},
        },
        {
            name = Config.Points.manualGrantCommand,
            ace = 'command.' .. Config.Points.manualGrantCommand,
            help = '指定したプレイヤーにMPを付与します（管理権限が必要）。',
            usage = '/' .. Config.Points.manualGrantCommand .. ' [プレイヤーID] [MP数] [理由]',
            example = '/' .. Config.Points.manualGrantCommand .. ' 12 100 業務実績への付与',
            params = {
                { name = 'プレイヤーID', help = '付与先のサーバーID（整数）。例: 12' },
                { name = 'MP数', help = '1〜' .. Config.Points.maxChangePerTransaction .. 'の整数。例: 100' },
                { name = '理由', help = '付与理由（必須）。例: 業務実績への付与。空白を含む文章も入力できます。' },
            },
        },
    },
}

Config = {
    TabletItem = 'ptech_ems_tablet',

    Home = {
        Title = 'EMSManager',
        Wallpaper = 'assets/mediora-wallpaper.svg',
    },

    -- 治療画面中央に、近くにいる患者本人を映すローカルカメラ。
    -- MaxDistanceは医療者と患者の距離。患者の位置や姿勢は変更しない。
    PatientView = {
        MaxDistance = 3.0,
        CameraDistance = 2.7,
        FieldOfView = 45.0,
    },
}

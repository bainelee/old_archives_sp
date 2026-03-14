# Figma Topbar UI 图片下载脚本
# 从 Figma Desktop localhost 下载图片，按组件分类存放，命名清洗
# 前置：Figma Desktop 已打开设计、MCP 使用 Local server 模式

$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:3845/assets"
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$assetsRoot = Join-Path $projectRoot "assets"

# 命名清洗：去掉结尾 " 数字"，handel→handle
function Clean-Name($raw) {
    $name = $raw -replace '\s+\d+$', ''
    $name = $name -replace '^handel_', 'handle_'
    return $name
}

# 按组件分类
function Get-AssetFolder($cleanedName) {
    if ($cleanedName -match '^background_topbar|^delimiter_topbar') { return "ui/topbar" }
    if ($cleanedName -match '^background_corrosion_number|^corrosion_number') { return "ui/corrosion_number" }
    if ($cleanedName -match '^background_corrosion_forecast|^handle_|^forecast_warning_sign') { return "ui/forecast_warning" }
    if ($cleanedName -match '^button_') { return "ui/buttons" }
    if ($cleanedName -match '^icon_pause|^icon_goon') { return "ui/buttons" }
    if ($cleanedName -match '^progress_|^icon_frame_|^animation_icon_') { return "ui/resource_block" }
    if ($cleanedName -match '^icon_') { return "icons" }
    return "ui/misc"
}

# URL -> (cleanedName, folder) 映射（从 design context 提取，去重）
$assets = @(
    @{ hash = "c1e705858f46dcd788babc6bf430b15ce925f8ec"; raw = "background_topbar_1 1" },
    @{ hash = "8da487812c12d1054e3cc3d739f894a6976be4d8"; raw = "background_topbar1_side 1" },
    @{ hash = "88556d92f02b223436c64e991da90339dbfd8997"; raw = "background_corrosion_number 1" },
    @{ hash = "23345b87212a3b49944c6090fccd5e184b71e02c"; raw = "corrosion_number_plus_sign 1" },
    @{ hash = "7d8831934fa9d110a46776dba3db1b856d9db3dd"; raw = "corrosion_number_minus_sign 1" },
    @{ hash = "6e0a7b93571c7eb64b6b772f9fab618acb6d23cf"; raw = "corrosion_number_4 1" },
    @{ hash = "11959b91627d4ca6d896650596bcd61be0a29a60"; raw = "corrosion_number_5 2" },
    @{ hash = "fd3fb5c478008ee8c6e8ddfd4ffe4be9e9ad3c36"; raw = "corrosion_number_6 1" },
    @{ hash = "be820c0f88756e57d968008e51cf0e0e977d010f"; raw = "corrosion_number_7 1" },
    @{ hash = "536fa15d1a45bc3a874289db1b951e61dfc66867"; raw = "corrosion_number_8 1" },
    @{ hash = "daf81b55c3af9e82c07c6149af33880e4054b15a"; raw = "corrosion_number_9 2" },
    @{ hash = "d15213e97a94788aa72a3bf8144ed78f1666e3f5"; raw = "button_48x32_disabled 1" },
    @{ hash = "9bb33d27e290483edbe2d772ada256023a6902b6"; raw = "button_48x32_nor 1" },
    @{ hash = "9db464ee7723a8eccd121dbbf71f81619ecbe1db"; raw = "button_48x32_press 1" },
    @{ hash = "b752f1f53986699c624e77d53092704088982ab8"; raw = "icon_pause_28x28 1" },
    @{ hash = "26e97be0ac7060816365f83b8a268e769f6709f5"; raw = "icon_goon_28x28 1" },
    @{ hash = "76349401fd423c007f3ad3d3da713b9015c5c9c4"; raw = "icon_goon_3x_28x28 1" },
    @{ hash = "175754b18c610ded85df62213b3907a8cabf3657"; raw = "icon_goon_2x_28x28 1" },
    @{ hash = "c0a1e90f50157b92eae1ffdbc0e1aeafe273c996"; raw = "button_48x32_hover 1" },
    @{ hash = "0499a709757bfc7529114f946bd7883fb9567a9f"; raw = "background_corrosion_forecast 1" },
    @{ hash = "e4afaa5ff58421d0c1504beb730a98f3b83b250c"; raw = "handel_green 1" },
    @{ hash = "594611a96909b0643b7c30c45ee19b999940bbf8"; raw = "forecast_warning_sign_green 1" },
    @{ hash = "1abfcd2473e93feee38100ba28c52df78b3b043e"; raw = "handel_blue 1" },
    @{ hash = "8825fffd8a22764e9978ef17d7b387a4c83f630a"; raw = "handel_orange 1" },
    @{ hash = "d947b5f18570f959caa46fe1f5b1dfbc8a43907f"; raw = "handel_purple 1" },
    @{ hash = "9ab6bab96138ef51cd461c4ffae6c8ba8753ff77"; raw = "handel_red 1" },
    @{ hash = "08eafbc0c130083a4abfa6170bf87c6827178547"; raw = "forecast_warning_sign_red 1" },
    @{ hash = "f6bfafd755af371a50f409a95595edc144f66f92"; raw = "background_topbar_0" },
    @{ hash = "40d405eb45277f86c6ed9f71039a5864f59a030c"; raw = "delimiter_topbar 1" },
    @{ hash = "0ff89fda9a5f4d98ccd61c75c0f0bda4dc2bb007"; raw = "icon_frame_base_32x32" },
    @{ hash = "ecc91ffc8933899ea96c99dfc5b68db1e9d57da3"; raw = "icon_truth 1" },
    @{ hash = "f154dc7a4fb46ce8d033e3493c7dd7cedeab7b25"; raw = "icon_investigator 1" },
    @{ hash = "8fdda574fefa5ff6660e8ecd0fa264067510c987"; raw = "icon_infomation" },
    @{ hash = "a96d351f721ecdd95831761d62ce90559f008cfa"; raw = "progress_back 1" },
    @{ hash = "6ef47a6cd21353f340e4929b2f9fb5392806309f"; raw = "progress_inside 1" },
    @{ hash = "65e32a2074868709ab324642e628f3ad894d9140"; raw = "icon_willpower" },
    @{ hash = "e45052c1a7f1977659ffcb327a849c09da30d44b"; raw = "icon_permission" },
    @{ hash = "a767ec774261b9f172557b594212b09824643a4f"; raw = "background_topbar1_mid 1" },
    @{ hash = "71c3483b59d6abc803ef0f5224d20b5c77487fbc"; raw = "icon_frame_blue_32x32 1" },
    @{ hash = "838ef5b78a31e5245c81ea36a294ee4abec2e51f"; raw = "icon_computing_power_white 1" },
    @{ hash = "d97bbd0ac67a5040dcb03cc3acee684baacce7e7"; raw = "icon_shelter_white 1" },
    @{ hash = "57be072f6dc35fb1b7c4efa90e548a24b63578a0"; raw = "animation_icon_convert_to_nor 1" },
    @{ hash = "308438979c6930b8f253c56f53e5126d6f133fce"; raw = "icon_cognition" },
    @{ hash = "4e0ddacad38066b1bb0553d236d053db19ae611e"; raw = "progress_back_long 1" },
    @{ hash = "ae05f26155176c2679143187368f07adcede2318"; raw = "icon_researcher" },
    @{ hash = "6bd07c295bd2701d7c82dfe375bf8997f9a68e55"; raw = "icon_house 1" },
    @{ hash = "898405e5ddbe86d163a0e6db3c4a3ade0efa6c70"; raw = "button_press_36x36" },
    @{ hash = "43c641b843916a624da9a4055b09268dc4a18cf5"; raw = "button_disabled_36x36" },
    @{ hash = "861580489537cbc445da1f3f72c2b7ef8f21bd9e"; raw = "button_nor_36x36" },
    @{ hash = "d85038792428c3b6bc58cb4adf2ab04e12e47cae"; raw = "icon_questions" },
    @{ hash = "7caa0a627de9fc376379db52d11083e90d5fe694"; raw = "icon_settings" }
)

# 创建目录
$folders = @("ui/topbar", "ui/corrosion_number", "ui/forecast_warning", "ui/buttons", "ui/resource_block", "ui/misc", "icons")
foreach ($f in $folders) {
    $dir = Join-Path $assetsRoot $f
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null; Write-Host "Created $dir" }
}

$downloaded = 0
foreach ($a in $assets) {
    $cleaned = Clean-Name $a.raw
    $folder = Get-AssetFolder $cleaned
    $dir = Join-Path $assetsRoot $folder
    $outPath = Join-Path $dir "$cleaned.png"
    $url = "$baseUrl/$($a.hash).png"

    try {
        Invoke-WebRequest -Uri $url -OutFile $outPath -UseBasicParsing
        Write-Host "OK $folder/$cleaned.png"
        $downloaded++
    } catch {
        Write-Warning "FAIL $url -> $outPath : $_"
    }
}

Write-Host "`nDownloaded $downloaded / $($assets.Count) assets"

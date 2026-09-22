Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$DefaultX = 0.714
$DefaultY = 0.900
$DefaultScale = 1.000
$ConfigDir = Join-Path $env:APPDATA 'Arrowhead\Helldivers2'
$ConfigPath = Join-Path $ConfigDir 'frv_hud_position.json'
$script:Lang = if ($PSUICulture -like 'zh*') { 'zh' } else { 'en' }
$script:Syncing = $false

$Text = @{
    en = @{
        Title = 'DRIVER HUD - FRV HUD Position'
        Heading = 'FRV HUD Position Adjustment'
        Horizontal = 'Horizontal position'
        Vertical = 'Vertical position'
        Scale = 'Scale'
        Left = 'Left'
        Right = 'Right'
        Up = 'Up'
        Down = 'Down'
        Apply = 'Apply'
        Reset = 'Reset Defaults'
        OpenFolder = 'Open Config Folder'
        Close = 'Close'
        Language = '中文'
        Hint = 'Changes are picked up by the running HUD in about 2 seconds. No Purge, Deploy, or game restart is needed.'
        Ready = 'Ready.'
        Loaded = 'Loaded current settings.'
        Defaulted = 'No valid saved settings found; showing defaults.'
        ResetDone = 'Defaults restored in the window. Click Apply to save them.'
        Applied = 'Applied. Return to the game to check the new position.'
        ApplyError = 'Could not save the FRV HUD settings.'
        FolderError = 'Could not open the configuration folder.'
        Path = 'Config file:'
    }
    zh = @{
        Title = 'DRIVER HUD - FRV HUD 位置'
        Heading = 'FRV HUD位置修改'
        Horizontal = '水平位置'
        Vertical = '垂直位置'
        Scale = '缩放'
        Left = '向左'
        Right = '向右'
        Up = '向上'
        Down = '向下'
        Apply = '应用'
        Reset = '恢复默认'
        OpenFolder = '打开配置目录'
        Close = '关闭'
        Language = 'English'
        Hint = '游戏运行期间也可以调整。点击“应用”后约 2 秒生效，无需 Purge、Deploy 或重启游戏。'
        Ready = '可以开始调整。'
        Loaded = '已读取当前设置。'
        Defaulted = '没有找到有效的已保存设置，当前显示默认值。'
        ResetDone = '已在窗口中恢复默认值；点击“应用”后保存。'
        Applied = '已应用。返回游戏即可查看新的位置。'
        ApplyError = '无法保存 FRV HUD 设置。'
        FolderError = '无法打开配置目录。'
        Path = '配置文件：'
    }
}

function Clamp-Value([double]$Value, [double]$Min, [double]$Max) {
    if ($Value -lt $Min) { return $Min }
    if ($Value -gt $Max) { return $Max }
    return $Value
}

$CurrentX = $DefaultX
$CurrentY = $DefaultY
$CurrentScale = $DefaultScale
$LoadState = 'Defaulted'
if (Test-Path -LiteralPath $ConfigPath) {
    try {
        $cfg = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $x = [double]$cfg.x
        $y = [double]$cfg.y
        $s = [double]$cfg.scale
        if (($x -ge 0.0) -and ($x -le 1.0) -and ($y -ge 0.0) -and ($y -le 1.0) -and ($s -ge 0.5) -and ($s -le 2.0)) {
            $CurrentX = $x
            $CurrentY = $y
            $CurrentScale = $s
            $LoadState = 'Loaded'
        }
    } catch {
        $LoadState = 'Defaulted'
    }
}

$form = New-Object System.Windows.Forms.Form
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(560, 430)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$heading = New-Object System.Windows.Forms.Label
$heading.Location = New-Object System.Drawing.Point(20, 18)
$heading.Size = New-Object System.Drawing.Size(390, 30)
$heading.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$form.Controls.Add($heading)

$langButton = New-Object System.Windows.Forms.Button
$langButton.Location = New-Object System.Drawing.Point(440, 16)
$langButton.Size = New-Object System.Drawing.Size(100, 30)
$form.Controls.Add($langButton)

$labelX = New-Object System.Windows.Forms.Label
$labelX.Location = New-Object System.Drawing.Point(22, 72)
$labelX.Size = New-Object System.Drawing.Size(145, 24)
$form.Controls.Add($labelX)

$trackX = New-Object System.Windows.Forms.TrackBar
$trackX.Location = New-Object System.Drawing.Point(160, 62)
$trackX.Size = New-Object System.Drawing.Size(285, 45)
$trackX.Minimum = 0
$trackX.Maximum = 1000
$trackX.TickFrequency = 100
$trackX.SmallChange = 5
$trackX.LargeChange = 25
$form.Controls.Add($trackX)

$numX = New-Object System.Windows.Forms.NumericUpDown
$numX.Location = New-Object System.Drawing.Point(458, 68)
$numX.Size = New-Object System.Drawing.Size(82, 24)
$numX.Minimum = 0
$numX.Maximum = 1
$numX.DecimalPlaces = 3
$numX.Increment = [decimal]0.005
$form.Controls.Add($numX)

$labelY = New-Object System.Windows.Forms.Label
$labelY.Location = New-Object System.Drawing.Point(22, 126)
$labelY.Size = New-Object System.Drawing.Size(145, 24)
$form.Controls.Add($labelY)

$trackY = New-Object System.Windows.Forms.TrackBar
$trackY.Location = New-Object System.Drawing.Point(160, 116)
$trackY.Size = New-Object System.Drawing.Size(285, 45)
$trackY.Minimum = 0
$trackY.Maximum = 1000
$trackY.TickFrequency = 100
$trackY.SmallChange = 5
$trackY.LargeChange = 25
$form.Controls.Add($trackY)

$numY = New-Object System.Windows.Forms.NumericUpDown
$numY.Location = New-Object System.Drawing.Point(458, 122)
$numY.Size = New-Object System.Drawing.Size(82, 24)
$numY.Minimum = 0
$numY.Maximum = 1
$numY.DecimalPlaces = 3
$numY.Increment = [decimal]0.005
$form.Controls.Add($numY)

$labelScale = New-Object System.Windows.Forms.Label
$labelScale.Location = New-Object System.Drawing.Point(22, 180)
$labelScale.Size = New-Object System.Drawing.Size(145, 24)
$form.Controls.Add($labelScale)

$trackScale = New-Object System.Windows.Forms.TrackBar
$trackScale.Location = New-Object System.Drawing.Point(160, 170)
$trackScale.Size = New-Object System.Drawing.Size(285, 45)
$trackScale.Minimum = 50
$trackScale.Maximum = 200
$trackScale.TickFrequency = 25
$trackScale.SmallChange = 1
$trackScale.LargeChange = 5
$form.Controls.Add($trackScale)

$numScale = New-Object System.Windows.Forms.NumericUpDown
$numScale.Location = New-Object System.Drawing.Point(458, 176)
$numScale.Size = New-Object System.Drawing.Size(82, 24)
$numScale.Minimum = [decimal]0.5
$numScale.Maximum = [decimal]2.0
$numScale.DecimalPlaces = 2
$numScale.Increment = [decimal]0.05
$form.Controls.Add($numScale)

$leftButton = New-Object System.Windows.Forms.Button
$leftButton.Location = New-Object System.Drawing.Point(88, 230)
$leftButton.Size = New-Object System.Drawing.Size(88, 30)
$form.Controls.Add($leftButton)

$rightButton = New-Object System.Windows.Forms.Button
$rightButton.Location = New-Object System.Drawing.Point(184, 230)
$rightButton.Size = New-Object System.Drawing.Size(88, 30)
$form.Controls.Add($rightButton)

$upButton = New-Object System.Windows.Forms.Button
$upButton.Location = New-Object System.Drawing.Point(288, 230)
$upButton.Size = New-Object System.Drawing.Size(88, 30)
$form.Controls.Add($upButton)

$downButton = New-Object System.Windows.Forms.Button
$downButton.Location = New-Object System.Drawing.Point(384, 230)
$downButton.Size = New-Object System.Drawing.Size(88, 30)
$form.Controls.Add($downButton)

$hint = New-Object System.Windows.Forms.Label
$hint.Location = New-Object System.Drawing.Point(22, 278)
$hint.Size = New-Object System.Drawing.Size(518, 42)
$form.Controls.Add($hint)

$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(22, 323)
$status.Size = New-Object System.Drawing.Size(518, 22)
$status.ForeColor = [System.Drawing.Color]::FromArgb(40, 110, 40)
$form.Controls.Add($status)

$pathLabel = New-Object System.Windows.Forms.Label
$pathLabel.Location = New-Object System.Drawing.Point(22, 348)
$pathLabel.Size = New-Object System.Drawing.Size(518, 34)
$pathLabel.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($pathLabel)

$applyButton = New-Object System.Windows.Forms.Button
$applyButton.Location = New-Object System.Drawing.Point(22, 390)
$applyButton.Size = New-Object System.Drawing.Size(92, 30)
$form.Controls.Add($applyButton)

$resetButton = New-Object System.Windows.Forms.Button
$resetButton.Location = New-Object System.Drawing.Point(122, 390)
$resetButton.Size = New-Object System.Drawing.Size(115, 30)
$form.Controls.Add($resetButton)

$folderButton = New-Object System.Windows.Forms.Button
$folderButton.Location = New-Object System.Drawing.Point(245, 390)
$folderButton.Size = New-Object System.Drawing.Size(155, 30)
$form.Controls.Add($folderButton)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Location = New-Object System.Drawing.Point(448, 390)
$closeButton.Size = New-Object System.Drawing.Size(92, 30)
$form.Controls.Add($closeButton)
$form.CancelButton = $closeButton

function Set-Values([double]$X, [double]$Y, [double]$Scale) {
    $script:Syncing = $true
    $X = Clamp-Value $X 0.0 1.0
    $Y = Clamp-Value $Y 0.0 1.0
    $Scale = Clamp-Value $Scale 0.5 2.0
    $numX.Value = [decimal]$X
    $numY.Value = [decimal]$Y
    $numScale.Value = [decimal]$Scale
    $trackX.Value = [int][math]::Round($X * 1000)
    $trackY.Value = [int][math]::Round($Y * 1000)
    $trackScale.Value = [int][math]::Round($Scale * 100)
    $script:Syncing = $false
}

function Set-Language([string]$NewLang) {
    $script:Lang = $NewLang
    $t = $Text[$script:Lang]
    $form.Text = $t.Title
    $heading.Text = $t.Heading
    $labelX.Text = $t.Horizontal
    $labelY.Text = $t.Vertical
    $labelScale.Text = $t.Scale
    $leftButton.Text = $t.Left
    $rightButton.Text = $t.Right
    $upButton.Text = $t.Up
    $downButton.Text = $t.Down
    $applyButton.Text = $t.Apply
    $resetButton.Text = $t.Reset
    $folderButton.Text = $t.OpenFolder
    $closeButton.Text = $t.Close
    $langButton.Text = $t.Language
    $hint.Text = $t.Hint
    $pathLabel.Text = $t.Path + ' ' + $ConfigPath
}

$trackX.Add_ValueChanged({
    if (-not $script:Syncing) {
        $script:Syncing = $true
        $numX.Value = [decimal]($trackX.Value / 1000.0)
        $script:Syncing = $false
    }
})
$numX.Add_ValueChanged({
    if (-not $script:Syncing) {
        $script:Syncing = $true
        $trackX.Value = [int][math]::Round(([double]$numX.Value) * 1000)
        $script:Syncing = $false
    }
})
$trackY.Add_ValueChanged({
    if (-not $script:Syncing) {
        $script:Syncing = $true
        $numY.Value = [decimal]($trackY.Value / 1000.0)
        $script:Syncing = $false
    }
})
$numY.Add_ValueChanged({
    if (-not $script:Syncing) {
        $script:Syncing = $true
        $trackY.Value = [int][math]::Round(([double]$numY.Value) * 1000)
        $script:Syncing = $false
    }
})
$trackScale.Add_ValueChanged({
    if (-not $script:Syncing) {
        $script:Syncing = $true
        $numScale.Value = [decimal]($trackScale.Value / 100.0)
        $script:Syncing = $false
    }
})
$numScale.Add_ValueChanged({
    if (-not $script:Syncing) {
        $script:Syncing = $true
        $trackScale.Value = [int][math]::Round(([double]$numScale.Value) * 100)
        $script:Syncing = $false
    }
})

$leftButton.Add_Click({ Set-Values (([double]$numX.Value) - 0.01) ([double]$numY.Value) ([double]$numScale.Value) })
$rightButton.Add_Click({ Set-Values (([double]$numX.Value) + 0.01) ([double]$numY.Value) ([double]$numScale.Value) })
$upButton.Add_Click({ Set-Values ([double]$numX.Value) (([double]$numY.Value) - 0.01) ([double]$numScale.Value) })
$downButton.Add_Click({ Set-Values ([double]$numX.Value) (([double]$numY.Value) + 0.01) ([double]$numScale.Value) })

$langButton.Add_Click({
    if ($script:Lang -eq 'zh') { Set-Language 'en' } else { Set-Language 'zh' }
    $status.Text = $Text[$script:Lang].Ready
})

$resetButton.Add_Click({
    Set-Values $DefaultX $DefaultY $DefaultScale
    $status.Text = $Text[$script:Lang].ResetDone
})

$folderButton.Add_Click({
    try {
        if (-not (Test-Path -LiteralPath $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
        Start-Process explorer.exe -ArgumentList ('"' + $ConfigDir + '"')
    } catch {
        [System.Windows.Forms.MessageBox]::Show($Text[$script:Lang].FolderError, $Text[$script:Lang].Title, 'OK', 'Error') | Out-Null
    }
})

$applyButton.Add_Click({
    try {
        if (-not (Test-Path -LiteralPath $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
        $obj = [ordered]@{
            x = [math]::Round([double]$numX.Value, 3)
            y = [math]::Round([double]$numY.Value, 3)
            scale = [math]::Round([double]$numScale.Value, 2)
        }
        $json = $obj | ConvertTo-Json
        $tmp = $ConfigPath + '.tmp'
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($tmp, $json + [Environment]::NewLine, $utf8)
        Move-Item -LiteralPath $tmp -Destination $ConfigPath -Force
        $status.Text = $Text[$script:Lang].Applied
    } catch {
        [System.Windows.Forms.MessageBox]::Show($Text[$script:Lang].ApplyError + [Environment]::NewLine + $_.Exception.Message, $Text[$script:Lang].Title, 'OK', 'Error') | Out-Null
    }
})

$closeButton.Add_Click({ $form.Close() })

Set-Values $CurrentX $CurrentY $CurrentScale
Set-Language $script:Lang
$status.Text = $Text[$script:Lang][$LoadState]
[void]$form.ShowDialog()

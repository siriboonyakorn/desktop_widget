$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
$script:companionStatePath=Join-Path $PSScriptRoot ('test-pet-'+[Guid]::NewGuid().ToString('N')+'.json')
function Assert-Pet($Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Click-PetMenu($Menu,[string]$Header) {
    $item=$Menu.Items | Where-Object Header -eq $Header
    Assert-Pet ($null -ne $item) "Missing menu: $Header"
    $item.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
}
try {
    $petWindow.Opacity=1; $petWindow.Show()
    $widgetPreferences.motion=$false
    $invalid=ConvertTo-PetProgress ([pscustomobject]@{palette='Unknown';hat='Unknown';bond=-12;best='NaN';souvenirs=@('Moon pebble','Moon pebble','invalid')})
    Assert-Pet ($invalid.palette -eq 'Blue' -and $invalid.hat -eq 'None' -and $invalid.bond -eq 0 -and $invalid.best -eq 0 -and $invalid.souvenirs.Count -eq 1) 'Saved-state validation failed'
    $companionState.play=New-PetProgress
    $petWindow.FindName('PetPatButton').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    Assert-Pet ($petPlay.mode -eq 'Pat' -and $companionState.play.bond -eq 1 -and $petArt.FindName('BuddyClosedEyes').Visibility -eq 'Visible') 'Pat action failed'
    $petWindow.FindName('PetTreatButton').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    Assert-Pet ($petPlay.mode -eq 'Snack' -and $companionState.play.bond -eq 3) 'Treat button failed'
    $playMenu=$petWindow.ContextMenu.Items | Where-Object Header -eq 'Play with buddy'
    $snackMenu=$petWindow.ContextMenu.Items | Where-Object Header -eq 'Share a treat'
    foreach ($snack in @('Moon berry','Cloud tea')) { Click-PetMenu $snackMenu $snack; Assert-Pet ($petPlay.mode -eq 'Snack' -and $petArt.FindName('BuddyProp').Text.Length -gt 0) 'Snack prop missing' }
    Click-PetMenu $playMenu 'Tiny disco'
    Assert-Pet ($petPlay.mode -eq 'Dance' -and -not $petBob.HasAnimatedProperties) 'Reduced-motion dance did not respect setting'
    $widgetPreferences.motion=$true; Update-PetPlayground
    Assert-Pet ($petBob.HasAnimatedProperties -and $petArt.FindName('BuddyTilt').HasAnimatedProperties) 'Dance animation missing'
    $widgetPreferences.motion=$false; Update-PetPlayground
    Assert-Pet (-not $petBob.HasAnimatedProperties -and -not $petArt.FindName('BuddyTilt').HasAnimatedProperties) 'Animation did not stop'
    Click-PetMenu $playMenu 'Nap / wake up'
    Assert-Pet ($petPlay.mode -eq 'Nap') 'Nap failed'
    Invoke-PetAction 'Pat'
    Assert-Pet ($petPlay.mode -eq 'Idle') 'Tap to wake failed'
    Click-PetMenu $playMenu 'Nap / wake up'
    Update-PetPlayground ([DateTime]::UtcNow.AddMinutes(3))
    Assert-Pet ($petPlay.mode -eq 'Idle') 'Nap deadline failed'
    Click-PetMenu $playMenu 'Bubble pop - 20 seconds'
    $bubble=$petWindow.FindName('PetBubbles').Children[0]
    for ($i=0; $i -lt 7; $i++) {
        $bubble.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        $x=[Windows.Controls.Canvas]::GetLeft($bubble); $y=[Windows.Controls.Canvas]::GetTop($bubble)
        Assert-Pet ($x -ge 0 -and $x+$bubble.Width -le 220 -and $y -ge 0 -and $y+$bubble.Height -le 124) 'Bubble escaped play area'
    }
    Assert-Pet ($petPlay.score -eq 7) 'Bubble click handler failed'
    Update-PetPlayground ([DateTime]::UtcNow.AddSeconds(21))
    Assert-Pet ($companionState.play.best -eq 7 -and $petPlay.mode -eq 'Idle' -and $petWindow.FindName('PetBubbles').Visibility -eq 'Collapsed') 'Game completion or record failed'
    Invoke-PetBubble
    Assert-Pet ($petPlay.score -eq 7) 'Scored a bubble after game ended'
    Invoke-PetAction 'Game'; $petPlay.until=[DateTime]::UtcNow.AddSeconds(-1); Invoke-PetBubble
    Assert-Pet ($petPlay.score -eq 0 -and $companionState.play.best -eq 7) 'Expired game scored or reset high score'
    Invoke-PetAction 'Adventure'; Invoke-PetAction 'Cancel'; Update-PetPlayground ([DateTime]::UtcNow.AddMinutes(1))
    Assert-Pet ($companionState.play.souvenirs.Count -eq 0) 'Cancelled adventure granted treasure'
    for ($i=0; $i -lt 7; $i++) { Click-PetMenu $playMenu 'Sofa galaxy adventure'; Update-PetPlayground ([DateTime]::UtcNow.AddSeconds(13)) }
    Assert-Pet ($companionState.play.souvenirs.Count -eq 6 -and @($companionState.play.souvenirs | Select-Object -Unique).Count -eq 6) 'Treasure collection duplicated or lost items'
    Click-PetMenu $petHatMenu 'Sprout'; Click-PetMenu $petPaletteMenu 'Mint'
    Assert-Pet ($companionState.play.hat -eq 'Sprout' -and $companionState.play.palette -eq 'Mint') 'Wardrobe menu failed'
    Assert-Pet ($petArt.FindName('HatSprout').Visibility -eq 'Visible' -and $petArt.FindName('BuddyShell').Fill.GradientStops[0].Color.ToString() -eq '#FFD2FFF0') 'Wardrobe visuals not applied'
    Assert-Pet ($petToast.FindName('ToastPet').Content.FindName('HatSprout').Visibility -eq 'Visible') 'Toast outfit did not match'
    Click-PetMenu $playMenu 'A tiny fortune'; $last=$petPlay.lastFortune; Click-PetMenu $playMenu 'A tiny fortune'
    Assert-Pet ($last -ne $petPlay.lastFortune -and $petPlay.mode -eq 'Fortune') 'Fortune repeated'
    $companionState.play.bond=39; Add-PetBond 1
    Assert-Pet ($petWindow.FindName('PetBond').Text -like 'LEVEL 3*') 'Friendship level boundary failed'
    $Preview=$false; Save-CompanionState; $Preview=$true
    Assert-Pet (-not $script:companionSaveFailed) 'Initial play state save failed'
    $Preview=$false; Save-CompanionState; $Preview=$true
    Assert-Pet (-not $script:companionSaveFailed) 'Atomic play state replacement failed'
    $restored=ConvertTo-PetProgress ((Get-Content -LiteralPath $companionStatePath -Raw | ConvertFrom-Json).play)
    Assert-Pet ($restored.hat -eq 'Sprout' -and $restored.palette -eq 'Mint' -and $restored.best -eq 7 -and $restored.bond -eq 40 -and $restored.souvenirs.Count -eq 6) 'Play state did not survive JSON round trip'
    $petWindow.FindName('PetPlayButton').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    Assert-Pet ($petWindow.ContextMenu.IsOpen -and $petCollectionMenu.Items.Count -eq 6) 'More menu or treasure shelf failed'
    $petWindow.ContextMenu.IsOpen=$false
    # The bottom action bar must remain inside the scalable card at all supported sizes.
    $card=$cornerCards | Where-Object Name -eq 'Pet'
    foreach ($scale in @(0.7,1.0,1.5)) {
        Set-WidgetScale $card $scale; $petWindow.UpdateLayout()
        $button=$petWindow.FindName('PetPlayButton')
        $bounds=$button.TransformToAncestor($petWindow).TransformBounds([Windows.Rect]::new(0,0,$button.ActualWidth,$button.ActualHeight))
        Assert-Pet ($bounds.Bottom -le $petWindow.Height -and $bounds.Right -le $petWindow.Width) "Action bar clipped at scale $scale"
    }
    Set-WidgetScale $card 1
    $visual=[Windows.Media.DrawingVisual]::new(); $draw=$visual.RenderOpen()
    $draw.DrawRectangle([Windows.Media.BrushConverter]::new().ConvertFromString('#111C2C'),$null,[Windows.Rect]::new(0,0,1008,568))
    $states=@(@('Blue','None','Pat'),@('Mint','Sprout','Cookie'),@('Peach','Crown','Dance'),@('Lilac','Space cap','Nap'),@('Blue','Space cap','Adventure'),@('Mint','None','Game'),@('Lilac','Crown','Fortune'),@('Peach','Sprout','Idle'))
    for ($i=0; $i -lt $states.Count; $i++) {
        $companionState.play.palette=$states[$i][0]; $companionState.play.hat=$states[$i][1]; Update-PetLook
        if ($states[$i][2] -eq 'Idle') { Set-PetMode 'Idle' 'A tiny friend for your corner of the world.' } else { Invoke-PetAction $states[$i][2] }
        $petWindow.UpdateLayout(); $petWindow.Dispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::Render)
        $frame=[Windows.Media.Imaging.RenderTargetBitmap]::new(480,488,192,192,[Windows.Media.PixelFormats]::Pbgra32); $frame.Render($petWindow)
        $x=8+($i%4)*250; $y=12+[Math]::Floor($i/4)*280
        $draw.DrawImage($frame,[Windows.Rect]::new($x,$y,240,244))
    }
    $draw.Close()
    $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(2016,1136,192,192,[Windows.Media.PixelFormats]::Pbgra32); $bitmap.Render($visual)
    $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $PSScriptRoot 'preview-pet-playground.png'))
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
    Write-Output 'PASS: all 10 features, routed buttons and menus, reduced motion, deadlines, cancellation, game bounds and records, unique collectibles, state validation and persistence, matching toast outfit, friendship, scaling, and 2x visual gallery.'
} finally {
    $Preview=$true; $petToast.Close()
    foreach ($entry in $cornerCards) { $entry.Window.Close() }
    foreach ($path in @($companionStatePath,($companionStatePath+'.tmp'))) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path } }
}

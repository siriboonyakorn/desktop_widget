# All play stays local. The shared companion tick drives deadlines; WPF drives animation.
$script:petPalettes = [ordered]@{
    Blue = @('#C1E4FF','#679DF5','#3555AA')
    Mint = @('#D2FFF0','#6DCBB5','#327F83')
    Peach = @('#FFE7CC','#F4AB91','#AE597C')
    Lilac = @('#ECDFFF','#B79AEF','#655BA9')
}
$script:petSouvenirs = @('Moon pebble','Cloud in a jar','Tiny comet','Lost sock','Starlight seed','Pocket rainbow')
$script:petFortunes = @('A small delight is hiding in an ordinary moment.', 'Your next great idea may arrive wearing pajamas.', 'The stars recommend one gloriously silly dance.', 'Somewhere, a cloud looks exactly like your buddy.', 'Today is a fine day to be a work in progress.', 'A lost sock is beginning an extraordinary adventure.', 'Your lucky number is potato. The universe is mysterious.', 'You have been awarded one imaginary gold star.')

function New-PetProgress {
    return @{ palette='Blue'; hat='None'; bond=0; best=0; souvenirs=@() }
}
function ConvertTo-PetProgress($Raw) {
    $result = New-PetProgress
    if ($Raw.palette -in @($script:petPalettes.Keys)) { $result.palette=[string]$Raw.palette }
    if ($Raw.hat -in @('None','Sprout','Crown','Space cap')) { $result.hat=[string]$Raw.hat }
    foreach ($key in @('bond','best')) {
        $value=0
        if ([int]::TryParse([string]$Raw.$key,[ref]$value)) { $result[$key]=[Math]::Max(0,[Math]::Min(10000,$value)) }
    }
    $result.souvenirs=@($script:petSouvenirs | Where-Object { $_ -in @($Raw.souvenirs) })
    return $result
}

function New-VectorPet {
    [xml]$xaml = @'
<Viewbox xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Width="162" Height="124" Stretch="Uniform">
 <Canvas Width="180" Height="144">
  <Canvas.Resources>
   <LinearGradientBrush x:Key="Shell" StartPoint="0.15,0" EndPoint="0.9,1"><GradientStop Color="#C1E4FF" Offset="0"/><GradientStop Color="#679DF5" Offset="0.45"/><GradientStop Color="#3555AA" Offset="1"/></LinearGradientBrush>
   <LinearGradientBrush x:Key="Visor" StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#243E63" Offset="0"/><GradientStop Color="#101B33" Offset="1"/></LinearGradientBrush>
   <RadialGradientBrush x:Key="Halo"><GradientStop Color="#355C9FFF" Offset="0"/><GradientStop Color="#005C9FFF" Offset="1"/></RadialGradientBrush>
  </Canvas.Resources>
  <Ellipse Canvas.Left="24" Canvas.Top="28" Width="132" Height="113" Fill="{StaticResource Halo}"/>
  <Ellipse Canvas.Left="49" Canvas.Top="130" Width="82" Height="9" Fill="#30081121"/>
  <Ellipse Canvas.Left="61" Canvas.Top="132" Width="58" Height="3" Fill="#506AAFF0"/>
  <Canvas x:Name="BuddyBody" Width="180" Height="144" RenderTransformOrigin="0.5,0.8">
   <Canvas.RenderTransform><TransformGroup><RotateTransform x:Name="BuddyTilt"/><TranslateTransform x:Name="BuddyFloat"/></TransformGroup></Canvas.RenderTransform>
   <Rectangle Canvas.Left="70" Canvas.Top="115" Width="16" Height="17" RadiusX="7" RadiusY="7" Fill="#416AAC" Stroke="#A2CDFF" StrokeThickness="1"/>
   <Rectangle Canvas.Left="96" Canvas.Top="115" Width="16" Height="17" RadiusX="7" RadiusY="7" Fill="#416AAC" Stroke="#A2CDFF" StrokeThickness="1"/>
   <Rectangle x:Name="BuddyTorso" Canvas.Left="62" Canvas.Top="91" Width="57" Height="34" RadiusX="15" RadiusY="15" Fill="{StaticResource Shell}" Stroke="#9AC9FF" StrokeThickness="1"/>
   <Rectangle Canvas.Left="48" Canvas.Top="96" Width="13" Height="25" RadiusX="6" RadiusY="6" Fill="{StaticResource Shell}" Stroke="#A2CDFF" StrokeThickness="1" RenderTransformOrigin="0.5,0.2"><Rectangle.RenderTransform><RotateTransform Angle="18"/></Rectangle.RenderTransform></Rectangle>
   <Rectangle Canvas.Left="121" Canvas.Top="96" Width="13" Height="25" RadiusX="6" RadiusY="6" Fill="{StaticResource Shell}" Stroke="#A2CDFF" StrokeThickness="1" RenderTransformOrigin="0.5,0.2"><Rectangle.RenderTransform><RotateTransform x:Name="BuddyArm" Angle="-18"/></Rectangle.RenderTransform></Rectangle>
   <Rectangle Canvas.Left="75" Canvas.Top="101" Width="31" Height="16" RadiusX="6" RadiusY="6" Fill="#334467A8"/>
   <Path Data="M 81,105 L 85,108 81,111 M 91,111 H 99" Stroke="#E7FFFF" StrokeThickness="2" StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"/>
   <Path Data="M 91,26 L 93,15" Stroke="#A9D9FF" StrokeThickness="3"/>
   <Ellipse Canvas.Left="89" Canvas.Top="9" Width="9" Height="9" Fill="#BEFFF0"/>
   <Rectangle Canvas.Left="37" Canvas.Top="51" Width="12" Height="26" RadiusX="6" RadiusY="6" Fill="#4C76BC" Stroke="#9AC9FF"/>
   <Rectangle Canvas.Left="132" Canvas.Top="51" Width="12" Height="26" RadiusX="6" RadiusY="6" Fill="#4C76BC" Stroke="#9AC9FF"/>
   <Rectangle x:Name="BuddyShell" Canvas.Left="43" Canvas.Top="25" Width="96" Height="74" RadiusX="29" RadiusY="29" Fill="{StaticResource Shell}" Stroke="#BCDFFF" StrokeThickness="1.3"/>
   <Path Data="M 57,40 Q 66,30 84,32 L 107,32" Stroke="#90FFFFFF" StrokeThickness="3" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
   <Rectangle Canvas.Left="52" Canvas.Top="43" Width="78" Height="44" RadiusX="18" RadiusY="18" Fill="{StaticResource Visor}" Stroke="#34598D" StrokeThickness="2"/>
   <Path Data="M 63,49 Q 85,44 117,50" Stroke="#304F7198" StrokeThickness="3" StrokeStartLineCap="Round"/>
   <Canvas x:Name="BuddyEyes">
    <Ellipse Canvas.Left="69" Canvas.Top="58" Width="10" Height="15" Fill="#B8FFF0"/>
    <Ellipse Canvas.Left="103" Canvas.Top="58" Width="10" Height="15" Fill="#B8FFF0"/>
    <Ellipse Canvas.Left="71" Canvas.Top="59" Width="3" Height="4" Fill="White"/>
    <Ellipse Canvas.Left="105" Canvas.Top="59" Width="3" Height="4" Fill="White"/>
   </Canvas>
   <Path x:Name="BuddyClosedEyes" Visibility="Collapsed" Data="M 67,68 Q 74,60 81,68 M 101,68 Q 108,60 115,68" Stroke="#B8FFF0" StrokeThickness="3" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
   <Path x:Name="BuddyMouth" Data="M 86,75 Q 91,80 96,75" Stroke="#B8FFF0" StrokeThickness="1.8" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
   <Ellipse Canvas.Left="62" Canvas.Top="73" Width="11" Height="4" Fill="#65F5AFC4"/>
   <Ellipse Canvas.Left="110" Canvas.Top="73" Width="11" Height="4" Fill="#65F5AFC4"/>
   <Canvas x:Name="HatSprout" Visibility="Collapsed"><Path Data="M 92,28 Q 94,16 90,10 M 92,19 Q 76,22 77,10 Q 89,8 92,19 M 92,15 Q 95,2 107,7 Q 109,17 92,15" Fill="#91E8B4" Stroke="#3DAB86" StrokeThickness="1.2"/></Canvas>
   <Path x:Name="HatCrown" Visibility="Collapsed" Data="M 70,29 L 66,9 80,17 91,3 102,17 116,9 112,29 Z" Fill="#FFD982" Stroke="#FFF1C3" StrokeThickness="1.5"/>
   <Canvas x:Name="HatSpace" Visibility="Collapsed"><Path Data="M 60,29 Q 63,4 91,4 Q 122,4 124,30 Z" Fill="#ECDEEFFF" Stroke="#9CB6EC" StrokeThickness="1.5"/><Ellipse Canvas.Left="81" Canvas.Top="9" Width="20" Height="14" Fill="#5675AC"/><Path Data="M 90,11 L 92,15 96,16 92,18 91,21 89,18 86,16 89,15 Z" Fill="#D9FFF4"/></Canvas>
  </Canvas>
  <TextBlock x:Name="BuddyProp" Canvas.Left="120" Canvas.Top="83" FontSize="28" FontFamily="Segoe UI Symbol" Foreground="#FFE4A5"/>
  <Canvas x:Name="BuddyParticles" IsHitTestVisible="False"/>
 </Canvas>
</Viewbox>
'@
    return [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xaml))
}

function Set-PetFace([bool]$Closed) {
    $script:petArt.FindName('BuddyEyes').Visibility=if ($Closed) { 'Collapsed' } else { 'Visible' }
    $script:petArt.FindName('BuddyClosedEyes').Visibility=if ($Closed) { 'Visible' } else { 'Collapsed' }
}
function Update-PetLook {
    $progress=$script:companionState.play
    foreach ($art in @($script:petArt,$script:petToast.FindName('ToastPet').Content)) {
        $stops=$art.FindName('BuddyShell').Fill.GradientStops
        for ($i=0; $i -lt 3; $i++) { $stops[$i].Color=[Windows.Media.ColorConverter]::ConvertFromString($script:petPalettes[$progress.palette][$i]) }
        foreach ($pair in @(@('HatSprout','Sprout'),@('HatCrown','Crown'),@('HatSpace','Space cap'))) {
            $art.FindName($pair[0]).Visibility=if ($progress.hat -eq $pair[1]) { 'Visible' } else { 'Collapsed' }
        }
    }
    $level=[Math]::Min(10,1+[int][Math]::Floor($progress.bond/20))
    $title=if ($level -ge 8) { 'COSMIC BESTIES' } elseif ($level -ge 5) { 'PARTNERS IN WONDER' } elseif ($level -ge 3) { 'LITTLE SIDEKICKS' } else { 'NEW FRIENDS' }
    $script:petWindow.FindName('PetBond').Text="LEVEL $level / $title"
    $script:petWindow.FindName('PetBond').ToolTip="Friendship: $($progress.bond) stars. Play and care to grow together. No streaks or penalties."
}
function Add-PetBond([int]$Amount) {
    $script:companionState.play.bond=[Math]::Min(10000,$script:companionState.play.bond+$Amount)
    Update-PetLook
    Save-CompanionState
}
function Show-PetParticles([string]$Symbol, [string]$Color='#FFC4DB') {
    $canvas=$script:petArt.FindName('BuddyParticles'); $canvas.Children.Clear()
    for ($i=0; $i -lt 6; $i++) {
        $p=[Windows.Controls.TextBlock]::new(); $p.Text=$Symbol; $p.FontFamily='Segoe UI Symbol'; $p.FontSize=12+($i%3)*3; $p.Foreground=$Color
        [Windows.Controls.Canvas]::SetLeft($p,30+$i*23); [Windows.Controls.Canvas]::SetTop($p,35+($i%2)*21)
        [void]$canvas.Children.Add($p)
        if ($script:widgetPreferences.motion) {
            $move=[Windows.Media.TranslateTransform]::new(); $p.RenderTransform=$move
            $float=[Windows.Media.Animation.DoubleAnimation]::new(8,-25,[TimeSpan]::FromSeconds(2.2)); $float.BeginTime=[TimeSpan]::FromMilliseconds($i*70)
            $move.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$float)
            $fade=[Windows.Media.Animation.DoubleAnimation]::new(1,0,[TimeSpan]::FromSeconds(2.8)); $p.BeginAnimation([Windows.UIElement]::OpacityProperty,$fade)
        }
    }
    $script:petPlay.particlesUntil=[DateTime]::UtcNow.AddSeconds(3)
}
function Set-PetAnimation {
    $motion=$script:widgetPreferences.motion -and $script:petWindow.Opacity -gt 0 -and $script:widgetPreferences.widgets.Pet.enabled
    $key="$motion/$($script:petPlay.mode)"
    if ($script:petPlay.animationKey -eq $key) { return }
    $script:petPlay.animationKey=$key
    $float=$script:petArt.FindName('BuddyFloat'); $tilt=$script:petArt.FindName('BuddyTilt'); $arm=$script:petArt.FindName('BuddyArm')
    $float.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$null); $float.Y=0
    $tilt.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty,$null); $tilt.Angle=if ($script:petPlay.mode -eq 'Nap') { -8 } else { 0 }
    $arm.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty,$null); $arm.Angle=-18
    if (-not $motion) {
        $script:petArt.FindName('BuddyParticles').Children.Clear()
        return
    }
    $dance=$script:petPlay.mode -eq 'Dance'
    $duration=if ($dance) { 0.23 } elseif ($script:petPlay.mode -eq 'Nap') { 2.2 } else { 1.4 }
    $height=if ($dance) { -7 } else { -2.5 }
    $anim=[Windows.Media.Animation.DoubleAnimation]::new(0,$height,[TimeSpan]::FromSeconds($duration)); $anim.AutoReverse=$true; $anim.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever
    $anim.EasingFunction=[Windows.Media.Animation.SineEase]::new()
    $float.BeginAnimation([Windows.Media.TranslateTransform]::YProperty,$anim)
    if ($dance) {
        foreach ($transform in @($tilt,$arm)) {
            $wiggle=[Windows.Media.Animation.DoubleAnimation]::new(-12,12,[TimeSpan]::FromSeconds(0.28)); $wiggle.AutoReverse=$true; $wiggle.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever
            $transform.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty,$wiggle)
        }
    }
}
function Set-PetMode([string]$Mode,[string]$Caption,[double]$Seconds=4,[string]$Prop='') {
    $script:petPlay.mode=$Mode; $script:petPlay.until=[DateTime]::UtcNow.AddSeconds($Seconds)
    $script:petArt.FindName('BuddyParticles').Children.Clear()
    $script:petWindow.FindName('PetCaption').Text=$Caption
    $script:petWindow.FindName('PetMood').Text=switch ($Mode) { 'Nap' {'DREAMING'} 'Dance' {'GROOVING'} 'Adventure' {'EXPLORING'} 'Game' {'PLAYTIME'} 'Pat' {'LOVED'} 'Snack' {'NOM NOM'} 'Fortune' {'STARGAZING'} default {'CURIOUS'} }
    $script:petArt.FindName('BuddyProp').Text=$Prop
    $script:petArt.FindName('BuddyClosedEyes').Data=[Windows.Media.Geometry]::Parse($(if ($Mode -eq 'Nap') { 'M 67,65 Q 74,72 81,65 M 101,65 Q 108,72 115,65' } else { 'M 67,68 Q 74,60 81,68 M 101,68 Q 108,60 115,68' }))
    $script:petWindow.FindName('PetBubbles').Visibility=if ($Mode -eq 'Game') { 'Visible' } else { 'Collapsed' }
    Set-PetFace ($Mode -in @('Nap','Pat','Snack'))
    Set-PetAnimation
}
function Invoke-PetAction([string]$Action) {
    # A new activity cleanly cancels the previous one, without granting its completion reward.
    switch ($Action) {
        'Pat' {
            if ($script:petPlay.mode -eq 'Nap') { Set-PetMode 'Idle' 'Good morning, tiny universe.' 5; return }
            Set-PetMode 'Pat' 'Head pats received. Heart: very full.' 4
            Show-PetParticles ([char]0x2665).ToString(); Add-PetBond 1
        }
        'Cookie' { Set-PetMode 'Snack' 'Crunch! Tastes like a very small galaxy.' 5 ([char]0x2605).ToString(); Show-PetParticles ([char]0x2726).ToString() '#FFE4A5'; Add-PetBond 2 }
        'Berry' { Set-PetMode 'Snack' 'A moon berry! Perfectly orbit-sized.' 5 ([char]0x25CF).ToString(); Show-PetParticles ([char]0x2665).ToString() '#D0BAFF'; Add-PetBond 2 }
        'Tea' { Set-PetMode 'Snack' 'Cloud tea. A warm hug in a tiny cup.' 5 ([char]0x2615).ToString(); Add-PetBond 2 }
        'Dance' { Set-PetMode 'Dance' 'No thoughts. Just extremely tiny disco.' 9 ([char]0x266B).ToString(); Show-PetParticles ([char]0x266A).ToString() '#C6E8FF'; Add-PetBond 2 }
        'Nap' {
            if ($script:petPlay.mode -eq 'Nap') { Set-PetMode 'Idle' 'That was a very productive dream.' 5 }
            else { Set-PetMode 'Nap' 'Dreaming of electric sheep. Tap to wake.' 120 'z Z'; Add-PetBond 1 }
        }
        'Game' {
            $script:petPlay.score=0; $script:petPlay.lastSecond=-1
            Set-PetMode 'Game' 'Pop the bubbles! 20 seconds to play.' 20
            Move-PetBubble
        }
        'Adventure' {
            Set-PetMode 'Adventure' 'Searching the sofa galaxy for treasure...' 12 ([char]0x2726).ToString()
            $script:petPlay.lastSecond=-1
        }
        'Fortune' {
            $choices=@(0..($script:petFortunes.Count-1) | Where-Object { $_ -ne $script:petPlay.lastFortune })
            $script:petPlay.lastFortune=Get-Random -InputObject $choices
            Set-PetMode 'Fortune' $script:petFortunes[$script:petPlay.lastFortune] 12 ([char]0x2727).ToString()
            Show-PetParticles ([char]0x2727).ToString() '#DCCBFF'
        }
        'Cancel' { Set-PetMode 'Idle' 'Happy just hanging out with you.' 5 }
    }
}
function Move-PetBubble {
    $canvas=$script:petWindow.FindName('PetBubbles')
    # Only one target exists at a time; it stays still and is easy to click at every scale.
    $button=$canvas.Children[0]
    [Windows.Controls.Canvas]::SetLeft($button,(Get-Random -Minimum 4 -Maximum 182))
    [Windows.Controls.Canvas]::SetTop($button,(Get-Random -Minimum 3 -Maximum 86))
}
function Invoke-PetBubble {
    if ($script:petPlay.mode -ne 'Game') { return }
    if ([DateTime]::UtcNow -ge $script:petPlay.until) { Update-PetPlayground; return }
    $script:petPlay.score++
    $script:petWindow.FindName('PetCaption').Text="Pop! $($script:petPlay.score) bubbles / best $($script:companionState.play.best)"
    Move-PetBubble
}
function Update-PetPlayground([DateTime]$Now=[DateTime]::UtcNow) {
    if (-not $script:petPlay) { return }
    Set-PetAnimation
    if ($Now -ge $script:petPlay.particlesUntil) { $script:petArt.FindName('BuddyParticles').Children.Clear() }
    $mode=$script:petPlay.mode
    if ($mode -ne 'Idle' -and $Now -ge $script:petPlay.until) {
        switch ($mode) {
            'Game' {
                $score=$script:petPlay.score
                $script:companionState.play.best=[Math]::Max($score,$script:companionState.play.best)
                Add-PetBond ([Math]::Min(8,$score))
                Set-PetMode 'Idle' "You popped $score bubbles! Best: $($script:companionState.play.best)." 6
            }
            'Adventure' {
                $missing=@($script:petSouvenirs | Where-Object { $_ -notin $script:companionState.play.souvenirs })
                if ($missing.Count) {
                    $found=Get-Random -InputObject $missing
                    $script:companionState.play.souvenirs+=@($found)
                    $message="Found: $found! $($script:companionState.play.souvenirs.Count)/6 treasures."
                } else { $message='Visited the moon. Your collection is complete!' }
                Add-PetBond 4
                Set-PetMode 'Idle' $message 8
                Show-PetParticles ([char]0x2726).ToString() '#FFE4A5'
            }
            'Nap' { Set-PetMode 'Idle' 'Back from the land of tiny dreams.' 5 }
            default { Set-PetMode 'Idle' 'Happy just hanging out with you.' 5 }
        }
    } elseif ($mode -in @('Game','Adventure')) {
        $remaining=[int][Math]::Ceiling(($script:petPlay.until-$Now).TotalSeconds)
        if ($remaining -ne $script:petPlay.lastSecond) {
            $script:petPlay.lastSecond=$remaining
            $script:petWindow.FindName('PetCaption').Text=if ($mode -eq 'Game') { "Pop the bubbles! $remaining s / $($script:petPlay.score) popped" } else { "Exploring the sofa galaxy... back in $remaining s." }
        }
    }
    # Brief irregular blinks, with no extra timer and no blinking in reduced-motion mode.
    if ($script:petPlay.mode -in @('Idle','Dance','Adventure','Fortune','Game')) {
        $blink=$script:widgetPreferences.motion -and $Now -lt $script:petPlay.blinkUntil
        Set-PetFace $blink
        if ($Now -ge $script:petPlay.nextBlink) {
            $script:petPlay.blinkUntil=$Now.AddMilliseconds(160)
            $script:petPlay.nextBlink=$Now.AddMilliseconds((Get-Random -Minimum 3000 -Maximum 7000))
        }
    }
}
function New-PetMenuAction([string]$Label,[string]$Action) {
    $item=[Windows.Controls.MenuItem]::new(); $item.Header=$Label; $item.Tag=$Action
    $item.Add_Click({ param($sender,$e) Invoke-PetAction ([string]$sender.Tag); $e.Handled=$true })
    return $item
}
function Initialize-PetPlayground {
    $script:petPlay=@{ mode='Idle'; until=[DateTime]::MinValue; particlesUntil=[DateTime]::MinValue; nextBlink=[DateTime]::UtcNow.AddSeconds(3); blinkUntil=[DateTime]::MinValue; animationKey=''; score=0; lastSecond=-1; lastFortune=-1 }
    [xml]$buttonStyle=@'
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
 <Setter Property="Foreground" Value="#E2EFFF"/><Setter Property="Background" Value="#DE263C59"/><Setter Property="FontSize" Value="10"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Margin" Value="2,0"/>
 <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="Surface" Background="{TemplateBinding Background}" BorderBrush="#507599C3" BorderThickness="1" CornerRadius="8" Padding="6,3"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Surface" Property="Background" Value="#EF416087"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="Surface" Property="Background" Value="#EF567DA5"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="Surface" Property="BorderBrush" Value="#E2FFFF"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
</Style>
'@
    $style=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($buttonStyle))
    foreach ($name in @('PetPatButton','PetTreatButton','PetPlayButton')) { $script:petWindow.FindName($name).Style=$style }
    $script:petWindow.FindName('PetPatButton').Add_Click({ Invoke-PetAction 'Pat' })
    $script:petWindow.FindName('PetTreatButton').Add_Click({ Invoke-PetAction 'Cookie' })
    $script:petWindow.FindName('PetPlayButton').Add_Click({ $script:petWindow.ContextMenu.PlacementTarget=$script:petWindow.FindName('PetPlayButton'); $script:petWindow.ContextMenu.Placement='Top'; $script:petWindow.ContextMenu.IsOpen=$true })
    [xml]$bubbleXaml=@'
<Button xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Width="34" Height="34" Cursor="Hand" ToolTip="Pop me!" AutomationProperties.Name="Pop bubble">
 <Button.Template><ControlTemplate TargetType="Button"><Grid><Ellipse x:Name="Orb" Stroke="#DCDEFFFF" StrokeThickness="1.5"><Ellipse.Fill><RadialGradientBrush GradientOrigin="0.25,0.2"><GradientStop Color="#F0CDFDFF" Offset="0"/><GradientStop Color="#B67AA0DF" Offset="0.5"/><GradientStop Color="#BCA9D6F4" Offset="1"/></RadialGradientBrush></Ellipse.Fill></Ellipse><Ellipse Width="8" Height="4" Fill="#C0FFFFFF" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="8,6,0,0"/></Grid><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Orb" Property="Stroke" Value="White"/><Setter TargetName="Orb" Property="StrokeThickness" Value="3"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Button.Template>
</Button>
'@
    $bubble=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($bubbleXaml))
    $bubble.Add_Click({ param($sender,$e) Invoke-PetBubble; $e.Handled=$true })
    [void]$script:petWindow.FindName('PetBubbles').Children.Add($bubble)
    $play=[Windows.Controls.MenuItem]::new(); $play.Header='Play with buddy'
    foreach ($entry in @(@('Head pats','Pat'),@('Tiny disco','Dance'),@('Nap / wake up','Nap'),@('Bubble pop - 20 seconds','Game'),@('Sofa galaxy adventure','Adventure'),@('A tiny fortune','Fortune'),@('Finish playing','Cancel'))) { [void]$play.Items.Add((New-PetMenuAction $entry[0] $entry[1])) }
    $treats=[Windows.Controls.MenuItem]::new(); $treats.Header='Share a treat'
    foreach ($entry in @(@('Star cookie','Cookie'),@('Moon berry','Berry'),@('Cloud tea','Tea'))) { [void]$treats.Items.Add((New-PetMenuAction $entry[0] $entry[1])) }
    $script:petHatMenu=[Windows.Controls.MenuItem]::new(); $petHatMenu.Header='Wardrobe'
    $script:petPaletteMenu=[Windows.Controls.MenuItem]::new(); $petPaletteMenu.Header='Colors'
    foreach ($group in @(@($petHatMenu,'hat',@('None','Sprout','Crown','Space cap')),@($petPaletteMenu,'palette',@($script:petPalettes.Keys)))) {
        foreach ($value in $group[2]) {
            $item=[Windows.Controls.MenuItem]::new(); $item.Header=$value; $item.Tag=@{ key=$group[1]; value=$value }; $item.IsCheckable=$true
            $item.Add_Click({ param($sender,$e) $script:companionState.play[$sender.Tag.key]=$sender.Tag.value; Update-PetLook; Save-CompanionState; $e.Handled=$true })
            [void]$group[0].Items.Add($item)
        }
    }
    $script:petCollectionMenu=[Windows.Controls.MenuItem]::new(); $petCollectionMenu.Header='Treasure shelf'
    $menu=$script:petWindow.ContextMenu
    $index=0
    foreach ($item in @($play,$treats,$petHatMenu,$petPaletteMenu,$petCollectionMenu,[Windows.Controls.Separator]::new())) { $menu.Items.Insert($index,$item); $index++ }
    $menu.Add_Opened({
        foreach ($group in @($script:petHatMenu,$script:petPaletteMenu)) { foreach ($item in $group.Items) { $item.IsChecked=$script:companionState.play[$item.Tag.key] -eq $item.Tag.value } }
        $script:petCollectionMenu.Items.Clear()
        foreach ($name in $script:petSouvenirs) {
            $item=[Windows.Controls.MenuItem]::new(); $item.Header=if ($name -in $script:companionState.play.souvenirs) { "Found / $name" } else { "Unexplored / $name" }; $item.IsEnabled=$false
            [void]$script:petCollectionMenu.Items.Add($item)
        }
    })
    Update-PetLook
}

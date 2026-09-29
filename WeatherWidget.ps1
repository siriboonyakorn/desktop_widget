# Live Bangkok conditions from Open-Meteo; uses Windows' existing .NET runtime.
Add-Type -AssemblyName System.Net.Http
[xml]$weatherXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Bangkok weather glass widget" Width="214" Height="244"
        WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True"
        Background="Transparent" ShowInTaskbar="False" ShowActivated="False"
        Opacity="0" FontFamily="Segoe UI" Foreground="White"
        TextOptions.TextRenderingMode="Grayscale" TextOptions.TextFormattingMode="Ideal">
    <Grid Margin="4,24,4,4">
        <Grid.RenderTransform><TranslateTransform x:Name="WeatherSlide" Y="-20"/></Grid.RenderTransform>
        <Border x:Name="WeatherGlass" CornerRadius="19" BorderThickness="1" Padding="15,13">
            <StackPanel>
                <TextBlock Text="BANGKOK" FontSize="11" FontWeight="SemiBold" Foreground="#DCE8FA"/>
                <Grid Margin="0,3,0,0">
                    <TextBlock x:Name="WeatherTemperature" Text="--&#xB0;" FontSize="42" FontWeight="Light"/>
                    <TextBlock x:Name="WeatherIcon" Text="&#x2601;" FontFamily="Segoe UI Symbol" FontSize="31" HorizontalAlignment="Right" VerticalAlignment="Center" Foreground="#D4EAFF"/>
                </Grid>
                <TextBlock x:Name="WeatherCondition" Text="Loading weather..." FontSize="12" TextTrimming="CharacterEllipsis"/>
                <TextBlock x:Name="WeatherFeels" Text="Feels like --&#xB0;C" FontSize="10" Foreground="#C7D9ED" Margin="0,4,0,9"/>
                <Border Height="1" Background="#25FFFFFF"/>
                <Grid Margin="0,9,0,8">
                    <TextBlock x:Name="WeatherHumidity" Text="Humidity --%" FontSize="10"/>
                    <TextBlock x:Name="WeatherWind" Text="-- km/h" FontSize="10" HorizontalAlignment="Right"/>
                </Grid>
                <TextBlock x:Name="WeatherUpdated" Text="Connecting..." FontSize="9" Foreground="#BBD0EB"/>
                <TextBlock FontSize="9" Margin="0,2,0,0"><Hyperlink x:Name="WeatherSource" Foreground="#BBD0EB" TextDecorations="None" ToolTip="Weather data by Open-Meteo">Open-Meteo</Hyperlink></TextBlock>
            </StackPanel>
        </Border>
        <Border Margin="2" CornerRadius="17" BorderBrush="#28FFFFFF" BorderThickness="0.7" IsHitTestVisible="False"/>
    </Grid>
</Window>
'@
$weatherWindow = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($weatherXaml))
$glassSource = $cornerTemplate.FindName('CalendarCard')
$weatherWindow.FindName('WeatherGlass').Background = $glassSource.Background.Clone()
$weatherWindow.FindName('WeatherGlass').BorderBrush = $glassSource.BorderBrush.Clone()
$script:cornerCards += @{ Name = 'Weather'; Window = $weatherWindow; Slide = $weatherWindow.FindName('WeatherSlide'); Handle = [IntPtr]::Zero; Visible = $false; LastNear = [DateTime]::MinValue; Offset = 10; Anchor = 'Right' }
$weatherTemperature = $weatherWindow.FindName('WeatherTemperature')
$weatherIcon = $weatherWindow.FindName('WeatherIcon')
$weatherCondition = $weatherWindow.FindName('WeatherCondition')
$weatherFeels = $weatherWindow.FindName('WeatherFeels')
$weatherHumidity = $weatherWindow.FindName('WeatherHumidity')
$weatherWind = $weatherWindow.FindName('WeatherWind')
$weatherUpdated = $weatherWindow.FindName('WeatherUpdated')
$weatherWindow.FindName('WeatherSource').Add_Click({
    [Diagnostics.Process]::Start('https://open-meteo.com/') | Out-Null
})
$script:weatherClient = [Net.Http.HttpClient]::new()
$script:weatherClient.Timeout = [TimeSpan]::FromSeconds(15)
$script:weatherTask = $null
$script:weatherNextFetch = [DateTime]::MinValue
$script:weatherLastUpdated = $null
$script:weatherError = $null
$script:weatherUrl = 'https://api.open-meteo.com/v1/forecast?latitude=13.7563&longitude=100.5018&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m&daily=sunrise,sunset&timezone=Asia%2FBangkok&temperature_unit=celsius&wind_speed_unit=kmh&forecast_days=2'

function Get-WeatherDescription([int]$Code) {
    switch ($Code) {
        0 { 'Clear sky' }
        1 { 'Mostly clear' }
        2 { 'Partly cloudy' }
        3 { 'Overcast' }
        { $_ -in 45,48 } { 'Foggy' }
        { $_ -in 51,53,55 } { 'Drizzle' }
        { $_ -in 56,57 } { 'Freezing drizzle' }
        61 { 'Light rain' }
        63 { 'Rain' }
        65 { 'Heavy rain' }
        { $_ -in 66,67 } { 'Freezing rain' }
        { $_ -in 71,73,75,77 } { 'Snow' }
        { $_ -in 80,81,82 } { 'Rain showers' }
        { $_ -in 85,86 } { 'Snow showers' }
        { $_ -in 95,96,99 } { 'Thunderstorms' }
        default { 'Conditions unavailable' }
    }
}

function Set-WeatherData($Data) {
    $current = $Data.current
    foreach ($field in @('temperature_2m','apparent_temperature','relative_humidity_2m','wind_speed_10m','weather_code','time')) {
        if ($null -eq $current.$field) { throw "Missing weather field: $field" }
    }
    $degree = [char]0x00B0
    $script:weatherData = $Data
    $fahrenheit = $script:widgetPreferences -and $script:widgetPreferences.weatherUnits -eq 'Fahrenheit'
    $temperature = [double]$current.temperature_2m; $feels = [double]$current.apparent_temperature
    $wind = [double]$current.wind_speed_10m; $unit = 'C'; $speedUnit = 'km/h'
    if ($fahrenheit) { $temperature = $temperature * 1.8 + 32; $feels = $feels * 1.8 + 32; $wind /= 1.609344; $unit = 'F'; $speedUnit = 'mph' }
    $weatherTemperature.Text = "{0}$degree" -f [Math]::Round($temperature)
    $weatherCondition.Text = Get-WeatherDescription ([int]$current.weather_code)
    $weatherCondition.ToolTip = $weatherCondition.Text
    $weatherFeels.Text = "Feels like {0}${degree}$unit" -f [Math]::Round($feels)
    $weatherHumidity.Text = "Humidity $($current.relative_humidity_2m)%"
    $weatherWind.Text = '{0} {1} wind' -f [Math]::Round($wind), $speedUnit
    $code = [int]$current.weather_code
    $symbol = if ($code -ge 95) { 0x26A1 } elseif ($code -ge 51) { 0x2602 } elseif ($code -ge 2) { 0x2601 } elseif ($current.is_day -eq 0) { 0x263D } else { 0x2600 }
    $weatherIcon.Text = [string][char]$symbol
    $script:weatherLastUpdated = [DateTime]::Parse($current.time, [Globalization.CultureInfo]::InvariantCulture)
    $unitLabel = if ($fahrenheit) { 'Fahrenheit' } else { 'Celsius' }
    $weatherUpdated.Text = 'Bangkok {0:HH:mm} | {1}' -f $script:weatherLastUpdated, $unitLabel
    $weatherUpdated.ToolTip = 'Conditions at {0:yyyy-MM-dd HH:mm} Bangkok time. Refreshes every 10 minutes.' -f $script:weatherLastUpdated
}

function Update-Weather {
    if ($Preview) { return }
    if ($script:weatherTask -and $script:weatherTask.IsCompleted) {
        try {
            if ($script:weatherTask.IsFaulted -or $script:weatherTask.IsCanceled) { throw 'Weather request failed' }
            $data = $script:weatherTask.Result | ConvertFrom-Json
            Set-WeatherData $data
            $script:weatherError = $null
            $script:weatherNextFetch = [DateTime]::Now.AddMinutes(10)
        } catch {
            $script:weatherError = $_.Exception.Message
            if ($script:weatherLastUpdated) {
                $weatherUpdated.Text = 'Offline | last data {0:HH:mm}' -f $script:weatherLastUpdated
            } else {
                $weatherCondition.Text = 'Weather unavailable'
                $weatherUpdated.Text = 'Retrying in 1 minute'
            }
            $weatherUpdated.ToolTip = 'Could not refresh from Open-Meteo. Check your internet connection.'
            $script:weatherNextFetch = [DateTime]::Now.AddMinutes(1)
        } finally {
            $script:weatherTask.Dispose()
            $script:weatherTask = $null
        }
    }
    if (-not $script:weatherTask -and [DateTime]::Now -ge $script:weatherNextFetch) {
        $script:weatherTask = $script:weatherClient.GetStringAsync($script:weatherUrl)
    }
}

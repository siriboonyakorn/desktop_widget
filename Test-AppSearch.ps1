$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ClockWidget.ps1') -Preview
try {
 $apps=@([pscustomobject]@{Name='Google Chrome';Target='chrome';Kind='App'},[pscustomobject]@{Name='Chrome';Target='short';Kind='App'},[pscustomobject]@{Name='Visual Studio Code';Target='code';Kind='App'})
 if(@(Find-LauncherApps $apps 'CHROME').Count -ne 2){throw 'Case-insensitive matching failed'}
 if((Find-LauncherApps $apps 'Chrome')[0].Name -ne 'Chrome'){throw 'Exact-match ranking failed'}
 if(@(Find-LauncherApps $apps 'visual code').Count -ne 1){throw 'Multiword matching failed'}
 if(@(Find-LauncherApps $apps 'missing').Count){throw 'No-match search failed'}
 $script:appSearchClosing=$false
 $script:appSearchApps=$apps
 $script:appSearchQuery.Text='Chrome'
 Update-AppSearchResults
 $appSearchWindow.Show();$appSearchWindow.UpdateLayout()
 if($appSearchResults.Items.Count -ne 2 -or $appSearchResults.SelectedIndex -ne 0){throw 'Results binding failed'}
 $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(1240,[int]($appSearchWindow.ActualHeight*2),192,192,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($appSearchWindow)
 $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
 $stream=[IO.File]::Create((Join-Path $PSScriptRoot 'preview-app-search.png'));try{$encoder.Save($stream)}finally{$stream.Dispose()}
 Start-AppSearchIndex
 $deadline=[DateTime]::Now.AddSeconds(20)
 while(-not $script:appSearchIndexJob.IsCompleted -and [DateTime]::Now -lt $deadline){Start-Sleep -Milliseconds 100}
 if(-not $script:appSearchIndexJob.IsCompleted){throw 'App indexing timed out'}
 $indexed=@($script:appSearchIndexWorker.EndInvoke($script:appSearchIndexJob));$script:appSearchIndexWorker.Dispose();$script:appSearchIndexWorker=$null;$script:appSearchIndexJob=$null
 if(-not $indexed.Count){throw 'No installed apps were indexed'}
 if(@($indexed | Where-Object {-not $_.Name -or -not $_.Target -or $_.Kind -notin @('App','Shortcut')}).Count){throw 'Invalid index entry'}
 $source=[Windows.Interop.HwndSource]::FromHwnd(([Windows.Interop.WindowInteropHelper]::new($appSearchWindow)).Handle)
 $h=$source.Handle
 # Use a different chord for registration tests so a live widget is undisturbed.
 if(-not [AppSearchNative]::RegisterHotKey($h,0x5144,0x4006,0x79)){throw 'Test hotkey registration failed'}
 if(-not [AppSearchNative]::UnregisterHotKey($h,0x5144)){throw 'Test hotkey cleanup failed'}
 Write-Output ('Search ranking, WPF results/rendering, '+$indexed.Count+' installed app entries, and hotkey registration/cleanup passed.')
}finally{Stop-AppSearch;foreach($entry in $script:cornerCards){$entry.Window.Close()}}


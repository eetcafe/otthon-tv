$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../windows/Core.ps1')
function Check([bool]$Condition,[string]$Name){if(!$Condition){throw "FAIL: $Name"};Write-Host "PASS: $Name"}
$script:DataDir=Join-Path ([IO.Path]::GetTempPath()) ('Otthon-TV-test-'+[guid]::NewGuid().ToString());New-Item -Force -ItemType Directory $script:DataDir | Out-Null
$script:DeviceKey='mock-device';$script:Model='MIBOX3'
$system=@('com.miui.tv.analytics','com.google.android.gms','com.google.android.tvlauncher')
$downloaded=@('com.spotify.tv.android','com.vendor.home','hu.otthon.tv','com.google.android.gms')
$allowed=@(Get-CleanupChoices ($system+$downloaded) $system $downloaded 'Xiaomi' @('com.vendor.home'))
Check ($allowed.Count -eq 2) 'Only eligible system and user apps offered; Home and core protected'
Check (@($allowed | Where-Object {$_.Recommended}).Count -eq 1) 'Only known analytics recommended in this fixture'
$philips=@(Get-CleanupChoices $system $system @() 'Philips' @())
Check ($philips.Count -eq 0) 'Xiaomi-specific profile excluded on Philips'
foreach($bad in @('com.google.android.gms','com.vendor.home','com.foo;reboot','hu.otthon.tv','com.unknown.system')){
 $blocked=$false;try{Assert-Removable $bad $allowed @('com.vendor.home')}catch{$blocked=$true};Check $blocked "Removal blocked: $bad"
}
Check ((Quote-NativeArgument 'C:\My Files\App\') -ceq '"C:\My Files\App\\"') 'Windows path with spaces and trailing slash is escaped'
$parsed=@(Convert-PackageList "package:com.example.one`nwarning garbage`npackage:com.example.two`npackage:com.example.one")
Check ($parsed.Count -eq 2) 'Package list ignores noise and duplicates'
$script:Installed=@('com.miui.tv.analytics');$script:Enabled=@();$script:FailRemove=$false;$script:Calls=@();$script:WrongDevice=$false
function Assert-Device { if($script:WrongDevice){throw 'Device changed'} }
function Get-Installed { return $script:Installed }
function Tv([string[]]$Arguments){
 $cmd=$Arguments -join ' ';$script:Calls+=@($cmd)
 if($cmd -eq 'pm list packages -e --user 0'){return ($script:Enabled | ForEach-Object {'package:'+$_}) -join "`n"}
 if($cmd -like 'pm uninstall *'){
  if($script:FailRemove){return 'Failure [DELETE_FAILED_INTERNAL_ERROR]'}
  $script:Installed=@($script:Installed | Where-Object {$_ -ne $Arguments[-1]});return 'Success'
 }
 if($cmd -like 'cmd package install-existing *'){$script:Installed+=@($Arguments[-1]);return 'Package installed for user: 0'}
 if($cmd -like 'pm disable-user *' -or $cmd -like 'pm enable *'){return 'state updated'}
 throw "Unexpected command $cmd"
}
$script:State=[pscustomobject]@{OldHome='';Removed=@();Model='MIBOX3'}
$item=$allowed | Where-Object {$_.Package -eq 'com.miui.tv.analytics'}
Remove-SelectedPackage $item $allowed @('com.vendor.home')
Check ($script:Installed.Count -eq 0 -and $script:State.Removed[0].Status -eq 'removed') 'Removal success is verified and journaled'
Check (!$script:State.Removed[0].WasEnabled) 'Prior disabled state is preserved in journal'
Restore-SelectedPackage $script:State.Removed[0]
Check ($script:Installed -contains 'com.miui.tv.analytics' -and $script:State.Removed.Count -eq 0) 'System package restored and journal entry cleared'
Check ($script:Calls -contains 'pm disable-user --user 0 com.miui.tv.analytics') 'Restore preserves prior disabled state'
$script:FailRemove=$true;$failed=$false
try{Remove-SelectedPackage $item $allowed @()}catch{$failed=$true}
Check ($failed -and $script:State.Removed[0].Status -eq 'pending') 'Failed removal is not marked successful; recovery record retained'
$script:WrongDevice=$true;$script:Calls=@();$failed=$false
try{Remove-SelectedPackage $item $allowed @()}catch{$failed=$true}
Check ($failed -and $script:Calls.Count -eq 0) 'Device change blocks mutation before package commands'
$script:WrongDevice=$false
$third=[pscustomobject]@{Package='com.spotify.tv.android';Name='Spotify';System=$false;WasEnabled=$true;Status='removed'}
$failed=$false;try{Restore-SelectedPackage $third}catch{$failed=$true}
Check $failed 'Missing downloaded APK never claims automatic restore'
Write-Host 'All cleanup safety and recovery tests passed.'

# Regression: Android's --brief output indents component names.
. (Join-Path $PSScriptRoot '../windows/Core.ps1')
$components=@(Convert-Components "2 activities found:`r`n  com.google.android.tvlauncher/.MainActivity`r`n    hu.otthon.tv/hu.otthon.tv.MainActivity`r`n")
Check ($components.Count -eq 2) 'Indented Android HOME components are parsed'
$parsed=@(Convert-PackageList "  package:com.miui.tv.analytics`r`n\tpackage:com.google.android.feedback".Replace('\t',"`t"))
Check ($parsed.Count -eq 2) 'Package list tolerates leading whitespace and CRLF'
$script:HomeFixture="2 activities found:`n  com.google.android.tvlauncher/.MainActivity`n  hu.otthon.tv/.MainActivity"
function Tv([string[]]$Arguments){return $script:HomeFixture}
$homes=@(Get-HomePackages)
Check ($homes.Count -eq 2 -and $homes -contains 'com.google.android.tvlauncher') 'Actual HOME query accepts indented shell output'
$script:HomeFixture='Unsupported command';$blocked=$false
try{Get-HomePackages}catch{$blocked=$true}
Check $blocked 'Unknown HOME query fails closed for deletion'
$inventory=[pscustomobject]@{
 Installed=@('com.miui.tv.analytics','com.google.android.feedback','com.google.android.gms')
 Disabled=@('com.miui.tv.analytics','com.google.android.feedback','com.google.android.gms')
 System=@('com.miui.tv.analytics','com.google.android.feedback','com.google.android.gms')
 KnownSystem=@('com.miui.tv.analytics','com.google.android.feedback','com.google.android.gms','com.google.android.music')
}
$recovery=@(Get-RecoveryChoices $inventory @() 'Xiaomi')
Check ($recovery.Count -eq 3) 'Recovery discovers old disabled apps and removed system apps without journal'
Check (@($recovery | Where-Object {$_.Package -eq 'com.google.android.gms'}).Count -eq 0) 'Recovery does not invent changes to critical system services'
$journal=@([pscustomobject]@{Package='com.miui.tv.analytics';Name='Analytics';System=$true;WasEnabled=$false;Status='removed'})
$recovery=@(Get-RecoveryChoices $inventory $journal 'Xiaomi')
Check ($recovery.Count -eq 3) 'Recovery deduplicates discovered and journaled packages'
Check (!($recovery | Where-Object {$_.Package -eq 'com.miui.tv.analytics'}).WasEnabled) 'Journaled original state wins over discovery'
$script:InventoryCalls=@()
function Tv([string[]]$Arguments){
 $c=$Arguments -join ' ';$script:InventoryCalls+=@($c)
 switch($c){
  'pm list packages --user 0' {return 'unrecognized output'}
  'cmd package list packages --user 0' {return "package:com.example.app`npackage:com.google.android.gms"}
  'pm list packages -s --user 0' {return 'package:com.google.android.gms'}
  'pm list packages -3 --user 0' {return 'package:com.example.app'}
  'pm list packages -d --user 0' {return ''}
  'pm list packages -s -u --user 0' {return 'package:com.google.android.gms'}
  default {throw "Unexpected: $c"}
 }
}
$read=Get-PackageInventory
Check ($read.Installed.Count -eq 2 -and $script:InventoryCalls -contains 'cmd package list packages --user 0') 'Inventory retries through cmd package instead of displaying empty data'
Write-Host 'All 2.1 list and recovery regressions passed.'

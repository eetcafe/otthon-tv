param([switch]$UiSmokeTest)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
try {
. (Join-Path $PSScriptRoot 'Core.ps1')
$script:DataDir=if($UiSmokeTest){Join-Path ([IO.Path]::GetTempPath()) ('otthon-ui-'+[guid]::NewGuid().ToString())}else{Join-Path $env:LOCALAPPDATA 'Otthon-TV-Kezelo'}
New-Item -ItemType Directory -Force -Path $script:DataDir | Out-Null
$script:SessionLog=Join-Path $script:DataDir ('kezelo-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+$PID+'.log')
function Write-SessionLog([string]$Text){try{Add-Content -LiteralPath $script:SessionLog -Value ((Get-Date -Format 'HH:mm:ss.fff')+' '+$Text) -Encoding UTF8}catch{}}
$script:AdbTrace={param($Text) Write-SessionLog $Text}
Write-SessionLog 'Kezelő 2.1.5 indul.'
$script:ReportedErrors=0

$script:Adb=Join-Path $env:LOCALAPPDATA 'Xiaomi-TV-Helper\platform-tools\adb.exe'
$script:DeviceKey='';$script:Target='';$script:Model='';$script:Manufacturer='';$script:State=$null
$script:Allowed=@();$script:Homes=@();$script:Busy=$false;$script:Recovery=@();$script:HomesVerified=$false
$script:PumpUi={ [Windows.Forms.Application]::DoEvents() }
$script:ExpectedHash='d97196a4ae343ad86070caf3c47f47eecd3454002b888807c53aa2707296a95b'
$form=New-Object Windows.Forms.Form
$form.Text='Otthon TV – Windows kezelő 2.1.5'
$form.Size=New-Object Drawing.Size(1100,840)
$form.MinimumSize=New-Object Drawing.Size(1100,840)
$form.StartPosition='CenterScreen'
$form.Font=New-Object Drawing.Font('Segoe UI',10)
$form.BackColor=[Drawing.Color]::FromArgb(16,24,38)
$form.ForeColor=[Drawing.Color]::White
$heading=New-Object Windows.Forms.Label
$heading.Text='OTTHON TV';$heading.Location=New-Object Drawing.Point(24,18);$heading.Size=New-Object Drawing.Size(260,36)
$heading.Font=New-Object Drawing.Font('Segoe UI',22,[Drawing.FontStyle]::Bold);$form.Controls.Add($heading)
$subtitle=New-Object Windows.Forms.Label
$subtitle.Text='Telepítés, saját kezdőképernyő és alkalmazástakarítás – parancsok nélkül.'
$subtitle.Location=New-Object Drawing.Point(26,61);$subtitle.Size=New-Object Drawing.Size(1000,26);$form.Controls.Add($subtitle)
$ip=New-Object Windows.Forms.TextBox
$ip.Text='';$ip.AccessibleName='TV IP-címe';$ip.Location=New-Object Drawing.Point(26,102);$ip.Size=New-Object Drawing.Size(175,30);$form.Controls.Add($ip)
$script:ActionButtons=@()
function Add-Button([string]$Title,[int]$X,[int]$Y,[int]$Width,[scriptblock]$Action) {
    $b=New-Object Windows.Forms.Button;$b.Text=$Title;$b.Location=New-Object Drawing.Point($X,$Y);$b.Size=New-Object Drawing.Size($Width,38)
    $b.FlatStyle='Flat';$b.BackColor=[Drawing.Color]::FromArgb(37,57,76);$b.ForeColor=[Drawing.Color]::White
    $b.Tag=$Action;$b.Add_Click({param($sender,$eventArgs) Invoke-UiAction $sender.Tag});$form.Controls.Add($b);$script:ActionButtons+=@($b);return $b
}
$status=New-Object Windows.Forms.Label
$status.Text='Írd be a tévé IP-címét. 1. Csatlakozz  →  2. Telepíts  →  3. Állítsd be kezdőképernyőnek'
$status.Location=New-Object Drawing.Point(26,154);$status.Size=New-Object Drawing.Size(1010,46);$form.Controls.Add($status)
$note=New-Object Windows.Forms.Label
$note.Text='A Home gomb és a teljes újraindítás az új főképernyőre vezet. Készenlétből a legutóbbi app is folytatódhat.'
$note.Location=New-Object Drawing.Point(26,742);$note.Size=New-Object Drawing.Size(1020,40);$form.Controls.Add($note)
$tabs=New-Object Windows.Forms.TabControl
$tabs.Location=New-Object Drawing.Point(26,290);$tabs.Size=New-Object Drawing.Size(1030,290);$form.Controls.Add($tabs)
$tabClean=New-Object Windows.Forms.TabPage;$tabClean.Text='Eltávolítható alkalmazások';[void]$tabs.TabPages.Add($tabClean)
$tabRestore=New-Object Windows.Forms.TabPage;$tabRestore.Text='Visszaállítás';[void]$tabs.TabPages.Add($tabRestore)
function New-AppList($Parent) {
    $list=New-Object Windows.Forms.ListView;$list.Dock='Fill';$list.View='Details';$list.CheckBoxes=$true;$list.FullRowSelect=$true;$list.GridLines=$true
    [void]$list.Columns.Add('Alkalmazás / hatás',455);[void]$list.Columns.Add('Csomagnév',330);[void]$list.Columns.Add('Típus',190)
    $Parent.Controls.Add($list);return $list
}
$clean=New-AppList $tabClean;$restore=New-AppList $tabRestore
$log=New-Object Windows.Forms.TextBox
$log.Location=New-Object Drawing.Point(26,638);$log.Size=New-Object Drawing.Size(1030,95);$log.Multiline=$true;$log.ReadOnly=$true;$log.ScrollBars='Vertical'
$log.BackColor=[Drawing.Color]::FromArgb(8,14,24);$log.ForeColor=[Drawing.Color]::FromArgb(154,224,200);$form.Controls.Add($log)
function Log([string]$Message) {
    Write-SessionLog $Message
    if(!$log.IsDisposed){$log.AppendText((Get-Date -Format 'HH:mm:ss')+'  '+$Message+"`r`n")}
}
function Report-OperationError($Record) {
    $script:ReportedErrors++
    $message=$Record.Exception.Message
    Write-SessionLog ($Record | Out-String)
    Write-SessionLog $Record.ScriptStackTrace
    Log ('Hiba: '+$message)
    if(!$UiSmokeTest -and !$form.IsDisposed){[void][Windows.Forms.MessageBox]::Show($form,($message+"`r`n`r`nHibanapló: "+$script:SessionLog),'A művelet nem sikerült','OK','Warning')}
}
function Invoke-UiAction([scriptblock]$Action) {
    try { & $Action } catch { Report-OperationError $_ }
}
function Work([scriptblock]$Action) {
    if ($script:Busy) { return }
    try {
        $script:Busy=$true
        foreach($b in $script:ActionButtons){if(!$b.IsDisposed){$b.Enabled=$false}}
        $ip.Enabled=$false;$tabs.Enabled=$false;$form.UseWaitCursor=$true
        & $Action
    } catch { Report-OperationError $_ }
    finally {
        $script:Busy=$false
        if(!$form.IsDisposed){$form.UseWaitCursor=$false;foreach($b in $script:ActionButtons){if(!$b.IsDisposed){$b.Enabled=$true}};$ip.Enabled=$true;$tabs.Enabled=$true}
    }
}
function Ensure-Adb {
    $bundled=Join-Path $PSScriptRoot 'platform-tools\\adb.exe'
    if (Test-Path -LiteralPath $bundled) { $script:Adb=$bundled;return }
    throw 'Az ADB nem található a csomagban. Töltsd le újra az Otthon TV Windows ZIP-et, majd csomagold ki teljesen.'
    if (Test-Path -LiteralPath $script:Adb) { return }
    $cached=Join-Path $script:DataDir 'platform-tools\adb.exe'
    if (Test-Path -LiteralPath $cached) { $script:Adb=$cached;return }
    Log 'A Google hivatalos ADB eszközének letöltése...';[Windows.Forms.Application]::DoEvents()
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $zip=Join-Path $script:DataDir 'platform-tools.zip'
    Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip -UseBasicParsing -TimeoutSec 90
    Expand-Archive -LiteralPath $zip -DestinationPath $script:DataDir -Force
    $script:Adb=Join-Path $script:DataDir 'platform-tools\adb.exe'
    if (!(Test-Path -LiteralPath $script:Adb)) { throw 'Az ADB letöltése vagy kicsomagolása nem sikerült.' }
}
function Fill-Restore {
    $restore.Items.Clear()
    foreach($entry in @($script:Recovery)) {
        $item=New-Object Windows.Forms.ListViewItem($entry.Name)
        [void]$item.SubItems.Add($entry.Package)
        $kind=if($entry.Status -eq 'disabled'){'Letiltva – újra engedélyezhető'}elseif($entry.System){'Rendszerből visszaállítható'}else{'Újratelepítés szükséges'}
        [void]$item.SubItems.Add($kind);$item.Tag=$entry;[void]$restore.Items.Add($item)
    }
    if (!$restore.Items.Count) {
        $item=New-Object Windows.Forms.ListViewItem('Nincs felismerhető letiltott vagy eltávolított app. Ez normális, ha még nem takarítottál.')
        $item.Tag=$null;[void]$restore.Items.Add($item)
    }
}
function Refresh-Apps {
    if (!$script:Target) { throw 'Először csatlakozz a készülékhez.' }
    $inventory=Get-PackageInventory
    $script:HomesVerified=$false;$script:Homes=@();$homeError=''
    try{$script:Homes=@(Get-HomePackages);$script:HomesVerified=$true}catch{$homeError=$_.Exception.Message;Log $homeError}
    $script:Allowed=@(Get-CleanupChoices $inventory.Installed $inventory.System $inventory.Downloaded $script:Manufacturer $script:Homes)
    $clean.Items.Clear()
    foreach($entry in $script:Allowed) {
        $name=if($entry.Recommended){'[Javasolt] '+$entry.Name}else{$entry.Name}
        $item=New-Object Windows.Forms.ListViewItem($name);[void]$item.SubItems.Add($entry.Package)
        $kind=if($inventory.Disabled -contains $entry.Package){'Jelenleg letiltva'}elseif($entry.System){'Rendszerapp'}else{'Telepített app'}
        [void]$item.SubItems.Add($kind);$item.Tag=$entry;[void]$clean.Items.Add($item)
    }
    if (!$clean.Items.Count) {
        $item=New-Object Windows.Forms.ListViewItem('A csomaglista beolvasható, de nincs ismert eltávolítható tétel. A Diagnosztika segít ellenőrizni.')
        $item.Tag=$null;[void]$clean.Items.Add($item)
    }
    $journal=if($script:State){@($script:State.Removed)}else{@()}
    $script:Recovery=@(Get-RecoveryChoices $inventory $journal $script:Manufacturer);Fill-Restore
    if($script:DeviceKey){$inventory.Installed | Set-Content -LiteralPath (Join-Path $script:DataDir ($script:DeviceKey+'-packages.txt')) -Encoding UTF8}
    $status.Text=$script:Manufacturer+' / '+$script:Model+' – '+$inventory.Installed.Count+' csomag; '+$script:Allowed.Count+' választható; '+$script:Recovery.Count+' visszaállítható.'
    if(!$script:HomesVerified){$status.Text+=' Eltávolítás szünetel: a Home-lista ellenőrzése nem sikerült.'}
    Log $status.Text
}
function Save-Diagnostics {
    if(!$script:Target){throw 'Először csatlakozz a készülékhez.'}
    $path=Join-Path $script:DataDir ('diagnosztika-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.txt')
    $rows=New-Object System.Collections.Generic.List[string]
    foreach($command in @('pm list packages --user 0','pm list packages -s --user 0','pm list packages -3 --user 0','pm list packages -d --user 0','cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME','cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME','am get-current-user','getprop ro.build.version.sdk','pm list features')) {
        $rows.Add('> '+$command);try{$rows.Add((Tv ($command -split ' ')))}catch{$rows.Add('HIBA: '+$_.Exception.Message)}
    }
    try { $support=Get-KioskSupport; $rows.Add('Kioszk: '+$support.Code+'; '+$support.Message);$rows.Add('DeviceAdmin='+$support.DeviceAdmin+'; Owner='+$support.OwnerPackage+'; PolicyReadable='+$support.PolicyReadable) } catch { $rows.Add('Kioszk ellenőrzési hiba: '+$_.Exception.Message) }
    $rows | Set-Content -LiteralPath $path -Encoding UTF8
    Log ('Diagnosztika mentve: '+$path);Start-Process notepad.exe -ArgumentList (Quote-NativeArgument $path)
}
function Connect-TV([string]$Address) {
    $script:DeviceKey='';$script:Target='';$script:Model='';$script:Manufacturer='';$script:State=$null
    $script:Allowed=@();$script:Recovery=@();$script:Homes=@();$script:HomesVerified=$false
    $clean.Items.Clear();$restore.Items.Clear();$status.Text='Csatlakozás...'
    $parsed=$null
    if(![Net.IPAddress]::TryParse($Address.Trim(),[ref]$parsed) -or $parsed.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork){throw 'Érvényes IPv4-címet írj be, például 192.168.1.50.'}
    Log 'ADB előkészítése...';Ensure-Adb;$script:Target=$parsed.ToString()+':5555'
    [void](Invoke-Adb @('start-server') 20)
    Log ('Kapcsolódás: '+$script:Target)
    $connectText=Invoke-Adb @('connect',$script:Target) 20;Log $connectText
    $state=Get-AdbConnectionState (Invoke-Adb @('devices') 10) $script:Target
    if($state -eq 'unauthorized'){throw 'A tévén engedélyezd az USB-/hálózati hibakeresési kapcsolatot, majd kattints újra a Csatlakozásra.'}
    if($state -eq 'offline'){throw 'A készülék ADB-kapcsolata offline. Ellenőrizd a tévén a hibakeresést, majd próbáld újra.'}
    if($state -ne 'device'){throw ('Nem jött létre ADB-kapcsolat. Ellenőrizd az IP-címet, a közös hálózatot és a tévén a hibakeresést. Részlet: '+$connectText)}
    Log 'Készülékadatok olvasása...'
    $script:Model=([string](Tv @('getprop','ro.product.model'))).Trim();$script:Manufacturer=([string](Tv @('getprop','ro.product.manufacturer'))).Trim()
    $version=([string](Tv @('getprop','ro.build.version.release'))).Trim()
    $script:State=[pscustomobject]@{OldHome='';Removed=@();Model=$script:Model}
    try{$script:DeviceKey=Get-Fingerprint;Read-State}catch{Log ('Azonosítás/napló hiba; csak olvasás: '+$_.Exception.Message);$script:DeviceKey=''}
    $status.Text=$script:Manufacturer+' / '+$script:Model+' / Android '+$version+' – csatlakoztatva'
    Log $status.Text
    try{Refresh-Apps}catch{Log ('A kapcsolat él, de az alkalmazáslista nem tölthető be: '+$_.Exception.Message);throw}
}
$script:ConnectButton=Add-Button 'Csatlakozás' 215 98 145 { Work { Connect-TV $ip.Text } }
$null=Add-Button 'Launcher telepítése / frissítése' 375 98 290 { Work {
    Assert-Device;$apk=Join-Path $PSScriptRoot 'Otthon-TV.apk'
    if(!(Test-Path -LiteralPath $apk)){throw 'Az Otthon-TV.apk nincs a kezelő mellett. A teljes ZIP-et csomagold ki.'}
    if((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant() -ne $script:ExpectedHash){throw 'Az APK nem egyezik a csomag ellenőrzőösszegével. Töltsd le újra a teljes ZIP-et.'}
    Log 'Launcher telepítése...'
    $result=Invoke-Adb @('-s',$script:Target,'install','-r',$apk) 120
    if($result -notmatch '(?m)^Success\s*$'){throw $result}
    Log 'Otthon TV 2.1 telepítve. Megnyitás a tévén...';[void](Tv @('am','start','-n',$script:OwnComponent))
} }
$null=Add-Button 'Launcher megnyitása' 680 98 220 { Work { Assert-Device;Log (Tv @('am','start','-n',$script:OwnComponent)) } }
$null=Add-Button 'Alapértelmezett kezdőképernyő' 26 199 295 { Work {
    Assert-Device
    if((Get-Installed) -notcontains $script:OwnPackage){throw 'Először telepítsd a launchert.'}
    $old=Get-HomeComponent
    if($old -and $old -notmatch '^hu\.otthon\.tv/' -and $old -notmatch '^android/'){ $script:State.OldHome=$old;Save-State }
    Log (Tv @('cmd','package','set-home-activity','--user','0',$script:OwnComponent))
    $current=Get-HomeComponent
    if($current -notmatch '^hu\.otthon\.tv/'){throw 'A normál Home-váltás nem igazolt. Xiaomi készüléken próbáld a Xiaomi Home javítása gombot. Az külön jóváhagyással, visszaállítható módon kapcsolja ki az aktív gyári launchert.'}
    [void](Tv @('input','keyevent','3'));Log 'Ellenőrizve: az Otthon TV az alapértelmezett kezdőképernyő.'
} }
$null=Add-Button 'Korábbi kezdőképernyő visszaállítása' 335 199 335 { Work {
    Assert-Device
    if(Restore-XiaomiHomeFallback){Log 'A gyári launcher újra engedélyezve és megnyitva. Ellenőrizd a Home gombot.';return}
    $old=$script:State.OldHome
    if(!$old -or $old -notmatch '^[a-zA-Z0-9_.]+/[a-zA-Z0-9_.$]+$'){throw 'Nincs mentett korábbi kezdőképernyő. A tévé beállításaiban válassz másik launchert.'}
    Log (Tv @('cmd','package','set-home-activity','--user','0',$old))
    if((Get-HomeComponent).Split('/')[0] -ne $old.Split('/')[0]){throw 'A rendszer nem igazolta a visszaállítást.'}
    [void](Tv @('input','keyevent','3'));Log 'A korábbi kezdőképernyő visszaállítva.'
} }
$null=Add-Button 'Xiaomi Home javítása' 865 590 190 { Work {
    $plan=Get-XiaomiHomePlan
    $message='A tévén most az Otthon TV felületének kell látszania. Ha működik, ez a lépés letiltja az aktív gyári kezdőképernyőt: '+$plan.Package+'. Nem törli. A Korábbi kezdőképernyő visszaállítása gomb újra engedélyezi. A régi felület a launcher Kilépés csempéjéből addig nem érhető el. Tartsd bekapcsolva a PC-t és az ADB-kapcsolatot a próbához. Látszik és működik az Otthon TV, és alkalmazod a javítást?'
    if([Windows.Forms.MessageBox]::Show($form,$message,'Xiaomi Home – visszaállítható módosítás',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Warning,[Windows.Forms.MessageBoxDefaultButton]::Button2) -ne 'Yes'){return}
    Apply-XiaomiHomeFallback $plan
    try {
        $message='Nyomd meg a tévé távirányítóján a Home gombot. Ha alkalmazásválasztó jelenik meg, válaszd az Otthon TV-t és a Mindig lehetőséget. Az Otthon TV marad a Home megnyomása után is? Az Igen megtartja a beállítást; a Nem visszaállítja a gyári felületet.'
        if([Windows.Forms.MessageBox]::Show($form,$message,'Home gomb kipróbálása',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question,[Windows.Forms.MessageBoxDefaultButton]::Button2) -eq 'Yes') {
            Confirm-XiaomiHomeFallback;Log 'Home-javítás megtartva a tévés próba jóváhagyása alapján. A visszaállító gomb újra engedélyezi a gyári launchert.'
        } else { [void](Restore-XiaomiHomeFallback);Log 'Gyári launcher visszaállítva.' }
    } catch {
        $failure=$_.Exception.Message
        try{[void](Restore-XiaomiHomeFallback)}catch{throw ('A visszaállítást újra meg kell próbálni a Korábbi kezdőképernyő visszaállítása gombbal. '+$_.Exception.Message)}
        throw ($failure+' A gyári launcher visszaállítva.')
    }
} }
$null=Add-Button 'Lista frissítése' 685 199 170 { Work { Refresh-Apps } }
$null=Add-Button 'Javasoltak kijelölése' 26 590 195 {
    $tabs.SelectedTab=$tabClean;foreach($item in $clean.Items){$item.Checked=($null -ne $item.Tag -and $item.Tag.Recommended)}
    Log 'Csak a javasolt tételek kijelölve. Törlés még nem történt.'
}
$null=Add-Button 'Kijelöltek eltávolítása' 235 590 205 { Work {
    Assert-Device;if(!$script:HomesVerified){throw 'A kezdőképernyők listája nem ellenőrzött. Előbb a Lista frissítése vagy a Diagnosztika gombot használd.'};$selected=@($clean.CheckedItems | ForEach-Object {$_.Tag} | Where-Object {$null -ne $_})
    if(!$selected.Count){throw 'Pipáld ki az eltávolítandó alkalmazásokat.'}
    $summary=($selected | ForEach-Object {$_.Name}) -join "`r`n"
    $warning="Ezek eltávolításra kerülnek a tévé fő felhasználójától:`r`n`r`n"+$summary+"`r`n`r`nA rendszerappok a Visszaállítás fülről visszahozhatók. A felhasználói appokat újra kell telepíteni. Az appadatokat megpróbáljuk megtartani. Folytatod?"
    if([Windows.Forms.MessageBox]::Show($form,$warning,'Eltávolítás áttekintése','YesNo','Warning') -ne 'Yes'){return}
    # Re-read eligibility before mutation; protect any newly selected Home handler.
    $homes=@(Get-HomePackages);$fresh=@(Get-CleanupChoices (Get-Installed) (Convert-PackageList (Tv @('pm','list','packages','-s','--user','0'))) (Convert-PackageList (Tv @('pm','list','packages','-3','--user','0'))) $script:Manufacturer $homes)
    foreach($entry in $selected){
        try{Log ('Eltávolítás: '+$entry.Name);Assert-Removable $entry.Package $fresh $homes;$actual=$fresh | Where-Object { $_.Package -eq $entry.Package };Remove-SelectedPackage $actual $fresh $homes;Log ('Kész: '+$entry.Package)}
        catch{Log ('Nem sikerült: '+$entry.Package+' – '+$_.Exception.Message)}
    }
    Refresh-Apps;Log 'A műveletek befejeződtek. Az eredmények a naplóban olvashatók.'
} }
$null=Add-Button 'Kijelöltek visszaállítása' 455 590 225 { Work {
    Assert-Device;$selected=@($restore.CheckedItems | ForEach-Object {$_.Tag} | Where-Object {$null -ne $_})
    if(!$selected.Count){throw 'A Visszaállítás fülön pipáld ki a visszaállítandó appokat.'}
    foreach($entry in $selected){try{Restore-SelectedPackage $entry;Log ('Visszaállítva: '+$entry.Package)}catch{Log ($entry.Package+' – '+$_.Exception.Message)}}
    Refresh-Apps
} }
$null=Add-Button 'Kioszk jogosultság beállítása' 26 242 295 { Work {
    Assert-Device
    if((Get-Installed) -notcontains $script:OwnPackage){throw 'Először frissítsd a launchert 2.1-re.'}
    $support=Get-KioskSupport
    if(!$support.CanAttempt){throw $support.Message}
    if($support.Code -eq 'AlreadyOwner'){Log $support.Message;[void][Windows.Forms.MessageBox]::Show($form,$support.Message,'Kioszk ellenőrzése','OK','Information');return}
    $message='Az Otthon TV eszközfelügyelői (Device Owner) jogosultságot kap a valódi kioszkmódhoz. Ez korlátozhatja a Home és az alkalmazásváltó működését. Kilépés: a tévén a Kilépés csempe; vészfeloldás: ebben az ablakban a Kioszk feloldása gomb. A jogosultság visszavonható. Meglévő fiókok mellett az Android elutasíthatja. Fiókot nem törlünk és nem végzünk gyári visszaállítást. Beállítod?'
    if([Windows.Forms.MessageBox]::Show($form,$message,'Kioszkmód előkészítése','YesNo','Warning') -ne 'Yes'){return}
    Log (Enable-KioskOwner)
    [void](Tv @('am','start','-n',$script:OwnComponent))
} }
$null=Add-Button 'Kioszk feloldása' 335 242 170 { Work {
    Assert-Device
    Log (Tv @('am','broadcast','-n','hu.otthon.tv/.ControlReceiver','-a','hu.otthon.tv.UNLOCK'))
    Log 'Feloldás kérve. Ellenőrizd a tévén; a normál launcher indul újra.'
} }
$null=Add-Button 'Felügyelet visszavonása' 520 242 235 { Work {
    Assert-Device
    Log (Tv @('am','broadcast','-n','hu.otthon.tv/.ControlReceiver','-a','hu.otthon.tv.RELEASE_OWNER'))
    Log 'Felügyelet visszavonása kérve. Az eredmény a tévén megjelenik.'
} }
$null=Add-Button 'Kioszk ellenőrzése' 770 242 270 { Work {
    if(!$script:Target){throw 'Először csatlakozz a készülékhez.'}
    $support=Get-KioskSupport;Log $support.Message
    [void][Windows.Forms.MessageBox]::Show($form,$support.Message,'Kioszk ellenőrzése','OK','Information')
} }
$null=Add-Button 'Diagnosztika' 870 199 170 { Work { Save-Diagnostics } }
$null=Add-Button 'Naplómappa' 695 590 155 { Start-Process explorer.exe -ArgumentList (Quote-NativeArgument $script:DataDir) }
$form.Add_FormClosing({param($sender,$e) if($script:Busy){$e.Cancel=$true}})
Log 'A tévén engedélyezett hálózati/USB-hibakeresés szükséges. Rendszergazdai indítás nem kell.'
if($UiSmokeTest){
    # Offline UI integration check: no ADB process, device, mutation or dialog is used.
    $script:Target='test-only';$script:DeviceKey='test-only';$script:Manufacturer='Xiaomi';$script:Model='MIBOX3'
    $script:State=[pscustomobject]@{OldHome='';Removed=@();Model='MIBOX3'}
    $script:SimulateMissingHome=$false
    function Tv([string[]]$Arguments){
        $c=$Arguments -join ' '
        switch($c){
            'pm list packages --user 0' {return "package:com.miui.tv.analytics`npackage:com.spotify.tv.android`npackage:com.google.android.tvlauncher"}
            'pm list packages -s --user 0' {return "package:com.miui.tv.analytics`npackage:com.google.android.tvlauncher"}
            'pm list packages -3 --user 0' {return 'package:com.spotify.tv.android'}
            'pm list packages -d --user 0' {return 'package:com.miui.tv.analytics'}
            'pm list packages -s -u --user 0' {return "package:com.miui.tv.analytics`npackage:com.google.android.tvlauncher"}
            default {if($c -like '*query-activities*'){if($script:SimulateMissingHome){return 'unknown command'};return "2 activities found:`n  com.google.android.tvlauncher/.MainActivity`n  hu.otthon.tv/.MainActivity"};throw "Unexpected UI mock command: $c"}
        }
    }
    Refresh-Apps
    if($clean.Items.Count -ne 2 -or $restore.Items.Count -ne 1 -or !$script:HomesVerified){throw 'UI regression: expected 2 cleanup entries, 1 recovered disabled app and verified Home handlers.'}
    $script:SimulateMissingHome=$true;Refresh-Apps
    if($clean.Items.Count -ne 2 -or $restore.Items.Count -ne 1 -or $script:HomesVerified){throw 'UI regression: missing Home data must not erase inventory or recovery.'}
    $script:Recovery=@();Fill-Restore
    if($restore.Items.Count -ne 1 -or $null -ne $restore.Items[0].Tag){throw 'UI regression: empty recovery needs explanatory placeholder.'}
    # Exercise the actual event action and Work guard through repeated failed/recovered connections.
    $script:ConnectionFixture='unauthorized'
    function Ensure-Adb { }
    function Get-Fingerprint {return 'ui-stick-fixture'}
    function Read-State { }
    function Invoke-Adb([string[]]$Arguments,[int]$TimeoutSeconds=60){
        switch($Arguments[0]){
            'start-server' {return ''}
            'connect' {if($script:ConnectionFixture -eq 'timeout'){throw 'simulated ADB timeout'};return 'connected to 192.0.2.1:5555'}
            'devices' {return "List of devices attached`n192.0.2.1:5555`t$script:ConnectionFixture"}
            default {throw 'Unexpected connection mock command'}
        }
    }
    # Preserve package fixtures while adding empty/successful device metadata responses.
    $script:OldTvMock=(Get-Item Function:Tv).ScriptBlock
    function Tv([string[]]$Arguments){
        if($Arguments[0] -eq 'getprop'){
            if($Arguments[-1] -eq 'ro.product.manufacturer'){return 'Xiaomi'}
            if($Arguments[-1] -eq 'ro.product.model'){return 'Mi TV Stick'}
            return ''
        }
        return & $script:OldTvMock $Arguments
    }
    $ip.Text='192.0.2.1';$script:SimulateMissingHome=$false
    foreach($failure in @('unauthorized','offline','timeout','disconnected')){
        $script:ConnectionFixture=$failure;$before=$script:ReportedErrors
        Invoke-UiAction $script:ConnectButton.Tag
        if($form.IsDisposed -or $script:Busy -or !$script:ConnectButton.Enabled -or $script:ReportedErrors -ne ($before+1)){throw "Connection regression: $failure closed the form or left it unusable."}
    }
    $script:ConnectionFixture='device';Invoke-UiAction $script:ConnectButton.Tag
    if($form.IsDisposed -or $script:Busy -or !$script:DeviceKey -or $clean.Items.Count -ne 2){throw 'Connection regression: reconnect after error failed.'}
    $text=Get-Content -LiteralPath $script:SessionLog -Raw
    if($text -notmatch 'simulated ADB timeout'){throw 'Connection regression: persistent error log missing.'}
    $form.Dispose();Write-Output 'Windows Forms inventory, reconnect and persistent error-log smoke tests passed.' 
}else{[void]$form.ShowDialog()}
} catch {
    if($UiSmokeTest){throw}
    try{Write-SessionLog ($_ | Out-String)}catch{}
    [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Otthon TV – indítási hiba','OK','Error')
    exit 1
}

# PowerShell 5.1 compatible. Device commands are isolated for validation.
Set-StrictMode -Version 2.0
$script:OwnPackage = 'hu.otthon.tv'
$script:OwnComponent = 'hu.otthon.tv/.MainActivity'
$script:Protected = @('android','hu.otthon.tv','com.spocky.projengmenu','com.google.android.gms','com.google.android.gsf','com.android.vending','com.google.android.tvlauncher','com.mitv.tvhome.atv','com.android.systemui','com.android.tv.settings','com.android.settings','com.google.android.tv.remote.service','com.android.bluetooth','com.droidlogic.ble','com.google.android.webview','com.google.android.packageinstaller','com.android.packageinstaller','com.google.android.inputmethod.latin','com.google.android.apps.mediashell')
$script:Catalog = @(
    @{Package='com.miui.tv.analytics'; Name='Xiaomi használati statisztikák'; Recommended=$true; Vendor='xiaomi'},
    @{Package='com.google.android.feedback'; Name='Google visszajelzés'; Recommended=$true; Vendor='all'},
    @{Package='com.google.android.tv.bugreportsender'; Name='Android TV hibajelentő'; Recommended=$true; Vendor='all'},
    @{Package='com.google.android.tvrecommendations'; Name='Google ajánlósávok – a gyári főképernyőt érinti'; Recommended=$false; Vendor='all'},
    @{Package='com.google.android.music'; Name='Régi Google Play Zene'; Recommended=$false; Vendor='all'},
    @{Package='com.google.android.videos'; Name='Google TV / Play Filmek'; Recommended=$false; Vendor='all'},
    @{Package='com.google.android.play.games'; Name='Google Play Játékok'; Recommended=$false; Vendor='all'},
    @{Package='com.google.android.youtube.tvmusic'; Name='YouTube Music'; Recommended=$false; Vendor='all'},
    @{Package='tunein.player'; Name='TuneIn rádió'; Recommended=$false; Vendor='all'},
    @{Package='tv.twitch.android.app'; Name='Twitch'; Recommended=$false; Vendor='all'},
    @{Package='com.nousguide.android.rbtv'; Name='Red Bull TV'; Recommended=$false; Vendor='all'},
    @{Package='com.aicareles.dlnaserver'; Name='DLNA-szerver – médiamegosztáshoz kellhet'; Recommended=$false; Vendor='xiaomi'}
)
function Test-PackageName([string]$Name) { return $Name -cmatch '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$' }
function Convert-PackageList([string]$Text) {
    return @($Text -split '\r?\n' | ForEach-Object { if ($_.Trim() -match '^package:([a-zA-Z0-9_.]+)\s*$') { $matches[1] } } | Sort-Object -Unique)
}
function Get-CleanupChoices([string[]]$Installed,[string[]]$System,[string[]]$Downloaded,[string]$Manufacturer,[string[]]$HomePackages) {
    $items = @()
    foreach ($row in $script:Catalog) {
        if ($row.Vendor -eq 'xiaomi' -and $Manufacturer -notmatch '(?i)xiaomi') { continue }
        if ($Installed -notcontains $row.Package -or $script:Protected -contains $row.Package -or $HomePackages -contains $row.Package) { continue }
        $items += [pscustomobject]@{Package=$row.Package;Name=$row.Name;Recommended=$row.Recommended;System=($System -contains $row.Package)}
    }
    foreach ($pkg in $Downloaded) {
        if (!(Test-PackageName $pkg) -or $Installed -notcontains $pkg -or $System -contains $pkg -or $script:Protected -contains $pkg -or $HomePackages -contains $pkg) { continue }
        if (@($items | Where-Object { $_.Package -eq $pkg }).Count) { continue }
        $items += [pscustomobject]@{Package=$pkg;Name="Telepített alkalmazás: $pkg";Recommended=$false;System=$false}
    }
    return @($items)
}
function Assert-Removable([string]$Package,[object[]]$Allowed,[string[]]$HomePackages) {
    if (!(Test-PackageName $Package) -or $script:Protected -contains $Package -or $HomePackages -contains $Package -or !(@($Allowed | Where-Object { $_.Package -ceq $Package }).Count)) {
        throw "Védett vagy nem jóváhagyható csomag: $Package"
    }
}
function Quote-NativeArgument([string]$Argument) {
    # Windows command-line escaping, including quotes and trailing backslashes.
    return '"' + (($Argument -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
}
function Invoke-Adb([string[]]$Arguments,[int]$TimeoutSeconds=60) {
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName=$script:Adb; $info.Arguments=($Arguments | ForEach-Object { Quote-NativeArgument $_ }) -join ' '
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $proc=New-Object System.Diagnostics.Process; $proc.StartInfo=$info
    try {
        [void]$proc.Start(); $stdout=$proc.StandardOutput.ReadToEndAsync(); $stderr=$proc.StandardError.ReadToEndAsync()
        $timer=[Diagnostics.Stopwatch]::StartNew()
        while (!$proc.WaitForExit(100)) {
            if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds) { $proc.Kill(); throw 'A készülék nem válaszolt időben. Ellenőrizd a kapcsolatot, majd frissítsd a listát.' }
            if ($script:PumpUi) { & $script:PumpUi }
        }
        $out=$stdout.Result; $err=$stderr.Result
        if ($proc.ExitCode -ne 0) { throw ($out + "`n" + $err).Trim() }
        return $out.Trim()
    } finally { $proc.Dispose() }
}
function Tv([string[]]$Arguments) { return Invoke-Adb (@('-s',$script:Target,'shell') + $Arguments) }
function Get-Installed { return @(Convert-PackageList (Tv @('pm','list','packages','--user','0'))) }
function Get-Fingerprint {
    $serial=(Tv @('getprop','ro.serialno')).Trim()
    if (!$serial -or $serial -eq 'unknown') { $serial=(Tv @('settings','get','secure','android_id')).Trim() }
    if (!$serial -or $serial -eq 'null' -or $serial -eq 'unknown') { throw 'Nem sikerült egyedileg azonosítani a készüléket. Nem végzek módosítást.' }
    $model=(Tv @('getprop','ro.product.model')).Trim()
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($serial+'|'+$model)))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Assert-Device {
    if (!$script:DeviceKey) { throw 'Először csatlakozz a készülékhez.' }
    if ((Get-Fingerprint) -ne $script:DeviceKey) { throw 'A címen másik készülék található. Csatlakozz újra.' }
    if ((Tv @('am','get-current-user')).Trim() -ne '0') { throw 'Ez a kezelő csak a fő (0) felhasználót támogatja. Válts a tévén a fő felhasználóra.' }
}
function Save-State {
    $path=Join-Path $script:DataDir ($script:DeviceKey+'.json')
    $temp=$path+'.tmp'
    $script:State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $path -Force
}
function Read-State {
    $path=Join-Path $script:DataDir ($script:DeviceKey+'.json')
    if (Test-Path -LiteralPath $path) { $script:State=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json }
    else { $script:State=[pscustomobject]@{OldHome='';Removed=@();Model=$script:Model} }
}
function Convert-Components([string]$Text) {
    return @($Text -split '\r?\n' | ForEach-Object {
        $line=$_.Trim()
        if ($line -match '^[a-zA-Z0-9_.]+/[a-zA-Z0-9_.$]+$') { $line }
    } | Sort-Object -Unique)
}
function Get-HomePackages {
    foreach ($prefix in @('cmd','pm')) {
        try {
            $argsHome=@('query-activities','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.HOME')
            if ($prefix -eq 'cmd') { $argsHome=@('cmd','package')+$argsHome } else { $argsHome=@('pm')+$argsHome }
            $raw=Tv $argsHome
            $homes=@(Convert-Components $raw | ForEach-Object { $_.Split('/')[0] } | Sort-Object -Unique)
            if ($homes.Count) { return $homes }
        } catch { }
    }
    throw 'A kezdőképernyők listája nem olvasható. Az appok láthatók, de az eltávolítás biztonsági okból szünetel. A Diagnosztika gombbal mentsd el a részleteket.'
}
function Get-HomeComponent {
    $raw=Tv @('cmd','package','resolve-activity','--brief','-a','android.intent.action.MAIN','-c','android.intent.category.HOME')
    return @(Convert-Components $raw | Select-Object -Last 1) -join ''
}
function Get-PackageInventory {
    $raw=Tv @('pm','list','packages','--user','0')
    $installed=@(Convert-PackageList $raw)
    if (!$installed.Count) {
        $raw=Tv @('cmd','package','list','packages','--user','0')
        $installed=@(Convert-PackageList $raw)
    }
    if (!$installed.Count) { throw 'A készülék üres vagy hibás csomaglistát adott. Kattints a Diagnosztika gombra; ez nem üres alkalmazáslistaként kezelhető.' }
    $system=@(Convert-PackageList (Tv @('pm','list','packages','-s','--user','0')))
    $downloaded=@(Convert-PackageList (Tv @('pm','list','packages','-3','--user','0')))
    $disabled=@(Convert-PackageList (Tv @('pm','list','packages','-d','--user','0')))
    $knownSystem=@(Convert-PackageList (Tv @('pm','list','packages','-s','-u','--user','0')))
    return [pscustomobject]@{Installed=$installed;System=$system;Downloaded=$downloaded;Disabled=$disabled;KnownSystem=$knownSystem}
}
function Get-RecoveryChoices([object]$Inventory,[object[]]$Journal,[string]$Manufacturer) {
    $result=@();$seen=@{}
    foreach ($entry in $Journal) {
        if (!$entry -or !(Test-PackageName $entry.Package)) { continue }
        $seen[$entry.Package]=$true
        $result+=@([pscustomobject]@{Package=$entry.Package;Name=$entry.Name;System=$entry.System;WasEnabled=$entry.WasEnabled;Status=$entry.Status;Source='journal'})
    }
    foreach ($row in $script:Catalog) {
        $pkg=$row.Package
        if($seen.ContainsKey($pkg) -or ($row.Vendor -eq 'xiaomi' -and $Manufacturer -notmatch '(?i)xiaomi')) { continue }
        if ($Inventory.Disabled -contains $pkg) {
            $result+=@([pscustomobject]@{Package=$pkg;Name=$row.Name;System=($Inventory.System -contains $pkg);WasEnabled=$true;Status='disabled';Source='discovered'})
        } elseif ($Inventory.KnownSystem -contains $pkg -and $Inventory.Installed -notcontains $pkg) {
            $result+=@([pscustomobject]@{Package=$pkg;Name=$row.Name;System=$true;WasEnabled=$true;Status='removed';Source='discovered'})
        }
    }
    return $result
}
function Remove-SelectedPackage([object]$Item,[object[]]$Allowed,[string[]]$Homes) {
    Assert-Device; Assert-Removable $Item.Package $Allowed $Homes
    $enabled=@(Convert-PackageList (Tv @('pm','list','packages','-e','--user','0')))
    $old=@($script:State.Removed | Where-Object { $_.Package -ne $Item.Package })
    $entry=[pscustomobject]@{Package=$Item.Package;Name=$Item.Name;System=$Item.System;WasEnabled=($enabled -contains $Item.Package);Status='pending'}
    $script:State.Removed=@($old)+@($entry);Save-State
    $result=Tv @('pm','uninstall','-k','--user','0',$Item.Package)
    if ($result -notmatch '(?m)^Success\s*$') { throw "Eltávolítás nem sikerült: $result" }
    if ((Get-Installed) -contains $Item.Package) { throw 'A csomag még telepítve van. Frissítsd a listát.' }
    $entry.Status='removed';Save-State
}
function Restore-SelectedPackage([object]$Entry) {
    Assert-Device
    if (!(Test-PackageName $Entry.Package)) { throw 'Érvénytelen naplóbejegyzés.' }
    if ((Get-Installed) -notcontains $Entry.Package) {
        if (!$Entry.System) { throw 'Ez felhasználói alkalmazás. Telepítsd újra a Play Áruházból vagy az eredeti APK-ból.' }
        $result=Tv @('cmd','package','install-existing','--user','0',$Entry.Package)
        if ((Get-Installed) -notcontains $Entry.Package) { throw "A visszaállítás nem sikerült: $result" }
    }
    $action=if ($Entry.WasEnabled) { 'enable' } else { 'disable-user' }
    [void](Tv @('pm',$action,'--user','0',$Entry.Package))
    $nowEnabled=@(Convert-PackageList (Tv @('pm','list','packages','-e','--user','0')))
    if (($nowEnabled -contains $Entry.Package) -ne [bool]$Entry.WasEnabled) { throw 'A visszaállított engedélyezési állapotot a készülék nem igazolta.' }
    $script:State.Removed=@($script:State.Removed | Where-Object { $_.Package -ne $Entry.Package });Save-State
}

function Get-KioskSupport {
    # Read-only capability checks. Never infer an account problem from the generic DPM error.
    $sdkText=(Tv @('getprop','ro.build.version.sdk')).Trim()
    $sdk=0;[void][int]::TryParse($sdkText,[ref]$sdk)
    $raw=Tv @('pm','list','features')
    $features=@($raw -split '\r?\n' | ForEach-Object { if($_.Trim() -match '^feature:([^=\s]+)(?:=\S+)?$'){$matches[1]} })
    $ownerPackage='';$policyReadable=$false
    try {
        $policy=Tv @('dumpsys','device_policy')
        $policyReadable=($policy -match '(?i)device policy|device owner|enabled device admins')
        if($policy -match '(?is)Device Owner\s*:\s*(?:admin\s*=\s*)?ComponentInfo\{([a-zA-Z0-9_.]+)/[^}]+\}'){$ownerPackage=$matches[1]}
    } catch { }
    $code='Ready';$canAttempt=$true
    $message='Az Android-verzió és az eszközfelügyeleti funkció megfelelő. A tényleges jogosultságot az Android még elutasíthatja (például meglévő fiók vagy gyártói korlátozás miatt).'
    if(!$sdk -or !$features.Count){$code='Unknown';$canAttempt=$false;$message='Nem olvasható megbízhatóan a készülék verziója vagy képességlistája. A Diagnosztika gombbal ments jelentést; a jogosultság beállítását nem indítottam el.'}
    elseif($sdk -lt 28){$code='OldAndroid';$canAttempt=$false;$message='Az Otthon TV teljes kioszkmódjához Android 9 vagy újabb rendszer kell. A normál kezdőképernyő használható.'}
    elseif($features -notcontains 'android.software.device_admin'){$code='UnsupportedFirmware';$canAttempt=$false;$message='A készülék firmware-e nem hirdeti az Android eszközfelügyeleti funkcióját (android.software.device_admin). Ezzel a firmware-rel az Otthon TV Device Owner kioszkmódja nem állítható be. Egy launcherfrissítés ezt a rendszerfunkciót nem tudja hozzáadni. A normál alapértelmezett kezdőképernyő használható; ehhez nem szükséges gyári visszaállítás.'}
    elseif($ownerPackage -eq $script:OwnPackage){$code='AlreadyOwner';$message='Az Otthon TV már eszközfelügyelő. A tévén az Útmutató → Kioszkmód menüben kapcsold be a lezárást.'}
    elseif($ownerPackage){$code='OtherOwner';$canAttempt=$false;$message='Másik alkalmazás az eszközfelügyelő: '+$ownerPackage+'. Ezt a kezelő nem távolítja el. A normál launcher használható.'}
    return [pscustomobject]@{Code=$code;CanAttempt=$canAttempt;Message=$message;Sdk=$sdk;DeviceAdmin=($features -contains 'android.software.device_admin');OwnerPackage=$ownerPackage;PolicyReadable=$policyReadable}
}
function Get-KioskFailureMessage([string]$ErrorText) {
    if($ErrorText -match '(?i)accounts?') { return 'Az Android a készüléken lévő fiókok miatt elutasította a Device Owner beállítását. A kezelő nem töröl fiókot. A normál launcher használható; a teljes kioszk most nem kapcsolható be.' }
    if($ErrorText -match '(?i)already.*device owner|device owner.*already') { return 'Az Android szerint már van eszközfelügyelő. Kattints a Kioszk ellenőrzése gombra; ne próbáld újra vakon a beállítást.' }
    if($ErrorText -match '(?i)unknown admin|not installed|bad component|not a valid.*admin') { return 'Az Android nem találja az Otthon TV felügyeleti komponensét. Először frissítsd a launchert a csomagban lévő 2.1-es APK-val.' }
    if($ErrorText -match '(?i)already.*set.up|already.*provision|device.*set.up') { return 'Az Android a készülék beállítási állapota miatt elutasította a kioszkfelügyeletet. Nem végzünk gyári visszaállítást. A normál kezdőképernyő továbbra is használható.' }
    return 'Az Android elutasította a Device Owner jogosultságot, de nem közölt egyértelmű okot. Ebből nem állapítható meg, hogy fiók vagy gyártói korlátozás akadályozza. Kattints a Kioszk ellenőrzése, majd szükség esetén a Diagnosztika gombra. Nem történt gyári visszaállítás vagy fióktörlés.'
}
function Enable-KioskOwner {
    Assert-Device
    if((Get-Installed) -notcontains $script:OwnPackage){throw 'Először telepítsd vagy frissítsd a 2.1-es launchert.'}
    $support=Get-KioskSupport
    if(!$support.CanAttempt){throw $support.Message}
    if($support.Code -eq 'AlreadyOwner'){return $support.Message}
    try {$result=Tv @('dpm','set-device-owner','hu.otthon.tv/.AdminReceiver')}
    catch {throw (Get-KioskFailureMessage $_.Exception.Message)}
    if($result -notmatch '(?m)^Success\b'){throw (Get-KioskFailureMessage $result)}
    return 'Az Android sikeresnek jelezte a jogosultság beállítását. A tévén az Útmutató → Kioszkmód menüben kapcsold be.'
}

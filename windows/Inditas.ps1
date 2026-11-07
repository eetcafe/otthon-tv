# Parent process keeps native host failures visible even if the GUI process exits.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
try {
    $folder=Join-Path $env:LOCALAPPDATA 'Otthon-TV-Kezelo'
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $id=(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+$PID
    $stdout=Join-Path $folder ('inditas-'+$id+'-stdout.log')
    $stderr=Join-Path $folder ('inditas-'+$id+'-stderr.log')
    $app=Join-Path $PSScriptRoot 'Otthon-TV-Kezelo.ps1'
    if(!(Test-Path -LiteralPath $app)){throw 'A teljes ZIP-et csomagold ki egy mappába.'}
    $arguments=@('-NoLogo','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+$app+'"'))
    $child=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    $handle=$child.Handle
    $child.WaitForExit();$code=$child.ExitCode
    if($code -ne 0){
        $message='A kezelő váratlanul bezárult. Kilépési kód: '+$code+"`r`n`r`nA részletek megmaradtak ebben a mappában:`r`n"+$folder+"`r`n`r`nAz Igen gomb megnyitja a naplómappát. A legújabb kezelo- és inditas-fájlok segítenek a javításban."
        if([Windows.Forms.MessageBox]::Show($message,'Otthon TV – mentett hibanapló','YesNo','Warning') -eq 'Yes'){
            Start-Process explorer.exe -ArgumentList ('"'+$folder+'"')
        }
    }
} catch {
    [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Otthon TV – indítási hiba','OK','Error')
}

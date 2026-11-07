$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../windows/Core.ps1')
$dir=Join-Path ([IO.Path]::GetTempPath()) ('otthon-process-'+[guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $dir | Out-Null
$script:Adb=Join-Path $dir 'fake-adb.exe'
Add-Type -TypeDefinition @'
using System;
using System.Threading;
public class FakeAdb {
 public static int Main(string[] args) {
  switch(args[0]) {
   case "slow": Thread.Sleep(500); Console.WriteLine("connected"); return 0;
   case "failure": Console.Error.WriteLine("connection refused"); return 42;
   case "large": Console.Write(new string('x',150000)); Console.Error.Write(new string('e',150000)); return 0;
   case "timeout": Thread.Sleep(10000); return 0;
   case "args": Console.Write(args[1]); return 0;
   default: return 0;
  }
 }
}
'@ -OutputAssembly $script:Adb -OutputType ConsoleApplication
$script:PumpCount=0;$script:PumpUi={$script:PumpCount++}
$script:TraceMessages=New-Object 'System.Collections.Generic.List[string]'
$script:AdbTrace={param($Message) $script:TraceMessages.Add($Message)}
try {
    if((Invoke-Adb @('slow')) -ne 'connected' -or $script:PumpCount -lt 1){throw 'Slow child process or UI-pump regression'}
    $failed=$false;try{Invoke-Adb @('failure')}catch{$failed=$_.Exception.Message -match '42' -and $_.Exception.Message -match 'connection refused'}
    if(!$failed){throw 'Native child failure did not preserve exit code and stderr'}
    if((Invoke-Adb @('large')).Length -ne 150000){throw 'Pipe output truncated or deadlocked'}
    $arg='C:\a folder\quote" and trailing\'
    if((Invoke-Adb @('args',$arg)) -cne $arg){throw 'Windows native argument quoting regression'}
    $failed=$false;$watch=[Diagnostics.Stopwatch]::StartNew()
    try{Invoke-Adb @('timeout') 1}catch{$failed=$_.Exception.Message -match 'időben'}
    if(!$failed -or $watch.Elapsed.TotalSeconds -gt 5){throw 'Timeout did not return promptly'}
    if(!$script:TraceMessages.Count){throw 'No command trace captured'}
    Write-Host 'Native process tests passed: slow response, exit error, large pipes, argument quoting and timeout.'
} finally {Remove-Item -LiteralPath $dir -Recurse -Force}

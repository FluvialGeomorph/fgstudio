# Always launch the analyst preview in a fresh R process, never a test session.
$taskR = Join-Path (Get-ItemProperty 'HKCU:\SOFTWARE\R-core\R').InstallPath 'bin\Rscript.exe'
Push-Location (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
try {
  & $taskR --vanilla dev/scripts/run-dev.R
  if ($LASTEXITCODE -ne 0) { throw 'FG Studio stopped with an error.' }
} finally { Pop-Location }

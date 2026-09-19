# Local build only. Does not publish GitHub Pages or change the analyst runtime.
$taskR = Join-Path (Get-ItemProperty 'HKCU:\SOFTWARE\R-core\R').InstallPath 'bin\Rscript.exe'
$taskPandoc = Join-Path $env:LOCALAPPDATA 'Programs\Positron\resources\app\quarto\bin\tools\pandoc.exe'
$taskOldPandoc = $env:RSTUDIO_PANDOC
Push-Location (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
try {
  if (!(Test-Path -LiteralPath $taskPandoc)) { throw 'Configured Pandoc was not found.' }
  $env:RSTUDIO_PANDOC = Split-Path -Parent $taskPandoc
  & $taskR --vanilla dev/scripts/build-docs.R
  if ($LASTEXITCODE -ne 0) { throw 'Documentation build failed.' }
} finally {
  $env:RSTUDIO_PANDOC = $taskOldPandoc
  Pop-Location
}

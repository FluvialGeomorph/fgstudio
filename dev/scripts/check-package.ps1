# Run from fgstudio. Direct R invocation avoids this workstation's processx pipe issue.
$taskR = Join-Path (Get-ItemProperty 'HKCU:\SOFTWARE\R-core\R').InstallPath 'bin\R.exe'
$taskNames = @('LC_ALL', 'LANG', 'LANGUAGE', 'R_LIBS_USER', 'RSTUDIO_PANDOC', '_R_CHECK_CRAN_INCOMING_REMOTE_', '_R_CHECK_CRAN_INCOMING_', 'FGSTUDIO_REQUIRE_NODE')
$taskPrevious = @{}
foreach ($taskName in $taskNames) { $taskPrevious[$taskName] = [Environment]::GetEnvironmentVariable($taskName, 'Process') }
try {
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Install Node.js and add it to PATH before running maintainer checks.' }
  $env:FGSTUDIO_REQUIRE_NODE = 'true'
  $env:LC_ALL = 'C'
  $env:LANG = 'C'
  $env:LANGUAGE = 'en'
  $env:R_LIBS_USER = (Resolve-Path 'dev/local-library').Path
  $env:_R_CHECK_CRAN_INCOMING_REMOTE_ = 'false'
  $env:_R_CHECK_CRAN_INCOMING_ = 'false'
  $env:RSTUDIO_PANDOC = Join-Path $env:LOCALAPPDATA 'Programs\Positron\resources\app\quarto\bin\tools'
  & $taskR CMD build .
  if ($LASTEXITCODE -ne 0) { throw 'R package build failed.' }
  New-Item -ItemType Directory -Path 'dev/check-output' -Force | Out-Null
  $taskVersion = ((Select-String -Path DESCRIPTION -Pattern '^Version:').Line -replace '^Version:\s*', '').Trim()
  & $taskR CMD check "fgstudio_$taskVersion.tar.gz" --no-manual --output=dev/check-output
  if ($LASTEXITCODE -ne 0) { throw 'R package check failed; inspect dev/check-output.' }
} finally {
  foreach ($taskName in $taskNames) { [Environment]::SetEnvironmentVariable($taskName, $taskPrevious[$taskName], 'Process') }
}

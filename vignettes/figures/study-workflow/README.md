# Study workflow screenshots

These images give reviewers a stable, visual tour of the eight top-level FG
Studio workflow stages. They use the complete Spencer Creek development study;
the study is documentation evidence, not a scientific acceptance template.

Regenerate the full set only when the top-level reviewer experience changes
materially. Start a local preview that can open the complete saved study, then
run from the repository root:

```powershell
$rInstall = (Get-ItemProperty 'HKCU:\SOFTWARE\R-core\R').InstallPath
$rScript = Join-Path $rInstall 'bin\Rscript.exe'
& $rScript --vanilla dev/scripts/capture-doc-screenshots.R `
  'http://127.0.0.1:8780/?study=<study-key>'
```

The data-driven script captures every top-level tab at the same viewport. Keep
the filenames and ordering stable so article references do not churn. Avoid
capturing transient progress messages, open menus, modals, or advanced controls;
those details change more frequently and belong in prose or focused tests.

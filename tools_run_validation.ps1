# Run from the project root and preserve the actual MATLAB exit code.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$matlabCommand = Get-Command matlab -ErrorAction SilentlyContinue
$matlabExe = if ($matlabCommand) { $matlabCommand.Source } else { 'C:\Program Files\MATLAB\R2025b\bin\matlab.exe' }
$ErrorActionPreference = 'Continue'
& $matlabExe -batch "addpath('tests','examples'); run_tests; demo_dtmf;" -logfile outputs/results/matlab_batch.log 2>&1 | Tee-Object -FilePath outputs/results/launcher.log
$matlabExitCode = $LASTEXITCODE
"MATLAB_EXIT_CODE=$matlabExitCode" | Add-Content outputs/results/launcher.log
exit $matlabExitCode

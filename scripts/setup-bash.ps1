$gitBash = "C:\Program Files\Git\bin"

if (Test-Path "$gitBash\bash.exe") {
    $env:Path = "$gitBash;$env:Path"
}

Get-Command bash
bash --version

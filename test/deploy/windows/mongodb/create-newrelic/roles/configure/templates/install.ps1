Write-Host "Install Service"
&"$Env:ProgramFiles\MongoDB\Server\4.4\bin\mongod.exe" --config "$mongoDataFolder\mongod.cfg" --install | Out-Null
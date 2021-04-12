Write-Host "Installing MongoDB..."
msiexec.exe /q /i mongodb-windows-x86_64-4.4.5-signed.msi "ADDLOCAL=ALL" SHOULD_INSTALL_COMPASS="0"  | Out-Null
 
Write-Host "Create data folder"
$mongoDataFolder = "c:\MongoData"
md "$mongoDataFolder\data"
md "$mongoDataFolder\logs"
 
Write-Host "Create config file"
$cfg = @"
systemLog:
    destination: file
    logAppend: true
    path: $mongoDataFolder\logs\mongod.log
storage:
    dbPath: $mongoDataFolder\data
net:
    port: 27017
    bindIp: localhost
"@
$cfg | Out-File "$mongoDataFolder\mongod.cfg"
 
Write-Host "Install Service"
&"$Env:ProgramFiles\MongoDB\Server\4.4\bin\mongod.exe" --config "$mongoDataFolder\mongod.cfg" --install | Out-Null
 
Write-Host "Configure Service"
Set-Service -Name MongoDB -StartupType Automatic
Start-Service -Name MongoDB
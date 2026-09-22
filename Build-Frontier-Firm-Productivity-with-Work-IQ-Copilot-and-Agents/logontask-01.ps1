Set-ExecutionPolicy -ExecutionPolicy bypass -Force
Start-Transcript -Path C:\WindowsAzure\Logs\CloudLabsLogOnTask.txt -Append
Write-Host "Logon-task-started" 

$commonscriptpath = "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.*\Downloads\0\cloudlabs-common\cloudlabs-windows-functions.ps1"
. $commonscriptpath

#installing extensions to vscode
choco install vscode-code-runner

#code --install-extension ms-toolsai.jupyter
code --install-extension TeamsDevApp.ms-teams-vscode-extension
code --install-extension ms-vscode.vscode-typescript-next

code --install-extension esbenp.prettier-vscode
code --install-extension dbaeumer.vscode-eslint

# Teams Developer CLI and M365 Agents Playground required by Lab 11.
# These are installed here rather than in psscript.ps1 because this task
# runs as azureuser, so "npm install -g" writes to the lab user's profile.
sleep 5
npm install -g @microsoft/teams.cli
npm install -g @microsoft/m365agentsplayground

# Ensure the npm global folder is on the user PATH, otherwise the "teams"
# command is not recognised even though the package installed correctly.
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$npmPath  = "$env:APPDATA\npm"
if ($userPath -notlike "*$npmPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$npmPath", "User")
}

sleep 5
$WebClient = New-Object System.Net.WebClient
 
# Create folder if it doesn't exist
New-Item -ItemType Directory -Path "C:\LabFiles" -Force | Out-Null
 
# Download ZIP
$WebClient.DownloadFile("https://experienceazure.blob.core.windows.net/templates/tf/frontier-firm-productivity-workiq-copilot-agents/MsIQ-cplt-agntsfrntr-post-build-SPLabs.zip", "C:\LabFiles\MsIQ-cplt-agntsfrntr-post-build-SPLabs.zip")
 
# Extract ZIP into C:\LabFiles
Expand-Archive -Path "C:\LabFiles\MsIQ-cplt-agntsfrntr-post-build-SPLabs.zip" -DestinationPath "C:\LabFiles" -Force
 
# Delete ZIP after extraction
Remove-Item "C:\LabFiles\MsIQ-cplt-agntsfrntr-post-build-SPLabs.zip" -Force

sleep 5
choco install visualstudio2022community -y

Unregister-ScheduledTask -TaskName "logontask" -Confirm:$false 

Restart-Computer -Force 

Stop-Transcript

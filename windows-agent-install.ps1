##################################################################################
# $DEVOPSURL :- https://dev.azure.com/{organization name}/
# $DEVOPSPAT :- Personal access token to authenticate VM with azure devops
# $DEVOPSPOOL:- Name of the Azure DevOps Agent Pool where you want to register your agent 
# $DEVOPSAGENT:- Name of the agent
# AGENTVERSION:- Agent version, by default its latest version
###################################################################################
param (
    [string]$URL,
    [string]$PAT,
    [string]$POOL,
    [Parameter(Mandatory=$false)][string]$AGENT,
    [Parameter(Mandatory=$false)]$AGENTVERSION
)

Start-Transcript

# remove an existing installation of agent
if (test-path "c:\agent")
{
    Remove-Item -Path "c:\agent" -Force  -Confirm:$false -Recurse 
}

#create a new folder
new-item -ItemType Directory -Force -Path "c:\agent"
set-location "c:\agent"

$env:VSTS_AGENT_HTTPTRACE = $true
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ($DEVOPSAGENT)
{
    $AGENT_NAME = $DEVOPSAGENT
}
else
{
    $AGENT_NAME = $env:COMPUTERNAME
}
# URL to download the agent
$download = "https://download.agent.dev.azure.com/agent/4.258.1/vsts-agent-win-x64-4.258.1.zip"

# Download the Agent
Invoke-WebRequest $download -Out agent.zip

# Extract the zio to agent folder
Expand-Archive -Path agent.zip -DestinationPath $PWD

# Run the cmd silently to install agent
.\config.cmd --unattended --url "$URL" --auth pat --token "$PAT" --pool "$POOL" --agent $AGENT --acceptTeeEula --runAsService

# Extra stuff - install Azure CLI
$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; Remove-Item .\AzureCLI.msi


#exit
Stop-Transcript
exit 0
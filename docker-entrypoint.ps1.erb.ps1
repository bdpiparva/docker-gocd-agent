# Copyright 2018 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
function setup_autoregister_properties_file_for_elastic_agent() {
    $properties = @("agent.auto.register.key=$env:GO_EA_AUTO_REGISTER_KEY",
    "agent.auto.register.environments=$env:GO_EA_AUTO_REGISTER_ENVIRONMENT",
    "agent.auto.register.elasticAgent.agentId=$env:GO_EA_AUTO_REGISTER_ELASTIC_AGENT_ID",
    "agent.auto.register.elasticAgent.pluginId=$env:GO_EA_AUTO_REGISTER_ELASTIC_PLUGIN_ID")

    $properties | Out-File "$($args[0])" -Encoding "default" -append
    
    $env:GO_SERVER_URL=$env:GO_EA_SERVER_URL

    # unset variables, so we don't pollute and leak sensitive stuff to the agent process...
    $env:GO_EA_AUTO_REGISTER_KEY='' 
    $env:GO_EA_AUTO_REGISTER_ENVIRONMENT=''
    $env:GO_EA_AUTO_REGISTER_ELASTIC_AGENT_ID=''
    $env:GO_EA_AUTO_REGISTER_ELASTIC_PLUGIN_ID=''
    $env:GO_EA_SERVER_URL='' 
    $env:AGENT_AUTO_REGISTER_HOSTNAME=''
}
    
function GetOrDefault($value, $defaultValue) {
    if ("$value" -eq nothing) {
        return $defaultValue
    }

    return "$value"
}

function NotExist($Path){
    return !(Test-Path -Path $Path)
}

function CreateDirIfNotExist($Path) {
    if(NotExist $Path) {
        Write-Host "Creating directory $Path."
        New-Item -ItemType Directory -Force -Path $Path
    }
}

function SymbolicLink($Target, $LinkPath) {
    if(!([bool] (Get-Item $LinkPath | Where-Object { $_.Attributes -match “ReparsePoint” }))) {
        cmd /c mklink /D $LinkPath $Target
    }
}

$VOLUME_DIR=GetOrDefault($env:VOLUME_DIR, "c:/godata") 
$AGENT_WORK_DIR = "c:/go"
$server_dirs = (config logs pipelines)
Write-Host "Creating directories and symlinks to hold GoCD configuration, data, and logs"

# ensure working dir exist
CreateDirIfNotExist $AGENT_WORK_DIR
# ensure proper directory structure in the volume directory
CreateDirIfNotExist $VOLUME_DIR

$server_dirs | foreach {
    CreateDirIfNotExist "$VOLUME_DIR/$_"
    SymbolicLink "$AGENT_WORK_DIR/$_" "$VOLUME_DIR/$_"
}


("agent-bootstrapper-logback-include.xml","agent-launcher-logback-include.xml","agent-logback-include.xml") | foreach {
    if(NotExist "$AGENT_WORK_DIR/config/$_") {
        Copy-Item "c:/config/$_" -Destination "$AGENT_WORK_DIR/config/$_"
    }
}

setup_autoregister_properties_file_for_elastic_agent "$AGENT_WORK_DIR\config\autoregister.properties"

Write-Host "Running custom scripts in /docker-entrypoint.d/ ..."
Get-ChildItem -Path "c:/docker-entrypoint.d/*" -File -Include *.ps1 | foreach {
    powershell -File $_    
}

Get-ChildItem -Path "c:/docker-entrypoint.d/*" -File -Include *.bat | foreach {
    cmd /c $_   
}

# these 3 vars are used by `/go-agent/agent.sh`, so we export
$env:AGENT_WORK_DIR=$AGENT_WORK_DIR
$env:GO_AGENT_SYSTEM_PROPERTIES = "$env:GO_AGENT_SYSTEM_PROPERTIES;-Dgo.console.stdout=true"
$env:AGENT_BOOTSTRAPPER_JVM_ARGS = "$env:AGENT_BOOTSTRAPPER_JVM_ARGS;-Dgo.console.stdout=true"

cmd /c c:/gocd-agent/agent.cmd

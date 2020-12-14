﻿# =================================================================================================================================================
# GENERAL INFORMATION
# =================================================================================================================================================
<# 
    External Tools Power BI model documentor script version 1.2.0
    New in this version: 
        - Introduced a small menu to choose the output format of your preference. 
            - Power BI
            - Excel

    Full change log can be found here: https://data-marc.com/model-documenter/
#>

# =================================================================================================================================================
# DEFINE PREFERENCES AND SETTINGS BASED ON INSTALLER
# =================================================================================================================================================

# Below you can define your personal preference for file saving and reading. 
    # The default location can be changed and will be leverages througout the entire script. 
    # InstallerLocation only applies to installation via PowerBI.tips Business Ops.
$InstallerLocation = '__TOOL_INSTALL_DIR__\'
$defaultLocation = 'C:\BusinessOpsTemp\'
$finalLocation = if($InstallerLocation -like '*TOOL_INSTALL_DIR*') 
{$defaultLocation} else {$InstallerLocation}

$Logfile = $finalLocation + 'PBI_DocumentModel_LogFile.txt'

#This part starts tracing to catch unfortunate errors and defines where to write the file. 
Start-Transcript -Path $Logfile | out-null

# Define Template Locations
# In case you are using a different pbit file, you can define that in below variable.
$PbitLocation = $finalLocation + 'ModelDocumentationTemplate.pbit'
$ExcelLocation = $finalLocation + 'ModelDocumentationTemplate.xlsx'

# Write out file locations - Uncomment below code section if you want to display the location on the screen for debugging purposes
<# 
Write-Host 'installer location ' + $InstallerLocation
Write-Host 'default location ' + $defaultLocation
Write-Host 'final location ' + $finalLocation
#>

# =================================================================================================================================================
# DEFINE FUNCTIONS
# =================================================================================================================================================

# Prefer the service you want to run and build start menu
Function StartMenu {
    [int]$xMenuChoiceA = 0
    while ( $xMenuChoiceA -lt 1 -or $xMenuChoiceA -gt 2 ){
    Write-host "Choose one of the below options to export your model documentation:"
    Write-host "1. Open Documentation in Power BI"
    Write-host "2. Open Documentation in Excel"
    [Int]$xMenuChoiceA = read-host "Please enter an option 1 or 2..." }
    Switch( $xMenuChoiceA ){
      1{ 
        Write-Host "`n"'You chose option #1, Open in Power BI'
        OpenDocumentationInPowerBI
        }
      2{
        Write-Host "`n"'You chose option #2, Open in Excel'
        OpenDocumentationInExcel
        }
    # default{<#run a default action or call a function here #>}
    }
}

# Creates a folder on earlier defined location for file dropoff
Function CreateDropOffFolder {
try {
    New-Item -Path "c:\" -Name $DefaultFolderName -ItemType "directory" | out-null
} catch {
    Write-Host "Error creating file path"
    Read-Host "Press a key to close the application"
}
}

# Function to automatically download the pbit file if it cannot be found on the defined location. 
# Function based on https://gist.github.com/chrisbrownie/f20cb4508975fb7fb5da145d3d38024a 
function DownloadTemplateFromRepo {
Param(
    $Owner = 'marclelijveld',
    $Repository = 'External-Tools-Model-Documentation'
    )

    $baseUri = "https://api.github.com/"
    $UriPath = "repos/$Owner/$Repository/contents/$Path"
    $wr = Invoke-WebRequest -Uri $($baseuri+$UriPath)
    $objects = $wr.Content | ConvertFrom-Json
    $files = $objects | Where-Object {$_.type -eq "file"} | Select-Object -exp download_url
    $directories = $objects | Where-Object {$_.type -eq "dir"}
    
    $directories | ForEach-Object { 
        DownloadTemplateFromRepo -Owner $Owner -Repository $Repository -Path $_.path -DefaultFolderPath $($DefaultFolderPath+$_.name)
    }

    if (-not (Test-Path $DefaultFolderPath)) {
        # Destination path does not exist, let's create it
        try {
            New-Item -Path $DefaultFolderPath -ItemType Directory -ErrorAction Stop
        } catch {
            throw "Could not create path '$DefaultFolderPath'!"
        }
    }

    foreach ($file in $files) {
        $fileDestination = Join-Path $DefaultFolderPath (Split-Path $file -Leaf)
        try {
            Invoke-WebRequest -Uri $file -OutFile $fileDestination -ErrorAction Stop -Verbose
            "Grabbed '$($file)' to '$fileDestination'"
        } catch {
            throw "Unable to download '$($file.path)'"
        }
    }

}

# Open PBIT template file from PBITLocation as defined in the variable. 
Function OpenDocumentationInPowerBI {
try {
    Invoke-Item $PbitLocation  -ErrorAction Stop 
} catch {
    $Path = 'ModelDocumentationTemplate.pbit'
    Write-Host "Template file not found." 
    Write-Host "Start download template from GitHub..."
    DownloadTemplateFromRepo
    Invoke-Item $PbitLocation
}
}

# Open Excel template file from PBITLocation as defined in the variable.
Function OpenDocumentationInExcel {
try {
    Invoke-Item $ExcelLocation  -ErrorAction Stop 
} catch {
    $Path = 'ModelDocumentationTemplate.xlsx'
    
    Write-Host "Template file not found." -ForegroundColor Red 
Write-Host @"

The current version of the script does not support automated download for the Excel Template yet. 
Please download the ModelDocumentationTemplate.xlsx and put in the $finalLocation
You can find the file here: https://github.com/marclelijveld/External-Tools-Model-Documentation
"@ -ForegroundColor Yellow
    # DownloadTemplateFromRepo
    Read-Host "Please press a key once you are ready to continue" 
    Invoke-Item $ExcelLocation -ErrorAction Inquire
}
}

# =================================================================================================================================================
# Pre-execution tasks
# =================================================================================================================================================

# Checks whether a dropoff location already exists, otherwise create location
$DefaultFolderName = "BusinessOpsTemp"
$DefaultFolderPath = "c:\" + $DefaultFolderName
$FolderExists = Test-Path $DefaultFolderPath
If ($FolderExists -eq $False) {
CreateDropOffFolder
}

# Below section defines the server and databasename based on the input captured from the External tools integration. 
# This is defined as arguments \"%server%\" and \"%database%\" in the external tools json. 
$Server = $args[0]
$DatabaseName = $args[1]

# Generate json array based on the received server and database information.
$json = @"
    {
    "Server": "$Server", 
    "DatabaseName": "$DatabaseName"
    }
"@

# Writes the connectionstring in json format to the defined file location. This is a temp fo and will be overwritten next time. 
$OutputLocation = $defaultLocation + 'ModelDocumenterConnectionDetails.json'
$json  | ConvertTo-Json  | Out-File $OutputLocation

# =================================================================================================================================================
# RUN APPLICATION
# =================================================================================================================================================

# Write Server and Database information to screen. 
Write-Host "`n"
Write-Host 'Welcome to the Power BI Model Documenter!'
Write-Host "`n"
Write-Host "Your Power BI Model currently runs with the following connection details:"
Write-Host "Server: " $Server 
Write-Host "Database: " $DatabaseName 
Write-Host "`n"

# Show Menu to choose action
StartMenu

# Stop tracing errors
Stop-Transcript
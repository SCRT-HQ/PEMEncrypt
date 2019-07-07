New-Variable -Name IsCI -Value $($IsCI -or (Test-Path Env:\TF_BUILD)) -Scope Global -Force -Option AllScope

function Get-Elapsed {
    if ($IsCI) {
        "[+$(((Get-Date) - (Get-Date $env:_BuildStart)).ToString())]"
    }
    else {
        "[$((Get-Date).ToString("HH:mm:ss")) +$(((Get-Date) - (Get-Date $env:_BuildStart)).ToString())]"
    }
}
function Resolve-Module {
    [Cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Name,

        [switch]$UpdateModules
    )
    Begin {
        $PSDefaultParameterValues = @{
            '*-Module:Verbose' = $false
            'Import-Module:ErrorAction' = 'Stop'
            'Import-Module:Force' = $true
            'Import-Module:Verbose' = $false
            'Install-Module:AllowClobber' = $true
            'Install-Module:ErrorAction' = 'Stop'
            'Install-Module:Force' = $true
            'Install-Module:Scope' = 'CurrentUser'
            'Install-Module:Verbose' = $false
        }
    }
    process {
        foreach ($moduleName in $Name) {
            $versionToImport = ''

            Write-Verbose -Message "Resolving Module [$($moduleName)]"
            if ($Module = Get-Module -Name $moduleName -ListAvailable -Verbose:$false) {
                # Determine latest version on PSGallery and warn us if we're out of date
                $latestLocalVersion = ($Module | Measure-Object -Property Version -Maximum).Maximum
                $latestGalleryVersion = (Find-Module -Name $moduleName -Repository PSGallery |
                    Measure-Object -Property Version -Maximum).Maximum

                # Out we out of date?
                if ($latestLocalVersion -lt $latestGalleryVersion) {
                    if ($UpdateModules) {
                        Write-Verbose -Message "$($moduleName) installed version [$($latestLocalVersion.ToString())] is outdated. Installing gallery version [$($latestGalleryVersion.ToString())]"
                        if ($UpdateModules) {
                            Install-Module -Name $moduleName -RequiredVersion $latestGalleryVersion
                            $versionToImport = $latestGalleryVersion
                        }
                    } else {
                        Write-Warning "$($moduleName) is out of date. Latest version on PSGallery is [$latestGalleryVersion]. To update, use the -UpdateModules switch."
                    }
                } else {
                    $versionToImport = $latestLocalVersion
                }
            } else {
                Write-Verbose -Message "[$($moduleName)] missing. Installing..."
                Install-Module -Name $moduleName -Repository PSGallery
                $versionToImport = (Get-Module -Name $moduleName -ListAvailable | Measure-Object -Property Version -Maximum).Maximum
            }

            Write-Verbose -Message "$($moduleName) installed. Importing..."
            if (-not [string]::IsNullOrEmpty($versionToImport)) {
                Import-module -Name $moduleName -RequiredVersion $versionToImport
            } else {
                Import-module -Name $moduleName
            }
        }
    }
}
function Set-BuildVariables {
    $gitVars = if ($IsCI) {
        @{
            BHBranchName = $env:BUILD_SOURCEBRANCHNAME
            BHPSModuleManifest = "$env:BuildScriptPath\$env:BuildProjectName\$env:BuildProjectName.psd1"
            BHPSModulePath = "$env:BuildScriptPath\$env:BuildProjectName"
            BHProjectName = $(if($env:BuildProjectName){$env:BuildProjectName})
            BHBuildNumber = $env:BUILD_BUILDNUMBER
            BHModulePath = "$env:BuildScriptPath\$env:BuildProjectName"
            BHBuildOutput = "$env:BuildScriptPath\BuildOutput"
            BHBuildSystem = 'VSTS'
            BHProjectPath = $env:SYSTEM_DEFAULTWORKINGDIRECTORY
            BHCommitMessage = $env:BUILD_SOURCEVERSIONMESSAGE
        }
    }
    else {
        @{
            BHBranchName = $((git rev-parse --abbrev-ref HEAD).Trim())
            BHPSModuleManifest = "$env:BuildScriptPath\$env:BuildProjectName\$env:BuildProjectName.psd1"
            BHPSModulePath = "$env:BuildScriptPath\$env:BuildProjectName"
            BHProjectName = $(if($env:BuildProjectName){$env:BuildProjectName})
            BHBuildNumber = 'Unknown'
            BHModulePath = "$env:BuildScriptPath\$env:BuildProjectName"
            BHBuildOutput = "$env:BuildScriptPath\BuildOutput"
            BHBuildSystem = [System.Environment]::MachineName
            BHProjectPath = $env:BuildScriptPath
            BHCommitMessage = $((git log --format=%B -n 1).Trim())
        }
    }
    Add-Heading 'Setting environment variables if needed'
    foreach ($var in $gitVars.Keys) {
        if (-not (Test-Path Env:\$var)) {
            Set-EnvironmentVariable $var $gitVars[$var]
        }
    }
}
function Write-BuildLog {
    [CmdletBinding()]
    param(
        [parameter(Mandatory,Position = 0,ValueFromRemainingArguments,ValueFromPipeline)]
        [System.Object]
        $Message,
        [parameter()]
        [Alias('c','Command')]
        [Switch]
        $Cmd,
        [parameter()]
        [Alias('w')]
        [Switch]
        $Warning,
        [parameter()]
        [Alias('s','e')]
        [Switch]
        $Severe,
        [parameter()]
        [Alias('x','nd','n')]
        [Switch]
        $Clean
    )
    Begin {
        if ($PSBoundParameters.ContainsKey('Debug') -and $PSBoundParameters['Debug'] -eq $true) {
            $fg = 'Yellow'
            $lvl = '##[debug]   '
        }
        elseif ($PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'] -eq $true) {
            $fg = if ($Host.UI.RawUI.ForegroundColor -eq 'Gray') {
                'White'
            }
            else {
                'Gray'
            }
            $lvl = '##[verbose] '
        }
        elseif ($Severe) {
            $fg = 'Red'
            $lvl = '##[error]   '
        }
        elseif ($Warning) {
            $fg = 'Yellow'
            $lvl = '##[warning] '
        }
        elseif ($Cmd) {
            $fg = 'Magenta'
            $lvl = '##[command] '
        }
        else {
            $fg = if ($Host.UI.RawUI.ForegroundColor -eq 'Gray') {
                'White'
            }
            else {
                'Gray'
            }
            $lvl = '##[info]    '
        }
    }
    Process {
        $fmtMsg = if ($Clean){
            $Message -split "[\r\n]" | Where-Object {$_} | ForEach-Object {
                $lvl + $_
            }
        }
        else {
            $date = "$(Get-Elapsed) "
            if ($Cmd) {
                $i = 0
                $Message -split "[\r\n]" | Where-Object {$_} | ForEach-Object {
                    $tag = if ($i -eq 0) {
                        'PS > '
                    }
                    else {
                        '  >> '
                    }
                    $lvl + $date + $tag + $_
                    $i++
                }
            }
            else {
                $Message -split "[\r\n]" | Where-Object {$_} | ForEach-Object {
                    $lvl + $date + $_
                }
            }
        }
        Write-Host -ForegroundColor $fg $($fmtMsg -join "`n")
    }
}
function Write-BuildWarning {
    param(
        [parameter(Mandatory,Position = 0,ValueFromRemainingArguments,ValueFromPipeline)]
        [System.String]
        $Message
    )
    Process {
        Write-Warning $Message
        if ($IsCI) {
            Write-Host "##vso[task.logissue type=warning;]$Message"
        }
        else {
        }
    }
}
function Write-BuildError {
    param(
        [parameter(Mandatory,Position = 0,ValueFromRemainingArguments,ValueFromPipeline)]
        [System.String]
        $Message
    )
    Process {
        if ($IsCI) {
            Write-Host "##vso[task.logissue type=error;]$Message"
        }
        Write-Error $Message
    }
}
function Set-EnvironmentVariable {
    param(
        [parameter(Position = 0)]
        [String]
        $Name,
        [parameter(Position = 1,ValueFromRemainingArguments)]
        [String[]]
        $Value
    )
    $fullVal = $Value -join " "
    Write-BuildLog "Setting env variable '$Name' to '$fullVal'"
    Set-Item -Path Env:\$Name -Value $fullVal -Force
    if ($IsCI) {
        "##vso[task.setvariable variable=$Name]$fullVal" | Write-Host
    }
}
function Invoke-CommandWithLog {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory,Position=0)]
        [ScriptBlock]
        $ScriptBlock
    )
    Write-BuildLog -Command ($ScriptBlock.ToString() -join "`n")
    $ScriptBlock.Invoke()
}
function Get-PsakeTaskSectionFormatter {
    $sb = {
        param($String)
        "$((Add-Heading "Executing task: {0}" -PassThru) -join "`n")" -f $String
    }
    return $sb
}
function Add-Heading {
    param(
        [parameter(Position = 0,ValueFromRemainingArguments)]
        [String]
        $Title,
        [Switch]
        $Passthru
    )
    $msgList = @(
        ''
        "##[section] $(Get-Elapsed) $Title"
    ) -join "`n"
    if ($Passthru) {
        $msgList
    }
    else {
        $msgList | Write-Host -ForegroundColor Cyan
    }
}
function Add-EnvironmentSummary {
    param(
        [parameter(Position = 0,ValueFromRemainingArguments)]
        [String]
        $State
    )
    Add-Heading Build Environment Summary
    @(
        $(if($env:BuildProjectName){"Project : $env:BuildProjectName"})
        $(if($State){"State   : $State"})
        "Engine  : PowerShell $($PSVersionTable.PSVersion.ToString())"
        "Host OS : $(if($PSVersionTable.PSVersion.Major -le 5 -or $IsWindows){"Windows"}elseif($IsLinux){"Linux"}elseif($IsMacOS){"macOS"}else{"[UNKNOWN]"})"
        "PWD     : $PWD"
        ''
    ) | Write-Host
}

function Publish-GitHubRelease {
    <#
        .SYNOPSIS
        Publishes a release to GitHub Releases. Borrowed from https://www.herebedragons.io/powershell-create-github-release-with-artifact
    #>
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $true)]
        [String]
        $VersionNumber,
        [parameter(Mandatory = $false)]
        [String]
        $CommitId = 'master',
        [parameter(Mandatory = $true)]
        [String]
        $ReleaseNotes,
        [parameter(Mandatory = $true)]
        [ValidateScript( {Test-Path $_})]
        [String]
        $ArtifactPath,
        [parameter(Mandatory = $true)]
        [String]
        $GitHubUsername,
        [parameter(Mandatory = $true)]
        [String]
        $GitHubRepository,
        [parameter(Mandatory = $true)]
        [String]
        $GitHubApiKey,
        [parameter(Mandatory = $false)]
        [Switch]
        $PreRelease,
        [parameter(Mandatory = $false)]
        [Switch]
        $Draft
    )
    $releaseData = @{
        tag_name         = [string]::Format("v{0}", $VersionNumber)
        target_commitish = $CommitId
        name             = [string]::Format("$($env:BHProjectName) v{0}", $VersionNumber)
        body             = $ReleaseNotes
        draft            = [bool]$Draft
        prerelease       = [bool]$PreRelease
    }

    $auth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($gitHubApiKey + ":x-oauth-basic"))

    $releaseParams = @{
        Uri         = "https://api.github.com/repos/$GitHubUsername/$GitHubRepository/releases"
        Method      = 'POST'
        Headers     = @{
            Authorization = $auth
        }
        ContentType = 'application/json'
        Body        = (ConvertTo-Json $releaseData -Compress)
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $result = Invoke-RestMethod @releaseParams
    $uploadUri = $result | Select-Object -ExpandProperty upload_url
    $uploadUri = $uploadUri -creplace '\{\?name,label\}'
    $artifact = Get-Item $ArtifactPath
    $uploadUri = $uploadUri + "?name=$($artifact.Name)"
    $uploadFile = $artifact.FullName

    $uploadParams = @{
        Uri         = $uploadUri
        Method      = 'POST'
        Headers     = @{
            Authorization = $auth
        }
        ContentType = 'application/zip'
        InFile      = $uploadFile
    }
    $result = Invoke-RestMethod @uploadParams
}

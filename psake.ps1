# PSake makes variables declared here available in other scriptblocks
# Init some things
Properties {
    # Find the build folder based on build system
    $ProjectRoot = $ENV:BHProjectPath
    if (-not $ProjectRoot) {
        if ($pwd.Path -like "*ci*") {
            Set-Location ..
        }
        $ProjectRoot = $pwd.Path
    }
    $sut = $env:BHModulePath
    $tests = "$projectRoot\Tests"
    $Timestamp = Get-Date -Uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.ToString()
    $TestFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"
    $lines = '----------------------------------------------------------------------'
    $outputDir = $env:BHBuildOutput
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $pathSeperator = [IO.Path]::PathSeparator
    $Verbose = @{}
    if ($ENV:BHCommitMessage -match "!verbose") {
        $Verbose = @{Verbose = $True}
    }
}
. .\ci\BuildHelpers.ps1
Set-BuildVariables
FormatTaskName (Get-PsakeTaskSectionFormatter)

#Task Default -Depends Init,Test,Build,Deploy
task default -depends Test

task Init {
    Set-Location $ProjectRoot
    Write-BuildLog "Build System Details:"
    Write-BuildLog "$((Get-ChildItem Env: | Where-Object {$_.Name -match "^(BUILD_|SYSTEM_|BH)"} | Sort-Object Name | Format-Table Name,Value -AutoSize | Out-String).Trim())"

    Write-BuildLog "Module version to publish: $($manifest.ModuleVersion.ToString())"
    Write-BuildLog "##vso[task.setvariable variable=ModuleVersion;]$($manifest.ModuleVersion.ToString())"
    'Pester' | Foreach-Object {
        Install-Module -Name $_ -Repository PSGallery -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Confirm:$false -ErrorAction Stop -Force
        Import-Module -Name $_ -Verbose:$false -ErrorAction Stop -Force
    }
} -description 'Initialize build environment'

task Clean -depends Init {
    Remove-Module -Name $env:BHProjectName -Force -ErrorAction SilentlyContinue

    if (Test-Path -Path $outputDir) {
        Get-ChildItem -Path $outputDir -Recurse | Remove-Item -Force -Recurse
    }
    else {
        New-Item -Path $outputDir -ItemType Directory > $null
    }
    "    Cleaned previous output directory [$outputDir]"
} -description 'Cleans module output directory'

task Compile -depends Clean {
    # Create module output directory
    $functionsToExport = @()
    $modDir = New-Item -Path $outputModDir -ItemType Directory -ErrorAction SilentlyContinue
    New-Item -Path $outputModVerDir -ItemType Directory -ErrorAction SilentlyContinue > $null

    # Append items to psm1
    Write-Verbose -Message 'Creating psm1...'
    $psm1 = New-Item -Path (Join-Path -Path $outputModVerDir -ChildPath "$($ENV:BHProjectName).psm1") -ItemType File -Force

    Get-Content (Join-Path -Path $ENV:BHModulePath -ChildPath "$($ENV:BHProjectName).psm1") -Raw  | Add-Content -Path $psm1 -Encoding UTF8

    if (Test-Path (Join-Path -Path $sut -ChildPath 'Private')) {
        Get-ChildItem -Path (Join-Path -Path $sut -ChildPath 'Private') -Filter "*.ps1" -Recurse -File | ForEach-Object {
            "$(Get-Content $_.FullName -Raw)`n" | Add-Content -Path $psm1 -Encoding UTF8
        }
    }
    if (Test-Path (Join-Path -Path $sut -ChildPath 'Public')) {
        Get-ChildItem -Path (Join-Path -Path $sut -ChildPath 'Public') -Filter "*.ps1" -Recurse -File | ForEach-Object {
            "$(Get-Content $_.FullName -Raw)`nExport-ModuleMember -Function '$($_.BaseName)'`n" | Add-Content -Path $psm1 -Encoding UTF8
            $functionsToExport += $_.BaseName
        }
    }
    Get-ChildItem -Path $sut -Directory | Where-Object {$_.BaseName -in @('lib','bin')} | ForEach-Object {
        Copy-Item $_.FullName -Destination $outputModVerDir -Container -Recurse
    }

    # Copy over manifest
    Copy-Item -Path $env:BHPSModuleManifest -Destination $outputModVerDir

    # Update FunctionsToExport on manifest
    Update-ModuleManifest -Path (Join-Path $outputModVerDir "$($env:BHProjectName).psd1") -FunctionsToExport ($functionsToExport | Sort-Object)

    if ((Get-ChildItem $outputModVerDir | Where-Object {$_.Name -eq "$($env:BHProjectName).psd1"}).BaseName -cne $env:BHProjectName) {
        "    Renaming manifest to correct casing"
        Rename-Item (Join-Path $outputModVerDir "$($env:BHProjectName).psd1") -NewName "$($env:BHProjectName).psd1" -Force
    }
    "    Created compiled module at [$outputModDir]"
    "    Output version directory contents"
    Get-ChildItem $outputModVerDir | Format-Table -Autosize
} -description 'Compiles module from source'

Task Import -Depends Compile {
    '    Testing import of compiled module'
    Import-Module (Join-Path $outputModVerDir "$($env:BHProjectName).psd1")
} -description 'Imports the newly compiled module'

task Test -Depends Init {
    '    Importing Pester'
    Import-Module -Name Pester -Verbose:$false -Force -ErrorAction Stop
    Push-Location
    Set-Location -PassThru $outputModDir
    if(-not $ENV:BHProjectPath) {
        Set-BuildEnvironment -Path $PSScriptRoot\..
    }

    $origModulePath = $env:PSModulePath
    if ( $env:PSModulePath.split($pathSeperator) -notcontains $outputDir ) {
        $env:PSModulePath = ($outputDir + $pathSeperator + $origModulePath)
    }

    Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue -Verbose:$false
    Import-Module -Name $outputModDir -Force -Verbose:$false
    $testResultsXml = Join-Path -Path $outputDir -ChildPath $TestFile
    $pesterParams = @{
        OutputFormat = 'NUnitXml'
        OutputFile = $testResultsXml
        PassThru = $true
        Path = $tests
    }
    if ($global:ExcludeTag) {
        $pesterParams['ExcludeTag'] = $global:ExcludeTag
        "    Invoking Pester and excluding tag(s) [$($global:ExcludeTag -join ', ')]..."
    }
    else {
        '    Invoking Pester...'
    }
    $testResults = Invoke-Pester @pesterParams
    '    Pester invocation complete!'
    if ($testResults.FailedCount -gt 0) {
        $testResults | Format-List
        Write-Error -Message 'One or more Pester tests failed. Build cannot continue!'
    }
    Pop-Location
    $env:PSModulePath = $origModulePath
} -description 'Run Pester tests against compiled module'


$deployScriptBlock = {
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
    if (($ENV:BHBuildSystem -eq 'VSTS' -and $env:BHCommitMessage -match '!deploy' -and $env:BHBranchName -eq "master") -or $global:ForceDeploy -eq $true) {
        if ($null -eq (Get-Module PoshTwit -ListAvailable)) {
            "    Installing PoshTwit module..."
            Install-Module PoshTwit -Scope CurrentUser
        }
        Import-Module PoshTwit -Verbose:$false
        # Load the module, read the exported functions, update the psd1 FunctionsToExport
        $commParsed = $env:BHCommitMessage | Select-String -Pattern '\sv\d+\.\d+\.\d+\s'
        if ($commParsed) {
            $commitVer = $commParsed.Matches.Value.Trim().Replace('v','')
        }
        $curVer = (Get-Module $env:BHProjectName).Version
        $galVer = if ($moduleInGallery = Find-Module "$env:BHProjectName*" -Repository PSGallery) {
            $moduleInGallery.Version.ToString()
        }
        else {
            '0.0.1'
        }
        $galVerSplit = $galVer.Split('.')
        $nextGalVer = [System.Version](($galVerSplit[0..($galVerSplit.Count - 2)] -join '.') + '.' + ([int]$galVerSplit[-1] + 1))

        $versionToDeploy = if ($commitVer -and ([System.Version]$commitVer -lt $nextGalVer)) {
            Write-Host -ForegroundColor Yellow "Version in commit message is $commitVer, which is less than the next Gallery version and would result in an error. Possible duplicate deployment build, skipping module bump and negating deployment"
            $env:BHCommitMessage = $env:BHCommitMessage.Replace('!deploy','')
            $null
        }
        elseif ($commitVer -and ([System.Version]$commitVer -gt $nextGalVer)) {
            Write-Host -ForegroundColor Green "Module version to deploy: $commitVer [from commit message]"
            [System.Version]$commitVer
        }
        elseif ($curVer -ge $nextGalVer) {
            Write-Host -ForegroundColor Green "Module version to deploy: $curVer [from manifest]"
            $curVer
        }
        elseif ($env:BHCommitMessage -match '!hotfix') {
            Write-Host -ForegroundColor Green "Module version to deploy: $nextGalVer [commit message match '!hotfix']"
            $nextGalVer
        }
        elseif ($env:BHCommitMessage -match '!minor') {
            $minorVers = [System.Version]("{0}.{1}.{2}" -f $nextGalVer.Major,([int]$nextGalVer.Minor + 1),0)
            Write-Host -ForegroundColor Green "Module version to deploy: $minorVers [commit message match '!minor']"
            $minorVers
        }
        elseif ($env:BHCommitMessage -match '!major') {
            $majorVers = [System.Version]("{0}.{1}.{2}" -f ([int]$nextGalVer.Major + 1),0,0)
            Write-Host -ForegroundColor Green "Module version to deploy: $majorVers [commit message match '!major']"
            $majorVers
        }
        else {
            Write-Host -ForegroundColor Green "Module version to deploy: $nextGalVer [PSGallery next version]"
            $nextGalVer
        }
        # Bump the module version
        if ($versionToDeploy) {
            try {
                if ($ENV:BHBuildSystem -eq 'VSTS' -and -not [String]::IsNullOrEmpty($env:NugetApiKey)) {
                    "    Publishing version [$($versionToDeploy)] to PSGallery..."
                    Update-Metadata -Path (Join-Path $outputModVerDir "$($env:BHProjectName).psd1") -PropertyName ModuleVersion -Value $versionToDeploy
                    try {
                        Publish-Module -Path $outputModVerDir -NuGetApiKey $env:NugetApiKey -Repository PSGallery
                        "    Deployment successful!"
                    }
                    catch {
                        $err = $_
                        Write-BuildError $err.Exception.Message
                        throw $err
                    }
                }
                else {
                    "    [SKIPPED] Deployment of version [$($versionToDeploy)] to PSGallery"
                }
                $commitId = git rev-parse --verify HEAD
                if (-not [String]::IsNullOrEmpty($env:GitHubPAT)) {
                    "    Creating Release ZIP..."
                    $zipPath = [System.IO.Path]::Combine($PSScriptRoot,"$($env:BHProjectName).zip")
                    if (Test-Path $zipPath) {
                        Remove-Item $zipPath -Force
                    }
                    Add-Type -Assembly System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::CreateFromDirectory($outputModDir,$zipPath)
                    "    Publishing Release v$($versionToDeploy) @ commit Id [$($commitId)] to GitHub..."
                    $ReleaseNotes = "# Changelog`n`n"
                    $ReleaseNotes += (git log -1 --pretty=%B | Select-Object -Skip 2) -join "`n"
                    $ReleaseNotes += "`n`n***`n`n# Instructions`n`n"
                    $ReleaseNotes += @"
1. [Click here](https://github.com/scrthq/$($env:BHProjectName)/releases/download/v$($versionToDeploy.ToString())/$($env:BHProjectName).zip) to download the *$($env:BHProjectName).zip* file attached to the release.
2. **If on Windows**: Right-click the downloaded zip, select Properties, then unblock the file.
    > _This is to prevent having to unblock each file individually after unzipping._
3. Unzip the archive.
4. (Optional) Place the module folder somewhere in your ``PSModulePath``.
    > _You can view the paths listed by running the environment variable ```$env:PSModulePath``_
5. Import the module, using the full path to the PSD1 file in place of ``$($env:BHProjectName)`` if the unzipped module folder is not in your ``PSModulePath``:
    ``````powershell
    # In `$env:PSModulePath
    Import-Module $($env:BHProjectName)

    # Otherwise, provide the path to the manifest:
    Import-Module -Path C:\MyPSModules\$($env:BHProjectName)\$($versionToDeploy.ToString())\$($env:BHProjectName).psd1
    ``````
"@
                    $gitHubParams = @{
                        VersionNumber    = $versionToDeploy.ToString()
                        CommitId         = $commitId
                        ReleaseNotes     = $ReleaseNotes
                        ArtifactPath     = $zipPath
                        GitHubUsername   = 'scrthq'
                        GitHubRepository = $env:BHProjectName
                        GitHubApiKey     = $env:GitHubPAT
                        Draft            = $false
                    }
                    Publish-GitHubRelease @gitHubParams
                    "    Release creation successful!"
                }
                else {
                    "    [SKIPPED] Publishing Release v$($versionToDeploy) @ commit Id [$($commitId)] to GitHub"
                }
                if ($ENV:BHBuildSystem -eq 'VSTS' -and -not [String]::IsNullOrEmpty($env:TwitterAccessSecret) -and -not [String]::IsNullOrEmpty($env:TwitterAccessToken) -and -not [String]::IsNullOrEmpty($env:TwitterConsumerKey) -and -not [String]::IsNullOrEmpty($env:TwitterConsumerSecret)) {
                    "    Publishing tweet about new release..."
                    $manifest = Import-PowerShellDataFile -Path (Join-Path $outputModVerDir "$($env:BHProjectName).psd1")
                    $text = "#$($env:BHProjectName) v$($versionToDeploy) is now available on the #PSGallery! https://www.powershellgallery.com/packages/$($env:BHProjectName) #PowerShell"
                    $manifest.PrivateData.PSData.Tags | Foreach-Object {
                        $text += " #$($_)"
                    }
                    if ($text.Length -gt 280) {
                        "    Trimming [$($text.Length - 280)] extra characters from tweet text to get to 280 character limit..."
                        $text = $text.Substring(0,280)
                    }
                    "    Tweet text: $text"
                    Publish-Tweet -Tweet $text -ConsumerKey $env:TwitterConsumerKey -ConsumerSecret $env:TwitterConsumerSecret -AccessToken $env:TwitterAccessToken -AccessSecret $env:TwitterAccessSecret
                    "    Tweet successful!"
                }
                else {
                    "    [SKIPPED] Twitter update of new release"
                }
            }
            catch {
                Write-Error $_ -ErrorAction Stop
            }
        }
        else {
            Write-Host -ForegroundColor Yellow "No module version matched! Negating deployment to prevent errors"
            $env:BHCommitMessage = $env:BHCommitMessage.Replace('!deploy','')
        }

    }
    else {
        Write-Host -ForegroundColor Magenta "Build system is not VSTS, commit message does not contain '!deploy' and/or branch is not 'master' -- skipping module update!"
    }
}

Task Deploy -Depends Init $deployScriptBlock -description 'Deploy module to PSGallery' -preaction {
    Import-Module -Name $outputModDir -Force -Verbose:$false
}

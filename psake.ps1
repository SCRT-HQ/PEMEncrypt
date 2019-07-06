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

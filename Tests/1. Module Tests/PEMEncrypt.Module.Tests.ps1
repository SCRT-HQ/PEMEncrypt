$projectRoot = Resolve-Path "$PSScriptRoot\..\.."
$ModulePath = Resolve-Path "$projectRoot\BuildOutput\$($env:BHProjectName)"
$decompiledModulePath = Resolve-Path "$projectRoot\$($env:BHProjectName)"

# Verbose output for non-master builds on appveyor
# Handy for troubleshooting.
# Splat @Verbose against commands as needed (here or in pester tests)
$Verbose = @{}
if ($ENV:BHBranchName -eq "development" -or $env:BHCommitMessage -match "!verbose") {
    $Verbose.add("Verbose",$True)
}

$moduleRoot = Split-Path (Resolve-Path "$ModulePath\*\*.psd1")

Import-Module $ModulePath -Force -Verbose:$false


Describe "Module tests: $($env:BHProjectName)" -Tag 'Module' {
    Context "Confirm files are valid Powershell syntax" {
        $scripts = Get-ChildItem $decompiledModulePath -Include *.ps1,*.psm1,*.psd1 -Recurse

        $testCase = $scripts | Foreach-Object {@{file = $_}}
        It "Script <file> should be valid Powershell" -TestCases $testCase {
            param($file)

            $file.fullname | Should Exist

            $contents = Get-Content -Path $file.fullname -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)
            $errors.Count | Should Be 0
        }
    }
    Context "Confirm there are no duplicate function names in private and public folders" {
        It 'Should have no duplicate functions' {
            $functions = Get-ChildItem "$decompiledModulePath\Public" -Recurse -Include *.ps1 | Select-Object -ExpandProperty BaseName
            $functions += Get-ChildItem "$decompiledModulePath\Private" -Recurse -Include *.ps1 | Select-Object -ExpandProperty BaseName
            ($functions | Group-Object | Where-Object {$_.Count -gt 1}).Count | Should -BeLessThan 1
        }
    }
}

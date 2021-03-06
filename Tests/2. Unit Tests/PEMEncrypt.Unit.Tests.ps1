$projectRoot = Resolve-Path "$PSScriptRoot\..\.."
if (-not $env:BHProjectName) {
    $env:BHProjectName = 'PEMEncrypt'
}
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
$pubPath = [System.IO.Path]::Combine($PSScriptRoot,'..','Resources','public.pem')
$pubPWPath = [System.IO.Path]::Combine($PSScriptRoot,'..','Resources','public_des3.pem')

$priPath = [System.IO.Path]::Combine($PSScriptRoot,'..','Resources','private.pem')
$priPWPath = [System.IO.Path]::Combine($PSScriptRoot,'..','Resources','private_des3.pem')

Import-Module $ModulePath -Verbose:$false

Describe "PEMEncrypt Unit Tests" {
    Context "String Encryption" {
        $testCases = @(
            @{
                Path = $pubPath
            }
            @{
                Path = $pubPWPath
            }
        )
        It "Should encrypt a string using a public key at path" -TestCases $testCases {
            Param(
                [String]
                $Path
            )
            $output = Protect-PEMString -StringToEncrypt 'hello' -PublicKey $Path
            $? | Should -Be $True
            $output.Length | Should -BeGreaterThan 1
            $output | Should -BeOfType 'System.String'
        }
        It "Should encrypt a string using a public key in string format" -TestCases $testCases {
            Param(
                [String]
                $Path
            )
            $pubKey = Get-Content $Path -Raw
            $output = Protect-PEMString -StringToEncrypt 'hello' -PublicKey $pubKey
            $? | Should -Be $True
            $output.Length | Should -BeGreaterThan 1
            $output | Should -BeOfType 'System.String'
        }
    }
    Context "String Decryption" {
        $testCases = @(
            @{
                PublicKeyPath = $pubPath
                PrivateKeyPath = $priPath
                Password = $null
            }
            @{
                PublicKeyPath = $pubPWPath
                PrivateKeyPath = $priPWPath
                Password = $(ConvertTo-SecureString 'private' -Force -AsPlainText)
            }
        )
        It "Should decrypt a string using the private key at path" -TestCases $testCases {
            Param(
                [String]
                $PublicKeyPath,
                [String]
                $PrivateKeyPath,
                [SecureString]
                $Password
            )
            $encString = $output = Protect-PEMString -StringToEncrypt 'hello' -PublicKey $PublicKeyPath
            $_password = @{}
            if ($null -ne $Password) {
                $_password['Password'] = $Password
            }
            $output = Unprotect-PEMString -StringToDecrypt $encString -PrivateKey $PrivateKeyPath @_password
            $? | Should -Be $True
            $output | Should -BeExactly 'hello'
            $output | Should -BeOfType 'System.String'
        }
        It "Should decrypt a string using the private key in string format" -TestCases $testCases {
            Param(
                [String]
                $PublicKeyPath,
                [String]
                $PrivateKeyPath,
                [SecureString]
                $Password
            )
            $pubKey = Get-Content $PublicKeyPath -Raw
            $priKey = Get-Content $PrivateKeyPath -Raw
            $encString = $output = Protect-PEMString -StringToEncrypt 'hello' -PublicKey $pubKey
            $_password = @{}
            if ($null -ne $Password) {
                $_password['Password'] = $Password
            }
            $output = Unprotect-PEMString -StringToDecrypt $encString -PrivateKey $priKey @_password
            $? | Should -Be $True
            $output | Should -BeExactly 'hello'
            $output | Should -BeOfType 'System.String'
        }
    }
}

function New-RSAKeyPair {
    <#
    .SYNOPSIS
    Generates an RSA PEM key pair and corresponding public SSH key.

    .DESCRIPTION
    Generates an RSA PEM key pair and corresponding public SSH key.

    .PARAMETER Length
    Alias: [-l,-b]
    The bit-length of the key to generate. Defaults to 4096.

    .PARAMETER Password
    Alias: -p
    A SecureString or plain-text String containing the password to encrypt the private key with. Exclude to create the private key without a password. For security, SecureString is recommended, although plain-text strings are allowed for broader compatibility.

    .PARAMETER Path
    Alias: -out
    The path to save the private key to. Defaults to ~/.ssh/id_rsa

    .PARAMETER Interactive
    Alias: -i
    If $true, prompt the user for the options to create the key with. Similar to creating a key with ssh-keygen.

    .PARAMETER NoFile
    Alias: -nof
    If $true, do not save any keys to file. Sets PassThru to $true and returns the generated RSAKey object containing the PublicPEM, PublicSSH, and PrivatePEM as string properties.

    .PARAMETER NoSSH
    Alias: -nos
    If $true, do not save the SSH key to file. Use when only the RSA PEM key pair is needed.

    .PARAMETER NoPEM
    Alias: -nop
    If $true, do not save the Public PEM key to file. Use when only the SSH key pair is needed.

    .PARAMETER PassThru
    Alias: -pt
    Returns the generated RSAKey object containing the PublicPEM, PublicSSH, and PrivatePEM as string properties.

    .PARAMETER Force
    Alias: -f
    If the keys at the file path already exist, overwrite them.

    .EXAMPLE
    New-RSAKeyPair -Interactive

    Generating public/private RSA key pair...
    Enter the path to save the key to (Default: C:\Users\nate\.ssh\id_rsa): .\Testing\id_pemencrypt
    Enter desired key length (Default: 4096):
    Enter passphrase (Default: No passphrase):
    Saving private key to path    : .\Testing\id_pemencrypt
    Saving public SSH key to path : .\Testing\id_pemencrypt.pub
    Saving public PEM key to path : .\Testing\id_pemencrypt.pem

    .EXAMPLE
    New-RSAKeyPair -NoFile

    PublicPEM
    ---------
    -----BEGIN PUBLIC KEY-----...

    .EXAMPLE
    New-RSAKeyPair -Length 1024 -NoFile | Select-Object -ExpandProperty PublicSSH
    ssh-rsa AAAAB3NzaC1yc2EAAAABAwAAAIEAo2CDoZRSy7JDJbX3ygsj3L09rMxq+46lMkWv6K33Cng3y4DokqqyUc2KCzhspBViGzVl3mJ+Y4S9O+D4bktcSDRZbEmZ0cVsFZFEAI17iEKnZHZnaqMIoIzaK2TS0rnQbkYpSDfKUAZtwSNiWB0TfMFdnOY6UJdlfLGzPeFJWTU= PEMEncrypt@User@Computer

    .EXAMPLE
    New-RSAKeyPair
    Key already exists at desired path: C:\Users\nate\.ssh\id_rsa. Use -Force to overwrite the existing key or choose a different path.
    At E:\Git\PEMEncrypt\BuildOutput\PEMEncrypt\0.2.0\PEMEncrypt.psm1:177 char:21
    + ...             throw "Key already exists at desired path: $Path. Use -Fo ...
    +                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : OperationStopped: (Key already exists \u2026e a different path.:String) [], RuntimeException
    + FullyQualifiedErrorId : Key already exists at desired path: C:\Users\nate\.ssh\id_rsa. Use -Force to overwrite the existing key or choose a different path.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
    [OutputType('SCRTHQ.PEMEncrypt.RSAKey')]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0)]
        [Alias('l','b')]
        [Int]
        $Length = 4096,
        [parameter()]
        [Alias('p')]
        [Object]
        $Password,
        [parameter()]
        [Alias('out')]
        [String]
        $Path = (Get-DefaultPath),
        [Parameter()]
        [Alias('i')]
        [Switch]
        $Interactive,
        [Parameter()]
        [Alias('nof')]
        [Switch]
        $NoFile,
        [Parameter()]
        [Alias('nos')]
        [Switch]
        $NoSSH,
        [Parameter()]
        [Alias('nop')]
        [Switch]
        $NoPEM,
        [Parameter()]
        [Alias('pt')]
        [Switch]
        $PassThru,
        [Parameter()]
        [Alias('f')]
        [Switch]
        $Force
    )
    Begin {
        Import-Assemblies
        if ($MyInvocation.InvocationName -eq 'genrsa') {
            $NoPEM = $false
            $NoSSH = $true
        }
        if ($MyInvocation.InvocationName -eq 'genssh') {
            $NoSSH = $false
            $NoPEM = $true
        }
    }
    Process {
        if ($Interactive) {
            Write-Host "Generating public/private RSA key pair..."
            if (-not $NoFile) {
                $newPath = if ($choice = Read-Host -Prompt "Enter the path to save the key to (Default: $Path)") {
                    $choice
                }
                else {
                    $Path
                }
                if (-not $Force -and (Test-Path $newPath)) {
                    Write-Error "Key already exists at desired path: $newPath. Use -Force to overwrite the existing key or choose a different path"
                    return
                }
                $parent = Split-Path $newPath -Parent
                if (-not (Test-Path $parent)) {
                    Write-Host "Creating missing parent folder: $parent"
                    New-Item -ItemType Directory $parent -Force | Out-Null
                }
            }
            $Length = if ($choice = Read-Host -Prompt "Enter desired key bit length (Default: 4096)") {
                $choice
            }
            else {
                4096
            }
            $Password = Read-Host -AsSecureString -Prompt "Enter passphrase (Default: No passphrase)"
            if (-not ([System.String]::IsNullOrEmpty((Unprotect-SecureString -SecureString $Password)))) {
                $confirmed = Read-Host -AsSecureString -Prompt "Enter the same passphrase to confirm"
                if ((Unprotect-SecureString -SecureString $confirmed) -ne (Unprotect-SecureString -SecureString $Password)) {
                    Write-Error "Passphrases provided do not match! Exiting"
                    return
                }
                Write-Host "Generating passphrase protected key pair"
                $keys = [SCRTHQ.PEMEncrypt.RSA]::Generate(
                    $Length,
                    (Unprotect-SecureString -SecureString $Password)
                )
            }
            else {
                Write-Host "Generating key pair"
                $keys = [SCRTHQ.PEMEncrypt.RSA]::Generate(
                    $Length
                )
            }
            if (-not $NoFile) {
                Write-Host "Saving private key to path    : $newPath"
                $keys.PrivatePEM | Set-Content -Path $newPath -Force
                if (-not $NoSSH) {
                    $sshPath = "{0}.pub" -f $newPath
                    Write-Host "Saving public SSH key to path : $sshPath"
                    $keys.PublicSSH | Set-Content -Path $sshPath -Force
                }
                if (-not $NoPEM) {
                    $pemPath = "{0}.pem" -f $newPath
                    Write-Host "Saving public PEM key to path : $pemPath"
                    $keys.PublicPEM | Set-Content -Path $pemPath -Force
                }
            }
            if ($PassThru -or $NoFile) {
                $keys
            }
        }
        else {
            if (-not $NoFile -and -not $Force -and (Test-Path $Path)) {
                Write-Error "Key already exists at desired path: $Path. Use -Force to overwrite the existing key or choose a different path."
                return
            }
            else {
                $parent = Split-Path $Path -Parent
                if (-not (Test-Path $parent)) {
                    Write-Host "Creating missing parent folder: $parent"
                    New-Item -ItemType Directory $parent -Force | Out-Null
                }
                $keys = if ($PSBoundParameters.ContainsKey('Password')) {
                    Write-Host "Generating passphrase protected key pair"
                    [SCRTHQ.PEMEncrypt.RSA]::Generate(
                        $Length,
                        $(
                            if ($Password -is [SecureString]) {
                                (Unprotect-SecureString -SecureString $Password)
                            }
                            else {
                                "$Password"
                            }
                        )
                    )
                }
                else {
                    Write-Host "Generating key pair"
                    [SCRTHQ.PEMEncrypt.RSA]::Generate(
                        $Length
                    )
                }
                if (-not $NoFile) {
                    Write-Host "Saving private key to path    : $Path"
                    $keys.PrivatePEM | Set-Content -Path $Path -Force
                    if (-not $NoSSH) {
                        $sshPath = "{0}.pub" -f $Path
                        Write-Host "Saving public SSH key to path : $sshPath"
                        $keys.PublicSSH | Set-Content -Path $sshPath -Force
                    }
                    if (-not $NoPEM) {
                        $pemPath = "{0}.pem" -f $Path
                        Write-Host "Saving public PEM key to path : $pemPath"
                        $keys.PublicPEM | Set-Content -Path $pemPath -Force
                    }
                }
                if ($PassThru -or $NoFile) {
                    $keys
                }
            }
        }
    }
}

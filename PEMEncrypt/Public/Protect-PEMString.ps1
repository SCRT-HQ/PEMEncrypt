function Protect-PEMString {
    <#
    .SYNOPSIS
    Encrypts a string by using a public RSA key.

    .DESCRIPTION
    Encrypts a string by using a public RSA key.

    .PARAMETER StringToEncrypt
    The plain-text string that you would like to encrypt with the public key.

    .PARAMETER PublicKey
    The full or relative path to the public key OR the key itself in string format.

    .EXAMPLE
    # Using a password-less private key
    $encrypted = 'Hello','How are you today?' | Protect-PEMString -PublicKey .\public.pem
    $encrypted | Unprotect-PEMString -PrivateKey .\private.pem

    .EXAMPLE
    # Use Get-Credential to prompt for credentials so it's not in plain text
    $encrypted = 'Hello','How are you today?' | Protect-PEMString -PublicKey .\public_des3.pem
    $keyCreds = Get-Credential -UserName key -Message 'Please enter the password for the private key'
    $encrypted | Unprotect-PEMString -PrivateKey .\private_des3.pem -Password $keyCreds.Password

    .EXAMPLE
    # Build a SecureString using a plain-text password
    $encrypted = 'Hello','How are you today?' | Protect-PEMString -PublicKey .\public_des3.pem
    $password = ConvertTo-SecureString 'P@$$w0rd' -AsPlainText -Force
    $encrypted | Unprotect-PEMString -PrivateKey .\private_des3.pem -Password $password
    #>
    [OutputType('System.String')]
    [CmdletBinding()]
    Param (
        [parameter(Mandatory,Position = 0,ValueFromPipeline)]
        [Alias('String')]
        [String[]]
        $StringToEncrypt,
        [parameter(Mandatory,Position = 1)]
        [Alias('PublicKeyPath','Key')]
        [String]
        $PublicKey
    )
    Begin {
        Import-Assemblies
        if ([System.IO.File]::Exists($PublicKey)) {
            $PublicKey = ([System.IO.File]::ReadAllText((Resolve-Path $PublicKey).Path))
        }
    }
    Process {
        foreach ($string in $StringToEncrypt) {
            try {
                [SCRTHQ.PEMEncrypt.Crypto]::Encrypt(
                    $string,
                    $PublicKey
                )
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
    }
}

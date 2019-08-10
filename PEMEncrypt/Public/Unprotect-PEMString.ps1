function Unprotect-PEMString {
    <#
    .SYNOPSIS
    Decrypts an encrypted string by using the private RSA key corresponding to the public key the string was encrypted with.

    .DESCRIPTION
    Decrypts an encrypted string by using the private RSA key corresponding to the public key the string was encrypted with.

    .PARAMETER StringToDecrypt
    The Base64 string that you would like to decrypt with the private key.

    .PARAMETER PrivateKey
    The full or relative path to the private key OR the key itself in string format.

    .PARAMETER Password
    A SecureString containing the password for the private key, if applicable.

    Exclude if the private key does not have a password.

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
        $StringToDecrypt,
        [parameter(Mandatory,Position = 1)]
        [Alias('PrivateKeyPath','Key')]
        [String]
        $PrivateKey,
        [parameter(Position = 2)]
        [AllowNull()]
        [SecureString]
        $Password
    )
    Begin {
        Import-Assemblies
        if ([System.IO.File]::Exists($PrivateKey)) {
            $PrivateKey = ([System.IO.File]::ReadAllText((Resolve-Path $PrivateKey).Path))
        }
    }
    Process {
        foreach ($string in $StringToDecrypt) {
            try {
                if ($PSBoundParameters.ContainsKey('Password')) {
                    [SCRTHQ.PEMEncrypt.Crypto]::Decrypt(
                        $string,
                        $PrivateKey,
                        (Unprotect-SecureString -SecureString $Password)
                    )
                }
                else {
                    [SCRTHQ.PEMEncrypt.Crypto]::Decrypt(
                        $string,
                        $PrivateKey
                    )
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
    }
}

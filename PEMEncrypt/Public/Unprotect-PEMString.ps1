function Unprotect-PEMString {
    [OutputType('System.String')]
    [CmdletBinding()]
    Param (
        [parameter(Mandatory,Position = 0,ValueFromPipeline)]
        [String[]]
        $StringToDecrypt,
        [parameter(Mandatory,Position = 1)]
        [String]
        $PrivateKeyPath,
        [parameter(Position = 2)]
        [AllowNull()]
        [SecureString]
        $Password
    )
    Begin {
        Import-Assemblies
    }
    Process {
        foreach ($string in $StringToDecrypt) {
            try {
                if ($PSBoundParameters.ContainsKey('Password')) {
                    [SCRTHQ.PEMEncrypt.Crypto]::Decrypt(
                        $string,
                        ([System.IO.File]::ReadAllText((Resolve-Path $PrivateKeyPath).Path)),
                        (New-Object PSCredential 'user',$Password).GetNetworkCredential().Password
                    )
                }
                else {
                    [SCRTHQ.PEMEncrypt.Crypto]::Decrypt(
                        $string,
                        ([System.IO.File]::ReadAllText((Resolve-Path $PrivateKeyPath).Path))
                    )
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
    }
}

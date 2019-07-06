function Protect-PEMString {
    [OutputType('System.String')]
    [CmdletBinding()]
    Param (
        [parameter(Mandatory,Position = 0,ValueFromPipeline)]
        [String[]]
        $StringToEncrypt,
        [parameter(Mandatory,Position = 1)]
        [String]
        $PublicKeyPath,
        [parameter(Position = 2)]
        [Int]
        $KeySize = 2048
    )
    Begin {
        Import-Assemblies
    }
    Process {
        foreach ($string in $StringToEncrypt) {
            try {
                [SCRTHQ.PEMEncrypt.Crypto]::Encrypt(
                    $string,
                    ([System.IO.File]::ReadAllText((Resolve-Path $PublicKeyPath).Path)),
                    $KeySize
                )
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
    }
}

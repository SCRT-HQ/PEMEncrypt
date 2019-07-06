function Protect-PEMString {
    Param (
        [parameter(Mandatory,Position = 0)]
        [String]
        $StringToEncrypt,
        [parameter(Mandatory,Position = 1)]
        [String]
        $PublicKeyPath,
        [parameter(Position = 2)]
        [Int]
        $KeySize = 2048
    )

    try {
        . ([System.IO.Path]::Combine($PSScriptRoot,'loadAssemblies.ps1'))

        [SCRTHQ.PEMEncrypt.Crypto]::Encrypt(
            $StringToEncrypt,
            ([System.IO.File]::ReadAllText((Resolve-Path $PublicKeyPath).Path)),
            $KeySize
        )
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

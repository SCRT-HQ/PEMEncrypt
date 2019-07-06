Param (
    [parameter(Mandatory,Position = 0)]
    [String]
    $StringToEncrypt,
    [parameter(Mandatory,Position = 1)]
    [String]
    $PublicKeyPath
)

try {
    . ([System.IO.Path]::Combine($PSScriptRoot,'loadAssemblies.ps1'))

    [SCRTHQ.PEMEncrypt.Encoder]::Encrypt(
        $StringToEncrypt,
        ([System.IO.File]::ReadAllText((Resolve-Path $PublicKeyPath).Path))
    )
}
catch {
    $PSCmdlet.ThrowTerminatingError($_)
}

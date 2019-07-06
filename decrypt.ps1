[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
Param (
    [parameter(Mandatory,Position = 0)]
    [String]
    $StringToDecrypt,
    [parameter(Mandatory,Position = 1)]
    [String]
    $PrivateKeyPath,
    [parameter(Position = 2)]
    [String]
    $Password = $null
)

try {
    . ([System.IO.Path]::Combine($PSScriptRoot,'loadAssemblies.ps1'))

    [SCRTHQ.PEMEncrypt.Decoder]::Decrypt(
        $StringToDecrypt,
        ([System.IO.File]::ReadAllText((Resolve-Path $PrivateKeyPath).Path)),
        $Password
    )
}
catch {
    $PSCmdlet.ThrowTerminatingError($_)
}

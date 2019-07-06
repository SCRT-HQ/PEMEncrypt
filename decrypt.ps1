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
    $Password
)

try {
    $bouncyCastlePath = [System.IO.Path]::Combine($PSScriptRoot,'BouncyCastle.Crypto.dll')
    if (-not ([System.Management.Automation.PSTypeName]'Org.BouncyCastle.Crypto.Engines.RsaEngine').Type) {
        Add-Type -Path $bouncyCastlePath | Out-Null
    }
    if ($Password -and -not ([System.Management.Automation.PSTypeName]'SCRTHQ.PEMEncrypt.Decoder').Type) {
        $PEMEncryptCS = [System.IO.Path]::Combine($PSScriptRoot,'SCRTHQ.PEMEncrypt.cs')
        Add-Type -Language CSharp -ReferencedAssemblies $bouncyCastlePath -TypeDefinition ([System.IO.File]::ReadAllText($PEMEncryptCS))
    }
}
catch {
    $global:Error.Remove($global:Error[0])
}
finally {
    try {
        $keyString = [System.IO.File]::ReadAllText((Resolve-Path $PrivateKeyPath).Path)
        if ($Password) {
            [SCRTHQ.PEMEncrypt.Decoder]::Decrypt(
                $StringToDecrypt,
                $keyString,
                $Password
            )
        }
        else {
            $bytesToDecrypt = [System.Convert]::FromBase64String($StringToDecrypt)
            $stream = New-Object System.IO.StringReader($keyString)
            $reader = New-Object Org.BouncyCastle.OpenSsl.PemReader($stream)
            $cert = $reader.ReadObject()
            $rsaEngine = New-Object Org.BouncyCastle.Crypto.Engines.RsaEngine
            $decryptEngine = New-Object Org.BouncyCastle.Crypto.Encodings.Pkcs1Encoding($rsaEngine)
            $decryptEngine.Init($false,$cert.Private)
            [System.Text.Encoding]::Default.GetString(
                $decryptEngine.ProcessBlock(
                    $bytesToDecrypt,
                    0,
                    $bytesToDecrypt.Length
                )
            )
        }

    }
    catch {
        $originalErr = $Error[0]
        if ($_.Exception.Message -match 'No password finder specified, but a password is required') {
            $PSCmdlet.ThrowTerminatingError(([System.MissingFieldException]::new('No password specified, but a password is required',$originalErr)))
        }
        else {
            $PSCmdlet.ThrowTerminatingError(([System.Exception]::new('Failed to decrypt the string with the provided Private Key',$originalErr)))
        }
    }
    finally {
        if ($stream) {
            $stream.Dispose()
        }
    }
}
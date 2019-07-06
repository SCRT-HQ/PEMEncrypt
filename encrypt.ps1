Param (
    [parameter(Mandatory,Position = 0)]
    [String]
    $StringToEncrypt,
    [parameter(Mandatory,Position = 1)]
    [String]
    $PublicKeyPath
)

try {
    $bouncyCastlePath = [System.IO.Path]::Combine($PSScriptRoot,'BouncyCastle.Crypto.dll')
    Add-Type -Path $bouncyCastlePath | Out-Null
}
catch {
    $global:Error.Remove($global:Error[0])
}
finally {
    try {
        $sr = New-Object System.IO.StreamReader((Resolve-Path $PublicKeyPath).Path)
        $reader = New-Object Org.BouncyCastle.OpenSsl.PemReader($sr)
        $cert = $reader.ReadObject()
        $rsaparameters = New-Object System.Security.Cryptography.RSAParameters
        $rsaparameters.Modulus = $cert.Modulus.ToByteArrayUnsigned()
        $rsaparameters.Exponent = $cert.Exponent.ToByteArrayUnsigned()
        $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider(1024)
        $rsa.ImportParameters($rsaparameters)
        $encryptedPassword = $rsa.Encrypt(
            ([System.Text.Encoding]::Default.GetBytes($StringToEncrypt)),
            [System.Security.Cryptography.RSAEncryptionPadding]::Pkcs1
        )

        [System.Convert]::ToBase64String($encryptedPassword)

    }
    catch {
        Write-Error $_
    }
    finally {
        if ($sr) {
            $sr.Dispose()
        }
    }
}
# PEMEncrypt

PEMEncrypt is a cross-platform PowerShell module handling string encryption and decryption using RSA keys only. It enables strings to be encrypted when the client only has the public key available, in the event the encrypted string is being sent to a secure endpoint housing the private key where it will be decrypted for further use. The same module can be implemented on the receiving endpoint to decrypt the strings as well, if desired.

***
<br />
<div align="center">
  <!-- Azure Pipelines -->
  <a href="https://dev.azure.com/scrthq/SCRT%20HQ/_build/latest?definitionId=6">
    <img src="https://dev.azure.com/scrthq/SCRT%20HQ/_apis/build/status/PEMEncrypt-CI"
      alt="Azure Pipelines" title="Azure Pipelines" />
  </a>&nbsp;&nbsp;&nbsp;&nbsp;
  <!-- Discord -->
  <a href="https://discord.gg/G66zVG7">
    <img src="https://img.shields.io/discord/235574673155293194.svg?style=flat&label=Discord&logo=discord&color=purple"
      alt="Discord - Chat" title="Discord - Chat" />
  </a>&nbsp;&nbsp;&nbsp;&nbsp;
  <!-- Slack -->
  <a href="https://scrthq-slack-invite.herokuapp.com/">
    <img src="https://img.shields.io/badge/chat-on%20slack-orange.svg?style=flat&logo=slack"
      alt="Slack - Chat" title="Slack - Chat" />
  </a>&nbsp;&nbsp;&nbsp;&nbsp;
  <!-- Codacy -->
  <a href="https://www.codacy.com/app/scrthq/PEMEncrypt?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=scrthq/PEMEncrypt&amp;utm_campaign=Badge_Grade">
    <img src="https://api.codacy.com/project/badge/Grade/63f7e2eb9b764c62a4ff196f68c59100"
      alt="Codacy" title="Codacy" />
  </a>
  </br>
  </br>
  <!-- PS Gallery -->
  <a href="https://www.PowerShellGallery.com/packages/PEMEncrypt">
    <img src="https://img.shields.io/powershellgallery/dt/PEMEncrypt.svg?style=flat&logo=powershell&color=blue"
      alt="PowerShell Gallery" title="PowerShell Gallery" />
  </a>&nbsp;&nbsp;&nbsp;&nbsp;
  <!-- GitHub Releases -->
  <a href="https://github.com/scrthq/PEMEncrypt/releases/latest">
    <img src="https://img.shields.io/github/downloads/scrthq/PEMEncrypt/total.svg?logo=github&color=blue"
      alt="GitHub Releases" title="GitHub Releases" />
  </a>&nbsp;&nbsp;&nbsp;&nbsp;
  <!-- GitHub Releases -->
  <a href="https://github.com/scrthq/PEMEncrypt/releases/latest">
    <img src="https://img.shields.io/github/release/scrthq/PEMEncrypt.svg?label=version&logo=github"
      alt="GitHub Releases" title="GitHub Releases" />
  </a>
</div>
<br />

***

## Background

Recently, I needed the ability to encrypt strings with *only* a public RSA key. I only needed to encrypt strings and only had access to the public key to encrypt with, as I would be sending that encrypted string to a secure endpoint which would decrypt the data sent and process it from there.

All of the PowerShell examples I came across online, both on sites like Stack Overflow as well as within modules in the PowerShell Gallery, focused on encrypting strings by using public methods found on the `X509Certificate2` class. If I had the full certificate, that wouldn't be an issue, but I only had the public RSA key / PEM file and I soon found out that instantiating an `X509Certificate2` with only a public key is a bit difficult, if not impossible.

## Installation

### PowerShell Gallery (Preferred)

```powershell
Install-Module PEMEncrypt -Scope CurrentUser -Repository PSGallery
```

### GitHub Releases

Please see the [Releases section of this repository](https://github.com/scrthq/PEMEncrypt/releases) for instructions.

## Usage

To view the function help at any time, please use `Get-Help Protect-PEMString` or `Get-Help Unprotect-PEMString` from your PowerShell session directly.

### Examples

```powershell
# Using a password-less private key
$encrypted = 'Hello','How are you today?' | Protect-PEMString -PublicKey .\public.pem
$encrypted | Unprotect-PEMString -PrivateKey .\private.pem

# Use Get-Credential to prompt for credentials so it's not in plain text
$encrypted = 'Hello','How are you today?' | Protect-PEMString -PublicKey .\public_des3.pem
$keyCreds = Get-Credential -UserName key -Message 'Please enter the password for the private key'
$encrypted | Unprotect-PEMString -PrivateKey .\private_des3.pem -Password $keyCreds.Password

# Build a SecureString using a plain-text password
$encrypted = 'Hello','How are you today?' | Protect-PEMString -PublicKey .\public_des3.pem
$password = ConvertTo-SecureString 'P@$$w0rd' -AsPlainText -Force
$encrypted | Unprotect-PEMString -PrivateKey .\private_des3.pem -Password $password
```

## FAQs

### Why not use existing tools like the built-in `*-CMSMessage` cmdlets or modules like ProtectedData or EncryptDecrypt?

The answer here is simple: I did not have a certificate and was not in a position to generate a new one for this use case; I had to use the public RSA key provided to me to encrypt my string with. Since I only had the public key and not a valid certificate, I could not use it to instantiate a certificate object.

### I'm receiving an error message that says "Bad Length". What's happening?

As outlined by [@praus](https://github.com/praus) in [Issue #3](https://github.com/scrthq/PEMEncrypt/issues/3), an RSA key "won't be able to encrypt strings longer than the key modulus size in bytes minus padding size (11 bytes for PKCS #1). For example, if your RSA key is 2048 bit long (therefore its modulus is 2048 bits/256 bytes), you will only be able to encrypt plaintexts that are 245 bytes in length or less. RSACryptoServiceProvider will throw CryptographicException when the plaintext is too long."

If you are running into this error and cannot shorten your string that you are trying to decrypt, you will need to generate a larger key pair to do the encryption with that supports the string size needed.

## Contributing

Interested in helping out with PEMEncrypt development? Please check out our [Contribution Guidelines](https://github.com/scrthq/PEMEncrypt/blob/master/CONTRIBUTING.md)!

Building the module locally to test changes is as easy as running the `build.ps1` file in the root of the repo. This will compile the module with your changes and import the newly compiled module at the end by default.

Want to run the Pester tests locally? Pass `Test` as the value to the `Task` script parameter like so:

```powershell
.\build.ps1 -Task Test
```

## Code of Conduct

Please adhere to our [Code of Conduct](https://github.com/scrthq/PEMEncrypt/blob/master/CODE_OF_CONDUCT.md) when interacting with this repo.

## License

[Apache 2.0](https://tldrlegal.com/license/apache-license-2.0-(apache-2.0))

## Changelog

[Full CHANGELOG here](https://github.com/scrthq/PEMEncrypt/blob/master/CHANGELOG.md)

***

## Generating RSA and SSH keys

Here are some helpful commands to generate key pairs with PEMEncrypt in comparison with the same commands in `openssl` and `ssh-keygen`

### RSA PEM Keys

**OpenSSL**

```powershell
# No password
openssl genrsa -out key 4096
openssl rsa -in key -outform PEM -pubout -out key.pem

# With password
openssl genrsa -des3 -out protected 4096 -passout pass:foobar
openssl rsa -in protected -outform PEM -pubout -out protected.pem -passin pass:foobar
```

**PEMEncrypt**

* Generates public/private key pair at once by default.
* Defaults to 4096 bit-length, but length left here for comparison.

```powershell
# No password
## Aliased command below translates to: New-RSAKeyPair -NoSSH -Length 4096 -Path key
genrsa -out key 4096

# With password
## Aliased command below translates to: New-RSAKeyPair -NoSSH -Length 4096 -Path key -Password foobar
genrsa -out protected -p foobar 4096
```

### SSH Keys

**ssh-keygen**

* Prompts for password if none is specified, even if no password is desired

```powershell
# No password
ssh-keygen -f ~/.ssh/id_newkey -t rsa -b 4096

# With password
ssh-keygen -f ~/.ssh/id_protected -t rsa -b 4096 -N foobar
```

**PEMEncrypt**

* Generates the key pair with no password when no password provided

```powershell
# No password
## Aliased command below translates to: New-RSAKeyPair -NoPEM -Length 4096 -Path ~/.ssh/id_newkey
genssh -out ~/.ssh/id_newkey -b 4096

# With password
## Aliased command below translates to: New-RSAKeyPair -NoPEM -Length 4096 -Path ~/.ssh/id_protected -Password foobar
genssh -out ~/.ssh/id_protected -b 4096 -p foobar
```

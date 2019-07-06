# PEMEncrypt

Cross-platform PowerShell scripts handling string encryption and decryption using RSA keys only. Allows strings to be encrypted when the client only has the public key available, in the event the encrypted string is being sent to a secure endpoint housing the private key where it will be decrypted for further use.


## ZEE PLAN

### Background

Recently, I needed the ability to encrypt strings with *only* a public RSA key. I only needed to encrypt and only had access to the public key to encrypt with, as I would be sending that encrypted string to a secure endpoint which would decrypt the data sent and process it from there.

All of the PowerShell examples I came across online, both on sites like Stack Overflow as well as within modules in the PowerShell Gallery, focused on encrypting strings by using public methods found on the `X509Certificate2` class. If I had the full certificate, that wouldn't be an issue, but I only had the public RSA key / PEM file and I soon found out that instantiating an `X509Certificate2` with only a public key is a bit difficult, if not impossible.

I knew what I wanted to do was possible, I was already doing it in Python. PowerShell has never let me down before and I'll be hardset if it lets me down today! **Let the scripting commence!** My typical pattern when I get hit with problems like this is...

1. Write a script or two that does what I need it to do.
2. Parameterize that script to make the script reusable.
3. Turn that script into a reusable function and wrap it in a module.
4. Send to anyone that could use it.
5. Eventually get a pipeline going to deploy it to the PowerShell Gallery for others to use.

As usual, I had my mind set on going about my normal path. I started to wrap the scripts in functions, then started to remember how many people I know that almost always get stuck here.

**Let's walk through this journey together!**

### What are we doing?

Today, we'll be walking through the following:

1. Converting the `encrypt.ps1` and `decrypt.ps1` scripts in this repo into reusable functions.
2. Wrapping those functions in a module.
3. Writing some Pester tests that can...
   1. Validate that we can encrypt and decrypt strings as expected.
   2. Throw errors when things should expectedly not work.
4. Write a build script that will compile our module into a distributable, final form:
   1. Run `dotnet build` against any C# projects, if applicable.
   2. Compile all public and private functions onto the final PSM1 file.
   3. Update our PSD1 module manifest file as needed.
5. Attach Azure Pipelines to our project in GitHub so a build is triggered whenever we push commits to the GitHub repository.
6. Set up a Release Pipeline in Azure Pipelines to automatically...
   1. Deploy the module to the PowerShell Gallery
   2. Deploy the module to GitHub Releases
   3. Send out a tweet letting everyone know that the module was released.

The best part about all of the above is 100% of what we walk through is **FREE**. Zero dollars, $free.99.

### Useful commands



```powershell
# Generate a private/public key pair (not password protected):
## Generate the private key and save as private.pem in the current directory.
openssl genrsa -out private.pem 2048

## Extract the public key from the generated private key.
openssl rsa -in private.pem -outform PEM -pubout -out public.pem

# Generate a password protected private/public key pair:
## Generate the private key and save as private.pem in the current directory.
## Enter the desired password when prompted, then verify the same password when prompted again.
openssl genrsa -des3 -out private_des3.pem 2048

## Extract the public key from the generated private key.
## Enter the password set when creating the private key when prompted.
openssl rsa -in private_des3.pem -outform PEM -pubout -out public_des3.pem
```

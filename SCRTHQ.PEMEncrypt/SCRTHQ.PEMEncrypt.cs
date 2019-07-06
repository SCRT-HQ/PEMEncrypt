using Org.BouncyCastle.Crypto;
using Org.BouncyCastle.Crypto.Encodings;
using Org.BouncyCastle.Crypto.Engines;
using Org.BouncyCastle.Crypto.Parameters;
using Org.BouncyCastle.OpenSsl;
using System;
using System.IO;
using System.Text;
using System.Security.Cryptography;

namespace SCRTHQ.PEMEncrypt
{
    public class Encoder
    {
        public static string Encrypt(string stringToEncrypt, string publicKey, int dwKeySize = 1024)
        {
            PemReader reader;
            RsaKeyParameters keyPair;

            using (TextReader txtreader = new StringReader(publicKey))
            {
                reader = new PemReader(txtreader);
                keyPair = (RsaKeyParameters) reader.ReadObject();
            }
            RSAParameters rsaParameters = new RSAParameters();
            rsaParameters.Modulus = keyPair.Modulus.ToByteArrayUnsigned();
            rsaParameters.Exponent = keyPair.Exponent.ToByteArrayUnsigned();
            RSACryptoServiceProvider rsa = new RSACryptoServiceProvider(dwKeySize);
            rsa.ImportParameters(rsaParameters);
            string encrypted = Convert.ToBase64String(
                rsa.Encrypt(
                    Encoding.UTF8.GetBytes(
                        stringToEncrypt
                    ),
                    RSAEncryptionPadding.Pkcs1
                )
            );
            return encrypted;
        }
    }
    public class Decoder
    {
        public static string Decrypt(string stringToDecrypt, string privateKey, string password = null)
        {
            var bytesToDecrypt = Convert.FromBase64String(stringToDecrypt);
            AsymmetricCipherKeyPair keyPair;
            var decryptEngine = new Pkcs1Encoding(new RsaEngine());

            using (TextReader txtreader = new StringReader(privateKey))
            {
                if (password == null)
                {
                    keyPair = (AsymmetricCipherKeyPair) DecodePrivateKey(txtreader);
                }
                else
                {
                    keyPair = (AsymmetricCipherKeyPair) DecodePrivateKey(txtreader, password);
                }
                decryptEngine.Init(false, keyPair.Private);
            }

            var decrypted = Encoding.UTF8.GetString(decryptEngine.ProcessBlock(bytesToDecrypt, 0, bytesToDecrypt.Length));
            return decrypted;
        }
        private static AsymmetricCipherKeyPair DecodePrivateKey(TextReader privateKey)
        {
            PemReader pemReader = new PemReader(privateKey);
            AsymmetricCipherKeyPair privateKeyObject = (AsymmetricCipherKeyPair)pemReader.ReadObject();
            RsaPrivateCrtKeyParameters rsaPrivatekey = (RsaPrivateCrtKeyParameters)privateKeyObject.Private;
            RsaKeyParameters rsaPublicKey = new RsaKeyParameters(false, rsaPrivatekey.Modulus, rsaPrivatekey.PublicExponent);
            AsymmetricCipherKeyPair kp = new AsymmetricCipherKeyPair(rsaPublicKey, rsaPrivatekey);
            return kp;
        }
        private static AsymmetricCipherKeyPair DecodePrivateKey(TextReader privateKey, string password)
        {
            PemReader pemReader = new PemReader(privateKey, new PasswordFinder(password));
            AsymmetricCipherKeyPair privateKeyObject = (AsymmetricCipherKeyPair)pemReader.ReadObject();
            RsaPrivateCrtKeyParameters rsaPrivatekey = (RsaPrivateCrtKeyParameters)privateKeyObject.Private;
            RsaKeyParameters rsaPublicKey = new RsaKeyParameters(false, rsaPrivatekey.Modulus, rsaPrivatekey.PublicExponent);
            AsymmetricCipherKeyPair kp = new AsymmetricCipherKeyPair(rsaPublicKey, rsaPrivatekey);
            return kp;
        }
        private class PasswordFinder : IPasswordFinder
        {
            private string password;

            public PasswordFinder(string password)
            {
                this.password = password;
            }
            public char[] GetPassword()
            {
                return password.ToCharArray();
            }
        }
    }
}
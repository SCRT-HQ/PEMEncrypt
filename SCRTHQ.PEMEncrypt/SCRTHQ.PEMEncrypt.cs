using System.Linq;
using Org.BouncyCastle.Crypto;
using Org.BouncyCastle.Crypto.Digests;
using Org.BouncyCastle.Crypto.Encodings;
using Org.BouncyCastle.Crypto.Engines;
using Org.BouncyCastle.Crypto.Generators;
using Org.BouncyCastle.Crypto.Parameters;
using Org.BouncyCastle.Math;
using Org.BouncyCastle.OpenSsl;
using Org.BouncyCastle.Security;
using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace SCRTHQ.PEMEncrypt
{
    public class Crypto
    {
        public static string Encrypt(string stringToEncrypt, string publicKey)
        {
            Byte[] bytesToEncrypt = Encoding.UTF8.GetBytes(stringToEncrypt);
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
            var padding = RSAEncryptionPadding.Pkcs1;

            RSACryptoServiceProvider rsa = new RSACryptoServiceProvider(keyPair.Modulus.BitLength);
            rsa.ImportParameters(rsaParameters);

            string encrypted = Convert.ToBase64String(
                rsa.Encrypt(
                    bytesToEncrypt,
                    padding
                )
            );
            return encrypted;
        }
        public static string Decrypt(string stringToDecrypt, string privateKey, string password = null)
        {
            Byte[] bytesToDecrypt = Convert.FromBase64String(stringToDecrypt);
            AsymmetricCipherKeyPair keyPair;
            Pkcs1Encoding decryptEngine = new Pkcs1Encoding(new RsaEngine());

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

            var decrypted = Encoding.UTF8.GetString(
                decryptEngine.ProcessBlock(
                    bytesToDecrypt,
                    0,
                    bytesToDecrypt.Length
                )
            );
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
            RsaPrivateCrtKeyParameters rsaPrivatekey;
            PemReader pemReader = new PemReader(privateKey, new PasswordFinder(password));
            var privateKeyObject = pemReader.ReadObject();
            if (privateKeyObject is AsymmetricCipherKeyPair ackp)
            {
                rsaPrivatekey = (RsaPrivateCrtKeyParameters)ackp.Private;
            }
            else
            {
                rsaPrivatekey = (RsaPrivateCrtKeyParameters)privateKeyObject;
            }
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
    public class RSAKey
    {
        public string PublicPEM { get; set; }
        public string PrivatePEM { get; set; }
        public string PublicSSH { get; set; }
    }
    public static class RSA
    {
        // Adapted from:
        // - https://stackoverflow.com/a/27659151/5302680
        // - https://stackoverflow.com/q/21937369/5302680
        public static RSAKey Generate(int strength = 4096, string passPhrase = null)
        {
            try
            {
                RSAKey result = new RSAKey();
                IAsymmetricCipherKeyPairGenerator gen;
                KeyGenerationParameters param;
                gen = new RsaKeyPairGenerator();
                param = new RsaKeyGenerationParameters(
                    BigInteger.ValueOf(3L),
                    new SecureRandom(),
                    strength,
                    80
                );
                gen.Init(param);
                AsymmetricCipherKeyPair pair = gen.GenerateKeyPair();
                using(TextWriter textWriter = new StringWriter())
                {
                    PemWriter wr = new PemWriter(textWriter);
                    if (passPhrase != null)
                    {
                        var encryptor = new Pkcs8Generator(pair.Private, Pkcs8Generator.PbeSha1_3DES);
                        encryptor.IterationCount = 80;
                        encryptor.Password = passPhrase.ToCharArray();
                        var pem = encryptor.Generate();
                        wr.WriteObject(pem);
                    }
                    else
                    {
                        wr.WriteObject(pair.Private);
                    }
                    wr.Writer.Flush();
                    result.PrivatePEM = textWriter.ToString();
                }

                using (TextWriter textWriter = new StringWriter())
                {
                    PemWriter wr = new PemWriter(textWriter);
                    wr.WriteObject(pair.Public);
                    wr.Writer.Flush();

                    result.PublicPEM = textWriter.ToString();
                }

                using (StringReader sr = new StringReader(result.PublicPEM))
                {
                    PemReader reader = new PemReader(sr);
                    RsaKeyParameters r = (RsaKeyParameters)reader.ReadObject();
                    byte[] sshrsa_bytes = Encoding.Default.GetBytes("ssh-rsa");
                    byte[] n = r.Modulus.ToByteArray();
                    byte[] e = r.Exponent.ToByteArray();

                    string buffer64;
                    using(MemoryStream ms = new MemoryStream()){
                        ms.Write(ToBytes(sshrsa_bytes.Length), 0, 4);
                        ms.Write(sshrsa_bytes, 0, sshrsa_bytes.Length);
                        ms.Write(ToBytes(e.Length), 0, 4);
                        ms.Write(e, 0, e.Length);
                        ms.Write(ToBytes(n.Length), 0, 4);
                        ms.Write(n, 0, n.Length);
                        ms.Flush();
                        buffer64 = Convert.ToBase64String(ms.ToArray());
                    }

                    result.PublicSSH = string.Format(
                        "ssh-rsa {0} {1}@{2}",
                        buffer64,
                        Environment.UserName,
                        Environment.MachineName);
                }

                return result;
            }
            catch (Org.BouncyCastle.Crypto.CryptoException ex)
            {
                throw ex;
            }
        }
        private static byte[] ToBytes(int i)
        {
            byte[] bts = BitConverter.GetBytes(i);
            if (BitConverter.IsLittleEndian)
            {
                Array.Reverse(bts);
            }
            return bts;
        }
    }
}

# Generate a private/public key pair (not password protected):

## Generate the private key and save as private.pem in the current directory.
openssl genrsa -out private.pem 2048

## Extract the public key from the generated private key.
openssl rsa -in private.pem -outform PEM -pubout -out public.pem

######

# Generate a password protected private/public key pair:

## Generate the private key and save as private.pem in the current directory.
## Enter the desired password when prompted, then verify the same password when prompted again.
openssl genrsa -des3 -out private_des3.pem 2048

## Extract the public key from the generated private key.
## Enter the password set when creating the private key when prompted.
openssl rsa -in private_des3.pem -outform PEM -pubout -out public_des3.pem

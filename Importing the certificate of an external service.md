#Cloud pak Business automation 

## Importing the certificate of an external service
To integrate with an external service, you must first import its Transport Layer Security (TLS) certificate into the operator trust list. These certificates are added to the truststore of each component in the Cloud Pak.

## Procedure

Get the signer certificate that is used to sign your external service and save it to a certificate.
For example, external-service-cert.crt.
For more information, see OpenSSL.

### Get Certificate based on ports

The following example command gets the certificate chain of cloud.ibm.com by using OpenSSL.

    echo | openssl s_client -showcerts -connect cloud.ibm.com:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > external-service-cert.crt 


(second option)The following example command gets the certificate chain of cloud.ibm.com by using keytool.

    keytool -printcert -sslserver cloud.ibm.com:443 -rfc > external-service-cert.crt

### Create secrets

To create the secret, run the following command in the OpenShift project:

    oc create secret generic secretName --from-file=tls.crt=your_cert_path/external-service-cert.crt

Substitute your values for secretName and your_cert_path/external-service-cert.crt. The certificate must be in Privacy Enhanced Mail (PEM) format. When the secret is created, you can discard the .crt file that you generated.

### Add the secret to the component's truststore.

If you want this service to be trusted by all components installed by the operator, add the secret to the custom resource in the shared_configuration.trusted_certificate_list parameter.

For example, the following list includes two external services:

        shared_configuration:
          trusted_certificate_list:
            - extenalservice1-tls-secret
            - externalservice2-tls-secret

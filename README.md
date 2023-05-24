# ACME webhook for Oracle Cloud Infrastructure

This solver can be used when you want to use cert-manager with Oracle Cloud Infrastructure as a DNS provider.

## Reference
- The Initial Developer of cert-manager-webhook-oci (https://github.com/cert-manager/webhook-example) is cert-manager (https://cert-manager.io/).
  Copyright 2019 The cert-manager Authors. All Rights Reserved.
- This project also contains the work of the
  cert-manager-webhook-oci project authors (https://gitlab.com/dn13/cert-manager-webhook-oci).
  Copyright 2020 The ACME webhook for Oracle Cloud Infrastructure Authors. All Rights Reserved.

## Requirements
-   [go](https://golang.org/) >= 1.17.0 *only for development*
-   [helm](https://helm.sh/) >= v3.0.0
-   [kubernetes](https://kubernetes.io/) >= v1.14.0
-   [cert-manager](https://cert-manager.io/) >= 1.0

## Installation

### cert-manager

Follow the [instructions](https://cert-manager.io/docs/installation/) using the cert-manager documentation to install it within your cluster.

### OCI-DNS Provider

#### From local checkout

```bash
helm install --namespace cert-manager cert-manager-webhook-oci deploy/cert-manager-webhook-oci
```
**Note**: The kubernetes resources used to install the cert-manager-ocidns should be deployed within the same namespace as the cert-manager.

To uninstall the webhook run
```bash
helm uninstall --namespace cert-manager cert-manager-ocidns
```

## Issuer Configuration

The webhook custom configuration (everything that appears below "webhook" in the `ClusterIssuer`) 
contains the following information:

```
	CompartmentOCID       string `json:"compartmentOCID"`
	OCIProfileSecretRef   string `json:"ociProfileSecretName"`
	OCIProfileSecretKey   string `json:"ociProfileSecretKey"`
	UseInstancePrincipals bool   `json:"useInstancePrincipals"`
	OciZoneName           string `json:"ociZoneName"`
```

This defines the OCI DNS client connection information required to communicate with an
OCI DNS Zone that can answer CertManager DNS01 challenges.  

### OCI Authentication

OCI authentication methods and data are determined in the following sequence:

1. From the `OCIProfileSecretRef` if it is defined
2. From the `UseInstancePrincipals` flag

The currently supported (and utilized) method by Verrazzano is via the `OCIProfileSecretRef`.  

The OCI authentication type and credentials are populated from the secret defined by `OCIProfileSecretRef`, and
`OCIProfileSecretKey` defines the key in the secret data holding the credential information.  

The secret must

* Be located in the same namespace that cert-manager is using for its [Cluster Resource Namespace](https://cert-manager.io/docs/configuration/#cluster-resource-namespace)
* Be in the format defined  by the [Verrazzano documentation](https://verrazzano.io/v1.5/docs/customize/dns/)

The secret format allows for both OCI `user_principal` (API Key) and `instance_principal` authentication.  See
[the OCI SDK documentation](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/sdk_authentication_methods.htm) for
details on OCI authentication methods.


# Example

The following example creates a `ClusterIssuer` for the Let's Encrypt Stating environment for the zone/domain 
`myzone.example.com` in OCI DNS:

## Let's Encrypt ClusterIssuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: verrazzano-cluster-issuer
spec:
  acme:
    # The ACME server URL
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: me@somedomain.com
    privateKeySecretRef:
      name: verrazzano-cert-acme-secret
    solvers:
      - dns01:
          webhook:
            groupName: verrazzano.io
            solverName: oci
            config:
              serviceAccountSecretRef: oci
              serviceAccountSecretKey: "oci.yaml"
              ocizonename: myzone.example.com
              compartmentOCID: ocid1.dns-zone.oc1..aabbcc...
```

## Create a certificate

Finally you can create certificates, for example:

```yaml
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: example-cert
  namespace: cert-manager
spec:
  commonName: myhost.myzone.example.com
  dnsNames:
    - myhost.myzone.example.com
  issuerRef:
    name: letsencrypt-staging
  secretName: example-cert
```

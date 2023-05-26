// Portions of the code in this file are derived from https://github.com/cert-manager/webhook-example/blob/master/main_test.go
// Portions of the code in this file are derived from https://gitlab.com/dn13/cert-manager-webhook-oci/-/blob/1.1.0/main_test.go

package main

import (
	"math/rand"
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	extapi "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"

	"github.com/cert-manager/cert-manager/pkg/acme/webhook/apis/acme/v1alpha1"
	"github.com/cert-manager/cert-manager/test/acme/dns"
	ocidns "github.com/oracle/oci-go-sdk/v64/dns"
)

var (
	zone = os.Getenv("TEST_ZONE_NAME")
	fqdn string
)

func TestRunsSuite(t *testing.T) {
	// The manifest path should contain a file named config.json that is a
	// snippet of valid configuration that should be included on the
	// ChallengeRequest passed as part of the test cases.

	fqdn = GetRandomString(20) + "." + zone + "."

	solver := &ociDNSProviderSolver{}
	fixture := dns.NewFixture(solver,
		dns.SetResolvedZone(zone),
		dns.SetResolvedFQDN(fqdn),
		dns.SetAllowAmbientCredentials(false),
		dns.SetManifestPath("testdata/oci"),
	)

	fixture.RunConformance(t)
	fixture.RunBasic(t)
	fixture.RunExtended(t)
}

func GetRandomString(n int) string {
	letters := []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

	b := make([]rune, n)
	for i := range b {
		b[i] = letters[rand.Intn(len(letters))]
	}
	return string(b)
}

var (
	testZone = "zone.example.com"
	config   = `{"ociZoneName":"zone.example.com","ociProfileSecretKey":"oci.yaml","ociProfileSecretName":"oci","useInstancePrincipals":false}`
)

func TestLoadConfig(t *testing.T) {
	var cfgJSON extapi.JSON
	cfgJSON.Raw = []byte(config)
	cfg, err := loadConfig(&cfgJSON)
	assert.Equal(t, testZone, cfg.OciZoneName)
	assert.False(t, cfg.UseInstancePrincipals)
	assert.Equal(t, "oci.yaml", cfg.OCIProfileSecretKey)
	assert.Equal(t, "oci", cfg.OCIProfileSecretRef)
	assert.Nil(t, err)
}

func TestPatchRequest(t *testing.T) {
	cfg := ociDNSProviderConfig{CompartmentOCID: "compartment.ocid"}
	ch := v1alpha1.ChallengeRequest{
		ResolvedZone: "resolved.zone.example.com",
		ResolvedFQDN: "resolvedfqdn.zone.example.com.",
		Key:          "key",
	}
	request := patchRequest(&cfg, &ch, ocidns.RecordOperationOperationRemove)
	assert.Equal(t, cfg.CompartmentOCID, *request.CompartmentId)
	assert.Equal(t, ch.ResolvedZone, *request.ZoneNameOrId)
	assert.Equal(t, ch.Key, *request.Items[0].Rdata)
	assert.Equal(t, 1, len(request.Items))
	assert.Equal(t, "TXT", *request.Items[0].Rtype)
	assert.Equal(t, 60, *request.Items[0].Ttl)
	assert.Equal(t, strings.TrimSuffix(ch.ResolvedFQDN, "."), *request.Items[0].Domain)
	assert.Equal(t, ocidns.RecordOperationOperationRemove, request.Items[0].Operation)
}

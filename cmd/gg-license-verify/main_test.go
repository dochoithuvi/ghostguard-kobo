package main

import (
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"testing"
)

func TestSharedRegistryVerifyAndLookup(t *testing.T) {
	priv, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil { t.Fatal(err) }
	der, err := x509.MarshalPKIXPublicKey(&priv.PublicKey)
	if err != nil { t.Fatal(err) }
	old := keyring
	keyring = map[string]string{"test-key": string(pem.EncodeToMemory(&pem.Block{Type:"PUBLIC KEY", Bytes:der}))}
	defer func(){ keyring = old }()

	serial := "N249123456789"
	reg := registry{RegistryFormat:1, Product:"DCPRO GhostGuard", KeyID:"test-key", SigAlg:"RSA-SHA256", Entries:[]licenseEntry{{SerialHash:serialHash(serial), LicenseID:"DCPRO-TEST", IssuedAt:"2026-08-01", Expire:"2026-12-31", Features:[]string{"kobo","ultimate"}, Status:"active"}}}
	regRaw, _ := json.Marshal(reg)
	digest := sha256.Sum256(regRaw)
	sig, err := rsa.SignPKCS1v15(rand.Reader, priv, crypto.SHA256, digest[:])
	if err != nil { t.Fatal(err) }
	env := signatureEnvelope{SignatureFormat:1, KeyID:"test-key", SigAlg:"RSA-SHA256", ContentSHA256:fmt.Sprintf("%x",digest[:]), Sig:base64.StdEncoding.EncodeToString(sig)}
	sigRaw, _ := json.Marshal(env)
	parsed, err := verifyPair(regRaw, sigRaw)
	if err != nil { t.Fatal(err) }
	e, err := evaluate(parsed, serial, "2026-08-21")
	if err != nil { t.Fatal(err) }
	if e.LicenseID != "DCPRO-TEST" { t.Fatalf("unexpected license %s", e.LicenseID) }

	tampered := append([]byte(nil), regRaw...)
	tampered[len(tampered)-1] ^= 1
	if _, err := verifyPair(tampered, sigRaw); err == nil { t.Fatal("tampered registry should fail") }
	if _, err := evaluate(parsed, "OTHER-SERIAL", "2026-08-21"); err == nil { t.Fatal("other serial should not be listed") }
}

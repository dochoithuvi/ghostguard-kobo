package main

import (
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Same public trust anchors used by GhostGuard Kindle online licensing.
// Private signing keys are never shipped to Kobo.
var keyring = map[string]string{
	"ghostguard-prod-2026-08": `-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA1ZixzeJ8w9dfVWSsx3AP
kTophnu2IsH9VYaCmsGqeCA4ffm1wayd6smC6c3kiVWWHTub3y2IdTS3ihveAh5O
N3+QkAdv+f/Jo7Y0xntmEdSgio/E4NM6DwZojXizulnUhAPEorsw3u32OopLc/wW
sq2b7mHj1X/n5y58TqBfgjs6fkVUGF+XZw+hsZphdPUSjCXbzxXQ6srSYKvFsbOL
0AowFZ60StSeYAhqXU1huk6khhMSXqbXG7cIqyPd2xPqpLTigL3r3fd661SHv0NS
gZ1gXSxWJTXi5RMmwo9CMujN0p7rkq0EEiW/kZfE236eqmEHJLQE9fEuaOA25Xhc
UlIiT8W4kLk/WaKb5lPrmaeydQk9ZkOddkrgcQmIPg9KStu7VDlCqadwDFgR+80w
afcF3WGU3bJVO6zWXuRgrZKmZXLySV3CnA/41BA5OH5f7X9M5WcphLv9/Z7XIZ31
6QqIt90T8mSMhar8f5a1FjnSzDNk6ud+QvRywXHLof7HAgMBAAE=
-----END PUBLIC KEY-----`,
	"ghostguard-rc-2026-08": `-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAoDN0HYwim4Aa6dcani4F
TW6sOOpPRtCFDLL0ohkTdcbOQqhikQ071eIVjslOqA0R22fmrHCiKVsKIfjzCFBH
RjU08CPED0qouOVqYCaVgzZsQGy9olseyIh0eC+M2NUFtBXPcoRjf+PPmb8DI6kt
RoIqRBGE+k2jMJnmaXFKar8hYTjTfYpKP9e2ShGgF9d6Avv+QDISMe4wzG4Jlr/2
VtWviGNUIXj/YqI54o3KPl5gETX/7RJX9wUdWF/XQaYs+c//125c+Uy/c25rk2g0
S8l12ErKTrmuZ0IZLSWi7gsgdftFH63GC7GdKTOs8/aXwTQV707ljKRXWW82jnI/
ckdzvR743hb5PEdQMAaE9hkqwLSJg0k9JT5vEvMXUDzyuCKN/vizbrJPEUa61fF1
7P8oMeDyQNcaMjv5ytR/AJ6b2QfkEfOeY86SpSWot1Mfk0ukHOPpjZp2AU1qoviU
o8qq5SKhI9QQBdmUmZoWQx3FOmDUikNh2jPLH/9/kJY3AgMBAAE=
-----END PUBLIC KEY-----`,
}

type signatureEnvelope struct {
	SignatureFormat int    `json:"signature_format"`
	KeyID           string `json:"key_id"`
	SigAlg          string `json:"sig_alg"`
	ContentSHA256   string `json:"content_sha256"`
	Sig             string `json:"sig"`
}

type licenseEntry struct {
	SerialHash string   `json:"serial_hash"`
	LicenseID  string   `json:"license_id"`
	IssuedAt   string   `json:"issued_at"`
	Expire     string   `json:"expire"`
	Features   []string `json:"features"`
	Status     string   `json:"status"`
}

type registry struct {
	RegistryFormat int            `json:"registry_format"`
	Product        string         `json:"product"`
	KeyID          string         `json:"key_id"`
	SigAlg         string         `json:"sig_alg"`
	Entries        []licenseEntry `json:"entries"`
}

func deny(msg string) { fmt.Printf("DENY|%s\n", msg); os.Exit(1) }
func ok(msg string)   { fmt.Printf("OK|%s\n", msg); os.Exit(0) }

func cleanSerial(s string) string {
	s = strings.ToUpper(s)
	var b strings.Builder
	for _, r := range s {
		if (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func serialHash(s string) string {
	h := sha256.Sum256([]byte(cleanSerial(s)))
	return fmt.Sprintf("%x", h[:])
}

func parsePublicKey(pemText string) (*rsa.PublicKey, error) {
	block, _ := pem.Decode([]byte(pemText))
	if block == nil {
		return nil, fmt.Errorf("pem decode")
	}
	pubAny, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	pub, ok := pubAny.(*rsa.PublicKey)
	if !ok {
		return nil, fmt.Errorf("not rsa")
	}
	return pub, nil
}

func verifyPair(regRaw, sigRaw []byte) (*registry, error) {
	var env signatureEnvelope
	if err := json.Unmarshal(sigRaw, &env); err != nil {
		return nil, fmt.Errorf("REGISTRY_SIG_JSON_INVALID")
	}
	if env.SignatureFormat != 1 {
		return nil, fmt.Errorf("REGISTRY_SIG_FORMAT_UNSUPPORTED")
	}
	if strings.ToUpper(env.SigAlg) != "RSA-SHA256" {
		return nil, fmt.Errorf("REGISTRY_SIG_ALG_UNSUPPORTED")
	}
	pemText, exists := keyring[strings.TrimSpace(env.KeyID)]
	if !exists {
		return nil, fmt.Errorf("REGISTRY_UNKNOWN_KEY_ID")
	}
	digest := sha256.Sum256(regRaw)
	actual := fmt.Sprintf("%x", digest[:])
	if env.ContentSHA256 != "" && !strings.EqualFold(env.ContentSHA256, actual) {
		return nil, fmt.Errorf("REGISTRY_CONTENT_HASH_MISMATCH")
	}
	sig, err := base64.StdEncoding.DecodeString(strings.TrimSpace(env.Sig))
	if err != nil {
		return nil, fmt.Errorf("REGISTRY_SIGNATURE_ENCODING_INVALID")
	}
	pub, err := parsePublicKey(pemText)
	if err != nil {
		return nil, fmt.Errorf("REGISTRY_PUBLIC_KEY_INVALID")
	}
	if err := rsa.VerifyPKCS1v15(pub, crypto.SHA256, digest[:], sig); err != nil {
		return nil, fmt.Errorf("REGISTRY_SIGNATURE_MISMATCH")
	}
	var reg registry
	if err := json.Unmarshal(regRaw, &reg); err != nil {
		return nil, fmt.Errorf("REGISTRY_JSON_INVALID")
	}
	if reg.RegistryFormat != 1 {
		return nil, fmt.Errorf("REGISTRY_FORMAT_UNSUPPORTED")
	}
	if reg.KeyID != env.KeyID {
		return nil, fmt.Errorf("REGISTRY_KEY_ID_MISMATCH")
	}
	if strings.ToUpper(reg.SigAlg) != "RSA-SHA256" {
		return nil, fmt.Errorf("REGISTRY_ALG_MISMATCH")
	}
	return &reg, nil
}

func allowedFeature(features []string) bool {
	for _, f := range features {
		switch strings.ToLower(strings.TrimSpace(f)) {
		case "kobo", "ghostguard", "ultimate", "ghostguard-kobo":
			return true
		}
	}
	return false
}

func validDate(s string) (time.Time, bool) {
	t, err := time.Parse("2006-01-02", s)
	return t, err == nil
}
func readLastDate(path string) (time.Time, bool) {
	b, err := os.ReadFile(path)
	if err != nil {
		return time.Time{}, false
	}
	return validDate(strings.TrimSpace(string(b)))
}
func writeLastDate(path, today string) {
	if path == "" {
		return
	}
	_ = os.MkdirAll(filepath.Dir(path), 0700)
	tmp := path + ".tmp"
	if os.WriteFile(tmp, []byte(today+"\n"), 0600) == nil {
		_ = os.Rename(tmp, path)
	}
}

func cacheAgeOK(path string, now int64, grace int64) error {
	if path == "" {
		return fmt.Errorf("ONLINE_SYNC_STATE_MISSING")
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("ONLINE_SYNC_STATE_MISSING")
	}
	var syncEpoch int64
	for _, line := range strings.Split(string(b), "\n") {
		if strings.HasPrefix(line, "SYNC_EPOCH=") {
			fmt.Sscanf(strings.TrimPrefix(line, "SYNC_EPOCH="), "%d", &syncEpoch)
		}
	}
	if syncEpoch <= 0 {
		return fmt.Errorf("ONLINE_SYNC_EPOCH_MISSING")
	}
	const rollbackTolerance = int64(300)
	if now+rollbackTolerance < syncEpoch {
		return fmt.Errorf("CLOCK_ROLLBACK_DETECTED")
	}
	if now-syncEpoch > grace {
		return fmt.Errorf("ONLINE_CACHE_EXPIRED")
	}
	return nil
}

func evaluate(reg *registry, serial, today string) (*licenseEntry, error) {
	hash := serialHash(serial)
	var entry *licenseEntry
	for i := range reg.Entries {
		if strings.EqualFold(reg.Entries[i].SerialHash, hash) {
			entry = &reg.Entries[i]
			break
		}
	}
	if entry == nil {
		return nil, fmt.Errorf("ONLINE_NOT_LISTED")
	}
	status := strings.ToLower(strings.TrimSpace(entry.Status))
	if status == "" {
		status = "active"
	}
	if status != "active" {
		return nil, fmt.Errorf("ONLINE_%s", strings.ToUpper(status))
	}
	if !allowedFeature(entry.Features) {
		return nil, fmt.Errorf("ONLINE_FEATURE_NOT_GRANTED")
	}
	now, ok := validDate(today)
	if !ok {
		return nil, fmt.Errorf("SYSTEM_DATE_INVALID")
	}
	if entry.IssuedAt != "" {
		issued, ok := validDate(entry.IssuedAt)
		if !ok {
			return nil, fmt.Errorf("ONLINE_ISSUED_AT_INVALID")
		}
		if now.Before(issued) {
			return nil, fmt.Errorf("CLOCK_BEFORE_ISSUE_DATE")
		}
	}
	exp := strings.ToLower(strings.TrimSpace(entry.Expire))
	if exp != "lifetime" {
		t, ok := validDate(exp)
		if !ok {
			return nil, fmt.Errorf("ONLINE_EXPIRE_INVALID")
		}
		if now.After(t) {
			return nil, fmt.Errorf("ONLINE_LICENSE_EXPIRED")
		}
	}
	return entry, nil
}

func main() {
	registryPath := ""
	signaturePath := ""
	statePath := "/mnt/onboard/.adds/ghostguard/data/license_last_date"
	syncState := ""
	serial := ""
	today := os.Getenv("DCPRO_NOW_DATE")
	source := "online"
	grace := int64(604800)
	nowEpoch := time.Now().Unix()
	for i := 1; i < len(os.Args); i++ {
		next := func() string {
			if i+1 >= len(os.Args) {
				deny("ARGUMENT_VALUE_MISSING")
			}
			i++
			return os.Args[i]
		}
		switch os.Args[i] {
		case "--registry":
			registryPath = next()
		case "--signature":
			signaturePath = next()
		case "--serial":
			serial = next()
		case "--state":
			statePath = next()
		case "--sync-state":
			syncState = next()
		case "--source":
			source = strings.ToLower(next())
		case "--grace-seconds":
			if _, err := fmt.Sscanf(next(), "%d", &grace); err != nil {
				deny("GRACE_INVALID")
			}
		case "--today":
			today = next()
		case "--now-epoch":
			if _, err := fmt.Sscanf(next(), "%d", &nowEpoch); err != nil {
				deny("NOW_EPOCH_INVALID")
			}
		case "--help":
			fmt.Println("gg-license-verify --registry FILE --signature FILE --serial SERIAL [--source online|cache] [--sync-state FILE]")
			return
		default:
			deny("UNKNOWN_ARGUMENT")
		}
	}
	serial = cleanSerial(serial)
	if serial == "" {
		deny("SERIAL_UNAVAILABLE")
	}
	if registryPath == "" || signaturePath == "" {
		deny("REGISTRY_OR_SIGNATURE_MISSING")
	}
	if today == "" {
		today = time.Now().Format("2006-01-02")
	}
	now, okDate := validDate(today)
	if !okDate {
		deny("SYSTEM_DATE_INVALID")
	}
	if last, ok := readLastDate(statePath); ok && now.Before(last) {
		deny("CLOCK_ROLLBACK_DETECTED")
	}
	if source == "cache" {
		if err := cacheAgeOK(syncState, nowEpoch, grace); err != nil {
			deny(err.Error())
		}
	} else if source != "online" {
		deny("SOURCE_INVALID")
	}
	regRaw, err := os.ReadFile(registryPath)
	if err != nil {
		deny("REGISTRY_READ_FAILED")
	}
	sigRaw, err := os.ReadFile(signaturePath)
	if err != nil {
		deny("REGISTRY_SIG_READ_FAILED")
	}
	reg, err := verifyPair(regRaw, sigRaw)
	if err != nil {
		deny(err.Error())
	}
	entry, err := evaluate(reg, serial, today)
	if err != nil {
		deny(err.Error())
	}
	writeLastDate(statePath, today)
	ok(strings.ToUpper(source) + "_ACTIVE;LICENSE_ID=" + entry.LicenseID + ";EXPIRE=" + entry.Expire)
}

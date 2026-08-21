package main

import (
	"bufio"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

const publicKeyHex = "f1c751a0daff7b64c21a69a23af69f4206b319948d6a063907ef53d57d02b463"

var requiredFields = []string{"license_format", "serial", "customer", "issued_at", "expire", "features", "license_id", "sig_alg", "sig"}

func deny(msg string) { fmt.Printf("DENY|%s\n", msg); os.Exit(1) }
func ok(msg string)   { fmt.Printf("OK|%s\n", msg); os.Exit(0) }

func cleanSerial(s string) string {
	s = strings.ToUpper(s)
	var b strings.Builder
	for _, r := range s {
		if (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') { b.WriteRune(r) }
	}
	return b.String()
}

func parseLicense(path string) map[string]string {
	f, err := os.Open(path); if err != nil { deny("MISSING_PLUGIN_LICENSE_KEY") }
	defer f.Close()
	vals := map[string]string{}; counts := map[string]int{}
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSuffix(strings.TrimSuffix(sc.Text(), "\r"), "\n")
		if line == "" || strings.HasPrefix(strings.TrimSpace(line), "#") { continue }
		i := strings.IndexByte(line, '='); if i <= 0 { deny("LICENSE_PARSE_FAILED") }
		k, v := line[:i], line[i+1:]; counts[k]++; if counts[k] == 1 { vals[k] = v }
	}
	if err := sc.Err(); err != nil { deny("LICENSE_READ_FAILED") }
	for _, k := range requiredFields { if counts[k] != 1 { deny("FIELD_" + k + "_MISSING_OR_DUPLICATE") } }
	return vals
}

func validDate(s string) (time.Time, bool) { t, err := time.Parse("2006-01-02", s); return t, err == nil }
func hasFeature(s string) bool {
	for _, f := range strings.Split(strings.ToLower(s), ",") {
		switch strings.TrimSpace(f) { case "ultimate", "ghostguard", "kobo", "ghostguard-kobo": return true }
	}
	return false
}
func canonical(v map[string]string) string {
	return strings.Join([]string{"4", cleanSerial(v["serial"]), v["customer"], v["issued_at"], v["expire"], v["features"], v["license_id"], "ed25519"}, "|")
}
func readLastDate(path string) (time.Time, bool) {
	b, err := os.ReadFile(path); if err != nil { return time.Time{}, false }
	return validDate(strings.TrimSpace(string(b)))
}
func writeState(path, today string) {
	if path == "" { return }
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil { return }
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, []byte(today+"\n"), 0600); err == nil { _ = os.Rename(tmp, path) }
}

func main() {
	licensePath := "/mnt/onboard/.adds/ghostguard/license.key"
	statePath := "/mnt/onboard/.adds/ghostguard/data/license_last_date"
	serial := ""; today := os.Getenv("DCPRO_NOW_DATE")
	for i := 1; i < len(os.Args); i++ {
		switch os.Args[i] {
		case "--license": if i+1 < len(os.Args) { i++; licensePath = os.Args[i] }
		case "--state": if i+1 < len(os.Args) { i++; statePath = os.Args[i] }
		case "--serial": if i+1 < len(os.Args) { i++; serial = os.Args[i] }
		case "--today": if i+1 < len(os.Args) { i++; today = os.Args[i] }
		case "--public-key": deny("PUBLIC_KEY_OVERRIDE_DISABLED")
		case "--help": fmt.Println("gg-license-verify --license PATH --serial SERIAL [--state PATH] [--today YYYY-MM-DD]"); return
		default: deny("UNKNOWN_ARGUMENT")
		}
	}
	serial = cleanSerial(serial); if serial == "" { deny("SERIAL_UNAVAILABLE") }
	if today == "" { today = time.Now().Format("2006-01-02") }
	now, okDate := validDate(today); if !okDate { deny("SYSTEM_DATE_INVALID") }

	v := parseLicense(licensePath)
	if v["license_format"] != "4" { deny("UNSUPPORTED_LICENSE_FORMAT") }
	if v["sig_alg"] != "ed25519" { deny("UNSUPPORTED_SIGNATURE_ALGORITHM") }
	keySerial := cleanSerial(v["serial"]); if keySerial == "" || keySerial != serial { deny("SERIAL_MISMATCH") }
	if strings.TrimSpace(v["customer"]) == "" { deny("CUSTOMER_EMPTY") }
	if strings.TrimSpace(v["license_id"]) == "" { deny("LICENSE_ID_EMPTY") }
	if !hasFeature(v["features"]) { deny("FEATURE_GHOSTGUARD_KOBO_NOT_GRANTED") }
	issued, okIssued := validDate(v["issued_at"]); if !okIssued { deny("ISSUED_AT_INVALID") }
	if now.Before(issued) { deny("CLOCK_BEFORE_ISSUE_DATE") }
	if v["expire"] != "lifetime" {
		exp, okExp := validDate(v["expire"]); if !okExp { deny("EXPIRE_INVALID") }
		if now.After(exp) { deny("LICENSE_EXPIRED") }
	}
	if last, okLast := readLastDate(statePath); okLast && now.Before(last) { deny("CLOCK_ROLLBACK_DETECTED") }

	pub, err := hex.DecodeString(publicKeyHex); if err != nil || len(pub) != ed25519.PublicKeySize { deny("PUBLIC_KEY_INVALID") }
	sig, err := base64.StdEncoding.DecodeString(v["sig"]); if err != nil || len(sig) != ed25519.SignatureSize { deny("SIGNATURE_FORMAT_INVALID") }
	if !ed25519.Verify(ed25519.PublicKey(pub), []byte(canonical(v)), sig) { deny("SIGNATURE_MISMATCH") }
	writeState(statePath, today)
	fields := []string{"CUSTOMER=" + v["customer"], "EXPIRE=" + v["expire"], "LICENSE_ID=" + v["license_id"]}
	sort.Strings(fields)
	ok("V4_VALID;" + strings.Join(fields, ";"))
}

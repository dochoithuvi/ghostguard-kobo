package main

import (
	"bufio"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

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

func canonical(serial, customer, issued, expire, features, id string) string {
	return strings.Join([]string{"4", cleanSerial(serial), customer, issued, expire, features, id, "ed25519"}, "|")
}

func readKV(path string) (map[string]string, error) {
	f, err := os.Open(path)
	if err != nil { return nil, err }
	defer f.Close()
	out := map[string]string{}
	s := bufio.NewScanner(f)
	for s.Scan() {
		line := strings.TrimSpace(s.Text())
		if line == "" || strings.HasPrefix(line, "#") { continue }
		i := strings.IndexByte(line, '=')
		if i <= 0 { continue }
		out[line[:i]] = line[i+1:]
	}
	return out, s.Err()
}

func loadPrivate(path string) (ed25519.PrivateKey, error) {
	m, err := readKV(path); if err != nil { return nil, err }
	raw, err := base64.StdEncoding.DecodeString(m["seed_b64"]); if err != nil { return nil, err }
	if len(raw) != ed25519.SeedSize { return nil, errors.New("private seed must be 32 bytes") }
	return ed25519.NewKeyFromSeed(raw), nil
}

func loadPublic(path string) (ed25519.PublicKey, error) {
	m, err := readKV(path); if err != nil { return nil, err }
	if h := m["public_hex"]; h != "" {
		raw, err := hex.DecodeString(h)
		if err == nil && len(raw) == ed25519.PublicKeySize { return ed25519.PublicKey(raw), nil }
	}
	raw, err := base64.StdEncoding.DecodeString(m["public_b64"]); if err != nil { return nil, err }
	if len(raw) != ed25519.PublicKeySize { return nil, errors.New("public key must be 32 bytes") }
	return ed25519.PublicKey(raw), nil
}

func writeKeys(privPath, pubPath string) error {
	pub, priv, err := ed25519.GenerateKey(rand.Reader); if err != nil { return err }
	seed := priv.Seed()
	privText := "DCPRO_GG_KOBO_ED25519_PRIVATE_V1\nseed_b64=" + base64.StdEncoding.EncodeToString(seed) + "\n"
	pubText := "DCPRO_GG_KOBO_ED25519_PUBLIC_V1\npublic_b64=" + base64.StdEncoding.EncodeToString(pub) + "\npublic_hex=" + hex.EncodeToString(pub) + "\n"
	if err := os.WriteFile(privPath, []byte(privText), 0600); err != nil { return err }
	return os.WriteFile(pubPath, []byte(pubText), 0644)
}

func makeID() string {
	b := make([]byte, 4); _, _ = rand.Read(b)
	return "DCPRO-" + time.Now().Format("20060102") + "-" + strings.ToUpper(hex.EncodeToString(b))
}

func cmdGen(args []string) {
	fs := flag.NewFlagSet("gen-key", flag.ExitOnError)
	priv := fs.String("private", "private_key.txt", "private key output")
	pub := fs.String("public", "public_key.txt", "public key output")
	_ = fs.Parse(args)
	if err := writeKeys(*priv, *pub); err != nil { fmt.Fprintln(os.Stderr, err); os.Exit(1) }
	fmt.Println("Generated:", *priv, *pub)
}

func cmdIssue(args []string) {
	fs := flag.NewFlagSet("issue", flag.ExitOnError)
	privPath := fs.String("private", "private_key.txt", "private key file")
	serial := fs.String("serial", "", "Kobo serial")
	customer := fs.String("customer", "", "customer name")
	issued := fs.String("issued", time.Now().Format("2006-01-02"), "issue date")
	expire := fs.String("expire", "lifetime", "expiry date or lifetime")
	features := fs.String("features", "ghostguard-kobo,ultimate", "comma-separated features")
	id := fs.String("id", "", "license id; generated when empty")
	out := fs.String("out", "license.key", "license output")
	_ = fs.Parse(args)
	s := cleanSerial(*serial)
	if s == "" || *customer == "" { fmt.Fprintln(os.Stderr, "serial and customer are required"); os.Exit(2) }
	if *id == "" { *id = makeID() }
	if _, err := time.Parse("2006-01-02", *issued); err != nil { fmt.Fprintln(os.Stderr, "invalid issued date"); os.Exit(2) }
	if *expire != "lifetime" { if _, err := time.Parse("2006-01-02", *expire); err != nil { fmt.Fprintln(os.Stderr, "invalid expire date"); os.Exit(2) } }
	priv, err := loadPrivate(*privPath); if err != nil { fmt.Fprintln(os.Stderr, err); os.Exit(1) }
	sig := ed25519.Sign(priv, []byte(canonical(s, *customer, *issued, *expire, *features, *id)))
	text := strings.Join([]string{
		"# DCPRO GhostGuard Kobo offline license", "license_format=4", "serial=" + s,
		"customer=" + *customer, "issued_at=" + *issued, "expire=" + *expire,
		"features=" + *features, "license_id=" + *id, "sig_alg=ed25519",
		"sig=" + base64.StdEncoding.EncodeToString(sig), "",
	}, "\n")
	if err := os.MkdirAll(filepath.Dir(*out), 0755); err != nil && filepath.Dir(*out) != "." { fmt.Fprintln(os.Stderr, err); os.Exit(1) }
	if err := os.WriteFile(*out, []byte(text), 0644); err != nil { fmt.Fprintln(os.Stderr, err); os.Exit(1) }
	fmt.Printf("Created %s for %s (%s)\n", *out, *customer, s)
}

func parseLicense(path string) (map[string]string, error) { return readKV(path) }

func cmdVerify(args []string) {
	fs := flag.NewFlagSet("verify", flag.ExitOnError)
	pubPath := fs.String("public", "public_key.txt", "public key file")
	licPath := fs.String("license", "license.key", "license file")
	_ = fs.Parse(args)
	pub, err := loadPublic(*pubPath); if err != nil { fmt.Fprintln(os.Stderr, err); os.Exit(1) }
	v, err := parseLicense(*licPath); if err != nil { fmt.Fprintln(os.Stderr, err); os.Exit(1) }
	sig, err := base64.StdEncoding.DecodeString(v["sig"]); if err != nil { fmt.Fprintln(os.Stderr, "bad signature encoding"); os.Exit(1) }
	msg := canonical(v["serial"], v["customer"], v["issued_at"], v["expire"], v["features"], v["license_id"])
	if !ed25519.Verify(pub, []byte(msg), sig) { fmt.Println("INVALID"); os.Exit(1) }
	fmt.Printf("VALID serial=%s customer=%s expire=%s license_id=%s\n", cleanSerial(v["serial"]), v["customer"], v["expire"], v["license_id"])
}

func usage() { fmt.Println("gg-license-tool <gen-key|issue|verify> [options]") }
func main() {
	if len(os.Args) < 2 { usage(); return }
	switch os.Args[1] {
	case "gen-key": cmdGen(os.Args[2:])
	case "issue": cmdIssue(os.Args[2:])
	case "verify": cmdVerify(os.Args[2:])
	default: usage(); os.Exit(2)
	}
}

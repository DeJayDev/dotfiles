package main

import (
	"maps"
	"testing"
)

func TestParseSecrets(t *testing.T) {
	got := parseSecrets("export RESTIC_PASSWORD=a+b/c==\nexport R2_ACCOUNT_ID=\"abc\"\n\nAWS_ACCESS_KEY_ID='key'\n")
	want := map[string]string{"RESTIC_PASSWORD": "a+b/c==", "R2_ACCOUNT_ID": "abc", "AWS_ACCESS_KEY_ID": "key"}
	if !maps.Equal(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

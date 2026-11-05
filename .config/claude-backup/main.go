package main

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"time"
)

var (
	home, _     = os.UserHomeDir()
	claudeDir   = cmp.Or(os.Getenv("CLAUDE_CONFIG_DIR"), filepath.Join(home, ".claude"))
	stateDir    = filepath.Join(cmp.Or(os.Getenv("XDG_STATE_HOME"), filepath.Join(home, ".local/state")), "claude-backup")
	localRepo   = filepath.Join(home, "syncthing/claude-backup")
	identity    = filepath.Join(stateDir, "hw-identity.txt")
	secretsFile = filepath.Join(home, ".config/claude-backup/secrets.age")
	statusFile  = filepath.Join(stateDir, "status")
	lockDir     = filepath.Join(stateDir, "lock")

	logFile *os.File
	logger  *log.Logger
)

func main() {
	os.Exit(run())
}

func run() int {
	minAge := time.Duration(0)
	switch strings.Join(os.Args[1:], " ") {
	case "":
	case "--if-older 12h":
		minAge = 12 * time.Hour
	default:
		fmt.Fprintln(os.Stderr, "usage: claude-backup [--if-older 12h]")
		return 2
	}

	must(os.MkdirAll(stateDir, 0o700))
	var err error
	logFile, err = os.OpenFile(filepath.Join(stateDir, "log"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	must(err)
	logger = log.New(logFile, "", log.LUTC|log.Ldate|log.Ltime)

	if info, err := os.Stat(lockDir); err == nil && time.Since(info.ModTime()) > 2*time.Hour {
		logger.Print("removing stale lock older than 2h")
		must(os.Remove(lockDir))
	}
	err = os.Mkdir(lockDir, 0o700)
	if errors.Is(err, os.ErrExist) {
		return 0
	}
	must(err)
	status := readStatus()
	defer func() {
		writeStatus(status)
		os.Remove(lockDir)
	}()

	if since(status, "success_local") < minAge && since(status, "success_r2") < minAge {
		return 0
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	secrets, err := loadSecrets(ctx)
	if err != nil {
		logger.Printf("secrets: %v", err)
		status["result_local"] = "fail"
		status["result_r2"] = "fail"
		return 1
	}
	env := append(os.Environ(), "AWS_DEFAULT_REGION=auto")
	for key, value := range secrets {
		env = append(env, key+"="+value)
	}

	hostname, err := os.Hostname()
	must(err)
	host, _, _ := strings.Cut(hostname, ".")
	now := strconv.FormatInt(time.Now().Unix(), 10)

	repos := []struct {
		name       string
		url        string
		checkEvery time.Duration
		checkArgs  []string
	}{
		{"local", localRepo, 7 * 24 * time.Hour, nil},
		{"r2", "s3:https://" + secrets["R2_ACCOUNT_ID"] + ".r2.cloudflarestorage.com/claude-backups", 30 * 24 * time.Hour, []string{"--read-data-subset=5%"}},
	}

	failed := false
	for _, repo := range repos {
		err := restic(ctx, env, "-r", repo.url, "backup", "--quiet", "--host", host, "--tag", "claude",
			filepath.Join(claudeDir, "projects"), filepath.Join(claudeDir, "history.jsonl"))
		if ctx.Err() != nil {
			logger.Print("interrupted, leaving status as it was")
			return 1
		}
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) && exitErr.ExitCode() == 3 {
			logger.Printf("backup %s warning: some files could not be read, snapshot saved without them", repo.name)
			err = nil
		}
		if err != nil {
			status["result_"+repo.name] = "fail"
			failed = true
			logger.Printf("backup %s failed", repo.name)
			continue
		}
		status["success_"+repo.name] = now
		status["result_"+repo.name] = "ok"
		logger.Printf("backup %s ok", repo.name)

		if since(status, "check_"+repo.name) < repo.checkEvery {
			continue
		}
		err = restic(ctx, env, append([]string{"-r", repo.url, "check", "--quiet"}, repo.checkArgs...)...)
		if ctx.Err() != nil {
			logger.Print("interrupted, leaving status as it was")
			return 1
		}
		status["check_"+repo.name] = now
		if err != nil {
			status["check_result_"+repo.name] = "fail"
			failed = true
			logger.Printf("check %s failed", repo.name)
			continue
		}
		status["check_result_"+repo.name] = "ok"
		logger.Printf("check %s ok", repo.name)
	}

	if failed {
		return 1
	}
	return 0
}

func loadSecrets(ctx context.Context) (map[string]string, error) {
	if runtime.GOOS != "darwin" {
		if _, err := os.Stat("/dev/tpmrm0"); err != nil {
			return nil, errors.New("no TPM at /dev/tpmrm0, this host can't hold the hardware-bound key")
		}
	}
	cmd := exec.CommandContext(ctx, "age", "-d", "-i", identity, secretsFile)
	cmd.Stderr = logFile
	out, err := cmd.Output()
	if err != nil {
		return nil, errors.New("could not decrypt the secrets, run yadm decrypt to bind them to this machine")
	}
	secrets := parseSecrets(string(out))
	for _, key := range []string{"RESTIC_PASSWORD", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "R2_ACCOUNT_ID"} {
		if secrets[key] == "" {
			return nil, fmt.Errorf("secrets.age does not set %s", key)
		}
	}
	return secrets, nil
}

func parseSecrets(text string) map[string]string {
	secrets := map[string]string{}
	for _, line := range strings.Split(text, "\n") {
		key, value, found := strings.Cut(strings.TrimPrefix(strings.TrimSpace(line), "export "), "=")
		if found {
			secrets[key] = strings.Trim(value, `"'`)
		}
	}
	return secrets
}

func restic(ctx context.Context, env []string, args ...string) error {
	cmd := exec.CommandContext(ctx, "restic", args...)
	cmd.Env = env
	cmd.Stderr = logFile
	// SIGINT instead of SIGKILL so restic removes its lock from the shared repo.
	cmd.Cancel = func() error { return cmd.Process.Signal(os.Interrupt) }
	cmd.WaitDelay = 30 * time.Second
	return cmd.Run()
}

func readStatus() map[string]string {
	status := map[string]string{
		"success_local": "0", "success_r2": "0",
		"result_local": "none", "result_r2": "none",
		"check_local": "0", "check_r2": "0",
		"check_result_local": "none", "check_result_r2": "none",
	}
	data, err := os.ReadFile(statusFile)
	if errors.Is(err, os.ErrNotExist) {
		return status
	}
	must(err)
	for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		if key, value, found := strings.Cut(line, "="); found {
			status[key] = value
		}
	}
	return status
}

func writeStatus(status map[string]string) {
	var lines []string
	for key, value := range status {
		lines = append(lines, key+"="+value)
	}
	slices.Sort(lines)
	must(os.WriteFile(statusFile+".tmp", []byte(strings.Join(lines, "\n")+"\n"), 0o600))
	must(os.Rename(statusFile+".tmp", statusFile))
}

func since(status map[string]string, key string) time.Duration {
	seconds, _ := strconv.ParseInt(status[key], 10, 64)
	return time.Since(time.Unix(seconds, 0))
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}

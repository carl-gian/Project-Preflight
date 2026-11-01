//go:build windows

// Preflight.exe: starts Preflight.ps1 from the same folder, with no console
// window, then exits. It does nothing else on purpose: everything that changes
// (including updates) lives in Preflight.ps1, so this file rarely needs a new
// build. Replaces Run-Preflight.vbs.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"
	"unsafe"
)

const (
	createNoWindow = 0x08000000
	mbIconError    = 0x10
	maxLogBytes    = 256 * 1024
)

func main() {
	exe, err := os.Executable()
	if err != nil {
		showError("Preflight couldn't find where it is running from.\n\n" + err.Error())
		os.Exit(1)
	}
	dir := filepath.Dir(exe)
	logPath := filepath.Join(dir, "launcher.log")
	logf := func(format string, a ...any) { writeLog(logPath, fmt.Sprintf(format, a...)) }

	logf("=== Preflight launcher starting ===")
	script := filepath.Join(dir, "Preflight.ps1")
	if _, err := os.Stat(script); err != nil {
		logf("ERROR: Preflight.ps1 not found at %s", script)
		showError("Preflight.ps1 isn't in the same folder as Preflight.exe.\n\nExpected: " + script +
			"\n\nPut both in one folder, then try again.")
		os.Exit(1)
	}

	ps := filepath.Join(os.Getenv("SystemRoot"), "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
	if _, err := os.Stat(ps); err != nil {
		ps = "powershell.exe"
	}
	args := append([]string{"-NoProfile", "-ExecutionPolicy", "Bypass", "-NonInteractive",
		"-WindowStyle", "Hidden", "-File", script}, os.Args[1:]...)

	cmd := exec.Command(ps, args...)
	cmd.Dir = dir
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: createNoWindow}
	logf("Running: %s %v", ps, args)
	if err := cmd.Start(); err != nil {
		logf("ERROR launching PowerShell: %v", err)
		showError("Preflight couldn't start PowerShell.\n\n" + err.Error() +
			"\n\nTry running Preflight.ps1 directly as Administrator.")
		os.Exit(1)
	}
	_ = cmd.Process.Release()
	logf("PowerShell launched (pid %d).", cmd.Process.Pid)
}

func writeLog(path, msg string) {
	if fi, err := os.Stat(path); err == nil && fi.Size() > maxLogBytes {
		_ = os.Rename(path, path+".old")
	}
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "[%s] %s\r\n", time.Now().Format("2006-01-02 15:04:05"), msg)
}

func showError(text string) {
	title, _ := syscall.UTF16PtrFromString("Audio-Video Preflight")
	body, _ := syscall.UTF16PtrFromString(text)
	proc := syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW")
	_, _, _ = proc.Call(0, uintptr(unsafe.Pointer(body)), uintptr(unsafe.Pointer(title)), mbIconError)
}

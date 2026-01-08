package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

// Global state for cleanup on exit
var (
	activePodID  string
	activeAPIKey string
)

const (
	// ========== CONFIGURATION ==========
	templateID      = "3ikte0az1e"
	networkVolumeID = "5oxn5a36e6"
	// ====================================

	runpodAPIURL     = "https://rest.runpod.io/v1/pods"
	runpodGraphQLURL = "https://api.runpod.io/graphql"
	configFile       = ".slicer-launcher-config"
)

var gpuTypes = []string{
	"NVIDIA RTX PRO 6000 Blackwell Server Edition",
}

// PodRequest represents the RunPod API request body
// Ports are inherited from the template
type PodRequest struct {
	Name            string   `json:"name"`
	TemplateID      string   `json:"templateId"`
	NetworkVolumeID string   `json:"networkVolumeId"`
	GPUTypeIDs      []string `json:"gpuTypeIds"`
	GPUCount        int      `json:"gpuCount"`
}

// PodResponse represents the RunPod API response
type PodResponse struct {
	ID              string `json:"id"`
	Name            string `json:"name"`
	DesiredStatus   string `json:"desiredStatus"`
	ImageName       string `json:"imageName"`
	Machine         Machine `json:"machine"`
}

type Machine struct {
	GpuDisplayName string `json:"gpuDisplayName"`
}

// ErrorResponse represents an error from the API
type ErrorResponse struct {
	Error string `json:"error"`
}

func enableWindowsANSI() {
	if runtime.GOOS == "windows" {
		// Enable virtual terminal processing on Windows
		kernel32 := syscall.NewLazyDLL("kernel32.dll")
		setConsoleMode := kernel32.NewProc("SetConsoleMode")
		getConsoleMode := kernel32.NewProc("GetConsoleMode")
		handle, _ := syscall.GetStdHandle(syscall.STD_OUTPUT_HANDLE)

		var mode uint32
		getConsoleMode.Call(uintptr(handle), uintptr(unsafe.Pointer(&mode)))
		mode |= 0x0004 // ENABLE_VIRTUAL_TERMINAL_PROCESSING
		setConsoleMode.Call(uintptr(handle), uintptr(mode))
	}
}

func main() {
	// Enable ANSI colors on Windows
	enableWindowsANSI()

	fmt.Println("╔════════════════════════════════════════════════════════════╗")
	fmt.Println("║           3D Slicer RunPod Launcher                        ║")
	fmt.Println("╚════════════════════════════════════════════════════════════╝")
	fmt.Println()

	// Setup signal handler for cleanup on Ctrl+C or window close
	setupSignalHandler()

	// Get API key
	apiKey, err := getAPIKey()
	if err != nil {
		fmt.Printf("Error getting API key: %v\n", err)
		waitForEnter()
		os.Exit(1)
	}

	// Launch pod
	fmt.Println("\nLaunching pod...")
	fmt.Printf("  Template ID: %s\n", templateID)
	fmt.Printf("  Network Volume: %s\n", networkVolumeID)
	fmt.Printf("  GPU Types: %v\n", gpuTypes)
	fmt.Println()

	podID, gpuName, err := launchPod(apiKey)
	if err != nil {
		fmt.Printf("Error launching pod: %v\n", err)
		waitForEnter()
		os.Exit(1)
	}

	// Store for cleanup on exit
	activeAPIKey = apiKey
	activePodID = podID

	fmt.Printf("✓ Pod created successfully!\n")
	fmt.Printf("  Pod ID: %s\n", podID)
	if gpuName != "" {
		fmt.Printf("  GPU: %s\n", gpuName)
	}

	// Wait for pod to be ready
	vncURL := fmt.Sprintf("https://%s-6080.proxy.runpod.net", podID)

	fmt.Println("\nWaiting for pod to be ready...")
	publicIP, portMappings, err := waitForPodReady(apiKey, podID, vncURL)
	if err != nil {
		fmt.Printf("Warning: %v\n", err)
		fmt.Println("Opening browser anyway...")
	}

	// Display connection info
	fmt.Println()
	fmt.Println("╔════════════════════════════════════════════════════════════╗")
	fmt.Println("║  CONNECTION INFO                                           ║")
	fmt.Println("╠════════════════════════════════════════════════════════════╣")
	fmt.Printf("║  noVNC (web):   %s\n", vncURL)
	if publicIP != "" && portMappings != nil {
		if vncPort, ok := portMappings["5901"]; ok {
			fmt.Printf("║  TurboVNC:      %s:%d\n", publicIP, vncPort)
		}
		if httpPort, ok := portMappings["8080"]; ok {
			fmt.Printf("║  File Browser:  http://%s:%d\n", publicIP, httpPort)
		}
		if sshPort, ok := portMappings["22"]; ok {
			fmt.Printf("║  SSH:           ssh root@%s -p %d\n", publicIP, sshPort)
		}
	}
	fmt.Println("╚════════════════════════════════════════════════════════════╝")

	// Open browser
	fmt.Printf("\nOpening noVNC in browser...\n")
	if err := openBrowser(vncURL); err != nil {
		fmt.Printf("Could not open browser automatically.\n")
		fmt.Printf("Please open this URL manually: %s\n", vncURL)
	}

	fmt.Println()
	fmt.Println("╔════════════════════════════════════════════════════════════╗")
	fmt.Println("║  WARNING: Closing this window or pressing Enter will       ║")
	fmt.Println("║  TERMINATE the pod to avoid charges!                       ║")
	fmt.Println("╚════════════════════════════════════════════════════════════╝")
	fmt.Println()

	// Show initial balance (green for balance, red for cost)
	green := "\033[32m"
	red := "\033[31m"
	reset := "\033[0m"
	if info, err := getAccountInfo(apiKey); err == nil {
		fmt.Printf("💰 Balance: %s$%.2f%s | Cost: %s$%.2f/hr%s | Est. runtime: %.1f hrs\n",
			green, info.Balance, reset, red, info.CostPerHr, reset, info.Balance/info.CostPerHr)
	}
	fmt.Println()

	// Start balance update goroutine
	done := make(chan bool)
	go func() {
		ticker := time.NewTicker(5 * time.Minute)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				if info, err := getAccountInfo(apiKey); err == nil {
					fmt.Printf("\r💰 Balance: %s$%.2f%s | Cost: %s$%.2f/hr%s | Est. runtime: %.1f hrs\n",
						green, info.Balance, reset, red, info.CostPerHr, reset, info.Balance/info.CostPerHr)
					fmt.Print("Press Enter to TERMINATE pod and exit...")
				}
			case <-done:
				return
			}
		}
	}()

	waitForEnter()
	done <- true

	// Terminate pod on exit
	if err := terminatePod(apiKey, podID); err != nil {
		fmt.Printf("Warning: %v\n", err)
	}
}

func getConfigPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("could not get home directory: %w", err)
	}
	return filepath.Join(home, configFile), nil
}

func loadSavedKey() (string, error) {
	configPath, err := getConfigPath()
	if err != nil {
		return "", err
	}

	data, err := os.ReadFile(configPath)
	if err != nil {
		if os.IsNotExist(err) {
			return "", nil // No saved key
		}
		return "", fmt.Errorf("could not read config file: %w", err)
	}

	return strings.TrimSpace(string(data)), nil
}

func saveKey(apiKey string) error {
	configPath, err := getConfigPath()
	if err != nil {
		return err
	}

	return os.WriteFile(configPath, []byte(apiKey), 0600)
}

func getAPIKey() (string, error) {
	// Try to load saved key
	savedKey, err := loadSavedKey()
	if err != nil {
		fmt.Printf("Warning: Could not check for saved key: %v\n", err)
	}

	if savedKey != "" {
		fmt.Println("Using saved API key.")
		fmt.Print("Press Enter to continue or type 'new' for a new key: ")

		reader := bufio.NewReader(os.Stdin)
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(strings.ToLower(input))

		if input != "new" {
			return savedKey, nil
		}
	}

	// Prompt for new key
	fmt.Println()
	fmt.Println("RunPod API Key Required")
	fmt.Println("------------------------")
	fmt.Println("To get your API key:")
	fmt.Println("  1. Go to https://www.runpod.io/console/user/settings")
	fmt.Println("  2. Click 'API Keys' in the left sidebar")
	fmt.Println("  3. Create a new key with 'All' permissions")
	fmt.Println("     (Read-only won't work - we need to create pods)")
	fmt.Println()
	fmt.Print("Paste your API key: ")

	reader := bufio.NewReader(os.Stdin)
	apiKey, err := reader.ReadString('\n')
	if err != nil {
		return "", fmt.Errorf("could not read input: %w", err)
	}
	apiKey = strings.TrimSpace(apiKey)

	if apiKey == "" {
		return "", fmt.Errorf("API key cannot be empty")
	}

	// Offer to save
	fmt.Print("Save this key for future use? (y/n): ")
	saveChoice, _ := reader.ReadString('\n')
	saveChoice = strings.TrimSpace(strings.ToLower(saveChoice))

	if saveChoice == "y" || saveChoice == "yes" {
		if err := saveKey(apiKey); err != nil {
			fmt.Printf("Warning: Could not save key: %v\n", err)
		} else {
			configPath, _ := getConfigPath()
			fmt.Printf("Key saved to: %s\n", configPath)
		}
	}

	return apiKey, nil
}

func launchPod(apiKey string) (string, string, error) {
	// Build the request
	reqBody := PodRequest{
		Name:            fmt.Sprintf("slicer-%d", time.Now().Unix()),
		TemplateID:      templateID,
		NetworkVolumeID: networkVolumeID,
		GPUTypeIDs:      gpuTypes,
		GPUCount:        1,
	}

	jsonBody, err := json.Marshal(reqBody)
	if err != nil {
		return "", "", fmt.Errorf("could not create request body: %w", err)
	}

	// Create HTTP request
	req, err := http.NewRequest("POST", runpodAPIURL, bytes.NewBuffer(jsonBody))
	if err != nil {
		return "", "", fmt.Errorf("could not create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", apiKey))

	// Send request
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", "", fmt.Errorf("API request failed: %w", err)
	}
	defer resp.Body.Close()

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", "", fmt.Errorf("could not read response: %w", err)
	}

	// Check for errors
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		var errResp ErrorResponse
		if json.Unmarshal(body, &errResp) == nil && errResp.Error != "" {
			return "", "", fmt.Errorf("API error (%d): %s", resp.StatusCode, errResp.Error)
		}
		return "", "", fmt.Errorf("API error (%d): %s", resp.StatusCode, string(body))
	}

	// Parse successful response
	var podResp PodResponse
	if err := json.Unmarshal(body, &podResp); err != nil {
		return "", "", fmt.Errorf("could not parse response: %w (body: %s)", err, string(body))
	}

	if podResp.ID == "" {
		return "", "", fmt.Errorf("no pod ID in response: %s", string(body))
	}

	return podResp.ID, podResp.Machine.GpuDisplayName, nil
}

func waitForPodReady(apiKey, podID, vncURL string) (string, map[string]int, error) {
	client := &http.Client{Timeout: 10 * time.Second}
	podURL := fmt.Sprintf("%s/%s", runpodAPIURL, podID)

	var publicIP string
	var portMappings map[string]int

	// Phase 1: Wait for pod to have a public IP (means it's actually running)
	fmt.Print("  Pod status: starting...")
	for i := 0; i < 120; i++ { // Max 10 minutes
		req, _ := http.NewRequest("GET", podURL, nil)
		req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", apiKey))

		resp, err := client.Do(req)
		if err != nil {
			fmt.Print(".")
			time.Sleep(5 * time.Second)
			continue
		}

		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		var pod struct {
			DesiredStatus string         `json:"desiredStatus"`
			PublicIP      string         `json:"publicIp"`
			PortMappings  map[string]int `json:"portMappings"`
		}
		json.Unmarshal(body, &pod)

		if pod.PublicIP != "" {
			publicIP = pod.PublicIP
			portMappings = pod.PortMappings
			fmt.Printf("\r  Pod status: RUNNING (IP: %s)    \n", pod.PublicIP)
			break
		}

		fmt.Printf("\r  Pod status: %s (%ds)...    ", pod.DesiredStatus, (i+1)*5)
		time.Sleep(5 * time.Second)
	}

	// Phase 2: Wait for VNC port to be accessible
	fmt.Print("  VNC port: checking...")
	for i := 0; i < 60; i++ { // Max 5 minutes
		resp, err := client.Get(vncURL)
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode == 200 || resp.StatusCode == 302 || resp.StatusCode == 401 {
				fmt.Printf("\r  VNC port: accessible!       \n")
				return publicIP, portMappings, nil
			}
		}
		fmt.Printf("\r  VNC port: waiting... (%ds)  ", (i+1)*5)
		time.Sleep(5 * time.Second)
	}

	return publicIP, portMappings, fmt.Errorf("timeout waiting for VNC port")
}

func openBrowser(url string) error {
	var cmd *exec.Cmd

	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("cmd", "/c", "start", url)
	case "darwin":
		cmd = exec.Command("open", url)
	default: // Linux and others
		cmd = exec.Command("xdg-open", url)
	}

	return cmd.Start()
}

func waitForEnter() {
	fmt.Print("Press Enter to TERMINATE pod and exit...")
	bufio.NewReader(os.Stdin).ReadBytes('\n')
}

func terminatePod(apiKey, podID string) error {
	if podID == "" || apiKey == "" {
		return nil
	}

	fmt.Printf("\nTerminating pod %s...\n", podID)

	req, err := http.NewRequest("DELETE", fmt.Sprintf("%s/%s", runpodAPIURL, podID), nil)
	if err != nil {
		return fmt.Errorf("could not create request: %w", err)
	}

	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", apiKey))

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("API request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 || resp.StatusCode == 204 {
		fmt.Println("✓ Pod terminated successfully!")
		return nil
	}

	body, _ := io.ReadAll(resp.Body)
	return fmt.Errorf("failed to terminate pod (%d): %s", resp.StatusCode, string(body))
}

func setupSignalHandler() {
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-c
		fmt.Println("\n\nReceived interrupt signal...")
		if activePodID != "" {
			terminatePod(activeAPIKey, activePodID)
		}
		os.Exit(0)
	}()
}

// AccountInfo holds balance information
type AccountInfo struct {
	Balance    float64
	CostPerHr  float64
}

func getAccountInfo(apiKey string) (*AccountInfo, error) {
	query := `{"query": "query { myself { currentSpendPerHr clientBalance } }"}`

	req, err := http.NewRequest("POST", runpodGraphQLURL+"?api_key="+apiKey, strings.NewReader(query))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)

	var result struct {
		Data struct {
			Myself struct {
				CurrentSpendPerHr float64 `json:"currentSpendPerHr"`
				ClientBalance     float64 `json:"clientBalance"`
			} `json:"myself"`
		} `json:"data"`
	}

	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}

	return &AccountInfo{
		Balance:   result.Data.Myself.ClientBalance,
		CostPerHr: result.Data.Myself.CurrentSpendPerHr,
	}, nil
}

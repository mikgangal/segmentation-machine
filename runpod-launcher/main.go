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
)

// Global state for cleanup on exit
var (
	activePodID  string
	activeAPIKey string
	launchStart  time.Time
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

// ANSI color codes
const (
	colorReset  = "\033[0m"
	colorGreen  = "\033[32m"
	colorRed    = "\033[31m"
	colorYellow = "\033[33m"
	colorCyan   = "\033[36m"
	colorDim    = "\033[2m"
)

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

	// Show technical details in compact format
	fmt.Println()
	fmt.Printf("%s── Configuration ──────────────────────────────────────────────%s\n", colorDim, colorReset)
	fmt.Printf("%sTemplate: %s │ Volume: %s │ GPU: %s%s\n",
		colorDim, templateID, networkVolumeID, gpuTypes[0], colorReset)
	fmt.Printf("%s───────────────────────────────────────────────────────────────%s\n", colorDim, colorReset)
	fmt.Println()

	// Start timing
	launchStart = time.Now()

	fmt.Println("Launching pod...")
	podID, gpuName, err := launchPod(apiKey)
	if err != nil {
		fmt.Printf("Error launching pod: %v\n", err)
		waitForEnter()
		os.Exit(1)
	}

	// Store for cleanup on exit
	activeAPIKey = apiKey
	activePodID = podID

	fmt.Printf("  %s✓%s Pod created: %s\n", colorGreen, colorReset, podID)
	if gpuName != "" {
		fmt.Printf("  %s✓%s GPU: %s\n", colorGreen, colorReset, gpuName)
	}
	fmt.Println()

	// Wait for pod to be ready with progress display
	vncURL := fmt.Sprintf("https://%s-6080.proxy.runpod.net", podID)
	_, tcpPorts, err := waitForPodReady(apiKey, podID, vncURL)
	if err != nil {
		fmt.Printf("Warning: %v\n", err)
		fmt.Println("Opening browser anyway...")
	}

	// Calculate and display load time
	loadDuration := time.Since(launchStart)
	fmt.Printf("\n%s✓ Ready in %s%s\n", colorGreen, formatDuration(loadDuration), colorReset)

	// Display user-friendly connection info
	fileBrowserURL := fmt.Sprintf("https://%s-8080.proxy.runpod.net/FILE%%20TRANSFERS/", podID)
	fmt.Println()
	fmt.Println("╔════════════════════════════════════════════════════════════╗")
	fmt.Println("║  YOUR SESSION IS READY                                     ║")
	fmt.Println("╠════════════════════════════════════════════════════════════╣")
	fmt.Println("║                                                            ║")
	fmt.Println("║  Desktop (opens automatically in browser):                 ║")
	fmt.Printf("║    %s%s%s\n", colorCyan, vncURL, colorReset)
	fmt.Println("║                                                            ║")
	fmt.Println("║  File Upload (drag & drop files):                          ║")
	fmt.Printf("║    %s%s%s\n", colorCyan, fileBrowserURL, colorReset)
	fmt.Printf("║    Login: %sadmin%s / %srunpod%s\n", colorGreen, colorReset, colorGreen, colorReset)
	fmt.Println("║                                                            ║")
	if tcpPorts != nil {
		fmt.Printf("%s║  Advanced: ", colorDim)
		if port, ok := tcpPorts[5901]; ok {
			fmt.Printf("VNC %s:%d ", port.IP, port.PublicPort)
		}
		if port, ok := tcpPorts[22]; ok {
			fmt.Printf("│ SSH -p %d", port.PublicPort)
		}
		fmt.Printf("%s\n", colorReset)
	}
	fmt.Println("╚════════════════════════════════════════════════════════════╝")

	// Open noVNC first
	fmt.Println()
	fmt.Println("Opening desktop (noVNC)...")
	if err := openBrowser(vncURL); err != nil {
		fmt.Printf("Could not open browser. Open this URL: %s\n", vncURL)
	}

	// Wait for File Browser and open it second (so it's the active tab)
	fileBrowserCheckURL := fmt.Sprintf("https://%s-8080.proxy.runpod.net", podID)
	waitForFileBrowser(fileBrowserCheckURL, fileBrowserURL)

	fmt.Println()
	fmt.Printf("%s⚠  IMPORTANT: Closing this window terminates the pod!%s\n", colorYellow, colorReset)
	fmt.Println()

	// Show initial balance
	if info, err := getAccountInfo(apiKey); err == nil {
		fmt.Printf("Balance: %s$%.2f%s │ Cost: %s$%.2f/hr%s │ Runtime: ~%.1f hrs\n",
			colorGreen, info.Balance, colorReset, colorRed, info.CostPerHr, colorReset, info.Balance/info.CostPerHr)
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
					elapsed := time.Since(launchStart)
					fmt.Printf("\rBalance: %s$%.2f%s │ Cost: %s$%.2f/hr%s │ Session: %s\n",
						colorGreen, info.Balance, colorReset, colorRed, info.CostPerHr, colorReset,
						formatDuration(elapsed))
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

// formatDuration formats a duration in a human-friendly way
func formatDuration(d time.Duration) string {
	if d < time.Minute {
		return fmt.Sprintf("%ds", int(d.Seconds()))
	} else if d < time.Hour {
		mins := int(d.Minutes())
		secs := int(d.Seconds()) % 60
		return fmt.Sprintf("%dm %ds", mins, secs)
	}
	hrs := int(d.Hours())
	mins := int(d.Minutes()) % 60
	return fmt.Sprintf("%dh %dm", hrs, mins)
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

// PortInfo holds TCP port mapping info
type PortInfo struct {
	IP         string
	PublicPort int
}

func waitForPodReady(apiKey, podID, vncURL string) (string, map[int]PortInfo, error) {
	client := &http.Client{Timeout: 10 * time.Second}

	var publicIP string
	var tcpPorts map[int]PortInfo

	// Clear line helper - clears entire line
	clearLine := "\r\033[K"

	spinner := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
	spinIdx := 0
	lastPhase := ""

	// Tips to show while waiting
	tips := []string{
		"Your files persist on the network volume at /workspace",
		"Use File Browser to drag & drop files directly to the pod",
		"TurboVNC client gives better performance than browser",
		"The nnInteractive server starts automatically with the desktop",
		"Click '3D Slicer' on the desktop to start segmenting",
		"GPU-accelerated apps: 3D Slicer, Blender, Fiji",
		"SSH access: root / runpod (see connection info)",
		"Claude Code CLI is pre-installed - just type 'claude'",
		"Closing this window auto-terminates the pod",
		"Balance updates every 5 minutes while running",
		"T2 DICOM folders auto-load into Slicer when uploaded",
		"lazygit is available via the GitHub desktop shortcut",
	}
	tipIdx := 0
	lastTipTime := time.Now()

	// Phase 1: Wait for pod to have public ports
	for i := 0; i < 180; i++ { // Max 6 minutes
		query := fmt.Sprintf(`{"query": "query { pod(input: {podId: \"%s\"}) { id desiredStatus runtime { ports { ip isIpPublic privatePort publicPort type } gpus { id } } } }"}`, podID)
		req, _ := http.NewRequest("POST", runpodGraphQLURL+"?api_key="+apiKey, strings.NewReader(query))
		req.Header.Set("Content-Type", "application/json")

		resp, err := client.Do(req)
		if err != nil {
			spinIdx = (spinIdx + 1) % len(spinner)
			fmt.Printf("%s  %s Connecting...    ", clearLine, spinner[spinIdx])
			time.Sleep(2 * time.Second)
			continue
		}

		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		var result struct {
			Data struct {
				Pod struct {
					DesiredStatus string `json:"desiredStatus"`
					Runtime       *struct {
						Ports []struct {
							IP          string `json:"ip"`
							IsIPPublic  bool   `json:"isIpPublic"`
							PrivatePort int    `json:"privatePort"`
							PublicPort  int    `json:"publicPort"`
							Type        string `json:"type"`
						} `json:"ports"`
						Gpus []struct {
							ID string `json:"id"`
						} `json:"gpus"`
					} `json:"runtime"`
				} `json:"pod"`
			} `json:"data"`
		}
		json.Unmarshal(body, &result)

		// Determine current phase based on pod state
		var phaseName string
		var phaseDetail string

		if result.Data.Pod.Runtime == nil {
			phaseName = "Waiting for GPU"
			phaseDetail = "in queue"
		} else if len(result.Data.Pod.Runtime.Gpus) == 0 {
			phaseName = "Pulling image"
			phaseDetail = ""
		} else if len(result.Data.Pod.Runtime.Ports) == 0 {
			phaseName = "Starting services"
			phaseDetail = ""
		} else {
			// Check for public ports
			hasPublic := false
			tcpPorts = make(map[int]PortInfo)
			for _, p := range result.Data.Pod.Runtime.Ports {
				if p.Type == "tcp" && p.IsIPPublic {
					hasPublic = true
					publicIP = p.IP
					tcpPorts[p.PrivatePort] = PortInfo{IP: p.IP, PublicPort: p.PublicPort}
				}
			}

			if !hasPublic {
				phaseName = "Configuring network"
				phaseDetail = ""
			} else {
				phaseName = "Running"
				phaseDetail = ""
			}
		}

		elapsed := time.Since(launchStart)
		spinIdx = (spinIdx + 1) % len(spinner)

		// Track phase changes
		if phaseName != lastPhase {
			if lastPhase != "" {
				// Clear both lines (status + tip) and print completed phase
				fmt.Print("\033[1B")  // Move down to tip line
				fmt.Printf("%s", clearLine)  // Clear tip line
				fmt.Print("\033[1A")  // Move back up
				fmt.Printf("%s  %s✓%s %s\n", clearLine, colorGreen, colorReset, lastPhase)
			}
			lastPhase = phaseName
		}

		// Show current phase with spinner and elapsed time
		statusLine := fmt.Sprintf("  %s %s", spinner[spinIdx], phaseName)
		if phaseDetail != "" {
			statusLine += fmt.Sprintf(" (%s)", phaseDetail)
		}
		statusLine += fmt.Sprintf(" - %s", formatDuration(elapsed))

		// Rotate tips every 5 seconds
		if time.Since(lastTipTime) > 5*time.Second {
			tipIdx = (tipIdx + 1) % len(tips)
			lastTipTime = time.Now()
		}

		// Show status with tip on second line
		fmt.Printf("%s%s\n", clearLine, statusLine)
		fmt.Printf("%s    %s💡 %s%s", clearLine, colorDim, tips[tipIdx], colorReset)
		// Move cursor back up one line for next update
		fmt.Print("\033[1A")

		if phaseName == "Running" && publicIP != "" {
			// Clear both lines and print completion
			fmt.Print("\033[1B")  // Move down to tip line
			fmt.Printf("%s", clearLine)  // Clear tip line
			fmt.Print("\033[1A")  // Move back up
			fmt.Printf("%s  %s✓%s %s\n", clearLine, colorGreen, colorReset, phaseName)
			break
		}

		time.Sleep(2 * time.Second)
	}

	// Phase 2: Wait for VNC port to be accessible
	spinIdx = 0
	tipIdx = 0
	lastTipTime = time.Now()
	for i := 0; i < 60; i++ { // Max 2 minutes
		resp, err := client.Get(vncURL)
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode == 200 || resp.StatusCode == 302 || resp.StatusCode == 401 {
				// Clear both lines and print completion
				fmt.Print("\033[1B")  // Move down to tip line
				fmt.Printf("%s", clearLine)  // Clear tip line
				fmt.Print("\033[1A")  // Move back up
				fmt.Printf("%s  %s✓%s Desktop ready\n", clearLine, colorGreen, colorReset)
				return publicIP, tcpPorts, nil
			}
		}
		spinIdx = (spinIdx + 1) % len(spinner)
		elapsed := time.Since(launchStart)

		// Rotate tips every 5 seconds
		if time.Since(lastTipTime) > 5*time.Second {
			tipIdx = (tipIdx + 1) % len(tips)
			lastTipTime = time.Now()
		}

		// Show status with tip
		fmt.Printf("%s  %s Waiting for desktop - %s\n", clearLine, spinner[spinIdx], formatDuration(elapsed))
		fmt.Printf("%s    %s💡 %s%s", clearLine, colorDim, tips[tipIdx], colorReset)
		fmt.Print("\033[1A")  // Move cursor back up

		time.Sleep(2 * time.Second)
	}

	return publicIP, tcpPorts, fmt.Errorf("timeout waiting for VNC port")
}

func waitForFileBrowser(checkURL, openURL string) {
	client := &http.Client{Timeout: 5 * time.Second}
	spinner := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
	spinIdx := 0
	clearLine := "\r\033[K"

	fmt.Printf("  %s Waiting for File Browser...", spinner[0])

	for i := 0; i < 60; i++ { // Max 3 minutes
		resp, err := client.Get(checkURL)
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode == 200 || resp.StatusCode == 401 || resp.StatusCode == 302 {
				fmt.Printf("%s  %s✓%s File Browser ready\n", clearLine, colorGreen, colorReset)
				fmt.Println("Opening File Browser (for uploads)...")
				openBrowser(openURL)
				return
			}
		}
		spinIdx = (spinIdx + 1) % len(spinner)
		fmt.Printf("%s  %s Waiting for File Browser...", clearLine, spinner[spinIdx])
		time.Sleep(3 * time.Second)
	}
	fmt.Printf("%s  %s⚠%s File Browser not detected (may need manual start)\n", clearLine, colorYellow, colorReset)
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

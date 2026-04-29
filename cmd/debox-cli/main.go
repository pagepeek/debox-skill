package main

import (
	"bytes"
	"crypto/rand"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

const (
	defaultBaseURL = "https://open.debox.pro"
	version        = "0.1.0"
)

type cliError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
	Hint    string `json:"hint"`
}

type response struct {
	OK     bool        `json:"ok"`
	Action string      `json:"action"`
	Data   interface{} `json:"data,omitempty"`
	Error  *cliError   `json:"error,omitempty"`
}

type env struct {
	APIKey     string
	AppID      string
	AppSecret  string
	WebhookKey string
	BaseURL    string
}

func main() {
	action := commandAction(os.Args[1:])
	if err := run(os.Args[1:]); err != nil {
		writeFailure(action, err)
		os.Exit(1)
	}
}

func commandAction(args []string) string {
	if len(args) == 0 {
		return "unknown"
	}
	switch args[0] {
	case "env":
		if len(args) > 1 && args[1] == "check" {
			return "env.check"
		}
	case "group":
		if len(args) > 1 && args[1] == "parse-id" {
			return "group.parse-id"
		}
	case "message":
		if len(args) > 1 {
			switch args[1] {
			case "send-group":
				return "message.send_group"
			case "send-private":
				return "message.send_private"
			}
		}
	case "webhook":
		if len(args) > 1 && args[1] == "verify" {
			return "webhook.verify"
		}
	}
	return args[0]
}

func run(args []string) error {
	if len(args) == 0 {
		return usageError("missing command", "Use one of: env check, group parse-id, message send-group, message send-private, webhook verify.")
	}

	switch args[0] {
	case "--version", "version":
		fmt.Printf("debox-cli %s\n", version)
		return nil
	case "env":
		return runEnv(args[1:])
	case "group":
		return runGroup(args[1:])
	case "message":
		return runMessage(args[1:])
	case "webhook":
		return runWebhook(args[1:])
	default:
		return usageError("unknown command: "+args[0], "Use one of: env check, group parse-id, message send-group, message send-private, webhook verify.")
	}
}

func runEnv(args []string) error {
	if len(args) == 0 || args[0] != "check" {
		return usageError("unknown env command", "Use: env check --json")
	}
	fs := newFlagSet("env check")
	if err := fs.Parse(args[1:]); err != nil {
		return err
	}

	e := readEnv()
	missing := []string{}
	if e.APIKey == "" {
		missing = append(missing, "DEBOX_API_KEY")
	}

	if len(missing) > 0 {
		return cliError{Code: "MISSING_CREDENTIALS", Message: "Missing required DeBox credentials.", Hint: "Set " + strings.Join(missing, ", ") + " in the local environment."}
	}

	writeSuccess("env.check", map[string]interface{}{
		"api_key":     "set",
		"app_id":      setState(e.AppID),
		"app_secret":  setState(e.AppSecret),
		"webhook_key": setState(e.WebhookKey),
		"base_url":    e.BaseURL,
	})
	return nil
}

func runGroup(args []string) error {
	if len(args) == 0 {
		return usageError("missing group command", "Use: group parse-id --url <url> --json")
	}
	switch args[0] {
	case "parse-id":
		fs := newFlagSet("group parse-id")
		inviteURL := fs.String("url", "", "DeBox group invite URL")
		if err := fs.Parse(args[1:]); err != nil {
			return err
		}
		groupID, err := parseGroupID(*inviteURL)
		if err != nil {
			return err
		}
		writeSuccess("group.parse-id", map[string]string{"group_id": groupID})
		return nil
	default:
		return usageError("unknown group command: "+args[0], "Use: group parse-id --url <url> --json")
	}
}

func runMessage(args []string) error {
	if len(args) == 0 {
		return usageError("missing message command", "Use: message send-group or message send-private.")
	}

	switch args[0] {
	case "send-group":
		fs := newFlagSet("message send-group")
		groupID := fs.String("group-id", "", "DeBox group ID")
		msgType := fs.String("type", "text", "message type")
		title := fs.String("title", "", "message title")
		content := fs.String("content", "", "message content")
		toUserID := fs.String("to-user-id", "", "optional mentioned user ID")
		if err := fs.Parse(args[1:]); err != nil {
			return err
		}
		if *groupID == "" {
			return usageError("missing --group-id", "Provide the DeBox group ID or parse it from an invite URL first.")
		}
		return sendMessage("message.send_group", "/openapi/messages/group/send", map[string]string{
			"group_id":    *groupID,
			"to_user_id":  *toUserID,
			"object_name": *msgType,
			"title":       *title,
			"content":     *content,
		})
	case "send-private":
		fs := newFlagSet("message send-private")
		userID := fs.String("user-id", "", "DeBox user ID")
		msgType := fs.String("type", "text", "message type")
		title := fs.String("title", "", "message title")
		content := fs.String("content", "", "message content")
		if err := fs.Parse(args[1:]); err != nil {
			return err
		}
		if *userID == "" {
			return usageError("missing --user-id", "Provide the DeBox user ID.")
		}
		return sendMessage("message.send_private", "/openapi/messages/private/send", map[string]string{
			"to_user_id":  *userID,
			"object_name": *msgType,
			"title":       *title,
			"content":     *content,
		})
	default:
		return usageError("unknown message command: "+args[0], "Use: message send-group or message send-private.")
	}
}

func runWebhook(args []string) error {
	if len(args) == 0 || args[0] != "verify" {
		return usageError("unknown webhook command", "Use: webhook verify --header-api-key-stdin --json")
	}

	fs := newFlagSet("webhook verify")
	fromStdin := fs.Bool("header-api-key-stdin", false, "read X-API-KEY header from stdin")
	if err := fs.Parse(args[1:]); err != nil {
		return err
	}
	if !*fromStdin {
		return usageError("missing --header-api-key-stdin", "Pipe the received X-API-KEY header value through stdin; do not pass it as an argument.")
	}

	e := readEnv()
	if e.WebhookKey == "" {
		return cliError{Code: "MISSING_CREDENTIALS", Message: "Missing DEBOX_WEBHOOK_KEY.", Hint: "Set DEBOX_WEBHOOK_KEY before verifying webhook callbacks."}
	}
	headerValueBytes, err := io.ReadAll(io.LimitReader(os.Stdin, 4096))
	if err != nil {
		return cliError{Code: "STDIN_READ_FAILED", Message: "Failed to read webhook header from stdin.", Hint: "Pipe the received X-API-KEY header value into this command."}
	}
	headerValue := strings.TrimSpace(string(headerValueBytes))
	if headerValue == "" {
		return cliError{Code: "MISSING_HEADER", Message: "Webhook header value is empty.", Hint: "Pipe the received X-API-KEY header value into this command."}
	}
	if headerValue != e.WebhookKey {
		return cliError{Code: "WEBHOOK_KEY_MISMATCH", Message: "Webhook key mismatch.", Hint: "Reject this webhook request."}
	}

	writeSuccess("webhook.verify", map[string]bool{"verified": true})
	return nil
}

func sendMessage(action, path string, payload map[string]string) error {
	if payload["content"] == "" {
		return usageError("missing --content", "Provide non-empty message content.")
	}
	if payload["object_name"] == "" {
		payload["object_name"] = "text"
	}
	if payload["object_name"] != "text" && payload["object_name"] != "richtext" {
		return usageError("unsupported --type: "+payload["object_name"], "Use --type text or --type richtext.")
	}

	e := readEnv()
	if e.APIKey == "" {
		return cliError{Code: "MISSING_CREDENTIALS", Message: "Missing DEBOX_API_KEY.", Hint: "Set DEBOX_API_KEY in the local environment."}
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return cliError{Code: "REQUEST_BUILD_FAILED", Message: "Failed to encode request body.", Hint: "Check message parameters."}
	}

	endpoint := strings.TrimRight(e.BaseURL, "/") + path
	req, err := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(bodyBytes))
	if err != nil {
		return cliError{Code: "REQUEST_BUILD_FAILED", Message: "Failed to create DeBox request.", Hint: "Check DEBOX_OPENAPI_BASE_URL."}
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-API-KEY", e.APIKey)
	if e.AppID != "" {
		req.Header.Set("app_id", e.AppID)
	}
	if e.AppSecret != "" {
		nonce, timestamp, signature, err := signedHeaders(e.AppSecret)
		if err != nil {
			return err
		}
		req.Header.Set("nonce", nonce)
		req.Header.Set("timestamp", timestamp)
		req.Header.Set("signature", signature)
	}

	client := &http.Client{Timeout: 20 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return cliError{Code: "HTTP_REQUEST_FAILED", Message: "Failed to call DeBox OpenPlatform.", Hint: "Check network access and DeBox API availability."}
	}
	defer resp.Body.Close()

	rawBody, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return cliError{Code: "HTTP_RESPONSE_READ_FAILED", Message: "Failed to read DeBox response.", Hint: "Retry later or inspect network connectivity."}
	}

	var decoded interface{}
	if len(rawBody) > 0 {
		_ = json.Unmarshal(rawBody, &decoded)
	}

	data := map[string]interface{}{
		"http_status": resp.StatusCode,
		"response":    decodedOrString(decoded, rawBody),
	}
	if messageID := findString(decoded, "message_id", "msg_id", "id"); messageID != "" {
		data["message_id"] = messageID
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return cliError{Code: "DEBOX_HTTP_ERROR", Message: fmt.Sprintf("DeBox returned HTTP %d.", resp.StatusCode), Hint: "Check credentials, target IDs, and message payload."}
	}
	if apiCode := findNumber(decoded, "code"); apiCode != 0 && apiCode != 200 {
		return cliError{Code: fmt.Sprintf("%v", apiCode), Message: findMessage(decoded), Hint: "Check credentials, target IDs, and message payload."}
	}
	if success, ok := findBool(decoded, "success"); ok && !success {
		message := findMessage(decoded)
		if message == "" || strings.EqualFold(message, "success") {
			writeSuccess(action, data)
			return nil
		}
		return cliError{Code: "DEBOX_API_ERROR", Message: message, Hint: "Check credentials, target IDs, and message payload."}
	}

	writeSuccess(action, data)
	return nil
}

func signedHeaders(appSecret string) (string, string, string, error) {
	nonceBytes := make([]byte, 4)
	if _, err := rand.Read(nonceBytes); err != nil {
		return "", "", "", cliError{Code: "NONCE_FAILED", Message: "Failed to generate request nonce.", Hint: "Retry the command."}
	}
	nonce := fmt.Sprintf("%08d", int(nonceBytes[0])<<24|int(nonceBytes[1])<<16|int(nonceBytes[2])<<8|int(nonceBytes[3])&0x7fffffff)
	if len(nonce) > 8 {
		nonce = nonce[len(nonce)-8:]
	}
	timestamp := fmt.Sprintf("%d", time.Now().UnixMilli())
	sum := sha1.Sum([]byte(appSecret + nonce + timestamp))
	return nonce, timestamp, hex.EncodeToString(sum[:]), nil
}

func parseGroupID(rawURL string) (string, error) {
	if rawURL == "" {
		return "", usageError("missing --url", "Provide a DeBox group invite URL.")
	}
	parsed, err := url.Parse(rawURL)
	if err == nil {
		if id := strings.TrimSpace(parsed.Query().Get("id")); id != "" {
			return id, nil
		}
	}
	return "", cliError{Code: "GROUP_ID_NOT_FOUND", Message: "No group ID found in URL.", Hint: "Use a DeBox invite URL like https://m.debox.pro/group?id=fxi3hqo5."}
}

func newFlagSet(name string) *flag.FlagSet {
	fs := flag.NewFlagSet(name, flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	fs.Bool("json", false, "emit JSON output")
	return fs
}

func readEnv() env {
	baseURL := strings.TrimSpace(os.Getenv("DEBOX_OPENAPI_BASE_URL"))
	if baseURL == "" {
		baseURL = defaultBaseURL
	}
	return env{
		APIKey:     strings.TrimSpace(os.Getenv("DEBOX_API_KEY")),
		AppID:      strings.TrimSpace(os.Getenv("DEBOX_APP_ID")),
		AppSecret:  strings.TrimSpace(os.Getenv("DEBOX_APP_SECRET")),
		WebhookKey: strings.TrimSpace(os.Getenv("DEBOX_WEBHOOK_KEY")),
		BaseURL:    baseURL,
	}
}

func setState(value string) string {
	if value == "" {
		return "missing"
	}
	return "set"
}

func usageError(message, hint string) error {
	return cliError{Code: "USAGE_ERROR", Message: message, Hint: hint}
}

func writeSuccess(action string, data interface{}) {
	writeJSON(response{OK: true, Action: action, Data: data})
}

func writeFailure(action string, err error) {
	var ce cliError
	if errors.As(err, &ce) {
		writeJSON(response{OK: false, Action: action, Error: &ce})
		return
	}
	writeJSON(response{OK: false, Action: action, Error: &cliError{Code: "INTERNAL_ERROR", Message: err.Error(), Hint: "Retry or report this CLI failure."}})
}

func writeJSON(value interface{}) {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetEscapeHTML(false)
	_ = encoder.Encode(value)
}

func (e cliError) Error() string {
	return e.Message
}

func decodedOrString(decoded interface{}, raw []byte) interface{} {
	if decoded != nil {
		return decoded
	}
	return string(raw)
}

func findMessage(value interface{}) string {
	if message := findString(value, "message", "msg", "error"); message != "" {
		return message
	}
	return "DeBox API returned an error."
}

func findString(value interface{}, keys ...string) string {
	m, ok := value.(map[string]interface{})
	if !ok {
		return ""
	}
	for _, key := range keys {
		if raw, ok := m[key]; ok {
			if s, ok := raw.(string); ok {
				return s
			}
		}
	}
	return ""
}

func findNumber(value interface{}, key string) float64 {
	m, ok := value.(map[string]interface{})
	if !ok {
		return 0
	}
	if raw, ok := m[key]; ok {
		if n, ok := raw.(float64); ok {
			return n
		}
	}
	return 0
}

func findBool(value interface{}, key string) (bool, bool) {
	m, ok := value.(map[string]interface{})
	if !ok {
		return false, false
	}
	if raw, ok := m[key]; ok {
		if b, ok := raw.(bool); ok {
			return b, true
		}
	}
	return false, false
}

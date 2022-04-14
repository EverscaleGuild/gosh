package cmd

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strconv"
)

var WebLogEnabled bool = false

func initWebLog() {
	v, err := strconv.ParseBool(os.Getenv("WEBLOG"))
	if v && err == nil {
		WebLogEnabled = true
	}
}

func dump(v interface{}) string {
	b, _ := json.Marshal(v)
	return string(b)
}

func dumpp(v interface{}) string {
	b, _ := json.MarshalIndent(v, "", "  ")
	return string(b)
}

func sendWebLog(msg string) string {
	if WebLogEnabled {
		http.Get("http://host.docker.internal:8888/?" + url.Values{"log": {msg}}.Encode())
	}
	return msg
}

func logf(format string, a ...interface{}) string {
	return sendWebLog(fmt.Sprintf(format, a...))
}

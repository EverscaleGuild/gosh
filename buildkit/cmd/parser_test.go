package cmd

import (
	"testing"
)

func TestParser(t *testing.T) {
	config, err := parseConfig([]byte(`
apiVersion: 1
image: bash:latest
workingDir: "/"
entrypoint:
  - sleep
  - infinity
steps:
  - name: print date
    run:
      command: ["/url/local/bin/bash"]
      args:
      - -c
      - >-
          (date +'%s %H:%M:%S %Z'; echo "Hi there") | tee /message.txt
    `))

	if err != nil {
		t.Errorf("%v", err)
	}

	if len(config.Steps) < 1 {
		t.Errorf("Wrong number of steps")
	}

	if config.Image != "bash:latest" {
		t.Errorf("Wrong image")
	}

	if len(config.Entrypoint) != 2 {
		t.Errorf("Wrong entrypoint")
	}

	step := config.Steps[0]

	if step.Run.Command == nil {
		t.Errorf("Wrong command")
	}

	if step.Name != "print date" {
		t.Errorf("Wrong step name: %s", config.Steps[0].Name)
	}

	if step.Copy != nil {
		t.Errorf("Wrong run and copy conflict")
	}

	if config.ApiVersion != "1" {
		t.Errorf("Expected API version")
	}
}

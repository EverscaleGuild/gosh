package cmd

import (
	"gopkg.in/yaml.v3"
)

type Config struct {
	ApiVersion string   `yaml:"apiVersion"`
	Image      string   `yaml:"image"`
	Entrypoint []string `yaml:"entrypoint,omitempty"`
	WorkingDir string   `yaml:"workingDir,omitempty"`
	Steps      []Step   `yaml:"steps"`
}

type Step struct {
	Name string `yaml:"name"`
	Run  *Run   `yaml:"run,omitempty"`
	Copy *Copy  `yaml:"copy,omitempty"`
}

type Copy struct{}

type Run struct {
	Command []string `yaml:"command"`
	Args    []string `yaml:"args"`
	Mounts  []Mount  `yaml:"mounts"`
}

type Mount struct {
	Gosh string `yaml:"gosh"`
	Dst  string `yaml:"dst"`
}

func parseConfig(data []byte) (*Config, error) {
	config := Config{}
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, err
	}
	return &config, nil
}

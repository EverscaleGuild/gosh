package cmd

import (
	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:           "buildkit-gosh",
	Short:         "DO NOT EXECUTE THIS BINARY MANUALLY",
	SilenceErrors: true,
	SilenceUsage:  true,
}

func Execute() {
	initWebLog()
	rootCmd.AddCommand(frontendCmd())
	if err := rootCmd.Execute(); err != nil {
		logrus.Fatal(err)
	}
}

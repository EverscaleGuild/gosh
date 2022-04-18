package cmd

import (
	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:           "buildkit-gosh",
	Short:         "DO NOT EXECUTE THIS BINARY MANUALLY",
	SilenceErrors: true,
	SilenceUsage:  true,
}

func Execute() {
	rootCmd.AddCommand(frontendCmd())
	if err := rootCmd.Execute(); err != nil {
		panic(err)
	}
}

package cmd

import (
	"buildkit-gosh/pkg/constants"
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/moby/buildkit/client/llb"
	"github.com/moby/buildkit/exporter/containerimage/exptypes"
	"github.com/moby/buildkit/frontend/gateway/client"
	"github.com/moby/buildkit/frontend/gateway/grpcclient"

	"github.com/moby/buildkit/util/appcontext"
	"github.com/moby/buildkit/util/system"
	ocispecs "github.com/opencontainers/image-spec/specs-go/v1"
	"github.com/pkg/errors"
	"github.com/spf13/cobra"

	opentracing "github.com/opentracing/opentracing-go"
	"github.com/opentracing/opentracing-go/log"
)

func frontendCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "frontend",
		Short: "Frontend entrypoint",
		Args:  cobra.NoArgs,
		RunE:  frontend,
	}
	return cmd
}

const (
	localConfigMount = "dockerfile"
	keyFilename      = "filename"
	sharedKeyHint    = constants.DefaultConfigFile
	labelPrefix      = "label:"
)

func frontend(*cobra.Command, []string) error {
	_, closer := initTracing("gosh-buildkit-frontend")
	defer closer.Close()

	ctx := appcontext.Context()

	span, ctx := opentracing.StartSpanFromContext(ctx, "grpcclient")
	defer span.Finish()

	err := grpcclient.RunFromEnvironment(ctx, frontendBuild())

	return err
}

func loadConfig(ctx context.Context, c client.Client) (*Config, error) {
	span, ctx := opentracing.StartSpanFromContext(ctx, "loadConfig")
	defer span.Finish()

	filename := c.BuildOpts().Opts[keyFilename]
	span.LogKV("filename", filename)
	if filename == "" {
		filename = constants.DefaultConfigFile
	}

	configState := llb.Local(
		localConfigMount,
		llb.SessionID(c.BuildOpts().SessionID),
		llb.SharedKeyHint(sharedKeyHint),
		llb.WithCustomName("[gosh load config] from "+filename),
	)

	span.LogFields(log.Object("configState", configState))
	def, err := configState.Marshal(ctx)
	if err != nil {
		return nil, errors.Wrapf(err, "failed to marshal local source")
	}

	span.LogKV("def", dumpp(def))

	var df []byte
	res, err := c.Solve(ctx, client.SolveRequest{
		Definition: def.ToPB(),
	})
	if err != nil {
		return nil, errors.Wrapf(err, "failed to resolve image config")
	}
	span.LogKV("res", dumpp(res))

	ref, err := res.SingleRef()
	if err != nil {
		return nil, err
	}
	span.LogKV("ref", dumpp(ref))

	df, err = ref.ReadFile(ctx, client.ReadRequest{
		Filename: filename,
	})

	span.LogKV("dockerfile", string(df))
	if err != nil {
		return nil, errors.Wrapf(err, "failed to read image config "+filename)
	}

	return parseConfig(df)
}

func imageHash(ctx context.Context, c client.Client, st *llb.State) (string, error) {
	span, ctx := opentracing.StartSpanFromContext(ctx, "imageHash")
	defer span.Finish()

	signer := llb.Image("alpine").Dir("/out").Run(
		llb.Args([]string{
			"sh",
			"-c",
			`find . -type f -exec sha256sum -b {} + | LC_ALL=C sort | sha256sum | awk '{ printf "sha256:%s", $1 }' > /hash`,
		}),
		llb.AddMount(".", *st, llb.SourcePath("/")),
		llb.IgnoreCache,
	).Root()

	// debug
	signer = signer.Run(
		llb.Args([]string{
			"sh",
			"-c",
			`find . -type f > /debug`,
		}),
		llb.AddMount(".", *st, llb.SourcePath("/")),
		llb.IgnoreCache,
	).Root()

	def, err := signer.Marshal(ctx)
	if err != nil {
		return "", errors.Wrapf(err, "failed to marshal local source")
	}

	span.LogKV("def", dumpp(def))

	res, err := c.Solve(ctx, client.SolveRequest{
		Definition: def.ToPB(),
	})
	if err != nil {
		return "", errors.Wrapf(err, "failed to resolve image config")
	}
	span.LogKV("res", dumpp(res))

	ref, err := res.SingleRef()
	if err != nil {
		return "", err
	}
	span.LogKV("ref", dumpp(ref))

	hash, err := ref.ReadFile(ctx, client.ReadRequest{
		Filename: "/hash",
	})

	hashSt := string(hash)

	span.LogKV("hash", hashSt)
	if err != nil {
		return "", errors.Wrapf(err, "failed to read /hash")
	}

	debug, err := ref.ReadFile(ctx, client.ReadRequest{
		Filename: "/debug",
	})

	debugSt := string(debug)

	span.LogKV("debug", debugSt)
	if err != nil {
		return "", errors.Wrapf(err, "failed to read /debug")
	}

	return hashSt, nil
}

func frontendBuild() client.BuildFunc {
	return func(ctx context.Context, c client.Client) (*client.Result, error) {
		span, ctx := opentracing.StartSpanFromContext(ctx, "build")
		defer span.Finish()

		opts := c.BuildOpts().Opts
		span.LogKV(
			"client", dumpp(c),
			"opts", dumpp(opts),
		)
		wallet := opts["wallet"]
		wallet_secret := opts["wallet_secret"]
		wallet_public := opts["wallet_public"]
		_ = wallet
		_ = wallet_secret
		_ = wallet_public

		// load config
		config, err := loadConfig(ctx, c)
		if err != nil {
			return nil, err
		}
		span.LogKV("config", dumpp(config))

		// init image
		goshImage := llb.Image(
			config.Image,
			llb.IgnoreCache,
			llb.WithMetaResolver(c),
			llb.WithCustomName(fmt.Sprintf("[gosh] init image %s", config.Image)),
		)

		goshImage = goshImage.Dir("/")
		goshImage = goshImage.Run(llb.Shlex("touch test.sock")).Root()

		// // localSock := llb.Local(
		// // 	"test.sock",
		// // 	llb.SessionID(c.BuildOpts().SessionID),
		// // ).File(llb.Mkfile("test.sock", 0777, []byte{}))
		// gitSock := llb.Image("bash")
		// 	.Dir("/")
		// 	.File(llb.Mkfile("test.sock", 0777, []byte{}))
		// 	.Run(llb.Shlex(
		// 		`echo 123 > test.sock`
		// 	)).Root()

		// run steps
		for i, step := range config.Steps {
			stepName := fmt.Sprintf("[step %d/%d] %s", i+1, len(config.Steps), step.Name)
			span.LogKV(stepName, dumpp(step))
			if step.Run != nil {
				runoptions := []llb.RunOption{
					llb.IgnoreCache,
					// llb.Network(opspb.NetMode_NONE), // important: disable internet
					llb.WithCustomName("[gosh] " + stepName),
					llb.Args(append(step.Run.Command, step.Run.Args...)),
				}
				goshImage = goshImage.Dir("/")
				runSt := goshImage.Run(runoptions...)
				goshImage = runSt.Root()
				continue
			}
		}

		marshalOpts := []llb.ConstraintsOpt{
			llb.WithCaps(c.BuildOpts().Caps),
		}

		span.LogKV("goshImage", dumpp(goshImage))
		def, err := goshImage.Marshal(ctx, marshalOpts...)
		if err != nil {
			return nil, err
		}

		//
		//

		span.LogKV("def", dumpp(def))

		res, err := c.Solve(ctx, client.SolveRequest{
			Definition: def.ToPB(),
		})

		hash, err := imageHash(ctx, c, goshImage)
		if err != nil {
			return nil, errors.Wrapf(err, "failed to resolve dockerfile")
		}

		labels := filter(opts, labelPrefix)
		if _, ok := labels["WALLET_PUBLIC"]; !ok {
			labels["WALLET_PUBLIC"] = wallet_public
		}
		labels["HASH"] = hash

		ref, err := res.SingleRef()
		if err != nil {
			return nil, err
		}

		span.LogKV("ref", fmt.Sprintf("%#+v %s", ref, dumpp(ref)))

		env := []string{
			"PATH=" + system.DefaultPathEnv(def.Constraints.Platform.OS),
		}

		workingDir := config.WorkingDir
		if len(workingDir) == 0 {
			workingDir = "/"
		}

		imgConfig := ocispecs.ImageConfig{
			Labels:     labels,
			WorkingDir: workingDir,
			Entrypoint: config.Entrypoint,
			Env:        env,
		}

		img := ocispecs.Image{
			Architecture: def.Constraints.Platform.Architecture,
			Config:       imgConfig,
			OS:           def.Constraints.Platform.OS,
			OSFeatures:   def.Constraints.Platform.OSFeatures,
			OSVersion:    def.Constraints.Platform.OSVersion,
			Variant:      def.Constraints.Platform.Variant,
		}
		exporterImageConfig, err := json.Marshal(img)
		if err != nil {
			return nil, errors.Wrapf(err, "failed to marshal image config")
		}
		res.AddMeta(exptypes.ExporterImageConfigKey, exporterImageConfig)
		res.SetRef(ref)

		span.LogKV("metadata", dumpp(res.Metadata))

		return res, nil
	}
}

func filter(opt map[string]string, key string) map[string]string {
	m := map[string]string{}
	for k, v := range opt {
		if strings.HasPrefix(k, key) {
			m[strings.TrimPrefix(k, key)] = v
		}
	}
	return m
}

// func getSelfImageSt(ctx context.Context, c client.Client, localDfSt llb.State, dfName string) (*llb.State, string, error) {
// 	localDfDef, err := localDfSt.Marshal(ctx)
// 	if err != nil {
// 		return nil, "", err
// 	}
// 	localDfRes, err := c.Solve(ctx, client.SolveRequest{
// 		Definition: localDfDef.ToPB(),
// 	})
// 	if err != nil {
// 		return nil, "", err
// 	}
// 	localDfRef, err := localDfRes.SingleRef()
// 	if err != nil {
// 		return nil, "", err
// 	}
// 	dfBytes, err := localDfRef.ReadFile(ctx, client.ReadRequest{Filename: dfName})
// 	if err != nil {
// 		return nil, "", err
// 	}
// 	selfImageRefStr, _, _, ok := dockerfile2llb.DetectSyntax(bytes.NewReader(dfBytes))
// 	if !ok {
// 		return nil, "", fmt.Errorf("failed to detect self image reference from %q", dfName)
// 	}
// 	if selfImageDgst, _, err := c.ResolveImageConfig(ctx, selfImageRefStr, llb.ResolveImageConfigOpt{}); err != nil {
// 		return nil, "", err
// 	} else if selfImageDgst != "" {
// 		selfImageRef, err := reference.ParseNormalizedNamed(selfImageRefStr)
// 		if err != nil {
// 			return nil, "", err
// 		}
// 		selfImageRefWithDigest, err := reference.WithDigest(selfImageRef, selfImageDgst)
// 		if err != nil {
// 			return nil, "", err
// 		}
// 		selfImageRefStr = selfImageRefWithDigest.String()
// 	}
// 	selfImageSt := llb.Image(selfImageRefStr, llb.WithMetaResolver(c), dockerfile2llb.WithInternalName("self image"))
// 	return &selfImageSt, selfImageRefStr, nil
// }

// func validateSelfImageSt(ctx context.Context, c client.Client, selfImageSt llb.State, selfImageRefStr string) (string, error) {
// 	selfPath, err := os.Executable()
// 	if err != nil {
// 		return "", err
// 	}
// 	selfR, err := os.Open(selfPath)
// 	if err != nil {
// 		return "", err
// 	}
// 	selfStat, err := selfR.Stat()
// 	if err != nil {
// 		selfR.Close()
// 		return "", err
// 	}
// 	selfSize := selfStat.Size()
// 	selfDigest, err := digest.Canonical.FromReader(selfR)
// 	if err != nil {
// 		selfR.Close()
// 		return "", err
// 	}
// 	if err = selfR.Close(); err != nil {
// 		return "", err
// 	}

// 	def, err := selfImageSt.Marshal(ctx)
// 	if err != nil {
// 		return "", err
// 	}
// 	res, err := c.Solve(ctx, client.SolveRequest{
// 		Definition: def.ToPB(),
// 	})
// 	if err != nil {
// 		return "", err
// 	}
// 	ref, err := res.SingleRef()
// 	if err != nil {
// 		return "", err
// 	}

// 	selfStat2, err := ref.StatFile(ctx, client.StatRequest{Path: selfPath})
// 	if err != nil {
// 		return "", err
// 	}
// 	selfSize2 := selfStat2.Size_
// 	if int64(selfSize2) != selfSize {
// 		return "", fmt.Errorf("expected the size of %q in the image %q to be %d, got %d [Hint: set sha256 explicitly in the `# syntax = IMAGE:TAG@sha256:SHA256` line]",
// 			selfPath, selfImageRefStr, selfSize, selfSize2)
// 	}

// 	selfR2, err := refutil.NewRefFileReader(ctx, ref, selfPath)
// 	if err != nil {
// 		return "", err
// 	}
// 	selfDigest2, err := digest.Canonical.FromReader(selfR2)
// 	if err != nil {
// 		return "", err
// 	}

// 	if selfDigest2.String() != selfDigest.String() {
// 		return "", fmt.Errorf("expected the digest of %q in the image %q to be %s, got %s [Hint: set sha256 explicitly in the `# syntax = IMAGE:TAG@sha256:SHA256` line]",
// 			selfPath, selfImageRefStr, selfDigest, selfDigest2)
// 	}
// 	return selfPath, nil
// }

package cmd

import (
	"buildkit-gosh/pkg/constants"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"github.com/moby/buildkit/client/llb"
	"github.com/moby/buildkit/exporter/containerimage/exptypes"
	"github.com/moby/buildkit/frontend/gateway/client"
	"github.com/moby/buildkit/frontend/gateway/grpcclient"
	"github.com/moby/buildkit/solver/pb"

	"github.com/moby/buildkit/util/appcontext"
	"github.com/moby/buildkit/util/system"
	ocispecs "github.com/opencontainers/image-spec/specs-go/v1"
	"github.com/pkg/errors"
	"github.com/spf13/cobra"

	opentracing "github.com/opentracing/opentracing-go"
	"github.com/opentracing/opentracing-go/log"
	config "github.com/uber/jaeger-client-go/config"
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

func initJaeger(service string) (opentracing.Tracer, io.Closer) {
	cfg := &config.Configuration{
		ServiceName: service,
		Sampler: &config.SamplerConfig{
			Type:  "const",
			Param: 1,
		},
		Reporter: &config.ReporterConfig{
			LogSpans: true,
		},
	}
	tracer, closer, err := cfg.NewTracer()

	if err != nil {
		panic(fmt.Sprintf("ERROR: cannot init Jaeger: %v\n", err))
	}
	opentracing.SetGlobalTracer(tracer)
	return tracer, closer
}

func frontend(_ *cobra.Command, _ []string) error {
	_, closer := initJaeger("gosh-buildkit-frontend")
	defer closer.Close()

	span := opentracing.StartSpan("grpcclient")
	defer span.Finish()

	err := grpcclient.RunFromEnvironment(appcontext.Context(), frontendBuild())
	return err
}

func loadConfig(ctx context.Context, c client.Client) (*Config, error) {
	span := opentracing.StartSpan("loadConfig")
	defer span.Finish()

	filename := c.BuildOpts().Opts[keyFilename]
	span.LogKV("filename", filename)
	if filename == "" {
		filename = constants.DefaultConfigFile
	}

	name := "load config"
	if filename != constants.DefaultConfigFile {
		name += " from " + filename
	}

	configState := llb.Local(
		localConfigMount,
		llb.SessionID(c.BuildOpts().SessionID),
		llb.SharedKeyHint(sharedKeyHint),
		llb.WithCustomName("[docker-gosh frontend/loadConfig] "+name),
	)

	span.LogFields(log.Object("configState", configState))
	def, err := configState.Marshal(ctx)
	if err != nil {
		return nil, errors.Wrapf(err, "failed to marshal local source")
	}

	logf("[docker-gosh frontend/loadConfig] definition: %s", dumpp(def))

	var configFile []byte
	res, err := c.Solve(ctx, client.SolveRequest{
		Definition: def.ToPB(),
	})
	logf("[docker-gosh frontend/loadConfig] res: %s", dumpp(res))
	if err != nil {
		return nil, errors.Wrapf(err, "failed to resolve image config")
	}

	ref, err := res.SingleRef()
	if err != nil {
		return nil, err
	}
	logf("[docker-gosh frontend/loadConfig] ref: %s", dumpp(ref))

	configFile, err = ref.ReadFile(ctx, client.ReadRequest{
		Filename: filename,
	})
	logf("[docker-gosh frontend/loadConfig] ref: %s", dumpp(ref))
	if err != nil {
		return nil, errors.Wrapf(err, "failed to read image config "+filename)
	}

	return parseConfig(configFile)
}

func frontendBuild() client.BuildFunc {
	return func(ctx context.Context, c client.Client) (*client.Result, error) {
		logf("[docker-gosh frontend/build] client %#v %s %s", c, dumpp(c), dump(c.(grpcclient.GrpcClient)))
		opts := c.BuildOpts().Opts
		logf("[docker-gosh frontend/build] opts %T %s", opts, dumpp(opts))
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
		logf("[docker-gosh frontend/build] config: %s", dumpp(config))

		// init image
		logf("[docker-gosh frontend/build] start build image %s", config.Image)
		goshImage := llb.Image(
			config.Image,
			llb.IgnoreCache,
			llb.WithMetaResolver(c),
			llb.WithCustomName("[docker-gosh frontend/build] init test gosh image"),
		)

		// run steps
		for _, step := range config.Steps {
			logf("[docker-gosh frontend/build] step: %s", dump(step))
			if step.Run != nil {
				runOptions := []llb.RunOption{
					llb.IgnoreCache,
					// llb.AddMount(
					// 	"/var/gosh.sock",
					// 	llb.Scratch(),
					// ),
					llb.Network(pb.NetMode_NONE), // important: disable internet
					llb.WithCustomName("[docker-gosh frontend/build] " + step.Name),
					llb.Args(append(step.Run.Command, step.Run.Args...)),
				}
				logf("[docker-gosh frontend/build] run: %s", dumpp(runOptions))
				runSt := goshImage.Run(runOptions...)
				goshImage = runSt.Root()
				continue
			}
		}

		marshalOpts := []llb.ConstraintsOpt{
			llb.WithCaps(c.BuildOpts().Caps),
		}

		logf("[docker-gosh frontend/build] marshal context %s", dumpp(goshImage))
		def, err := goshImage.Marshal(ctx, marshalOpts...)
		if err != nil {
			return nil, err
		}
		logf("[docker-gosh frontend/build] definition: %s", dumpp(def))

		labels := filter(opts, labelPrefix)
		if _, ok := labels["WALLET_PUBLIC"]; !ok {
			labels["WALLET_PUBLIC"] = wallet_public
		}

		logf("[docker-gosh frontend/build] solve protobuf")
		res, err := c.Solve(ctx, client.SolveRequest{
			Definition: def.ToPB(),
		})
		if err != nil {
			return nil, errors.Wrapf(err, "failed to resolve dockerfile")
		}

		ref, err := res.SingleRef()
		if err != nil {
			return nil, err
		}
		logf("[docker-gosh frontend/build] ref: %#+v %s", ref, dumpp(ref))

		env := []string{
			"PATH=" + system.DefaultPathEnv(def.Constraints.Platform.OS),
		}

		imgConfig := ocispecs.ImageConfig{
			Labels:     labels,
			WorkingDir: "/",
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
		logf("[docker-gosh frontend/build] metadata %s", dumpp(res.Metadata))

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

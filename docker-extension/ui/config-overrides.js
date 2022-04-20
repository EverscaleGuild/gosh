const path = require('path');
const CopyPlugin = require('copy-webpack-plugin');

module.exports = function override(config, env) {
  const wasmExtensionRegExp = /\.wasm$/;

  config.resolve.extensions.push('.wasm');

  if (!config.plugins) {
    config.plugins = [];
  }

  config.plugins.push(
    new CopyPlugin(
    { 
      patterns: [{
        from: './node_modules/@eversdk/lib-web/eversdk.wasm',
        to: "assets/eversdk.wasm"
      }],
    })
  );

  config.module.rules.forEach(rule => {
    (rule.oneOf || []).forEach(oneOf => {
      if (oneOf.loader && oneOf.loader.indexOf('file-loader') >= 0) {
        // make file-loader ignore WASM files
        oneOf.exclude.push(wasmExtensionRegExp);
      }
    });
  });

  return config;
};
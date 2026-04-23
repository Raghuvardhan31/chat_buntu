const esbuild = require('esbuild');
const path = require('path');

esbuild.build({
  entryPoints: [path.join(__dirname, '../src/utils/ChatService.ts')],
  bundle: true,
  outfile: path.join(__dirname, '../public/js/ChatService.js'),
  format: 'esm',
  platform: 'browser',
  target: ['es2020'],
  sourcemap: true,
}).catch(() => process.exit(1));

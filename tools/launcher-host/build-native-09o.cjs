#!/usr/bin/env node
/* Build native Home for U09.09 operation-ui (e.g. 75U7KQ / V0000.09.09O.P0930).
 *
 * app-service exposes getCurrentShowApps("Launcher"), not getAppList — see
 * native-platform.js. The 75U8QTUK frontend shim is kept for vidaahub icons.
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { hash } = require('./native-trial.cjs');

const PARTS = [
  'native-platform.js',
  'free-my-tv-native.js',
  'free-my-tv-native-75u8qtuk.js',
  'native-entry.js'
];

function build(stockFile, output, expect) {
  assert.ok(expect, 'stock sha256 is required for 09.09O builds');
  const stock = fs.readFileSync(stockFile);
  assert.equal(hash(stock), expect, 'wrong 09.09O stock launcher revision');
  const license = fs.readFileSync(path.join(__dirname, 'third-party/free-my-tv/LICENSE'), 'utf8');
  const candidate = '/* ALVIDAA_FREE_MY_TV_NATIVE_09O_V1\n' + license + '\n*/\n' +
    stock + '\n;\n' +
    PARTS.map(file => fs.readFileSync(path.join(__dirname, file), 'utf8')).join('\n;\n');
  new vm.Script(candidate, { filename: 'native-candidate-09o.js' });
  if (output) {
    const target = path.resolve(output);
    const privateRoot = path.resolve(__dirname, '../../firmware') + path.sep;
    assert.ok(target.startsWith(privateRoot) || target.startsWith('/tmp/'),
      'vendor-containing output must stay private');
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, candidate, { mode: 0o600 });
    fs.chmodSync(target, 0o600);
  }
  return candidate;
}

if (require.main === module) {
  const [stock, output, expect] = process.argv.slice(2);
  assert.ok(stock && output && expect,
    'Usage: build-native-09o.cjs private-stock.js private-output.js expected-sha256');
  const candidate = build(stock, output, expect);
  const buf = Buffer.from(candidate);
  console.log('Built 09.09O native candidate: ' + buf.length + ' bytes; sha256 ' + hash(buf));
}
module.exports = { build, PARTS };
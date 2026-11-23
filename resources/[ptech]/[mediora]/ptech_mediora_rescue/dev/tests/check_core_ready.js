// Exercise the real Core browser startup when its NUI callback is registered late.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const element = {
    addEventListener() {},
    classList: {contains() {return false;}, add() {}, remove() {}, toggle() {}},
};
const timers = [];
let attempts = 0;
const window = {addEventListener() {}};
window.parent = window;
const context = vm.createContext({
    window,
    document: {getElementById: () => element},
    ResizeObserver: class {observe() {}},
    GetParentResourceName: () => 'ptech_mediora_core',
    fetch: async () => {
        attempts++;
        if (attempts === 1) return {ok: false};
        if (attempts === 2) throw new Error('NUI callback not registered yet');
        return {ok: true, json: async () => ({ok: true})};
    },
    setTimeout(fn, ms) {assert.equal(ms, 300);timers.push(fn);},
    console,
});
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8'), context);
(async () => {
    await new Promise(setImmediate);
    assert.equal(attempts, 1);
    assert.equal(timers.length, 1, 'failed first handshake must retry');
    timers.shift()();
    await new Promise(setImmediate);
    assert.equal(attempts, 2);
    assert.equal(timers.length, 1, 'network failure must retry');
    timers.shift()();
    await new Promise(setImmediate);
    assert.equal(attempts, 3);
    assert.equal(timers.length, 0, 'successful handshake must stop retries');
})().catch(error => {console.error(error);process.exitCode = 1;});

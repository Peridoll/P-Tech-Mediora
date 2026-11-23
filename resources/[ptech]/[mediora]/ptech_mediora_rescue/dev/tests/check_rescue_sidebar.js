// Feed panels from the real Rescue Lua script to Core's actual NUI state machine.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const input = JSON.parse(fs.readFileSync(0, 'utf8'));
const elements = new Map();
function element(id) {
    if (elements.has(id)) return elements.get(id);
    const value = {
        className: id === 'action-panel' ? 'action-panel is-hidden' : '',
        style: {setProperty() {}},
        addEventListener() {}, replaceChildren() {}, appendChild() {}, setAttribute() {},
        getBoundingClientRect() {return {left: 0, top: 0, right: 400, bottom: 200, width: 400, height: 200};},
    };
    const classes = () => new Set(value.className.split(/\s+/).filter(Boolean));
    value.classList = {
        contains(name) {return classes().has(name);},
        add(name) {const c = classes();c.add(name);value.className = [...c].join(' ');},
        remove(name) {const c = classes();c.delete(name);value.className = [...c].join(' ');},
        toggle(name, force) {
            const add = force === undefined ? !this.contains(name) : force;
            this[add ? 'add' : 'remove'](name);
        },
    };
    elements.set(id, value);
    return value;
}
const listeners = {};
const window = {innerWidth: 1920, innerHeight: 1080, addEventListener(name, fn) {listeners[name] = fn;}};
window.parent = window;
const context = vm.createContext({
    window,
    document: {getElementById: element, createElement: () => element('new-' + elements.size)},
    ResizeObserver: class {observe() {}},
    matchMedia: () => ({matches: true}),
    clearTimeout() {}, setTimeout() {}, console,
});
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8'), context);
const send = data => listeners.message({data});
const panel = element('action-panel');
// Sidebar starts minimized in Core, including when another module has registered a panel.
send({action: 'setPanel', id: 'marine', panel: {title: 'Other', text: 'other', startMinimized: true}});
assert(panel.classList.contains('is-minimized'));
for (const value of input) {
    send({action: 'setPanel', id: 'rescue', panel: value});
    assert(!panel.classList.contains('is-hidden'), 'Rescue panel must be visible');
    assert(!panel.classList.contains('is-minimized'), `${value.state} must open the sidebar`);
    assert.equal(element('title').textContent, '緊急離脱');
    assert.equal(element('message').textContent, value.text);
    assert(!element('track').classList.contains('is-hidden'), 'progress gauge must be visible');
}
send({action: 'removePanel', id: 'rescue'});
assert(panel.classList.contains('is-minimized'), 'restore original sidebar state after Rescue ends');

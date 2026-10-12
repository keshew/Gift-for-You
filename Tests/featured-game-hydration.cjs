// Run: node Tests/featured-game-hydration.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const swift = fs.readFileSync(process.argv[2] || path.join(__dirname,
  '../Gift Compass/App/CompassWebRoute.swift'), 'utf8');
const source = swift.slice(swift.indexOf('fileprivate static func featuredGameInterceptor'))
  .split('return """')[1].split('"""')[0]
  .replaceAll('\\(gameId)', 'tower')
  .replaceAll('\\(provider)', 'inout')
  .replaceAll('\\(preloadedGameJSON ?? "null")', JSON.stringify({gpGameId: 'tower', name: 'Tower'}))
  .replaceAll('\\(CompassFeaturedGameLoader.catalogAddress)', 'https://example.com/gameList');

let requests = 0;
class XHR {
  open() {}
  send() { requests++; throw new Error('Hydration must use the preloaded game'); }
  abort() {}
}
const context = vm.createContext({XMLHttpRequest: XHR, URL, Headers, Response, Event,
  location: {href: 'https://example.com/', reload() { throw new Error('Unexpected reload'); }},
  fetch: async () => { requests++; return new Response('{}'); }, dispatchEvent() {}});
context.window = context;
vm.runInContext(source, context);

// Names, shelf paths and Pinia hydration order verified in the site's lobby_v2
// store and app bundles. Card identities here are synthetic; no session data.
for (const storeName of ['mf-lobby_v2-games', 'mf-lobby-games', 'mfLobbyGames']) {
  const state = {[storeName]: {games: {
    'category/top': [{gpGameId: 'a'}, {gpGameId: 'b'}, {gpGameId: 'c'}],
    'category/exclusive': [{gpGameId: 'exclusive'}],
    'category/trendingnow': [{gpGameId: 'trending'}]
  }}};
  for (const envelope of [state, {data: state}]) {
    context.serializedState = JSON.stringify(envelope);
    const hydrated = vm.runInContext(`
      window._pinia = JSON.parse(serializedState);
      globalThis.pinia = {state: {value: window._pinia}};
      delete window._pinia;
      pinia.state.value;
    `, context);
    const games = (hydrated.data || hydrated)[storeName].games;
    assert.equal(games['category/top'][2].gpGameId, 'tower', storeName);
    assert.equal(games['category/top'][2].name, 'Tower');
    assert.equal(games['category/trendingnow'][0].gpGameId, 'tower');
    assert.equal(games['category/exclusive'][0].gpGameId, 'exclusive');
    context.serializedState = JSON.stringify(hydrated);
    const repeated = vm.runInContext('JSON.parse(serializedState)', context);
    const top = (repeated.data || repeated)[storeName].games['category/top'];
    assert.equal(top.filter(game => game.gpGameId === 'tower').length, 1);
    assert.equal(top[2].gpGameId, 'tower');
  }
}
assert.equal(requests, 0);
console.log('PASS: v2 and legacy hydration put Tower at Top[2] before rendering; no reload or request');

import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const distUrl = new URL('../dist/', import.meta.url);
const homePath = new URL('index.html', distUrl);
const termsPath = new URL('terms/index.html', distUrl);

const APP_STORE_URL = 'https://apps.apple.com/app/yandee/id6817918076';
const RUSTORE_URL = 'https://www.rustore.ru/catalog/app/com.yandee.yandee';
const CONTACT_EMAIL = 'babaliants@gmail.com';

const read = (url) => (existsSync(url) ? readFileSync(url, 'utf8') : '');

test('static site contains both requested routes', () => {
  assert.equal(existsSync(homePath), true, 'home route is missing');
  assert.equal(existsSync(termsPath), true, 'terms route is missing');
});

test('both routes expose language, viewport, and reciprocal navigation', () => {
  const home = read(homePath);
  const terms = read(termsPath);

  for (const [name, html] of [['home', home], ['terms', terms]]) {
    assert.match(html, /<html[^>]+lang="ru"/i, `${name} route needs Russian language metadata`);
    assert.match(html, /<meta[^>]+name="viewport"/i, `${name} route needs viewport metadata`);
  }

  assert.match(home, /href="\/terms"/, 'home route needs a link to terms');
  assert.match(terms, /href="\/"/, 'terms route needs a link to home');
});

test('home page contains the approved parent-facing product copy', () => {
  const home = read(homePath).replace(/<[^>]+>/g, '');

  assert.match(home, /Yandee — маленькая игра для больших открытий/);
  assert.match(home, /предмет/iu);
  assert.match(home, /назван/iu);
  assert.match(home, /без рекламы/iu);
});

test('home page links to both app stores', () => {
  const home = read(homePath);

  assert.ok(home.includes(`href="${APP_STORE_URL}"`), 'home route needs the App Store link');
  assert.ok(home.includes(`href="${RUSTORE_URL}"`), 'home route needs the RuStore link');
});

test('terms page states the confirmed privacy commitments', () => {
  const terms = read(termsPath);

  for (const phrase of ['персональн', 'реклам', 'аккаунт', 'покуп', 'аналитик', 'сервер']) {
    assert.match(terms, new RegExp(phrase, 'iu'), `terms page needs a ${phrase} statement`);
  }
});

test('terms page has a real contact and no pre-release placeholder', () => {
  const terms = read(termsPath);

  assert.ok(terms.includes(`mailto:${CONTACT_EMAIL}`), 'terms route needs a contact email');
  assert.doesNotMatch(terms, /будет добавлен/iu, 'terms route still has the contact placeholder');
});

test('every local asset referenced by the pages exists', () => {
  for (const html of [read(homePath), read(termsPath)]) {
    for (const [, path] of html.matchAll(/(?:src|href)="\/((?:assets\/|favicon|apple-touch)[^"#]*)"/g)) {
      assert.equal(existsSync(new URL(path, distUrl)), true, `missing asset: /${path}`);
    }
  }
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const homePath = new URL('../dist/index.html', import.meta.url);
const termsPath = new URL('../dist/terms/index.html', import.meta.url);

test('static site contains both requested routes', () => {
  assert.equal(existsSync(homePath), true, 'home route is missing');
  assert.equal(existsSync(termsPath), true, 'terms route is missing');
});

test('both routes expose language, viewport, and reciprocal navigation', () => {
  const home = existsSync(homePath) ? readFileSync(homePath, 'utf8') : '';
  const terms = existsSync(termsPath) ? readFileSync(termsPath, 'utf8') : '';

  for (const [name, html] of [['home', home], ['terms', terms]]) {
    assert.match(html, /<html[^>]+lang="ru"/i, `${name} route needs Russian language metadata`);
    assert.match(html, /<meta[^>]+name="viewport"/i, `${name} route needs viewport metadata`);
  }

  assert.match(home, /href="\/terms"/, 'home route needs a link to terms');
  assert.match(terms, /href="\//, 'terms route needs a link to home');
});

test('home page contains the approved parent-facing product copy', () => {
  const home = readFileSync(homePath, 'utf8');

  assert.match(home, /Yandee — маленькая игра для больших открытий/);
  assert.match(home, /предмет/iu);
  assert.match(home, /назван/iu);
  assert.match(home, /без рекламы/iu);
});

test('terms page states the confirmed privacy commitments', () => {
  const terms = readFileSync(termsPath, 'utf8');

  for (const phrase of ['персональн', 'реклам', 'аккаунт', 'покуп', 'аналитик', 'сервер']) {
    assert.match(terms, new RegExp(phrase, 'iu'), `terms page needs a ${phrase} statement`);
  }
});

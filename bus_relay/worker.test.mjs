// worker.js 점검(학교 서버는 흉내 낸다).  실행: node bus_relay/worker.test.mjs
import assert from 'node:assert/strict';
import worker from './worker.js';

// 업스트림 호출을 가짜로 대체한다.
let lastFetch = null;
globalThis.fetch = async (url, init) => {
  lastFetch = { url: String(url), headers: init && init.headers };
  return new Response('{"buses":[]}', { status: 200, headers: { 'Content-Type': 'application/json; charset=utf-8' } });
};
const env = { ALLOWED_ORIGINS: 'http://localhost:8765, https://me.github.io' };
const call = (path, origin, method = 'GET') =>
  worker.fetch(new Request('https://relay.example' + path, { method, headers: origin ? { Origin: origin, Referer: origin + '/' } : {} }), env);

let r = await call('/api/location/get', 'https://me.github.io');
assert.equal(r.status, 200);
assert.equal(r.headers.get('Access-Control-Allow-Origin'), 'https://me.github.io');
assert.equal(await r.text(), '{"buses":[]}');
assert.equal(lastFetch.url, 'https://bus.jejunu.ac.kr/api/location/get'); // 학교 버스 API를 그대로 받아 전달

r = await call('/api/location/get', 'https://evil.example');
assert.equal(r.headers.get('Access-Control-Allow-Origin'), null); // 허용 안 한 사이트는 브라우저가 막는다

assert.equal((await call('/api/location/get', 'https://me.github.io', 'OPTIONS')).status, 204);
assert.equal((await call('/other', 'https://me.github.io')).status, 404); // 버스 위치 말고는 전달 안 함
assert.equal((await call('/api/location/get', 'https://me.github.io', 'POST')).status, 405);

// 공지 목록: 페이지·분류 번호만 넘겨 학교 공지 페이지를 그대로 전달한다.
r = await call('/notice?page=2&category=320', 'https://me.github.io');
assert.equal(r.status, 200);
assert.equal(r.headers.get('Access-Control-Allow-Origin'), 'https://me.github.io');
assert.match(r.headers.get('Content-Type'), /text\/html/);
assert.equal(lastFetch.url, 'http://www.jejunu.ac.kr/ara/noticesurvey/outEvent.htm?page=2&category=320');
assert.ok(lastFetch.headers['User-Agent']); // 학교 홈페이지는 이름표(User-Agent)가 없으면 오류 페이지를 준다
await call('/notice', 'https://me.github.io');
assert.equal(lastFetch.url, 'http://www.jejunu.ac.kr/ara/noticesurvey/outEvent.htm?page=1');
await call('/notice?page=1;x&category=../../admin&act=download', 'https://me.github.io');
assert.equal(lastFetch.url, 'http://www.jejunu.ac.kr/ara/noticesurvey/outEvent.htm?page=1'); // 숫자 아닌 값·다른 인자는 버린다

r = await call('/menu?place=secondfixmenu', 'https://me.github.io');
assert.equal(r.status, 200);
assert.match(r.headers.get('Content-Type'), /text\/html/);
assert.equal(lastFetch.url, 'http://www.jejunu.ac.kr/camp/stud/foodmenu/secondfixmenu.htm');
assert.equal((await call('/menu?place=../../admin', 'https://me.github.io')).status, 404); // 정해진 식당 이름만 허용
assert.equal((await call('/menu', 'https://me.github.io')).status, 404);

globalThis.fetch = async () => { throw new Error('down'); };
r = await call('/api/location/get', 'https://me.github.io');
assert.equal(r.status, 502);
assert.equal(r.headers.get('Access-Control-Allow-Origin'), 'https://me.github.io');
console.log('bus_relay: all ok');

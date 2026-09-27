// map.html 안의 경로·화살표 계산 함수를 꺼내 검사한다.  실행: node test/map_html_check.mjs
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const html = readFileSync(new URL('../assets/web/map.html', import.meta.url), 'utf8');
// 인라인 스크립트가 여러 개(카카오 로더 등)일 수 있으니, 지도 로직이 담긴 블록을 고른다.
const src = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]).find((s) => s.includes('function drawBusRoute'));
// 지도 도형 흉내: 어떤 종류가 몇 개 지도에 올라가 있는지 센다
const onMap = { CustomOverlay: 0, Polyline: 0 };
const shape = (kind) => class { constructor() { this.kind = kind; } setMap(m) { onMap[kind] += m ? 1 : -1; } };
const sandbox = {
  kakao: { maps: { load() {}, event: { addListener() {} }, LatLng: class { constructor(lat, lng) { this.lat = lat; this.lng = lng; } getLat() { return this.lat; } getLng() { return this.lng; } },
    CustomOverlay: shape('CustomOverlay'), Polyline: shape('Polyline') } },
  document: { getElementById: () => null, querySelectorAll: () => [] },
  window: {}, navigator: {}, console,
};
const { distM, bearingDeg, splitRoute, makePath, projectOnPath, pointAt, buildRoutePaths, routePaths, updateBusMarkers, stationAlongs, legWindow, locateBus } = new Function(
  ...Object.keys(sandbox),
  src + '; mapKakaoMap = {}; return { distM, bearingDeg, splitRoute, makePath, projectOnPath, pointAt, buildRoutePaths, routePaths, updateBusMarkers, stationAlongs, legWindow, locateBus };',
)(...Object.values(sandbox));

// 웹은 srcdoc iframe(location.protocol = 'about:')이라 카카오 SDK가 http로 지도를 부른다 → https 페이지에서 차단됨. 자동 https 승격이 있어야 한다.
assert.match(html, /<meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">/);

const near = (a, b, tol = 1) => assert.ok(Math.abs(a - b) <= tol, `${a} ≠ ${b}`);
const LAT = 33.45, mPerLat = 110540, mPerLng = 111320 * Math.cos(LAT * Math.PI / 180);

// 방위각: 북=0, 동=90, 남=180, 서=270 / 거리
near(bearingDeg([126.56, LAT], [126.56, LAT + 0.01]), 0);
near(bearingDeg([126.56, LAT], [126.57, LAT]), 90);
near(bearingDeg([126.56, LAT], [126.56, LAT - 0.01]), 180);
near(bearingDeg([126.56, LAT], [126.55, LAT]), 270);
near(distM([126.56, LAT], [126.56, LAT + 0.001]), 111, 2);

// 북쪽으로 400m 가는 경로: 누적 거리, 가까운 지점 찾기, 거리→지점
const north400 = makePath([[126.56, LAT], [126.56, LAT + 200 / mPerLat], [126.56, LAT + 400 / mPerLat]]);
near(north400.cum[1], 200, 2); near(north400.cum[2], 400, 3);
const prj = projectOnPath(north400, [126.56 + 10 / mPerLng, LAT + 300 / mPerLat]); // 경로 300m 지점에서 동쪽 10m
near(prj.along, 300, 3); near(prj.dist, 10, 1);
const p100 = pointAt(north400, 100);
near(distM([126.56, LAT], [p100[0], p100[1]]), 100, 2); near(p100[2], 0);
const total = north400.cum[2];
near(pointAt(north400, total + 50)[1], pointAt(north400, 50)[1], 1e-9);      // 끝을 넘으면 처음으로(순환)
near(pointAt(north400, -50)[1], pointAt(north400, total - 50)[1], 1e-9);     // 시작 전은 끝쪽으로

// 진입 구간 / 순환 구간 / 복귀 구간 나누기, A노선 = 진입 + 순환(반대) + 복귀
const P = [[0, 0], [0, -1], [1, -1], [1, -2], [0.01, -1.01], [0.01, 0]];
const st = { '해대1호관': [0, -1], '해대1호관(서)': [0.01, -1.01] };
const parts = splitRoute(P, st);
assert.deepEqual(parts.out, [P[0], P[1]]);
assert.deepEqual(parts.loop, [P[1], P[2], P[3], P[4]]);
assert.deepEqual(parts.back, [P[4], P[5]]);
assert.deepEqual(splitRoute(P, {}), { out: [], loop: P, back: [] });  // 정류장을 못 찾으면 전체를 순환 구간으로
buildRoutePaths(P, st);
assert.deepEqual(routePaths.B.pts, P);
assert.deepEqual(routePaths.A.pts, [P[0], P[1], P[4], P[3], P[2], P[1], P[4], P[5]]);
// 순환 구간의 같은 지점에서 A와 B의 진행 방향은 정반대
const mid = [1, -1.5], onA = projectOnPath(routePaths.A, mid), onB = projectOnPath(routePaths.B, mid);
near((pointAt(routePaths.B, onB.along)[2] + 180) % 360, pointAt(routePaths.A, onA.along)[2], 1);

// 실제 노선과 닮은 축소 모형(m 단위 → 위경도): 정문에서 남쪽으로 내려가는 진입로와 15m 서쪽의 복귀로가 나란하고, 그 사이에 순환 구간
const xy = (x, y) => [126.56 + x / mPerLng, LAT + y / mPerLat];
const R = [xy(0, 0), xy(0, -200), xy(0, -400), xy(200, -400), xy(200, -600), xy(-15, -600), xy(-15, -400), xy(-15, -200), xy(-15, 0)];
const RS = { '정문': xy(-7, 5), '약대': xy(-10, -100), '해대1호관': xy(5, -400), '교양동': xy(200, -500), '해대1호관(서)': xy(-20, -400) };
buildRoutePaths(R, RS);
const RB = routePaths.B, rtotal = RB.cum[RB.cum.length - 1];
near(rtotal, 1615, 8);
// 정류장이 경로 위 어디에 있는지: 약대는 진입로(100m)와 복귀로(1515m) 두 곳에서 가깝다
const yak = stationAlongs(RB, RS['약대']);
assert.equal(yak.length, 2); near(yak[0], 100, 3); near(yak[1], 1515, 8);
assert.deepEqual(stationAlongs(RB, xy(500, 500)), []);                      // 경로에서 먼 지점은 없음
// 서버가 알려준 구간 → 경로 구간 [시작, 길이] (앞뒤 50m 여유)
const leg = legWindow(RB, '약대', '해대1호관');
near(leg[0], 100 - 50, 3); near(leg[1], 305 + 100, 8);
const home = legWindow(RB, '해대1호관(서)', '정문');                           // 순환: 끝(1615)이 처음(0)으로 이어진다
near(home[0], 1215 - 50, 8); near(home[1], 400 + 100, 8);
assert.equal(legWindow(RB, '없는정류장', '약대'), null);
assert.equal(legWindow(RB, '약대', '약대'), null);
// 진입로 위 버스가 GPS 오차로 복귀로에 더 가까워도, 구간을 알면 진입로에 붙는다 (이게 화살표 뒤집힘의 원인이었다)
const wobble = xy(-9, -150);                                                 // 복귀로까지 6m, 진입로까지 9m
near(projectOnPath(RB, wobble).along, 1465, 8);                              // 구간 정보 없이는 복귀로
near(projectOnPath(RB, wobble, leg).along, 150, 3);                          // 구간 안에서는 진입로
near(projectOnPath(RB, xy(0, -70), leg).along, 70, 3);                       // 정류장 50m 앞(여유 구간)도 그대로
const clamped = projectOnPath(RB, xy(0, -20), leg);                          // 구간 밖이면 구간 끝으로 붙이고 거리는 그만큼 커진다
near(clamped.along, 50, 3); near(clamped.dist, 30, 3);
buildRoutePaths(P, st);                                                      // 아래 검사는 원래 경로로

// 회차로(해대4호관처럼 들어갔다 되돌아 나오는 길): 한 구간 안에 동쪽길과 14m 아래 서쪽길이 나란하다.
// 구간 정보로는 못 가르므로, 버스가 실제로 움직인 방위(heading)와 맞는 길을 고른다.
const H = makePath([xy(0, 0), xy(200, 0), xy(200, -7), xy(200, -14), xy(0, -14)]);
const between = xy(100, -9);                                                   // 서쪽길까지 5m, 동쪽길까지 9m
near(projectOnPath(H, between).along, 314, 3);                                   // 방위를 모르면 가까운 서쪽길
near(projectOnPath(H, between, null, 90).along, 100, 3);                         // 동쪽으로 가는 중 → 동쪽길
near(projectOnPath(H, between, null, 270).along, 314, 3);                        // 서쪽으로 가는 중 → 서쪽길
const bd = {};
near(locateBus(bd, H, xy(60, -9)).along, 354, 3);                            // 첫 위치: 아직 방위 모름
near(locateBus(bd, H, xy(100, -9)).along, 100, 3);                           // 40m 동진 → 방위 생김 → 동쪽길
near(locateBus(bd, H, xy(110, -9)).along, 110, 3);                           // 10m는 GPS 흔들림일 수 있어 방위 유지
near(locateBus(bd, H, xy(170, -9)).along, 170, 3);
near(locateBus(bd, H, xy(130, -9)).along, 284, 3);                           // 되돌아 40m 서진 → 서쪽길

// 버스가 움직여도 지나온 길 흔적(선·점)은 남지 않는다: 버스 표시 1개 + 화살표 최대 4개만
for (const t of [0.2, 0.5, 0.8]) updateBusMarkers([{ busId: 'B', latitude: -t, longitude: 0 }]);
assert.equal(onMap.Polyline, 0);
assert.ok(onMap.CustomOverlay >= 1 && onMap.CustomOverlay <= 5, `overlays on map: ${onMap.CustomOverlay}`);

console.log('map_html_check: all ok');

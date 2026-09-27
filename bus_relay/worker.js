// 중간 서버(Cloudflare Worker): 웹 버전이 학교 버스 API·공지 목록·학식 메뉴를 쓸 수 있게 대신 받아 전달한다.
// 브라우저는 학교 서버에서 직접 못 받으므로(허용 표시 없음), 이 서버가 받아서 허용 표시를 붙여 넘긴다.
const UPSTREAM = 'https://bus.jejunu.ac.kr/api/location/get';
// 학교 홈페이지는 HTTPS 중간 인증서를 빠뜨려 Worker의 HTTPS 요청이 실패한다(브라우저만 알아서 보충함).
// 공개된 공지 목록·식단표만 읽어 오는 것이라 HTTP로 받는다. 학교가 인증서를 고치면 https로 바꾸면 된다.
const NOTICE = 'http://www.jejunu.ac.kr/ara/noticesurvey/outEvent.htm';
const MENU = 'http://www.jejunu.ac.kr/camp/stud/foodmenu/';
const CAFETERIAS = ['firstfixmenu', 'secondfixmenu', 'fixfirst', 'fixmenu', 'fifthmenu'];

// 요청 경로 → 학교 주소와 응답 형식. 공지는 페이지·분류 번호(숫자)만 넘기고 나머지 인자는 버린다.
function upstreamFor(url) {
  if (url.pathname === '/api/location/get') return [UPSTREAM, 'application/json; charset=utf-8'];
  if (url.pathname === '/notice') {
    const num = (k) => (/^\d{1,6}$/.test(url.searchParams.get(k) || '') ? url.searchParams.get(k) : null);
    const cat = num('category');
    return [`${NOTICE}?page=${num('page') || 1}${cat ? `&category=${cat}` : ''}`, 'text/html; charset=utf-8'];
  }
  if (url.pathname === '/menu' && CAFETERIAS.includes(url.searchParams.get('place'))) {
    return [`${MENU}${url.searchParams.get('place')}.htm`, 'text/html; charset=utf-8'];
  }
  return null;
}

function corsFor(origin, allowed) {
  return allowed
    ? { 'Access-Control-Allow-Origin': origin, Vary: 'Origin' }
    : { Vary: 'Origin' };
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';
    const allowed = (env.ALLOWED_ORIGINS || '').split(',').map((s) => s.trim()).includes(origin);
    const cors = corsFor(origin, allowed);

    const target = upstreamFor(new URL(request.url));
    if (!target) return new Response('Not found', { status: 404, headers: cors });
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: { ...cors, 'Access-Control-Allow-Methods': 'GET', 'Access-Control-Allow-Headers': 'Content-Type' },
      });
    }
    if (request.method !== 'GET') return new Response('Method not allowed', { status: 405, headers: cors });

    try {
      // 학교 홈페이지는 User-Agent가 없으면 오류 페이지를 준다.
      const upstream = await fetch(target[0], { headers: { 'User-Agent': 'Mozilla/5.0 (compatible; jejunu-bus-relay)' } });
      return new Response(upstream.body, {
        status: upstream.status,
        headers: { ...cors, 'Content-Type': target[1], 'Cache-Control': 'no-store' },
      });
    } catch (e) {
      console.error("upstream fetch failed:", target[0], e && e.message);
      return new Response('{"error":"upstream unreachable"}', { status: 502, headers: { ...cors, 'Content-Type': 'application/json' } });
    }
  },
};

const admin = require('firebase-admin');
const sa = require('./serviceAccountKey.json');
const axios = require('axios');
const {parseStringPromise} = require('xml2js');
const crypto = require('crypto');

admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const FEEDS = [
  {url: 'https://www.hira.or.kr/cms/policy/03/01/01/01/act_notice.xml', topic: 'act', filterKeyword: null},
  {url: 'https://www.hira.or.kr/cms/inform/01/notice.xml', topic: 'notice', filterKeyword: '치과'},
  {url: 'https://www.hira.or.kr/cms/policy/03/01/01/02/care_notice.xml', topic: 'material', filterKeyword: null},
  {url: 'https://www.hira.or.kr/cms/policy/03/01/04/02/request.xml', topic: 'billing', filterKeyword: null},
];

function parseDate(s) {
  const t = (s||'').trim();
  const m = /^(\d{4})(\d{2})(\d{2})\s+(\d{2}):(\d{2}):(\d{2})$/.exec(t);
  if (m) return new Date(m[1]+'-'+m[2]+'-'+m[3]+'T'+m[4]+':'+m[5]+':'+m[6]+'+09:00');
  const d = new Date(t);
  return isNaN(d.getTime()) ? new Date() : d;
}

function htmlToPlainText(html) {
  if (!html) return '';
  return html.replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&').replace(/&quot;/g,'"').replace(/&#xD;\n?/g,'\n').replace(/<!\[CDATA\[/gi,'').replace(/\]\]>/g,'').replace(/<br\s*\/?>/gi,'\n').replace(/<\/p>/gi,'\n').replace(/<\/div>/gi,'\n').replace(/<\/li>/gi,'\n').replace(/<\/tr>/gi,'\n').replace(/<[^>]+>/g,'').replace(/&nbsp;/g,' ').replace(/[ \t]+/g,' ').replace(/\n{3,}/g,'\n\n').trim().slice(0,3000);
}

function absolutize(link) {
  const t = (link||'').trim();
  if (!t) return t;
  if (/^https?:\/\//i.test(t)) return t;
  return t.startsWith('/') ? 'https://www.hira.or.kr'+t : 'https://www.hira.or.kr/'+t;
}

function extractEffDate(text) {
  const patterns = [/시행일[자]?\s*[:：]\s*(\d{4})[.\-\/\s](\d{1,2})[.\-\/\s](\d{1,2})/, /(\d{4})[.\-\/](\d{1,2})[.\-\/](\d{1,2})[.\s]*시행/];
  for (const re of patterns) {
    const m = re.exec(text);
    if (m) {
      const d = new Date(m[1]+'-'+m[2].padStart(2,'0')+'-'+m[3].padStart(2,'0')+'T00:00:00+09:00');
      if (!isNaN(d.getTime())) return admin.firestore.Timestamp.fromDate(d);
    }
  }
  return null;
}

function calcScore(title) {
  const strong = ['치과','구강','치주','임플란트','교정','보철','근관','스케일링','치석','마취'];
  const med = ['수가','급여','행위','청구','기준','고시','산정','인정','심사'];
  const weak = ['보험','평가','공단','제도','개정'];
  let score = 0; const kws = [];
  for (const k of strong) if (title.includes(k)) { score+=30; kws.push(k); }
  for (const k of med) if (title.includes(k)) { score+=15; kws.push(k); }
  for (const k of weak) if (title.includes(k)) { score+=5; kws.push(k); }
  return {score: Math.min(score,100), keywords: kws};
}

function getLevel(s) { if(s>=70) return 'HIGH'; if(s>=40) return 'MID'; return 'LOW'; }

function getHints(title) {
  const h = [];
  if (/청구|산정|행위|코드|수가/.test(title)) h.push('청구팀 확인 필요');
  if (/기준|인정|산정기준/.test(title)) h.push('차트/기록 방식 변경 여부 확인');
  if (/서식|양식|제출/.test(title)) h.push('서식 업데이트 필요');
  if (/치과|구강|스케일링|치주/.test(title)) h.push('치과 항목 영향 가능');
  if (h.length===0) h.push('원문 링크로 핵심 문단만 확인');
  return h.slice(0,3);
}

async function run() {
  const threeMonthsAgo = new Date();
  threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);
  let total = 0;

  for (const {url, topic, filterKeyword} of FEEDS) {
    const resp = await axios.get(url, {timeout:20000});
    const parsed = await parseStringPromise(resp.data);
    const items = parsed.rss?.channel?.[0]?.item || [];
    let feedCount = 0;

    for (const item of items) {
      const title = item.title?.[0] || '';
      const rawLink = item.link?.[0] || '';
      const link = absolutize(rawLink);
      const pubDate = item.pubDate?.[0] || '';
      const descHtml = item.description?.[0] || '';
      if (!title || !link) continue;

      const publishedDate = parseDate(pubDate);
      if (publishedDate < threeMonthsAgo) continue;

      const body = htmlToPlainText(descHtml);
      if (filterKeyword && !title.includes(filterKeyword) && !body.includes(filterKeyword)) continue;

      const docId = crypto.createHash('sha1').update(link).digest('hex');
      const {score, keywords} = calcScore(title);

      await db.collection('content_hira_updates').doc(docId).set({
        title, link,
        publishedAt: admin.firestore.Timestamp.fromDate(publishedDate),
        topic,
        impactScore: score,
        impactLevel: getLevel(score),
        keywords,
        actionHints: getHints(title),
        fetchedAt: admin.firestore.Timestamp.now(),
        body,
        effectiveDate: extractEffDate(body),
      });
      feedCount++;
    }
    console.log(topic + ': ' + feedCount + ' docs saved');
    total += feedCount;
  }
  console.log('Total: ' + total + ' docs saved');
}
run().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });

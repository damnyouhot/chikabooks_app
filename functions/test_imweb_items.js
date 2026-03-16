/**
 * prod-orders의 items 내부 구조 확인
 */
const admin = require("firebase-admin");
const axios = require("axios");
const serviceAccount = require("../tools/serviceAccountKey.json");

async function main() {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();

  const keysSnap = await db.collection("api_keys").doc("imweb_keys").get();
  const { key, secret_key } = keysSnap.data();
  const authRes = await axios.get(`https://api.imweb.me/v2/auth?key=${key}&secret=${secret_key}`);
  const headers = { "access-token": authRes.data.access_token };

  const ORDER_NO = "202603162131575";
  const prodRes = await axios.get(
    `https://api.imweb.me/v2/shop/orders/${ORDER_NO}/prod-orders`,
    { headers }
  );

  const list = extractList(prodRes.data);
  
  console.log(`총 ${list.length}개의 prod-order\n`);

  list.forEach((po, i) => {
    console.log(`━━━ prod-order [${i}] ━━━`);
    console.log(`  order_no: ${po.order_no}`);
    console.log(`  status: ${po.status}`);
    
    const items = po.items;
    if (Array.isArray(items)) {
      items.forEach((item, j) => {
        console.log(`\n  📘 item [${j}]:`);
        // 모든 키-값 출력
        for (const [k, v] of Object.entries(item)) {
          const val = typeof v === "object" ? JSON.stringify(v).substring(0, 200) : v;
          console.log(`     ${k}: ${val}`);
        }
      });
    } else if (items && typeof items === "object") {
      // items가 object인 경우 (키가 상품코드?)
      for (const [itemKey, itemVal] of Object.entries(items)) {
        console.log(`\n  📘 item key="${itemKey}":`);
        if (typeof itemVal === "object") {
          for (const [k, v] of Object.entries(itemVal)) {
            const val = typeof v === "object" ? JSON.stringify(v).substring(0, 200) : v;
            console.log(`     ${k}: ${val}`);
          }
        }
      }
    } else {
      console.log(`  items: ${JSON.stringify(items).substring(0, 500)}`);
    }
  });
}

function extractList(response) {
  const d = response?.data;
  if (Array.isArray(d)) return d;
  if (d && typeof d === "object") {
    if (Array.isArray(d.list)) return d.list;
  }
  return [];
}

main().then(() => process.exit(0)).catch((e) => {
  console.error("❌:", e.message);
  process.exit(1);
});



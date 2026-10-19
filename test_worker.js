const url = 'https://biblia-ia-esboco.nivaldo-nilngn.workers.dev';
async function test() {
  const resp = await fetch(url, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      action: 'getDictionaryList', // Just a guess
      version: 'STRONG (BR)'
    })
  });
  const data = await resp.json();
  console.log(JSON.stringify(data, null, 2));
}
test();

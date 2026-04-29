const { Client } = require('pg');
const http = require('http');

const c = new Client({
  host: 'localhost', port: 5432,
  user: 'postgres', password: '8123',
  database: 'cbhi_db',
});

c.connect()
  .then(() => c.query("SELECT id FROM users LIMIT 1"))
  .then(r => {
    if (r.rows.length === 0) { console.log('No users in DB'); c.end(); return; }
    const userId = r.rows[0].id;
    console.log('Using userId:', userId);
    c.end();
    submitIndigent(userId);
  })
  .catch(e => { console.error('DB error:', e.message); c.end(); });

function submitIndigent(userId) {
  const payload = JSON.stringify({
    userId,
    income: 500,
    employmentStatus: 'unemployed',
    familySize: 6,
    hasProperty: false,
    disabilityStatus: false,
    documents: [],
  });

  const req = http.request('http://localhost:3000/api/v1/indigent/apply', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) },
  }, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      console.log('Status:', res.statusCode);
      try { console.log('Body:', JSON.stringify(JSON.parse(data), null, 2)); } catch { console.log('Body:', data); }
    });
  });
  req.on('error', e => console.log('Connection error:', e.message));
  req.write(payload);
  req.end();
}

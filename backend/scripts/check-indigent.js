const { Client } = require('pg');
const c = new Client({
  host: 'localhost', port: 5432,
  user: 'postgres', password: '8123',
  database: 'cbhi_db',
});
c.connect()
  .then(() => c.query('SELECT id, status, score, reason, "userId" FROM indigent_applications'))
  .then(r => { console.log('Indigent rows:', r.rows.length); r.rows.forEach(x => console.log(x.status, x.score, x.reason, x.userId)); c.end(); })
  .catch(e => { console.error(e.message); c.end(); });

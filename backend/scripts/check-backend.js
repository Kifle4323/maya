const http = require('http');
const req = http.get('http://localhost:3000/api/v1/health', (res) => {
  let data = '';
  res.on('data', c => data += c);
  res.on('end', () => console.log('Backend status:', res.statusCode, data));
});
req.on('error', e => console.log('Backend NOT running:', e.message));
req.setTimeout(5000, () => { console.log('Backend timeout'); req.destroy(); });

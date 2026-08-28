const net = require('net');

const host = String(process.argv[2] || '');
const port = Number(process.argv[3]);
const localPort = Number(process.argv[4]);
const validIp = /^(?:\d{1,3}\.){3}\d{1,3}$/.test(host) &&
  host.split('.').every(part => Number(part) >= 0 && Number(part) <= 255);

if (!validIp || !Number.isInteger(port) || !Number.isInteger(localPort) ||
    port < 1 || port > 65535 || localPort < 1 || localPort > 65535) {
  process.exit(2);
}

const server = net.createServer(client => {
  const upstream = net.createConnection({ host, port });
  client.setNoDelay(true);
  upstream.setNoDelay(true);
  client.pipe(upstream);
  upstream.pipe(client);

  const closePair = () => {
    client.destroy();
    upstream.destroy();
  };
  client.once('error', closePair);
  upstream.once('error', closePair);
});

server.listen(localPort, '127.0.0.1');

#!/usr/bin/env bash
# Recreates the intentionally vulnerable sample app in the eval workspace.
set -euo pipefail
mkdir -p "sample-app/api"
cat > "sample-app/api/.env" <<'FIXTURE_EOF'
DATABASE_URL=postgres://postgres:postgres@db.example.com:5432/app
JWT_SECRET=secret
STRIPE_SECRET_KEY=sk_live_FAKE_EXAMPLE_NOT_A_REAL_KEY
FIXTURE_EOF
mkdir -p "sample-app/api"
cat > "sample-app/api/package.json" <<'FIXTURE_EOF'
{ "name": "api", "dependencies": { "express": "4.17.1", "cors": "2.8.5", "helmet": "7.1.0", "jsonwebtoken": "8.5.1", "multer": "1.4.2", "pg": "8.11.3", "node-fetch": "2.6.7" } }
FIXTURE_EOF
mkdir -p "sample-app/api"
cat > "sample-app/api/server.js" <<'FIXTURE_EOF'
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const multer = require('multer');
const fetch = require('node-fetch');
const { Pool } = require('pg');

const app = express();
const db = new Pool({ connectionString: process.env.DATABASE_URL });
app.use(helmet());
app.use(cors({ origin: true, credentials: true }));
app.use(express.json());

const upload = multer({ storage: multer.diskStorage({
  destination: 'public/uploads',
  filename: (req, file, cb) => cb(null, file.originalname),
}) });

function auth(req, res, next) {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  try { req.user = jwt.verify(token, process.env.JWT_SECRET); next(); }
  catch { res.status(401).json({ error: 'unauthorized' }); }
}

app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const { rows } = await db.query('SELECT * FROM users WHERE email = $1', [email]);
  if (!rows[0]) return res.status(404).json({ error: 'User not found' });
  const hash = crypto.createHash('md5').update(password).digest('hex');
  if (hash !== rows[0].password_hash) return res.status(401).json({ error: 'Wrong password' });
  const token = jwt.sign({ id: rows[0].id, role: rows[0].role }, process.env.JWT_SECRET);
  res.json({ token });
});

app.get('/orders/:id', auth, async (req, res) => {
  const { rows } = await db.query('SELECT * FROM orders WHERE id = ' + req.params.id);
  res.json(rows[0]);
});

app.get('/orders', auth, async (req, res) => {
  const sort = req.query.sort || 'created_at';
  const { rows } = await db.query(`SELECT * FROM orders WHERE user_id = $1 ORDER BY ${sort}`, [req.user.id]);
  res.json(rows);
});

app.put('/users/me', auth, async (req, res) => {
  const fields = Object.keys(req.body).map((k, i) => `${k} = $${i + 2}`).join(', ');
  await db.query(`UPDATE users SET ${fields} WHERE id = $1`, [req.user.id, ...Object.values(req.body)]);
  res.json({ ok: true });
});

app.delete('/admin/users/:id', auth, async (req, res) => {
  if (req.headers['x-role'] !== 'admin') return res.status(403).end();
  await db.query('DELETE FROM users WHERE id = $1', [req.params.id]);
  res.json({ ok: true });
});

app.post('/avatar', auth, upload.single('file'), (req, res) => res.json({ url: '/uploads/' + req.file.originalname }));

app.get('/preview', async (req, res) => {
  const r = await fetch(req.query.url);
  res.send(await r.text());
});

app.get('/health', async (req, res) => res.json({ ok: true, db: process.env.DATABASE_URL, node: process.version }));

app.use((err, req, res, next) => res.status(500).json({ error: err.message, stack: err.stack }));

app.listen(3000);
FIXTURE_EOF
mkdir -p "sample-app/web"
cat > "sample-app/web/.env.local" <<'FIXTURE_EOF'
NEXT_PUBLIC_API_URL=http://api.example.com
NEXT_PUBLIC_OPENAI_KEY=sk-proj-FAKE_EXAMPLE_NOT_A_REAL_KEY
FIXTURE_EOF
mkdir -p "sample-app/web/app"
cat > "sample-app/web/app/layout.tsx" <<'FIXTURE_EOF'
import Script from 'next/script';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        <Script src="https://www.googletagmanager.com/gtag/js?id=G-XXXX" />
        <Script id="ga">{`window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments)}gtag('js',new Date());gtag('config','G-XXXX');`}</Script>
        {children}
        <footer>© 2026 Acme</footer>
      </body>
    </html>
  );
}
FIXTURE_EOF
mkdir -p "sample-app/web/app/login"
cat > "sample-app/web/app/login/page.tsx" <<'FIXTURE_EOF'
'use client';
import { useState } from 'react';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  async function submit(e: React.FormEvent) {
    e.preventDefault();
    const r = await fetch(process.env.NEXT_PUBLIC_API_URL + '/login', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const data = await r.json();
    if (data.error) alert(data.error);
    localStorage.setItem('token', data.token);
    console.log('logged in', data);
    window.location.href = '/';
  }
  return (
    <form onSubmit={submit}>
      <input placeholder="Email" onChange={e => setEmail(e.target.value)} />
      <input type="password" placeholder="Password" onChange={e => setPassword(e.target.value)} />
      <button>Login</button>
    </form>
  );
}
FIXTURE_EOF
mkdir -p "sample-app/web/app"
cat > "sample-app/web/app/page.tsx" <<'FIXTURE_EOF'
export default function Home() {
  return (
    <main style={{ width: 1200 }}>
      <img src="/hero.png" />
      <h1>Acme</h1>
      <p>Best product ever.</p>
    </main>
  );
}
FIXTURE_EOF
mkdir -p "sample-app/web/app/post/[id]"
cat > "sample-app/web/app/post/[id]/page.tsx" <<'FIXTURE_EOF'
export default async function Post({ params }: { params: { id: string } }) {
  const post = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/posts/${params.id}`).then(r => r.json());
  const ai = await fetch('https://api.openai.com/v1/models', { headers: { Authorization: `Bearer ${process.env.NEXT_PUBLIC_OPENAI_KEY}` } });
  return (
    <article>
      <h1>{post.title}</h1>
      <div dangerouslySetInnerHTML={{ __html: post.body }} />
      <a href={post.authorWebsite} target="_blank">Author</a>
    </article>
  );
}
FIXTURE_EOF
mkdir -p "sample-app/web"
cat > "sample-app/web/next.config.js" <<'FIXTURE_EOF'
module.exports = { productionBrowserSourceMaps: true };
FIXTURE_EOF
mkdir -p "sample-app/web"
cat > "sample-app/web/package.json" <<'FIXTURE_EOF'
{ "name": "web", "dependencies": { "next": "14.2.3", "react": "18.3.1", "react-dom": "18.3.1" } }
FIXTURE_EOF
mkdir -p "sample-app/web/public"
cat > "sample-app/web/public/robots.txt" <<'FIXTURE_EOF'
User-agent: *
Disallow: /
Disallow: /admin-secret-panel
FIXTURE_EOF

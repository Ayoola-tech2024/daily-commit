const fs = require('fs');
const path = require('path');
const { marked } = require('marked');

const ROOT = path.resolve(__dirname, '..');
const CONTENT_DIR = path.join(ROOT, 'content');
const DATA_DIR = path.join(ROOT, 'src', 'data');
const ASSETS_DIR = path.join(ROOT, 'assets');
const SITE_DIR = path.join(ROOT, '_site');
const LAYOUT_FILE = path.join(ROOT, '_layouts', 'default.html');

const config = {
  title: 'Daily Build Journal',
  description: 'One commit, every day',
  author: 'Ayoola Damisile',
  baseurl: process.env.VERCEL_ENV === 'production' ? '' : ''
};

function readJSON(p) {
  return JSON.parse(fs.readFileSync(p, 'utf-8'));
}

function renderTemplate(content, vars) {
  let h = content;
  for (const [k, v] of Object.entries(vars)) {
    const re = new RegExp(`{{ ${k} }}`, 'g');
    h = h.replace(re, v);
    const re2 = new RegExp(`{{ ${k} \\| default:.*? }}`, 'g');
    h = h.replace(re2, v);
    const re3 = new RegExp(`{{ site\\.${k} }}`, 'g');
    h = h.replace(re3, v);
    const re4 = new RegExp(`{{ site\\.${k} \\| default:.*? }}`, 'g');
    h = h.replace(re4, v);
  }
  h = h.replace(/\{\{ site\.time \| date: '%Y' \}\}/g, String(new Date().getFullYear()));
  h = h.replace(/\{\{ page\.title \| default: site\.title \}\}/g, vars.title || config.title);
  h = h.replace(/\{\{ '\/assets\/css\/style\.css' \| relative_url \}\}/g, './assets/css/style.css');
  h = h.replace(/\{\{ site\.baseurl \}\}\//g, `${config.baseurl}/`);
  h = h.replace(/\{\{ site\.baseurl \}\}/g, config.baseurl);
  return h;
}

function build() {
  if (!fs.existsSync(CONTENT_DIR)) {
    fs.mkdirSync(CONTENT_DIR, { recursive: true });
  }

  const layout = fs.readFileSync(LAYOUT_FILE, 'utf-8');

  const outDirs = [
    path.join(SITE_DIR, 'content'),
    path.join(SITE_DIR, 'assets', 'css')
  ];
  for (const d of outDirs) {
    fs.mkdirSync(d, { recursive: true });
  }

  fs.cpSync(path.join(ASSETS_DIR, 'css', 'style.css'), path.join(SITE_DIR, 'assets', 'css', 'style.css'));

  const layoutVars = {
    title: config.title,
    description: config.description,
    author: config.author
  };
  const layoutHtml = renderTemplate(layout, layoutVars);

  function stripFrontMatter(md) {
    return md.replace(/^---[\s\S]*?---\n*/, '');
  }

  const contentFiles = fs.readdirSync(CONTENT_DIR)
    .filter(f => f.endsWith('.md'))
    .sort();

  for (const file of contentFiles) {
    const raw = fs.readFileSync(path.join(CONTENT_DIR, file), 'utf-8');
    const md = stripFrontMatter(raw)
      .replace(/\.md\)/g, '.html)')
      .replace(/\(\/daily-commit\/\)/g, '(/)');
    const title = md.match(/^# (.+)$/m)?.[1] || file.replace('.md', '');
    const bodyHtml = marked(md);
    const pageLayout = layoutHtml.replace(/\{\{ content \}\}/g, bodyHtml);
    const finalHtml = pageLayout.replace(/\{\{ page\.title \| default: site\.title \}\}/g, title);
    const htmlFile = file.replace('.md', '.html');
    fs.writeFileSync(path.join(SITE_DIR, 'content', htmlFile), finalHtml);
  }

  const indexRaw = fs.readFileSync(path.join(ROOT, 'index.md'), 'utf-8');
  const indexMd = stripFrontMatter(indexRaw)
    .replace(/\.md\)/g, '.html)')
    .replace(/\(\/daily-commit\/\)/g, '(/)');
  const indexTitle = indexMd.match(/^# (.+)$/m)?.[1] || config.title;
  const indexBody = marked(indexMd);
  let indexHtml = layoutHtml.replace(/\{\{ content \}\}/g, indexBody);
  indexHtml = indexHtml.replace(/\{\{ page\.title \| default: site\.title \}\}/g, indexTitle);
  fs.writeFileSync(path.join(SITE_DIR, 'index.html'), indexHtml);

  const contentEntries = contentFiles
    .map(f => {
      const md = fs.readFileSync(path.join(CONTENT_DIR, f), 'utf-8');
      const title = md.match(/## Build #\d+: (.+)$/m)?.[1] || f.replace('.md', '');
      const date = f.replace('.md', '');
      return { date, title, file: f.replace('.md', '.html') };
    })
    .reverse();

  console.log(`Built ${contentEntries.length} content pages + index`);
  console.log('✅ Site built to _site/');
}

build();

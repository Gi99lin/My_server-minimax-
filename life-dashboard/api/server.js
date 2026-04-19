/**
 * Life Dashboard API — Express server
 *
 * POST /api/entry  — saves mood, food, note to metrics.json + Obsidian daily note
 * GET  /api/forecast — returns 7-day weather forecast
 */

import express from 'express';
import cors from 'cors';
import { readFileSync, writeFileSync, existsSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const app = express();
app.use(cors());
app.use(express.json());

// ---- Config ----
const VAULT_PATH = process.env.VAULT_PATH || '/Users/ivanakimkin/Documents/1';
const METRICS_PATH = process.env.METRICS_PATH || join(__dirname, '..', 'data', 'metrics.json');

// ---- Helpers ----

function loadMetrics() {
  try {
    return JSON.parse(readFileSync(METRICS_PATH, 'utf-8'));
  } catch {
    return { days: {}, meta: {} };
  }
}

function saveMetrics(data) {
  data.meta.last_updated = new Date().toISOString();
  writeFileSync(METRICS_PATH, JSON.stringify(data, null, 2), 'utf-8');
}

/**
 * Parse YAML frontmatter from an Obsidian daily note file.
 * Returns { mood, food_before_20, sleep_goal, project_work } or null.
 */
function parseFrontmatter(filePath) {
  try {
    const content = readFileSync(filePath, 'utf-8');
    const match = content.match(/^---\s*\n([\s\S]*?)\n---/);
    if (!match) return null;

    const result = {};
    for (const line of match[1].split('\n')) {
      const colonIdx = line.indexOf(':');
      if (colonIdx === -1) continue;
      const key = line.slice(0, colonIdx).trim();
      const val = line.slice(colonIdx + 1).trim().replace(/^["']|["']$/g, '');

      if (key === 'mood' && val && val !== '') {
        const num = parseInt(val);
        if (!isNaN(num)) result.mood = num;
      } else if (key === 'Питание_до_20') {
        result.food_before_20 = val.toLowerCase() === 'true';
      } else if (key === 'Сон_8ч_и_до_9') {
        result.sleep_goal = val.toLowerCase() === 'true';
      } else if (key === 'Работа_над_проектом') {
        result.project_work = val.toLowerCase() === 'true';
      }
    }
    return Object.keys(result).length ? result : null;
  } catch {
    return null;
  }
}

/**
 * Sync recent daily notes from Obsidian vault into metrics.json.
 * Scans last `daysBack` days of daily notes and updates manual fields.
 */
function syncFromVault(daysBack = 14) {
  const metrics = loadMetrics();
  const today = new Date();
  let updated = 0;

  for (let i = 0; i < daysBack; i++) {
    const dt = new Date(today);
    dt.setDate(dt.getDate() - i);
    const dateStr = dt.toISOString().slice(0, 10);

    const notePath = findDailyNote(dateStr);
    if (!existsSync(notePath)) continue;

    const fm = parseFrontmatter(notePath);
    if (!fm) continue;

    // Ensure day entry exists
    if (!metrics.days[dateStr]) {
      const weekdays = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
      metrics.days[dateStr] = {
        date: dateStr,
        weekday: weekdays[dt.getDay()],
        week_iso: getISOWeek(dateStr),
      };
    }
    if (!metrics.days[dateStr].manual) {
      metrics.days[dateStr].manual = {};
    }

    // Update from frontmatter (Obsidian is source of truth)
    if (fm.mood != null) metrics.days[dateStr].manual.mood = fm.mood;
    if (fm.food_before_20 != null) metrics.days[dateStr].manual.food_before_20 = fm.food_before_20;

    updated++;
  }

  if (updated > 0) {
    saveMetrics(metrics);
    console.log(`🔄 Synced ${updated} days from Obsidian vault`);
  }

  return metrics;
}

/**
 * Find the daily note file path for a given date.
 * Tries multiple directory structures.
 */
function findDailyNote(dateStr) {
  const [year, monthNum] = dateStr.split('-');
  const monthNames = {
    '01': '01-Январь', '02': '02-Февраль', '03': '03-Март',
    '04': '04-Апрель', '05': '05-Май', '06': '06-Июнь',
    '07': '07-Июль', '08': '08-Август', '09': '09-Сентябрь',
    '10': '10-Октябрь', '11': '11-Ноябрь', '12': '12-Декабрь',
  };

  const candidates = [
    // New structure: Daily/YYYY/MM-Месяц/YYYY-MM-DD.md
    join(VAULT_PATH, 'Жизнь', 'Daily', year, monthNames[monthNum] || '', `${dateStr}.md`),
    // Old/flat structure: Daily/YYYY-MM-DD.md
    join(VAULT_PATH, 'Жизнь', 'Daily', `${dateStr}.md`),
  ];

  for (const path of candidates) {
    if (existsSync(path)) return path;
  }

  // Return the flat path for creating new files
  return join(VAULT_PATH, 'Жизнь', 'Daily', `${dateStr}.md`);
}

/**
 * Update (or create) daily note frontmatter.
 */
function updateDailyNote(dateStr, entry) {
  const filePath = findDailyNote(dateStr);
  let content = '';

  if (existsSync(filePath)) {
    content = readFileSync(filePath, 'utf-8');
  }

  // Parse existing frontmatter
  const fmMatch = content.match(/^---\s*\n([\s\S]*?)\n---/);

  const fm = {
    mood: entry.mood ?? '',
    'Сон_8ч_и_до_9': false,
    'Питание_до_20': entry.food_before_20 ?? false,
    'Работа_над_проектом': false,
  };

  if (fmMatch) {
    // Preserve existing values we don't overwrite
    const existing = fmMatch[1];
    for (const line of existing.split('\n')) {
      const colonIdx = line.indexOf(':');
      if (colonIdx === -1) continue;
      const key = line.slice(0, colonIdx).trim();
      const val = line.slice(colonIdx + 1).trim().replace(/^["']|["']$/g, '');

      if (key === 'Сон_8ч_и_до_9') {
        fm['Сон_8ч_и_до_9'] = val === 'true';
      } else if (key === 'Работа_над_проектом') {
        fm['Работа_над_проектом'] = val === 'true';
      }
    }

    // Overwrite only what we have
    if (entry.mood != null) fm.mood = entry.mood;
    if (entry.food_before_20 != null) fm['Питание_до_20'] = entry.food_before_20;

    // Rebuild frontmatter
    const newFm = [
      '---',
      `mood: "${fm.mood}"`,
      `Сон_8ч_и_до_9: ${fm['Сон_8ч_и_до_9']}`,
      `Питание_до_20: ${fm['Питание_до_20']}`,
      `Работа_над_проектом: ${fm['Работа_над_проектом']}`,
      '---',
    ].join('\n');

    // Replace frontmatter, keep body
    const body = content.slice(fmMatch[0].length);
    let newContent = newFm + body;

    // Append note if provided and body doesn't already have it
    if (entry.note && !body.includes(entry.note)) {
      newContent = newContent.trimEnd() + '\n\n> ' + entry.note + '\n';
    }

    writeFileSync(filePath, newContent, 'utf-8');
  } else {
    // Create new file with frontmatter
    const newContent = [
      '---',
      `mood: "${entry.mood || ''}"`,
      `Сон_8ч_и_до_9: false`,
      `Питание_до_20: ${entry.food_before_20 ?? false}`,
      `Работа_над_проектом: false`,
      '---',
      '',
      `## 📅 ${dateStr}`,
      '',
      entry.note ? `> ${entry.note}` : '',
      '',
    ].join('\n');

    writeFileSync(filePath, newContent, 'utf-8');
  }

  return filePath;
}

// ---- Routes ----

/**
 * POST /api/entry
 * Body: { date, mood, food_before_20, note }
 */
app.post('/api/entry', (req, res) => {
  try {
    const { date, mood, food_before_20, note } = req.body;
    const dateStr = date || new Date().toISOString().slice(0, 10);

    console.log(`📝 Entry for ${dateStr}: mood=${mood}, food=${food_before_20}, note="${note || ''}"`);

    // 1. Update metrics.json
    const metrics = loadMetrics();
    if (!metrics.days[dateStr]) {
      const dt = new Date(dateStr);
      const weekdays = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
      metrics.days[dateStr] = {
        date: dateStr,
        weekday: weekdays[dt.getDay()],
        week_iso: getISOWeek(dateStr),
      };
    }

    if (!metrics.days[dateStr].manual) {
      metrics.days[dateStr].manual = {};
    }

    if (mood != null) metrics.days[dateStr].manual.mood = mood;
    if (food_before_20 != null) metrics.days[dateStr].manual.food_before_20 = food_before_20;
    if (note) metrics.days[dateStr].manual.note = note;

    saveMetrics(metrics);

    // 2. Update Obsidian daily note
    const notePath = updateDailyNote(dateStr, { mood, food_before_20, note });
    console.log(`   → metrics.json updated`);
    console.log(`   → ${notePath} updated`);

    // 3. Copy to dashboard public dir
    const publicPath = join(__dirname, '..', 'dashboard', 'public', 'data', 'metrics.json');
    try { writeFileSync(publicPath, JSON.stringify(metrics, null, 2), 'utf-8'); } catch {}

    res.json({ ok: true, date: dateStr });
  } catch (err) {
    console.error('Entry error:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/forecast
 * Returns 7-day weather forecast from Open-Meteo
 */
app.get('/api/forecast', async (req, res) => {
  try {
    const lat = 55.7558;
    const lon = 37.6173;
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=temperature_2m_max,temperature_2m_min,weathercode,precipitation_sum&timezone=auto&forecast_days=7`;

    const response = await fetch(url);
    const data = await response.json();

    const WMO = {
      0: ['Ясно', '☀️'], 1: ['Малооблачно', '🌤'], 2: ['Облачно', '⛅'], 3: ['Пасмурно', '☁️'],
      45: ['Туман', '🌫'], 48: ['Изморось', '🌫'],
      51: ['Морось', '🌧'], 53: ['Морось', '🌧'], 55: ['Сильная морось', '🌧'],
      56: ['Ледяная морось', '🌧'], 57: ['Ледяная морось', '🌧'],
      61: ['Дождь', '🌧'], 63: ['Умеренный дождь', '🌧'], 65: ['Сильный дождь', '🌧'],
      66: ['Ледяной дождь', '🌧'], 67: ['Ледяной дождь', '🌧'],
      71: ['Снег', '🌨'], 73: ['Умеренный снег', '🌨'], 75: ['Сильный снег', '🌨'],
      77: ['Снежная крупа', '🌨'],
      80: ['Ливень', '🌧'], 81: ['Сильный ливень', '🌧'], 82: ['Штормовой ливень', '🌧'],
      85: ['Снежный ливень', '🌨'], 86: ['Снежный ливень', '🌨'],
      95: ['Гроза', '⛈'], 96: ['Гроза с градом', '⛈'], 99: ['Гроза', '⛈'],
    };

    const WEEKDAYS = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    const daily = data.daily || {};
    const days = (daily.time || []).map((date, i) => {
      const code = daily.weathercode?.[i] ?? 0;
      const [desc, icon] = WMO[code] || ['?', '❓'];
      const dt = new Date(date + 'T12:00:00');
      return {
        date,
        weekday: WEEKDAYS[dt.getDay()],
        temp_max: daily.temperature_2m_max?.[i],
        temp_min: daily.temperature_2m_min?.[i],
        precip: daily.precipitation_sum?.[i],
        desc,
        icon,
      };
    });

    res.json({ days });
  } catch (err) {
    console.error('Forecast error:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/sync
 * Reads recent Obsidian daily notes and updates metrics.json.
 * Returns the updated metrics.
 */
app.get('/api/sync', (req, res) => {
  try {
    const days = parseInt(req.query.days) || 14;
    const metrics = syncFromVault(days);
    res.json(metrics);
  } catch (err) {
    console.error('Sync error:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/metrics
 * Returns current metrics.json (without syncing).
 */
app.get('/api/metrics', (req, res) => {
  try {
    res.json(loadMetrics());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function getISOWeek(dateStr) {
  const dt = new Date(dateStr);
  const d = new Date(Date.UTC(dt.getFullYear(), dt.getMonth(), dt.getDate()));
  d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(weekNo).padStart(2, '0')}`;
}

// ---- Start ----
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`🌿 Life Dashboard API on http://localhost:${PORT}`);
  console.log(`   Vault: ${VAULT_PATH}`);
  console.log(`   Metrics: ${METRICS_PATH}`);

  // Initial sync on startup
  try {
    syncFromVault(14);
  } catch (e) {
    console.warn('Initial vault sync failed:', e.message);
  }
});

/**
 * ScheduleEditor.js — Interactive schedule editor modal.
 * Supports date navigation, inline editing, add/delete rows,
 * and Quick Confirm (option A: shift subsequent activities up).
 */

let currentDate = null;
let blocks = [];

const MONTHS_RU = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
const WEEKDAYS_RU = ['воскресенье', 'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота'];

function formatDateRu(dateStr) {
  const d = new Date(dateStr + 'T12:00:00');
  return `${d.getDate()} ${MONTHS_RU[d.getMonth()]}, ${WEEKDAYS_RU[d.getDay()]}`;
}

function nowHHMM() {
  const n = new Date();
  return String(n.getHours()).padStart(2, '0') + ':' + String(n.getMinutes()).padStart(2, '0');
}

function todayStr() {
  return new Date().toISOString().slice(0, 10);
}

function shiftDate(dateStr, delta) {
  const d = new Date(dateStr + 'T12:00:00');
  d.setDate(d.getDate() + delta);
  return d.toISOString().slice(0, 10);
}

export function openScheduleEditor(date) {
  currentDate = date || todayStr();
  const overlay = document.getElementById('scheduleEditorOverlay');
  if (!overlay) return;
  overlay.classList.add('open');

  document.getElementById('schedPrev')?.addEventListener('click', () => {
    currentDate = shiftDate(currentDate, -1);
    loadAndRender();
  });
  document.getElementById('schedNext')?.addEventListener('click', () => {
    currentDate = shiftDate(currentDate, 1);
    loadAndRender();
  });
  document.getElementById('schedModalClose')?.addEventListener('click', closeScheduleEditor);
  document.getElementById('schedSaveBtn')?.addEventListener('click', saveSchedule);

  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) closeScheduleEditor();
  });

  loadAndRender();
}

function closeScheduleEditor() {
  document.getElementById('scheduleEditorOverlay')?.classList.remove('open');
}

async function loadAndRender() {
  document.getElementById('schedDateTitle').textContent = formatDateRu(currentDate);

  try {
    const res = await fetch(`/api/schedule?date=${currentDate}`);
    const data = await res.json();
    blocks = (data.blocks || []).map(b => ({ ...b }));
  } catch {
    blocks = [];
  }

  renderRows();
}

function renderRows() {
  const body = document.getElementById('scheduleEditorBody');
  if (!body) return;

  const curHm = nowHHMM();
  const isToday = currentDate === todayStr();

  let html = '';
  blocks.forEach((b, i) => {
    const isCurrent = isToday && curHm >= b.start && curHm < b.end;

    html += `
      <div class="sched-row${isCurrent ? ' sched-current' : ''}" data-idx="${i}">
        <input class="sched-time-input" type="text" value="${b.start}" data-field="start" data-idx="${i}" maxlength="5" />
        <span class="sched-time-sep">&ndash;</span>
        <input class="sched-time-input" type="text" value="${b.end}" data-field="end" data-idx="${i}" maxlength="5" />
        <input class="sched-activity-input" type="text" value="${b.activity}" data-field="activity" data-idx="${i}" />
        ${isCurrent ? `<button class="sched-confirm-btn" data-idx="${i}" title="Завершить сейчас">&#10003;</button>` : ''}
        <button class="sched-delete-btn" data-idx="${i}" title="Удалить">&times;</button>
      </div>
    `;
  });

  html += `
    <div class="sched-add-row">
      <button class="sched-add-btn" id="schedAddRow">+ Добавить активность</button>
    </div>
  `;

  body.innerHTML = html;

  // Attach input change listeners
  body.querySelectorAll('.sched-time-input, .sched-activity-input').forEach(input => {
    input.addEventListener('change', (e) => {
      const idx = parseInt(e.target.dataset.idx);
      const field = e.target.dataset.field;
      blocks[idx][field] = e.target.value.trim();
    });
  });

  // Delete buttons
  body.querySelectorAll('.sched-delete-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const idx = parseInt(e.target.dataset.idx);
      blocks.splice(idx, 1);
      renderRows();
    });
  });

  // Quick Confirm buttons
  body.querySelectorAll('.sched-confirm-btn').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      const idx = parseInt(e.target.dataset.idx);
      const now = nowHHMM();

      // End current activity at now
      const originalEnd = blocks[idx].end;
      blocks[idx].end = now;

      // Calculate saved time delta in minutes
      const savedMinutes = timeToMin(originalEnd) - timeToMin(now);

      if (savedMinutes > 0 && idx + 1 < blocks.length) {
        // Start next activity at now
        blocks[idx + 1].start = now;

        // Shift all subsequent activities up proportionally
        for (let j = idx + 1; j < blocks.length; j++) {
          const origStart = timeToMin(blocks[j].start);
          const origEnd = timeToMin(blocks[j].end);

          if (j === idx + 1) {
            // Already set start to now; keep original duration
            const duration = origEnd - timeToMin(originalEnd) + (timeToMin(originalEnd) - origStart);
            // Actually: just shift start, keep end shifted by same delta
            blocks[j].start = now;
            blocks[j].end = minToTime(timeToMin(now) + (origEnd - origStart));
          } else {
            // Shift by delta
            blocks[j].start = minToTime(timeToMin(blocks[j - 1].end));
            const duration = origEnd - origStart;
            blocks[j].end = minToTime(timeToMin(blocks[j].start) + duration);
          }
        }
      }

      // Auto-save immediately
      await saveSchedule();
      renderRows();
    });
  });

  // Add row
  document.getElementById('schedAddRow')?.addEventListener('click', () => {
    const lastEnd = blocks.length > 0 ? blocks[blocks.length - 1].end : '09:00';
    const newEnd = minToTime(timeToMin(lastEnd) + 60);
    blocks.push({ start: lastEnd, end: newEnd, activity: '' });
    renderRows();
  });
}

function timeToMin(hhmm) {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + (m || 0);
}

function minToTime(min) {
  const h = Math.floor(min / 60) % 24;
  const m = min % 60;
  return String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0');
}

async function saveSchedule() {
  try {
    await fetch('/api/schedule', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ date: currentDate, blocks }),
    });
  } catch (err) {
    console.error('Schedule save error:', err);
  }
}

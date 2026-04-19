/**
 * QuickEntry.js — Refined entry form with mini-card sections.
 */

export function renderQuickEntry(container) {
  container.innerHTML = `
    <div class="qe-card">
      <div class="qe-card-header">Настроение</div>
      <div class="mood-buttons" id="moodButtons">
        ${[1, 2, 3, 4, 5].map(v =>
          `<button class="mood-btn" data-mood="${v}">
            <span class="mood-btn-value">${v}</span>
            <span class="mood-btn-label">${['плохо', 'так', 'норм', 'хорошо', 'супер'][v-1]}</span>
          </button>`
        ).join('')}
      </div>
    </div>

    <div class="qe-card">
      <div class="qe-card-header">Питание до 20:00</div>
      <div class="toggle-row">
        <label class="toggle">
          <input type="checkbox" id="foodToggle">
          <span class="toggle-slider"></span>
        </label>
        <span class="toggle-text" id="foodLabel">Нет</span>
      </div>
    </div>

    <div class="qe-card">
      <div class="qe-card-header">Заметка</div>
      <textarea class="qe-textarea" id="entryNote" placeholder="Как прошёл день..." rows="2"></textarea>
    </div>

    <div class="qe-actions">
      <span class="qe-status" id="saveStatus"></span>
      <button class="qe-save" id="saveBtn">Сохранить</button>
    </div>
  `;

  let selectedMood = null;

  // Mood selection
  container.querySelector('#moodButtons').addEventListener('click', (e) => {
    const btn = e.target.closest('.mood-btn');
    if (!btn) return;
    selectedMood = parseInt(btn.dataset.mood);
    container.querySelectorAll('.mood-btn').forEach(b => b.classList.remove('selected'));
    btn.classList.add('selected');
  });

  // Food toggle
  const foodToggle = container.querySelector('#foodToggle');
  const foodLabel = container.querySelector('#foodLabel');
  foodToggle.addEventListener('change', () => {
    foodLabel.textContent = foodToggle.checked ? 'Да' : 'Нет';
  });

  // Save
  container.querySelector('#saveBtn').addEventListener('click', async () => {
    const note = container.querySelector('#entryNote').value.trim();
    const entry = {
      date: new Date().toISOString().slice(0, 10),
      mood: selectedMood,
      food_before_20: foodToggle.checked,
      note: note || undefined,
    };

    try {
      const res = await fetch('/api/entry', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(entry),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      showStatus(container, 'Сохранено');
      resetForm(container);
    } catch (err) {
      console.warn('API save failed, storing locally:', err);
      const local = JSON.parse(localStorage.getItem('pendingEntries') || '[]');
      local.push(entry);
      localStorage.setItem('pendingEntries', JSON.stringify(local));
      showStatus(container, 'Сохранено локально');
    }
  });

  function resetForm(c) {
    selectedMood = null;
    c.querySelectorAll('.mood-btn').forEach(b => b.classList.remove('selected'));
    c.querySelector('#entryNote').value = '';
    foodToggle.checked = false;
    foodLabel.textContent = 'Нет';
  }
}

function showStatus(container, text) {
  const el = container.querySelector('#saveStatus');
  if (!el) return;
  el.textContent = text;
  el.classList.add('visible');
  setTimeout(() => el.classList.remove('visible'), 2500);
}

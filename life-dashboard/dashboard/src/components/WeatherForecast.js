/**
 * WeatherForecast.js — Current weather + 7-day forecast panel.
 */

export async function initWeather() {
  const widget = document.getElementById('weatherWidget');
  const forecastPanel = document.getElementById('forecastPanel');

  try {
    const res = await fetch('/api/forecast');
    if (!res.ok) return;

    const { days } = await res.json();
    if (!days?.length) return;

    const today = days[0];

    // Populate widget
    const iconEl = document.getElementById('weatherIcon');
    const tempEl = document.getElementById('weatherTemp');
    const descEl = document.getElementById('weatherDesc');
    const pressureEl = document.getElementById('weatherPressure');

    if (iconEl) iconEl.textContent = today.icon;
    if (tempEl) tempEl.textContent = `${Math.round(today.temp_max)}°`;
    if (descEl) descEl.textContent = today.desc;

    // Expand/collapse forecast
    if (widget) {
      // Create forecast panel if not exists
      let panel = document.getElementById('forecastPanel');
      if (!panel) {
        panel = document.createElement('div');
        panel.id = 'forecastPanel';
        panel.className = 'forecast-panel';
        // Insert after header
        const header = document.getElementById('header');
        if (header) header.after(panel);
      }

      widget.addEventListener('click', () => {
        const isOpen = panel.style.maxHeight === '120px';
        if (isOpen) {
          panel.style.maxHeight = '0';
          panel.style.opacity = '0';
          panel.style.padding = '0 16px';
          widget.classList.remove('weather-active');
        } else {
          renderForecast(panel, days);
          panel.style.maxHeight = '120px';
          panel.style.opacity = '1';
          panel.style.padding = '14px 16px';
          widget.classList.add('weather-active');
        }
      });
    }
  } catch (err) {
    console.warn('Weather unavailable:', err);
  }
}

function renderForecast(panel, days) {
  const todayStr = new Date().toISOString().slice(0, 10);

  panel.innerHTML = days.map(day => {
    const isToday = day.date === todayStr;
    return `
      <div class="fc-day ${isToday ? 'fc-today' : ''}">
        <span class="fc-label">${isToday ? 'Сегодня' : day.weekday}</span>
        <span class="fc-icon">${day.icon}</span>
        <div class="fc-temps">
          <span class="fc-max">${Math.round(day.temp_max)}°</span>
          <span class="fc-min">${Math.round(day.temp_min)}°</span>
        </div>
        ${day.precip > 0 ? `<span class="fc-precip">${day.precip}mm</span>` : ''}
      </div>
    `;
  }).join('');
}

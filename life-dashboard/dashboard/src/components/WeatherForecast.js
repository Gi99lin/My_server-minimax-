/**
 * WeatherForecast.js — Current weather + Hourly forecast
 */

export async function initWeather() {
  const widget = document.getElementById('weatherWidget');
  if (!widget) return;

  try {
    const res = await fetch('/api/forecast');
    if (!res.ok) return;

    const { days, hourly } = await res.json();
    if (!days?.length || !hourly?.length) return;

    const today = days[0];

    // Populate current
    const iconEl = document.getElementById('weatherIcon');
    const tempEl = document.getElementById('weatherTemp');
    const descEl = document.getElementById('weatherDesc');
    const pressureEl = document.getElementById('weatherPressure');

    if (iconEl) iconEl.textContent = today.icon || '';
    if (tempEl) tempEl.textContent = `${Math.round(today.temp_max)}°`;
    if (descEl) descEl.textContent = today.desc || '';
    if (pressureEl) pressureEl.textContent = `Мин: ${Math.round(today.temp_min)}°`;

    // Render hourly
    const hourlyEl = document.getElementById('weatherHourly');
    if (hourlyEl) {
      renderHourly(hourlyEl, hourly);
    }

  } catch (err) {
    console.warn('Weather unavailable:', err);
  }
}

function renderHourly(container, hourlyData) {
  // Find current hour index
  const now = new Date();
  const currentIsoHour = now.toISOString().slice(0, 13) + ':00'; // "YYYY-MM-DDTHH:00"

  let startIndex = hourlyData.findIndex(h => h.time === currentIsoHour);
  if (startIndex === -1) startIndex = 0;

  // Take the next 8 hours
  const displayHours = hourlyData.slice(startIndex, startIndex + 8);

  container.innerHTML = displayHours.map(h => {
    // extract HH:MM
    const timeLabel = new Date(h.time + 'Z').toISOString().slice(11, 16); 
    // Open-Meteo returns time in local timezone string like "2026-04-19T14:00"
    // So let's parse it without Z
    const localTimeLabel = h.time.slice(11, 16);

    return `
      <div class="hourly-item">
        <span class="hc-time">${localTimeLabel}</span>
        <span class="hc-icon">${h.icon}</span>
        <span class="hc-temp">${Math.round(h.temp)}°</span>
      </div>
    `;
  }).join('');
}

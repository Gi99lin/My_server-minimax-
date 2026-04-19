/**
 * Life Dashboard — main entry point
 */
import './styles/main.css';
import { loadMetrics, getDays } from './utils/dataLoader.js';
import { renderStatCards } from './components/StatCards.js';
import { renderTrendChart } from './components/TrendChart.js';
import { renderTimeBreakdown } from './components/TimeBreakdown.js';
import { renderMoodHeatmap } from './components/MoodHeatmap.js';
import { renderQuickEntry } from './components/QuickEntry.js';
import { initWeather } from './components/WeatherForecast.js';

// V2 Imports
import { initAuth, showLoginModal } from './components/LoginModal.js';
import { renderLiveSchedule } from './components/LiveSchedule.js';
import { renderDevOpsHUD } from './components/DevOpsHUD.js';
import { renderHealthCharts } from './components/HealthCharts.js';
import { io } from 'socket.io-client';

function setGreeting() {
  const el = document.getElementById('greeting');
  if (!el) return;

  const hour = new Date().getHours();
  let text;
  if (hour >= 5 && hour < 12) text = 'Доброе утро';
  else if (hour >= 12 && hour < 18) text = 'Добрый день';
  else text = 'Добрый вечер';

  el.textContent = text;
}

function setDate() {
  const el = document.getElementById('dateDisplay');
  if (!el) return;

  const now = new Date();
  const months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
  ];
  const weekdays = ['воскресенье', 'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота'];
  el.textContent = `${now.getDate()} ${months[now.getMonth()]}, ${weekdays[now.getDay()]}`;
}

function setSyncDot(status) {
  const dot = document.getElementById('syncDot');
  if (!dot) return;
  dot.className = 'sync-dot' + (status === 'error' ? ' error' : '');
}

async function init() {
  const token = initAuth();
  if (!token) return; // Halt init until authenticated

  setGreeting();
  setDate();

  // Setup generic fetch wrapper to inject Auth header
  const originalFetch = window.fetch;
  window.fetch = async (url, options = {}) => {
    if (url.startsWith('/api')) {
      options.headers = { ...options.headers, 'Authorization': encodeURIComponent(token) };
    }
    return originalFetch(url, options);
  };

  // V2 live sockets
  const socket = io('/', { auth: { token } });
  
  socket.on('connect_error', (err) => {
    if (err.message === 'Unauthorized') showLoginModal('Неверный пароль');
  });

  socket.on('docker_pulse', (state) => {
    const el = document.getElementById('devOpsHUD');
    if (el) renderDevOpsHUD(el, state);
  });
  
  socket.on('agent_pulse', (state) => {
    const el = document.getElementById('devOpsHUD');
    if (el) renderDevOpsHUD(el, state);
  });

  // Fetch Live Schedule
  try {
    const sRes = await fetch('/api/schedule');
    const sData = await sRes.json();
    const sCont = document.getElementById('liveSchedule');
    if (sCont) renderLiveSchedule(sCont, sData);
  } catch(e) {
    console.error("No schedule data", e);
  }

  const data = await loadMetrics();
  setSyncDot(data.days ? 'ok' : 'error');

  // Stat cards
  const statContainer = document.getElementById('statCards');
  if (statContainer) renderStatCards(statContainer, data);

  // Weather
  initWeather();

  // Trend chart
  const trendCanvas = document.getElementById('trendChart');
  if (trendCanvas) renderTrendChart(trendCanvas, data, 30);

  // Period selector
  const periodSelector = document.getElementById('periodSelector');
  if (periodSelector) {
    periodSelector.addEventListener('click', (e) => {
      const btn = e.target.closest('.period-btn');
      if (!btn) return;
      periodSelector.querySelectorAll('.period-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const days = parseInt(btn.dataset.days);
      renderTrendChart(trendCanvas, data, days);
    });
  }

  // Time breakdown
  const timeCanvas = document.getElementById('timeChart');
  if (timeCanvas) renderTimeBreakdown(timeCanvas, data);

  // Mood heatmap
  const heatmapEl = document.getElementById('moodHeatmap');
  if (heatmapEl) renderMoodHeatmap(heatmapEl, data);

  // Quick entry
  const quickEntry = document.getElementById('quickEntry');
  if (quickEntry) renderQuickEntry(quickEntry);

  // Health Charts (V2)
  renderHealthCharts(data);

  // Tab switching
  document.getElementById('tabs')?.addEventListener('click', (e) => {
    const btn = e.target.closest('.tab');
    if (!btn) return;
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
    btn.classList.add('active');
    const target = document.getElementById(`tab-${btn.dataset.tab}`);
    if (target) target.classList.add('active');
  });
}

init();

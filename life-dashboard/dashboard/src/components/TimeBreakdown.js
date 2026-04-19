/**
 * TimeBreakdown.js — Weekly stacked bar chart.
 */

import { Chart, registerables } from 'chart.js';
import { getDays } from '../utils/dataLoader.js';

Chart.register(...registerables);

let chart = null;

export function renderTimeBreakdown(canvas, data) {
  const days = getDays(data, 7);

  const labels = days.map(d => d.weekday || d.date.slice(5));
  const cats = ['hours_work', 'hours_projects', 'hours_games', 'hours_rest', 'hours_food'];
  const names = ['Работа', 'Проекты', 'Игры', 'Отдых', 'Еда'];
  const colors = ['#7fbbb3', '#a7c080', '#e69875', '#d699b6', '#dbbc7f'];

  if (chart) chart.destroy();

  chart = new Chart(canvas, {
    type: 'bar',
    data: {
      labels,
      datasets: cats.map((cat, i) => ({
        label: names[i],
        data: days.map(d => d.schedule?.[cat] ?? 0),
        backgroundColor: colors[i] + 'cc',
        borderColor: colors[i],
        borderWidth: 1,
        borderRadius: 3,
        borderSkipped: false,
      })),
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: true,
          position: 'bottom',
          labels: {
            color: '#6b7b72',
            font: { size: 10, weight: '500' },
            boxWidth: 10,
            boxHeight: 10,
            padding: 12,
            useBorderRadius: true,
            borderRadius: 2,
          },
        },
        tooltip: {
          backgroundColor: 'rgba(35, 42, 46, 0.95)',
          titleColor: '#d3c6aa',
          bodyColor: '#9da9a0',
          borderColor: 'rgba(125, 135, 125, 0.15)',
          borderWidth: 1,
          cornerRadius: 10,
          padding: 10,
          titleFont: { size: 11, weight: '500' },
          bodyFont: { size: 11 },
        },
      },
      scales: {
        x: {
          stacked: true,
          ticks: { color: '#6b7b72', font: { size: 10 } },
          grid: { display: false },
          border: { display: false },
        },
        y: {
          stacked: true,
          ticks: { color: '#6b7b72', font: { size: 10 } },
          grid: { color: 'rgba(125,135,125,0.06)' },
          border: { display: false },
        },
      },
      animation: { duration: 700, easing: 'easeOutCubic' },
    },
  });
}

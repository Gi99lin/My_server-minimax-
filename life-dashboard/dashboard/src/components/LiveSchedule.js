export function renderLiveSchedule(container, data) {
  if (!data || (!data.current && !data.next)) {
    const dbg = data?.debugInfo ? JSON.stringify(data.debugInfo) : '';
    container.innerHTML = `<div class="schedule-empty">Нет активностей по расписанию <br><small style="opacity:0.4">${dbg}</small></div>`;
    return;
  }

  const { current, next } = data;

  container.innerHTML = `
    <div class="schedule-live">
      <div class="schedule-block schedule-current">
        <span class="schedule-tag">СЕЙЧАС</span>
        <div class="schedule-details">
          <span class="schedule-title">${current ? current.activity : 'Свободное время'}</span>
          ${current ? `<span class="schedule-time">до ${current.end}</span>` : ''}
        </div>
      </div>
      
      ${next ? `
      <div class="schedule-block schedule-next">
        <span class="schedule-tag">ДАЛЕЕ</span>
        <div class="schedule-details">
          <span class="schedule-title">${next.activity}</span>
          <span class="schedule-time">${next.start} - ${next.end}</span>
        </div>
      </div>
      ` : ''}
    </div>
  `;
}

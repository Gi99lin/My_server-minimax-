export function renderDevOpsHUD(container, dockerState) {
  if (!dockerState || !dockerState.containers) {
    container.innerHTML = `<div class="devops-loading">Syncing LifeOS Modules...</div>`;
    return;
  }

  const { containers, activeAgent } = dockerState;

  let html = `<div class="devops-grid">`;
  
  // -- Agent Rooms --
  const defaultAgents = ['schedule_agent', 'writer_agent', 'research_agent'];
  let agentsToRender = [...defaultAgents];
  if (activeAgent && !agentsToRender.includes(activeAgent)) {
    agentsToRender.push(activeAgent);
  }

  html += `<div class="agent-rooms-grid">`;
  
  for (const ag of agentsToRender) {
    const isWorking = (ag === activeAgent);
    html += `
      <div class="devops-room ${isWorking ? 'room-active' : 'room-sleep'}">
        <div class="room-floor">
          <div class="room-bed" title="Bed">🛏️</div>
          <div class="room-mascot">👾</div>
          <div class="room-desk" title="Desk">💻</div>
        </div>
        <div class="room-info">
          <span class="room-title">${ag}</span>
          <span class="room-sub">${isWorking ? 'Working...' : 'Sleeping...'}</span>
        </div>
      </div>
    `;
  }
  html += `</div>`;

  // -- Server Infrastructure --
  for (const c of containers) {
    const isUp = c.state === 'running';
    const cpu = typeof c.cpu === 'number' ? c.cpu : 0;
    const mem = typeof c.mem === 'number' ? c.mem : 0;

    html += `
      <div class="devops-container ${isUp ? 'cont-up' : 'cont-down'}">
        <div class="cont-header">
          <span class="cont-name">${c.name}</span>
          <span class="cont-state">${isUp ? 'Online' : c.state}</span>
        </div>
        ${isUp && (cpu || mem) ? `
          <div class="cont-stats">
            <div class="cont-stat" title="CPU Limit">
              CPU: ${cpu.toFixed(1)}% 
              <div class="stat-bar-bg"><div class="stat-bar-fill" style="width: ${Math.min(cpu, 100)}%;"></div></div>
            </div>
            <div class="cont-stat" title="Memory Limit">
              MEM: ${mem.toFixed(1)}% 
              <div class="stat-bar-bg"><div class="stat-bar-fill" style="width: ${Math.min(mem, 100)}%;"></div></div>
            </div>
          </div>
        ` : ''}
      </div>
    `;
  }

  html += `</div>`;
  container.innerHTML = html;
}

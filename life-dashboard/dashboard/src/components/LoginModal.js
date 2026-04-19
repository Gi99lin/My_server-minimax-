export function initAuth() {
  const token = localStorage.getItem('dashboard_token');
  if (!token) {
    showLoginModal();
    return null;
  }
  return token;
}

export function showLoginModal(errorMsg = '') {
  let modal = document.getElementById('loginModal');
  if (!modal) {
    modal = document.createElement('div');
    modal.id = 'loginModal';
    modal.className = 'login-modal';
    document.body.appendChild(modal);
  }

  modal.innerHTML = `
    <div class="login-box">
      <h2>LifeOS 2.0</h2>
      <p class="login-sub">Secure Backend Connection</p>
      <input type="password" id="loginPass" placeholder="Enter password..." autofocus />
      ${errorMsg ? `<div class="login-error">${errorMsg}</div>` : ''}
      <button id="loginBtn">Unlock</button>
    </div>
  `;

  document.getElementById('loginBtn').addEventListener('click', () => {
    const p = document.getElementById('loginPass').value;
    if (p) {
      localStorage.setItem('dashboard_token', p);
      window.location.reload();
    }
  });

  document.getElementById('loginPass').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') document.getElementById('loginBtn').click();
  });
}

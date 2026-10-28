const panel = document.getElementById('flotation');
const message = document.getElementById('message');
const track = document.getElementById('track');
const fill = document.getElementById('fill');

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'hide') {
        panel.classList.add('is-hidden');
        return;
    }
    if (data.action !== 'show') return;

    panel.className = `flotation state-${data.state || 'ready'}`;
    message.textContent = data.text || '';
    const hasProgress = Number.isFinite(data.progress);
    track.classList.toggle('is-hidden', !hasProgress);
    fill.style.width = `${Math.max(0, Math.min(100, data.progress || 0))}%`;
});
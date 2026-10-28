// Renders a visual step-by-step tracking timeline for an order status.
// Returns an HTML string — caller inserts it wherever needed.
function renderTrackingTimeline(status) {
  const steps = ['placed', 'accepted', 'processing', 'ready', 'shipped', 'delivered'];
  const labels = { placed: 'Placed', accepted: 'Accepted', processing: 'Processing', ready: 'Ready', shipped: 'Shipped', delivered: 'Delivered' };

  if (status === 'rejected' || status === 'cancelled') {
    return `
      <div class="tracking-timeline">
        <div class="tracking-step done"><div class="tracking-dot">✓</div><div class="tracking-label">Placed</div></div>
        <div class="tracking-step ${status}"><div class="tracking-dot">✕</div><div class="tracking-label">${status === 'rejected' ? 'Rejected' : 'Cancelled'}</div></div>
      </div>
    `;
  }

  const currentIndex = steps.indexOf(status);

  return `
    <div class="tracking-timeline">
      ${steps.map((s, i) => {
        let cls = '';
        if (i < currentIndex) cls = 'done';
        else if (i === currentIndex) cls = 'current';
        const icon = i < currentIndex ? '✓' : (i + 1);
        return `
          <div class="tracking-step ${cls}">
            <div class="tracking-dot">${icon}</div>
            <div class="tracking-label">${labels[s]}</div>
          </div>
        `;
      }).join('')}
    </div>
  `;
}

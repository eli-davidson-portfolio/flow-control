// Initialize charts
document.addEventListener('DOMContentLoaded', () => {
    // Create overview charts when data is loaded
    htmx.on('#overview-content', 'htmx:afterSettle', () => {
        const ctx = document.getElementById('metrics-chart');
        if (ctx) {
            new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: JSON.parse(ctx.dataset.labels),
                    datasets: [{
                        label: 'Issues by Category',
                        data: JSON.parse(ctx.dataset.values),
                        backgroundColor: [
                            'rgba(239, 68, 68, 0.5)',  // red
                            'rgba(234, 179, 8, 0.5)',  // yellow
                            'rgba(59, 130, 246, 0.5)', // blue
                        ],
                        borderColor: [
                            'rgb(239, 68, 68)',
                            'rgb(234, 179, 8)',
                            'rgb(59, 130, 246)',
                        ],
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    plugins: {
                        legend: {
                            position: 'top',
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            ticks: {
                                stepSize: 1
                            }
                        }
                    }
                }
            });
        }
    });

    // Create coverage chart when data is loaded
    htmx.on('#audit-content', 'htmx:afterSettle', () => {
        const ctx = document.getElementById('coverage-chart');
        if (ctx) {
            new Chart(ctx, {
                type: 'doughnut',
                data: {
                    labels: ['Covered', 'Uncovered'],
                    datasets: [{
                        data: [
                            parseFloat(ctx.dataset.covered),
                            100 - parseFloat(ctx.dataset.covered)
                        ],
                        backgroundColor: [
                            'rgba(34, 197, 94, 0.5)', // green
                            'rgba(239, 68, 68, 0.5)'  // red
                        ],
                        borderColor: [
                            'rgb(34, 197, 94)',
                            'rgb(239, 68, 68)'
                        ],
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    plugins: {
                        legend: {
                            position: 'top',
                        }
                    }
                }
            });
        }
    });
});

// Handle file tree expansion
document.addEventListener('click', (e) => {
    if (e.target.matches('.file-tree-toggle')) {
        const item = e.target.closest('.file-tree-item');
        const children = item.querySelector('.file-tree-children');
        if (children) {
            children.classList.toggle('hidden');
            e.target.textContent = children.classList.contains('hidden') ? '▶' : '▼';
        }
    }
});

// Handle issue filtering
htmx.on('select[hx-get="/audit/issues"]', 'change', (evt) => {
    const severity = evt.target.value;
    document.querySelectorAll('#issues-content .issue-item').forEach(item => {
        if (severity === 'all' || item.dataset.severity === severity) {
            item.classList.remove('hidden');
        } else {
            item.classList.add('hidden');
        }
    });
});

// Update status after audit run
htmx.on('#audit-status', 'htmx:afterSettle', () => {
    const status = document.querySelector('#audit-status');
    const indicator = status.querySelector('.rounded-full');
    const timestamp = new Date().toLocaleString();
    
    status.querySelector('span').textContent = `Last audit: ${timestamp}`;
    indicator.classList.remove('bg-green-500', 'bg-yellow-500', 'bg-red-500');
    
    if (status.dataset.success === 'true') {
        indicator.classList.add('bg-green-500');
    } else if (status.dataset.warning === 'true') {
        indicator.classList.add('bg-yellow-500');
    } else {
        indicator.classList.add('bg-red-500');
    }
}); 
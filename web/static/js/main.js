// Initialize Monaco Editor
require.config({ paths: { vs: 'https://unpkg.com/monaco-editor@latest/min/vs' } });

let editor;

require(['vs/editor/editor.main'], function () {
    // Define custom language for flow configuration
    monaco.languages.register({ id: 'flowlang' });
    monaco.languages.setMonarchTokensProvider('flowlang', {
        keywords: [
            'flow', 'config', 'node', 'inputs', 'outputs', 'type', 'from', 'to', 'nodeType'
        ],
        tokenizer: {
            root: [
                [/"[^"]*"/, 'string'],
                [/[{}[\]]/, 'delimiter'],
                [/[a-zA-Z_]\w*/, {
                    cases: {
                        '@keywords': 'keyword',
                        '@default': 'identifier'
                    }
                }],
                [/\/\/.*$/, 'comment'],
                [/\d+/, 'number'],
            ]
        }
    });

    // Create editor instance
    editor = monaco.editor.create(document.getElementById('editor-content'), {
        value: '',
        language: 'flowlang',
        theme: 'vs-dark',
        automaticLayout: true,
        minimap: {
            enabled: false
        },
        scrollBeyondLastLine: false,
        fontSize: 14,
        lineNumbers: 'on',
        renderLineHighlight: 'all',
        scrollbar: {
            vertical: 'visible',
            horizontal: 'visible',
            useShadows: false,
            verticalHasArrows: false,
            horizontalHasArrows: false
        }
    });

    // Add save command
    editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyS, function() {
        const flowId = document.querySelector('[data-flow-id]')?.dataset.flowId;
        if (flowId) {
            const content = editor.getValue();
            htmx.ajax('POST', `/flows/${flowId}`, {
                content,
                target: '#editor-content',
                swap: 'none'
            });
        }
    });
});

// Initialize Mermaid
mermaid.initialize({
    startOnLoad: true,
    theme: 'dark',
    themeVariables: {
        darkMode: true,
        primaryColor: '#2563eb',
        primaryTextColor: '#e2e8f0',
        primaryBorderColor: '#475569',
        lineColor: '#475569',
        secondaryColor: '#475569',
        tertiaryColor: '#1e293b'
    }
});

// SSE Connection Management
function setupEventSource(flowId) {
    const statusEvents = new EventSource(`/events/flows/${flowId}/status`);
    const metricsEvents = new EventSource(`/events/flows/${flowId}/metrics`);
    const logsEvents = new EventSource(`/events/flows/${flowId}/logs`);
    const diagramEvents = new EventSource(`/events/flows/${flowId}/diagram`);

    statusEvents.onmessage = (event) => {
        const status = JSON.parse(event.data);
        updateFlowStatus(status);
    };

    metricsEvents.onmessage = (event) => {
        const metrics = JSON.parse(event.data);
        updateMetrics(metrics);
    };

    logsEvents.onmessage = (event) => {
        const log = JSON.parse(event.data);
        appendLog(log);
    };

    diagramEvents.onmessage = (event) => {
        const diagram = JSON.parse(event.data);
        updateDiagram(diagram);
    };

    return {
        cleanup: () => {
            statusEvents.close();
            metricsEvents.close();
            logsEvents.close();
            diagramEvents.close();
        }
    };
}

// UI Update Functions
function updateFlowStatus(status) {
    const statusIndicator = document.querySelector('#flow-status');
    if (statusIndicator) {
        statusIndicator.innerHTML = `
            <div class="w-2 h-2 rounded-full ${
                status.state === 'running' ? 'bg-green-500' :
                status.state === 'error' ? 'bg-red-500' :
                'bg-slate-500'
            }"></div>
            <span>${status.message}</span>
        `;
    }
}

function updateMetrics(metrics) {
    const metricsContent = document.querySelector('#metrics-content');
    if (metricsContent) {
        metricsContent.innerHTML = metrics.map(metric => `
            <div class="p-3 rounded-md bg-slate-800 border border-slate-700">
                <div class="text-sm text-slate-400">${metric.name}</div>
                <div class="flex items-end gap-2">
                    <div class="text-lg font-semibold text-slate-200">${metric.value}</div>
                    <div class="text-sm ${
                        metric.trend.startsWith('+') ? 'text-green-400' : 'text-red-400'
                    }">${metric.trend}</div>
                </div>
            </div>
        `).join('');
    }
}

function appendLog(log) {
    const consoleContent = document.querySelector('#console-content');
    if (consoleContent) {
        const logEntry = document.createElement('div');
        logEntry.className = `log-entry ${log.level.toLowerCase()}`;
        logEntry.innerHTML = `
            <span class="text-slate-500">${log.timestamp}</span>
            <span class="w-12">[${log.level}]</span>
            <span>${log.message}</span>
        `;
        consoleContent.appendChild(logEntry);
        consoleContent.scrollTop = consoleContent.scrollHeight;
    }
}

function updateDiagram(diagram) {
    const flowDiagram = document.querySelector('#flow-diagram');
    if (flowDiagram) {
        flowDiagram.innerHTML = `<pre class="mermaid">${diagram}</pre>`;
        mermaid.init();
    }
}

// HTMX Events
document.addEventListener('htmx:afterSettle', (event) => {
    if (event.detail.target.id === 'editor-content') {
        // Reinitialize Monaco editor after content update
        if (editor) {
            editor.dispose();
        }
        require(['vs/editor/editor.main'], function () {
            editor = monaco.editor.create(document.getElementById('editor-content'), {
                value: event.detail.target.textContent,
                language: 'flowlang',
                theme: 'vs-dark',
                automaticLayout: true,
                minimap: {
                    enabled: false
                }
            });
        });
    }
}); 
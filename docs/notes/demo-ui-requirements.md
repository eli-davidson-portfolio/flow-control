import React from 'react';
import { Menu, Plus, Play, Pause, Settings, AlertCircle, MoreVertical, ChevronDown, Save, XCircle } from 'lucide-react';

const FlowControlUI = () => {
  const sampleMermaid = `graph LR
    A[Source API] -->|Events| B(Filter)
    B --> C{Condition}
    C -->|Match| D[Transform]
    C -->|No Match| E[Error Handler]
    D --> F[Sink DB]
    E --> G[Error Queue]
    style A fill:#2A4365
    style B fill:#2A4365
    style C fill:#2A4365
    style D fill:#2A4365
    style E fill:#6B2E2E
    style F fill:#2A4365
    style G fill:#6B2E2E`;

  return (
    <div className="h-screen w-full flex flex-col bg-slate-900 text-slate-200">
      {/* Top Bar */}
      <div className="h-14 border-b border-slate-700 bg-slate-800 flex items-center justify-between px-4">
        <div className="flex items-center space-x-4">
          <Menu className="w-6 h-6 text-slate-400" />
          <h1 className="font-bold text-lg text-blue-400">Flow Control</h1>
        </div>
        <div className="flex items-center space-x-3">
          <button className="px-3 py-1.5 rounded-md bg-blue-600 hover:bg-blue-700 text-white flex items-center gap-2 text-sm">
            <Plus className="w-4 h-4" />
            New Flow
          </button>
          <button className="p-2 rounded-md hover:bg-slate-700">
            <Settings className="w-5 h-5 text-slate-400" />
          </button>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 flex">
        {/* Sidebar */}
        <div className="w-64 border-r border-slate-700 bg-slate-800">
          <div className="p-4">
            <h2 className="font-semibold text-slate-200 mb-3">Flows</h2>
            <div className="space-y-1">
              {[
                { name: 'Event Pipeline', status: 'active' },
                { name: 'Data Processor', status: 'error' },
                { name: 'Alert Service', status: 'stopped' }
              ].map((flow) => (
                <div key={flow.name} 
                     className="p-2.5 rounded-md hover:bg-slate-700 cursor-pointer flex items-center justify-between group">
                  <div className="flex items-center gap-2">
                    <div className={`w-2 h-2 rounded-full ${
                      flow.status === 'active' ? 'bg-green-500' :
                      flow.status === 'error' ? 'bg-red-500' :
                      'bg-slate-500'
                    }`} />
                    <span className="text-sm">{flow.name}</span>
                  </div>
                  <MoreVertical className="w-4 h-4 text-slate-400 opacity-0 group-hover:opacity-100" />
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Content Grid */}
        <div className="flex-1 grid grid-cols-2 grid-rows-2 gap-1 bg-slate-800 p-1">
          {/* Flow Diagram */}
          <div className="bg-slate-900 p-4 rounded-md flex flex-col">
            <div className="flex justify-between items-center mb-4">
              <h3 className="font-semibold text-slate-200">Flow Diagram</h3>
              <div className="flex items-center space-x-2">
                <button className="p-1.5 rounded-md bg-green-600 hover:bg-green-700">
                  <Play className="w-4 h-4" />
                </button>
              </div>
            </div>
            <div className="flex-1 bg-slate-800 rounded-md p-4 overflow-auto">
              <pre className="text-xs">
                {sampleMermaid}
              </pre>
            </div>
          </div>

          {/* Metrics */}
          <div className="bg-slate-900 p-4 rounded-md">
            <div className="flex justify-between items-center mb-4">
              <h3 className="font-semibold text-slate-200">Metrics</h3>
              <select className="text-sm bg-slate-800 border border-slate-700 rounded px-2 py-1">
                <option>Last 5m</option>
                <option>Last 15m</option>
                <option>Last 1h</option>
              </select>
            </div>
            <div className="grid grid-cols-2 gap-4">
              {[
                { name: 'Messages/sec', value: '1.2k', trend: '+5%' },
                { name: 'Error Rate', value: '0.01%', trend: '-2%' },
                { name: 'Avg Latency', value: '45ms', trend: '+1%' },
                { name: 'Memory Usage', value: '256MB', trend: '75%' }
              ].map((metric) => (
                <div key={metric.name} className="p-3 rounded-md bg-slate-800 border border-slate-700">
                  <div className="text-sm text-slate-400">{metric.name}</div>
                  <div className="flex items-end gap-2">
                    <div className="text-lg font-semibold text-slate-200">{metric.value}</div>
                    <div className="text-sm text-green-400">{metric.trend}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Code Editor */}
          <div className="bg-slate-900 p-4 rounded-md flex flex-col">
            <div className="flex justify-between items-center mb-4">
              <h3 className="font-semibold text-slate-200">Flow Configuration</h3>
              <div className="flex items-center space-x-2">
                <button className="px-3 py-1.5 text-sm rounded-md bg-blue-600 hover:bg-blue-700 text-white flex items-center gap-2">
                  <Save className="w-4 h-4" />
                  Save
                </button>
              </div>
            </div>
            <div className="flex-1 font-mono text-sm bg-slate-800 rounded-md p-4 overflow-auto">
              <pre className="text-blue-300">{`{
  "nodes": [
    {
      "id": "source",
      "type": "source",
      "config": {
        "url": "https://api.example.com/events",
        "interval": "5s"
      }
    },
    {
      "id": "filter",
      "type": "transform",
      "config": {
        "condition": "event.type == 'ALERT'"
      }
    },
    {
      "id": "sink",
      "type": "sink",
      "config": {
        "connection": "postgresql://localhost:5432/events"
      }
    }
  ],
  "edges": [
    {"from": "source", "to": "filter"},
    {"from": "filter", "to": "sink"}
  ]
}`}</pre>
            </div>
          </div>

          {/* Console */}
          <div className="bg-slate-900 p-4 rounded-md flex flex-col">
            <div className="flex justify-between items-center mb-4">
              <h3 className="font-semibold text-slate-200">Console</h3>
              <div className="flex items-center gap-2">
                <button className="px-2 py-1 text-xs rounded-md bg-slate-800 hover:bg-slate-700 border border-slate-700">
                  Clear
                </button>
                <select className="text-sm bg-slate-800 border border-slate-700 rounded px-2 py-1">
                  <option>All Levels</option>
                  <option>Errors</option>
                  <option>Warnings</option>
                </select>
              </div>
            </div>
            <div className="flex-1 font-mono text-sm bg-slate-800 rounded-md p-4 overflow-auto">
              {[
                { level: 'INFO', time: '10:45:23', msg: 'Flow started successfully' },
                { level: 'WARN', time: '10:45:25', msg: 'High latency detected (145ms)' },
                { level: 'ERROR', time: '10:45:26', msg: 'Failed to connect to database' },
                { level: 'INFO', time: '10:45:28', msg: 'Retrying connection...' },
                { level: 'INFO', time: '10:45:29', msg: 'Connection restored' }
              ].map((log, i) => (
                <div key={i} className={`py-1 flex gap-3 ${
                  log.level === 'ERROR' ? 'text-red-400' :
                  log.level === 'WARN' ? 'text-yellow-400' :
                  'text-slate-300'
                }`}>
                  <span className="text-slate-500">{log.time}</span>
                  <span className="w-12">[{log.level}]</span>
                  <span>{log.msg}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Status Bar */}
      <div className="h-8 border-t border-slate-700 bg-slate-800 flex items-center justify-between px-4 text-sm text-slate-300">
        <div className="flex items-center space-x-4">
          <div className="flex items-center space-x-2">
            <div className="w-2 h-2 rounded-full bg-green-500"></div>
            <span>System Online</span>
          </div>
          <div>Active Flows: 3</div>
          <div>CPU: 15%</div>
          <div>Memory: 256MB</div>
        </div>
        <div className="flex items-center space-x-2 text-slate-400">
          <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></div>
          <span>Connected</span>
        </div>
      </div>
    </div>
  );
};

export default FlowControlUI;
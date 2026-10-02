import {useEffect, useRef, useState} from 'react';
import {LocalProvider, type ModelConnection} from './ai';
import type {Settings} from './core';

export function LocalModelSettings({settings, save}: {settings: Settings; save: (patch: Partial<Settings>) => Promise<boolean>}) {
  const [endpoint, setEndpoint] = useState(settings.localEndpoint || 'http://localhost:1234/v1');
  const [connection, setConnection] = useState<ModelConnection>();
  const [error, setError] = useState('');
  const [testing, setTesting] = useState(false);
  const generation = useRef(0);
  useEffect(() => () => { generation.current++; }, []);
  async function test() {
    const request = ++generation.current;
    setTesting(true); setError(''); setConnection(undefined);
    try {
      const result = await new LocalProvider(endpoint).connect();
      if (request !== generation.current) return;
      const model = result.models.includes(settings.localModel || '') ? settings.localModel : result.models[0];
      if (!await save({localEndpoint: result.endpoint, localModel: model})) throw new Error('The connection worked, but its settings couldn’t be saved. Try again.');
      if (request === generation.current) setConnection(result);
    } catch (e) { if (request === generation.current) setError(e instanceof Error ? e.message : 'The model server is unavailable.'); }
    finally { if (request === generation.current) setTesting(false); }
  }
  return <div className="local-model-settings">
    <label className="field">Local OpenAI-compatible endpoint<input type="url" autoCapitalize="none" spellCheck={false} value={endpoint} onChange={e => { generation.current++; setTesting(false); setEndpoint(e.target.value); setConnection(undefined); setError(''); }} onBlur={() => { if(endpoint.trim() !== settings.localEndpoint) void save({localEndpoint:endpoint.trim(),localModel:undefined}); }}/></label>
    <p className="help muted">On iPhone, localhost is the phone itself. For a model on your Mac, use its LAN address on the same Wi-Fi. The server must allow this app through CORS; HTTPS browsers can block HTTP LAN connections.</p>
    <button className="quiet" onClick={test} disabled={testing}>{testing ? 'Testing connection…' : 'Test connection'}</button>
    <div className="model-status" role="status">
      {connection ? <><strong>Connected · {connection.latency} ms</strong><small>{connection.endpoint}</small><label className="field">Model<select aria-label="Model" value={settings.localModel || connection.models[0]} onChange={e => void save({localModel:e.target.value})}>{connection.models.map(model => <option key={model}>{model}</option>)}</select></label><p>Connection verified now. Assistant checks again before each request.</p></> : <p>{error || 'Not tested. No records are sent by a connection test.'}</p>}
    </div>
    <p className="help muted">Assistant can use this model after you explicitly enable sharing there. All core features work without it.</p>
  </div>;
}

import { useEffect, useState } from 'react';

import { LAB_NAME } from './config/config_socle';
import { getLab } from './api/client';

import deployment from '../deployment.json' with { type: 'json' };

function App() {
  const [backendName, setBackendName] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getLab()
      .then((data) => {
        setBackendName(data.name);
      })
      .catch(() => {
        setError('Impossible de contacter le backend.');
      });
  }, []);

  return (
    <main>
      <h1>Laboratoire {deployment.title} </h1>

      <p>
        <strong>LAB FRONT :</strong> {LAB_NAME}
      </p>

      <p>
        <strong>LAB BACK :</strong> {backendName ?? 'chargement...'}
      </p>

      {error && <p>{error}</p>}
    </main>
  );
}

export default App;

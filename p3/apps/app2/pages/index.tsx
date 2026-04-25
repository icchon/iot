import { useState, useEffect } from 'react';
import Head from 'next/head';

export default function Home() {
  const [results, setResults] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(false);
  const appId = "app2";
  const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "/api";

  const fetchResults = async () => {
    try {
      const res = await fetch(`${backendUrl}/results/${appId}`);
      if (res.ok) {
        const data = await res.json();
        setResults(data);
      }
    } catch (error) {
      console.error("Failed to fetch results:", error);
    }
  };

  const vote = async (choice: string) => {
    setLoading(true);
    try {
      const res = await fetch(`${backendUrl}/vote`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ app_id: appId, choice }),
      });
      if (res.ok) {
        await fetchResults();
      }
    } catch (error) {
      console.error("Vote failed:", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchResults();
    const interval = setInterval(fetchResults, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="container">
      <Head>
        <title>App 2: 海派 vs 山派</title>
      </Head>

      <main>
        <div className="app-id-badge">APP 2</div>
        <h1>どっち派？ (海 vs 山)</h1>
        <div className="voting-section">
          <button onClick={() => vote('sea')} disabled={loading} className="btn sea">🏖️ 海派</button>
          <button onClick={() => vote('mountain')} disabled={loading} className="btn mountain">⛰️ 山派</button>
        </div>

        <div className="results">
          <h2>現在の集計</h2>
          <div className="stat">
            <span>海: {results.sea || 0} 票</span>
            <span>山: {results.mountain || 0} 票</span>
          </div>
        </div>
        <div className="version">v0.4.0</div>
      </main>

      <style jsx>{`
        .container { min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; font-family: sans-serif; background-color: #e0f2f1; }
        main { background: white; padding: 2rem; border-radius: 1rem; box-shadow: 0 10px 25px rgba(0,0,0,0.1); text-align: center; position: relative; }
        .app-id-badge { position: absolute; top: -15px; left: 50%; transform: translateX(-50%); background: #1a202c; color: white; padding: 5px 20px; border-radius: 20px; font-weight: bold; font-size: 0.75rem; }
        h1 { color: #333; margin-bottom: 2rem; font-size: 1.8rem; }
        .voting-section { display: flex; gap: 1rem; margin-bottom: 2rem; }
        .btn { padding: 1rem 2rem; font-size: 1.2rem; border: none; border-radius: 0.5rem; cursor: pointer; transition: all 0.2s; }
        .btn:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0,0,0,0.15); }
        .btn:active { transform: translateY(0); }
        .btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .sea { background-color: #00bcd4; color: white; }
        .mountain { background-color: #4caf50; color: white; }
        .results { border-top: 1px solid #eee; padding-top: 1rem; }
        .stat { display: flex; justify-content: space-around; font-size: 1.5rem; font-weight: bold; color: #555; gap: 2rem; }
        .version { margin-top: 1.5rem; font-size: 0.8rem; color: #999; }
      `}</style>
    </div>
  );
}

import React, { useState, useEffect } from 'react'
import axios from 'axios'

function App() {
  const [runs, setRuns] = useState([])
  const [selectedRun, setSelectedRun] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    fetchRuns()
  }, [])

  const fetchRuns = async () => {
    try {
      setLoading(true)
      const response = await axios.get('/api/runs')
      setRuns(response.data.runs || [])
      setError(null)
    } catch (error) {
      console.error('Error fetching runs:', error)
      setError('Failed to fetch runs')
    } finally {
      setLoading(false)
    }
  }

  const fetchRunDetails = async (runId) => {
    try {
      const response = await axios.get(`/api/runs/${runId}`)
      setSelectedRun(response.data)
    } catch (error) {
      console.error('Error fetching run details:', error)
    }
  }

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleString()
  }

  const getStatusClass = (status) => {
    switch (status) {
      case 'running': return 'status-badge status-running'
      case 'completed': return 'status-badge status-completed'
      case 'failed': return 'status-badge status-failed'
      default: return 'status-badge'
    }
  }

  if (loading) {
    return (
      <div className="loading">
        Loading training runs...
      </div>
    )
  }

  if (error) {
    return (
      <div className="loading">
        <p>Error: {error}</p>
        <button className="btn btn-primary" onClick={fetchRuns}>
          Retry
        </button>
      </div>
    )
  }

  return (
    <div>
      <header className="header">
        <div className="container">
          <h1>ML Training Dashboard</h1>
          <p>{runs.length} training runs found</p>
          <button className="btn btn-primary" onClick={fetchRuns}>
            Refresh
          </button>
        </div>
      </header>

      <div className="container">
        <div className="runs-grid">
          {/* Runs List */}
          <div className="runs-list">
            <h3>Training Runs</h3>
            
            {runs.length === 0 ? (
              <div className="empty-state">
                <p>No training runs found</p>
                <p style={{fontSize: '14px', marginTop: '10px'}}>
                  Make sure your training scripts use dashboard_logger
                </p>
              </div>
            ) : (
              runs.map((run) => (
                <div
                  key={`${run.project}-${run.id}`}
                  className={`run-item ${selectedRun?.id === run.id ? 'active' : ''}`}
                  onClick={() => fetchRunDetails(run.id)}
                >
                  <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start'}}>
                    <div>
                      <div style={{fontWeight: 'bold', marginBottom: '5px'}}>{run.id}</div>
                      <div style={{fontSize: '12px', color: '#666', marginBottom: '5px'}}>
                        📁 {run.project}
                      </div>
                      <div style={{fontSize: '12px', color: '#666'}}>
                        {run.epochs || 0} epochs • {run.metrics_count || 0} metrics
                      </div>
                      <div style={{fontSize: '11px', color: '#999', marginTop: '5px'}}>
                        {formatDate(run.created_at)}
                      </div>
                    </div>
                    <span className={getStatusClass(run.status)}>
                      {run.status}
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>

          {/* Run Details */}
          <div className="run-details">
            {selectedRun ? (
              <div>
                <h3>{selectedRun.id}</h3>
                <p style={{fontSize: '14px', color: '#666', marginBottom: '20px'}}>
                  📁 {selectedRun.project} • {selectedRun.path}
                </p>

                {/* Quick Stats */}
                <div style={{
                  display: 'grid', 
                  gridTemplateColumns: 'repeat(3, 1fr)', 
                  gap: '15px', 
                  margin: '20px 0',
                  padding: '15px',
                  backgroundColor: '#f8f9fa',
                  borderRadius: '6px'
                }}>
                  <div style={{textAlign: 'center'}}>
                    <div style={{fontSize: '24px', fontWeight: 'bold', color: '#007bff'}}>
                      {selectedRun.metrics?.validation_metrics?.length || 0}
                    </div>
                    <div style={{fontSize: '12px', color: '#666'}}>Epochs</div>
                  </div>
                  <div style={{textAlign: 'center'}}>
                    <div style={{fontSize: '24px', fontWeight: 'bold', color: '#28a745'}}>
                      {selectedRun.metrics?.training_metrics?.length || 0}
                    </div>
                    <div style={{fontSize: '12px', color: '#666'}}>Steps</div>
                  </div>
                  <div style={{textAlign: 'center'}}>
                    <div style={{fontSize: '24px', fontWeight: 'bold', color: '#6f42c1'}}>
                      {(selectedRun.plots?.length || 0) + (selectedRun.samples?.length || 0)}
                    </div>
                    <div style={{fontSize: '12px', color: '#666'}}>Files</div>
                  </div>
                </div>

                {/* Training Plots */}
                {selectedRun.plots && selectedRun.plots.length > 0 && (
                  <div style={{marginBottom: '30px'}}>
                    <h4>Training Plots</h4>
                    {selectedRun.plots.map((plot) => (
                      <div key={plot} className="plot-container">
                        <img 
                          src={`/api/files/${selectedRun.id}/plots/${plot}`}
                          alt={plot}
                          onError={(e) => {
                            e.target.style.display = 'none'
                            e.target.nextSibling.style.display = 'block'
                          }}
                        />
                        <div style={{display: 'none', padding: '20px', color: '#999'}}>
                          Failed to load: {plot}
                        </div>
                        <p style={{fontSize: '14px', color: '#666', marginTop: '10px'}}>{plot}</p>
                      </div>
                    ))}
                  </div>
                )}

                {/* Generated Samples - SHOW ALL SAMPLES */}
                {selectedRun.samples && selectedRun.samples.length > 0 && (
                  <div style={{marginBottom: '30px'}}>
                    <h4>Generated Samples ({selectedRun.samples.length})</h4>
                    <div style={{display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '15px'}}>
                      {selectedRun.samples.map((sample) => (
                        <div key={sample} className="plot-container">
                          <img 
                            src={`/api/files/${selectedRun.id}/samples/${sample}`}
                            alt={sample}
                          />
                          <p style={{fontSize: '12px', color: '#666', marginTop: '5px'}}>{sample}</p>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Configuration */}
                <div style={{marginBottom: '30px'}}>
                  <h4>Configuration</h4>
                  <pre>{JSON.stringify(selectedRun.config, null, 2)}</pre>
                </div>

                {/* Latest Metrics */}
                {selectedRun.metrics?.validation_metrics && selectedRun.metrics.validation_metrics.length > 0 && (
                  <div>
                    <h4>Latest Metrics</h4>
                    <div style={{backgroundColor: '#f8f9fa', padding: '15px', borderRadius: '6px'}}>
                      {Object.entries(selectedRun.metrics.validation_metrics[selectedRun.metrics.validation_metrics.length - 1])
                        .filter(([key]) => key !== 'timestamp' && key !== 'epoch')
                        .map(([key, value]) => (
                          <div key={key} style={{display: 'flex', justifyContent: 'space-between', padding: '5px 0'}}>
                            <span style={{color: '#666'}}>{key}:</span>
                            <span style={{fontWeight: '500'}}>
                              {typeof value === 'number' ? value.toFixed(4) : value}
                            </span>
                          </div>
                        ))}
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <div className="empty-state">
                <h3>Select a Training Run</h3>
                <p>Click on a training run from the list to view details, plots, and metrics.</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

export default App
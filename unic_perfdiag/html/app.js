const app = document.getElementById('app');
const fpsInstant = document.getElementById('fpsInstant');
const fpsAvg = document.getElementById('fpsAvg');
const frameAvg = document.getElementById('frameAvg');
const spikes = document.getElementById('spikes');
const statusText = document.getElementById('statusText');
const cooldownText = document.getElementById('cooldownText');
const resultsBody = document.getElementById('resultsBody');
const exportOutput = document.getElementById('exportOutput');
const exportInfo = document.getElementById('exportInfo');
const fixedLocationToggle = document.getElementById('fixedLocation');
const activeLocation = document.getElementById('activeLocation');
const locationA = document.getElementById('locationA');
const locationB = document.getElementById('locationB');
const baselineA = document.getElementById('baselineA');
const baselineB = document.getElementById('baselineB');
const groupSelect = document.getElementById('groupSelect');
const groupMode = document.getElementById('groupMode');

const resourceName = (window.GetParentResourceName && GetParentResourceName()) || 'unic_perfdiag';

let lastExport = { json: '', csv: '' };
let exportMode = 'json';

const post = (endpoint, data = {}) => {
  return fetch(`https://${resourceName}/${endpoint}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8'
    },
    body: JSON.stringify(data)
  });
};

const formatLocation = (loc) => {
  if (!loc) return 'não definido';
  return `${loc.x.toFixed(2)}, ${loc.y.toFixed(2)}, ${loc.z.toFixed(2)}`;
};

const formatBaseline = (result) => {
  if (!result) return '-';
  return `${result.fps.toFixed(1)} FPS | ${result.frameMs.toFixed(2)} ms`;
};

const updateMetrics = (data) => {
  fpsInstant.textContent = data.fpsInstant.toFixed(0);
  fpsAvg.textContent = data.fpsAvg.toFixed(1);
  frameAvg.textContent = `${data.frameTimeAvg.toFixed(2)} ms`;
  spikes.textContent = data.spikes;
};

const updateResults = (results = []) => {
  resultsBody.innerHTML = '';
  results
    .slice()
    .sort((a, b) => b.deltaFps - a.deltaFps)
    .forEach((row) => {
      const entry = document.createElement('div');
      entry.className = 'table__row';
      entry.innerHTML = `
        <span>${row.resource}</span>
        <span>${row.type}</span>
        <span>${row.fpsBaseline.toFixed(1)}</span>
        <span>${row.fpsTest.toFixed(1)}</span>
        <span>${row.deltaFps.toFixed(1)}</span>
        <span>${row.frameBaseline.toFixed(2)} ms</span>
        <span>${row.frameTest.toFixed(2)} ms</span>
        <span>${row.deltaFrame.toFixed(2)} ms</span>
      `;
      resultsBody.appendChild(entry);
    });
};

const updateGroups = (groups = []) => {
  groupSelect.innerHTML = '<option value="all">Todos</option>';
  groups.forEach((group) => {
    const option = document.createElement('option');
    option.value = group;
    option.textContent = group;
    groupSelect.appendChild(option);
  });
};

const handleExportDisplay = () => {
  const data = exportMode === 'json' ? lastExport.json : lastExport.csv;
  exportOutput.value = data || '';
  if (data) {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(data).catch(() => null);
    }
  }
};

const setPanelVisible = (visible) => {
  app.classList.toggle('hidden', !visible);
};

window.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || !data.type) return;

  switch (data.type) {
    case 'open':
      setPanelVisible(true);
      if (data.metrics) updateMetrics(data.metrics);
      if (data.results) updateResults(data.results);
      if (data.groups) updateGroups(data.groups);
      if (data.fixedLocationEnabled !== undefined) {
        fixedLocationToggle.checked = data.fixedLocationEnabled;
      }
      if (data.activeLocation) {
        activeLocation.textContent = data.activeLocation;
      }
      if (data.locations) {
        locationA.textContent = formatLocation(data.locations.A);
        locationB.textContent = formatLocation(data.locations.B);
      }
      break;
    case 'metrics':
      updateMetrics(data.metrics);
      break;
    case 'status':
      statusText.textContent = data.status || 'idle';
      break;
    case 'cooldown':
      cooldownText.textContent = data.remaining ? `${data.remaining}s` : '-';
      break;
    case 'results':
      updateResults(data.results || []);
      break;
    case 'exportData':
      lastExport = { json: data.json || '', csv: data.csv || '' };
      handleExportDisplay();
      break;
    case 'exportSaved':
      if (data.error) {
        exportInfo.textContent = `Falha ao salvar: ${data.error}`;
      } else {
        exportInfo.textContent = `Export salvo: ${data.jsonFile} | ${data.csvFile}`;
      }
      break;
    case 'location':
      if (data.slot === 'A') locationA.textContent = formatLocation(data.location);
      if (data.slot === 'B') locationB.textContent = formatLocation(data.location);
      break;
    case 'activeLocation':
      activeLocation.textContent = data.slot;
      break;
    case 'fixedLocation':
      fixedLocationToggle.checked = data.enabled;
      break;
    case 'baselineCompare':
      baselineA.textContent = formatBaseline(data.resultA);
      baselineB.textContent = formatBaseline(data.resultB);
      break;
    case 'config':
      if (data.config && data.config.groups) {
        updateGroups(Object.keys(data.config.groups));
      }
      break;
    case 'triggerStart':
      startBenchmark();
      break;
    default:
      break;
  }
});

const startBenchmark = () => {
  const sampleSeconds = document.getElementById('sampleSeconds').value;
  const stabilizationSeconds = document.getElementById('stabilizationSeconds').value;
  const cooldownSeconds = document.getElementById('cooldownSeconds').value;
  const mapsOnly = document.getElementById('mapsOnly').checked;
  const group = groupSelect.value;
  const groupModeValue = groupMode.value;

  post('start', {
    sampleSeconds,
    stabilizationSeconds,
    cooldownSeconds,
    mapsOnly,
    group,
    groupMode: groupModeValue
  });
};

const closePanel = () => {
  setPanelVisible(false);
  post('close');
};

const stopBenchmark = () => {
  post('stop');
};

const exportJson = () => {
  exportMode = 'json';
  post('export');
};

const exportCsv = () => {
  exportMode = 'csv';
  post('export');
};

const setLocation = (slot) => {
  post('setLocation', { slot });
};

const useLocation = (slot) => {
  post('useLocation', { slot });
};

const toggleFixedLocation = () => {
  post('toggleFixedLocation', { enabled: fixedLocationToggle.checked });
};

const runBaselineCompare = () => {
  const sampleSeconds = document.getElementById('sampleSeconds').value;
  const stabilizationSeconds = document.getElementById('stabilizationSeconds').value;
  post('runBaselineCompare', {
    sampleSeconds,
    stabilizationSeconds
  });
};

window.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    closePanel();
  }
});

window.onload = () => {
  document.getElementById('startBtn').addEventListener('click', startBenchmark);
  document.getElementById('stopBtn').addEventListener('click', stopBenchmark);
  document.getElementById('exportJsonBtn').addEventListener('click', exportJson);
  document.getElementById('exportCsvBtn').addEventListener('click', exportCsv);
  document.getElementById('closeBtn').addEventListener('click', closePanel);
  fixedLocationToggle.addEventListener('change', toggleFixedLocation);
  document.querySelectorAll('[data-set]').forEach((btn) => {
    btn.addEventListener('click', () => setLocation(btn.dataset.set));
  });
  document.querySelectorAll('[data-use]').forEach((btn) => {
    btn.addEventListener('click', () => useLocation(btn.dataset.use));
  });
  document.getElementById('compareBtn').addEventListener('click', runBaselineCompare);
};

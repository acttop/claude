'use strict';

// ── State ──────────────────────────────────────────────────────────────────
let players = [];
let results = [];
let ladderMap = [];       // ladderMap[col][row] = true if horizontal bar starts here (going right)
let assignments = [];     // assignments[playerIndex] = resultIndex
let revealed = [];        // revealed[playerIndex] = true after animation
let animating = false;

const COLS_MIN = 2;
const COLS_MAX = 10;
const ROWS = 14;           // number of horizontal rungs slots
const COL_W = 90;          // px per column
const ROW_H = 40;          // px per row
const LINE_W = 3;
const ANIM_STEP_MS = 40;

// ── DOM helpers ────────────────────────────────────────────────────────────
const $ = id => document.getElementById(id);
const show = id => { $(id).classList.add('active'); };
const hide = id => { $(id).classList.remove('active'); };

// ── Setup helpers ──────────────────────────────────────────────────────────
function renderList(listId, arr, removeCallback) {
  const el = $(listId);
  el.innerHTML = '';
  arr.forEach((name, i) => {
    const tag = document.createElement('div');
    tag.className = 'name-tag';
    tag.innerHTML = `<span>${name}</span><button onclick="${removeCallback}(${i})">✕</button>`;
    el.appendChild(tag);
  });
}

function addPlayer() {
  const input = $('player-input');
  const name = input.value.trim();
  if (!name) return;
  if (players.length >= COLS_MAX) { showError('최대 10명까지 추가할 수 있어요'); return; }
  players.push(name);
  input.value = '';
  renderList('players-list', players, 'removePlayer');
  clearError();
}

function removePlayer(i) {
  players.splice(i, 1);
  renderList('players-list', players, 'removePlayer');
}

function addResult() {
  const input = $('result-input');
  const name = input.value.trim();
  if (!name) return;
  if (results.length >= COLS_MAX) { showError('최대 10개까지 추가할 수 있어요'); return; }
  results.push(name);
  input.value = '';
  renderList('results-list', results, 'removeResult');
  clearError();
}

function removeResult(i) {
  results.splice(i, 1);
  renderList('results-list', results, 'removeResult');
}

function loadSample() {
  players = ['철수', '영희', '민준', '서연'];
  results = ['당첨!', '꽝', '치킨', '꽝'];
  renderList('players-list', players, 'removePlayer');
  renderList('results-list', results, 'removeResult');
  clearError();
}

function showError(msg) { $('setup-error').textContent = msg; }
function clearError() { $('setup-error').textContent = ''; }

// Enter key support
document.addEventListener('DOMContentLoaded', () => {
  $('player-input').addEventListener('keydown', e => { if (e.key === 'Enter') addPlayer(); });
  $('result-input').addEventListener('keydown', e => { if (e.key === 'Enter') addResult(); });
});

// ── Game start ─────────────────────────────────────────────────────────────
function startGame() {
  if (players.length < COLS_MIN) { showError('참가자를 최소 2명 이상 추가해주세요'); return; }
  if (results.length !== players.length) { showError(`결과 개수(${results.length})를 참가자 수(${players.length})와 같게 맞춰주세요`); return; }
  clearError();
  hide('setup-screen');
  show('game-screen');
  buildGame();
}

function backToSetup() {
  hide('game-screen');
  show('setup-screen');
  animating = false;
}

function buildGame() {
  const n = players.length;
  revealed = new Array(n).fill(false);
  animating = false;

  // Build random ladder
  ladderMap = Array.from({ length: n }, () => new Array(ROWS).fill(false));
  for (let row = 0; row < ROWS; row++) {
    let col = 0;
    while (col < n - 1) {
      if (Math.random() < 0.38) {
        ladderMap[col][row] = true;
        col += 2; // skip next col to avoid adjacent bars
      } else {
        col++;
      }
    }
  }

  // Compute assignments by following each column
  assignments = players.map((_, startCol) => {
    let col = startCol;
    for (let row = 0; row < ROWS; row++) {
      if (ladderMap[col][row]) {
        col++;
      } else if (col > 0 && ladderMap[col - 1][row]) {
        col--;
      }
    }
    return col;
  });

  renderPlayerNames();
  renderResultNames();
  drawLadder(null);
  $('result-panel').innerHTML = '';
}

function resetGame() {
  buildGame();
}

// ── Name rows ─────────────────────────────────────────────────────────────
function renderPlayerNames() {
  const row = $('player-names');
  row.innerHTML = '';
  const n = players.length;
  players.forEach((name, i) => {
    const box = document.createElement('div');
    box.className = 'name-box';
    box.id = `player-box-${i}`;
    box.style.width = COL_W + 'px';
    box.innerHTML = `<div class="label">${name}</div>`;
    box.onclick = () => animatePlayer(i);
    row.appendChild(box);
  });
}

function renderResultNames() {
  const row = $('result-names');
  row.innerHTML = '';
  results.forEach((name, i) => {
    const box = document.createElement('div');
    box.className = 'name-box';
    box.id = `result-box-${i}`;
    box.style.width = COL_W + 'px';
    box.innerHTML = `<div class="label">${name}</div>`;
    row.appendChild(box);
  });
}

// ── Canvas drawing ─────────────────────────────────────────────────────────
function getCanvas() {
  const canvas = $('ladder-canvas');
  const n = players.length;
  canvas.width = n * COL_W;
  canvas.height = ROWS * ROW_H;
  return canvas;
}

function colX(col) {
  return col * COL_W + COL_W / 2;
}

function drawLadder(highlight) {
  // highlight: { path: [{col, row}, ...], color }
  const canvas = getCanvas();
  const ctx = canvas.getContext('2d');
  const n = players.length;

  ctx.clearRect(0, 0, canvas.width, canvas.height);

  // Vertical lines
  ctx.strokeStyle = '#334';
  ctx.lineWidth = LINE_W;
  for (let col = 0; col < n; col++) {
    ctx.beginPath();
    ctx.moveTo(colX(col), 0);
    ctx.lineTo(colX(col), canvas.height);
    ctx.stroke();
  }

  // Horizontal bars
  ctx.strokeStyle = '#445';
  ctx.lineWidth = LINE_W;
  for (let col = 0; col < n - 1; col++) {
    for (let row = 0; row < ROWS; row++) {
      if (ladderMap[col][row]) {
        const y = row * ROW_H + ROW_H / 2;
        ctx.beginPath();
        ctx.moveTo(colX(col), y);
        ctx.lineTo(colX(col + 1), y);
        ctx.stroke();
      }
    }
  }

  // Draw highlight path
  if (highlight) {
    ctx.strokeStyle = highlight.color;
    ctx.lineWidth = LINE_W + 2;
    ctx.shadowColor = highlight.color;
    ctx.shadowBlur = 10;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    const path = highlight.path;
    if (path.length > 0) {
      ctx.beginPath();
      const first = path[0];
      ctx.moveTo(colX(first.col), first.y0);
      for (const seg of path) {
        ctx.lineTo(colX(seg.col), seg.y1);
        if (seg.nextCol !== undefined) {
          ctx.lineTo(colX(seg.nextCol), seg.y1);
        }
      }
      ctx.stroke();
    }
    ctx.shadowBlur = 0;
  }
}

// ── Animation ──────────────────────────────────────────────────────────────
function buildPath(startCol) {
  // Returns array of segments for drawing animation
  const segs = [];
  let col = startCol;
  for (let row = 0; row < ROWS; row++) {
    const y0 = row * ROW_H + (row === 0 ? 0 : ROW_H / 2);
    const y1 = row * ROW_H + ROW_H / 2;
    segs.push({ col, y0, y1, nextCol: undefined });

    if (ladderMap[col][row]) {
      const y = row * ROW_H + ROW_H / 2;
      segs.push({ col, y0: y, y1: y, nextCol: col + 1 });
      col++;
    } else if (col > 0 && ladderMap[col - 1][row]) {
      const y = row * ROW_H + ROW_H / 2;
      segs.push({ col, y0: y, y1: y, nextCol: col - 1 });
      col--;
    }
  }
  // Final segment to bottom
  const lastRow = ROWS - 1;
  segs.push({ col, y0: lastRow * ROW_H + ROW_H / 2, y1: ROWS * ROW_H });
  return { segs, finalCol: col };
}

function animatePlayer(playerIdx) {
  if (animating) return;
  if (revealed[playerIdx]) {
    // Already revealed — just highlight
    const { segs, finalCol } = buildPath(playerIdx);
    drawLadder({ path: segs, color: '#a855f7' });
    highlightBoxes(playerIdx, finalCol);
    return;
  }

  animating = true;
  const box = $(`player-box-${playerIdx}`);
  box.classList.add('active');

  const { segs, finalCol } = buildPath(playerIdx);
  const color = '#a855f7';
  let stepIdx = 0;

  const tick = () => {
    drawLadder({ path: segs.slice(0, stepIdx + 1), color });
    stepIdx++;
    if (stepIdx < segs.length) {
      setTimeout(tick, ANIM_STEP_MS);
    } else {
      // Done
      animating = false;
      box.classList.remove('active');
      revealed[playerIdx] = true;
      highlightBoxes(playerIdx, finalCol);
      showResultCard(playerIdx, finalCol);
    }
  };
  tick();
}

function highlightBoxes(playerIdx, resultIdx) {
  $(`player-box-${playerIdx}`).classList.add('revealed');
  $(`result-box-${resultIdx}`).classList.add('revealed');
}

function showResultCard(playerIdx, resultIdx) {
  const panel = $('result-panel');
  // Avoid duplicates
  if (panel.querySelector(`[data-player="${playerIdx}"]`)) return;

  const card = document.createElement('div');
  card.className = 'result-card';
  card.dataset.player = playerIdx;
  card.innerHTML = `
    <div class="player-name">${players[playerIdx]}</div>
    <div class="arrow">↓</div>
    <div class="result-name">${results[resultIdx]}</div>
  `;
  panel.appendChild(card);
}

function revealAll() {
  if (animating) return;
  players.forEach((_, i) => {
    if (!revealed[i]) {
      revealed[i] = true;
      const finalCol = assignments[i];
      highlightBoxes(i, finalCol);
      showResultCard(i, finalCol);
    }
  });
  drawLadder(null);
}

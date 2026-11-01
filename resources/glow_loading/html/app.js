'use strict';

const $ = (id) => document.getElementById(id);

function element(tag, className, text) {
  const el = document.createElement(tag);
  if (className) el.className = className;
  if (text !== undefined) el.textContent = text;
  return el;
}

function buildKeys() {
  for (const [key, label] of KEYS) {
    const row = element('div', 'key');
    row.append(element('kbd', '', key), element('span', '', label));
    $('keys').append(row);
  }
}

// The list is drawn twice so the scroll loops with no visible jump
function buildCredits() {
  const roll = $('credits-roll');
  let count = 0;
  for (let copy = 0; copy < 2; copy++) {
    for (const { section, items } of CREDITS) {
      roll.append(element('div', 'credit-section', section));
      for (const [name, author] of items) {
        const row = element('div', 'credit');
        row.append(element('div', 'credit-name', name), element('div', 'credit-author', author));
        roll.append(row);
        if (copy === 0) count++;
      }
    }
  }
  roll.style.setProperty('--roll-time', `${Math.max(30, count * 3.5)}s`);
}

/* ------------------------------ progress */
const PHASES = {
  startInitFunctionOrder: 'Starting up',
  startDataFileEntries: 'Loading game data',
  performMapLoadFunction: 'Loading the map',
};

let best = 0;

function setProgress(fraction) {
  // FiveM reports each loading phase separately, so the bar only ever moves forward
  best = Math.max(best, Math.min(1, fraction));
  const percent = Math.round(best * 100);
  $('bar-fill').style.width = `${percent}%`;
  $('percent').textContent = `${percent}%`;
}

window.addEventListener('message', ({ data }) => {
  if (data.eventName === 'loadProgress') {
    setProgress(data.loadFraction);
  } else if (data.eventName === 'onLogLine') {
    $('status').textContent = data.message;
  } else if (PHASES[data.eventName]) {
    $('status').textContent = PHASES[data.eventName];
  }
});

$('name').textContent = SERVER_NAME;
$('tagline').textContent = SERVER_TAGLINE;
buildKeys();
buildCredits();

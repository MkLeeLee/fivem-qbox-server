'use strict';

const $ = (id) => document.getElementById(id);
const SVG_NS = 'http://www.w3.org/2000/svg';

function svg(tag, attrs, text) {
  const el = document.createElementNS(SVG_NS, tag);
  for (const [key, value] of Object.entries(attrs)) el.setAttribute(key, value);
  if (text !== undefined) el.textContent = text;
  return el;
}

function setText(el, value) {
  const text = String(value);
  if (el.textContent !== text) el.textContent = text;
}

/* ------------------------------ gauge geometry */
const CENTER = 200;
const SWEEP_START = -135; // degrees clockwise from the top; RPM 0 sits here
const SWEEP = 270;

function polar(radius, degrees) {
  const rad = (degrees - 90) * Math.PI / 180;
  return [CENTER + radius * Math.cos(rad), CENTER + radius * Math.sin(rad)];
}

function arcPath(radius) {
  const [x1, y1] = polar(radius, SWEEP_START);
  const [x2, y2] = polar(radius, SWEEP_START + SWEEP);
  return `M${x1} ${y1}A${radius} ${radius} 0 1 1 ${x2} ${y2}`;
}

function setArc(el, percent) {
  el.setAttribute('stroke-dasharray', `${percent} 100`);
}

function buildGauge() {
  $('fuel-track').setAttribute('d', arcPath(190));
  $('fuel-arc').setAttribute('d', arcPath(190));
  $('rpm-track').setAttribute('d', arcPath(158));
  $('rpm-arc').setAttribute('d', arcPath(158));

  const ticks = $('ticks');
  for (let i = 0; i <= 10; i++) {
    const angle = SWEEP_START + SWEEP * i / 10;
    const [x1, y1] = polar(150, angle);
    const [x2, y2] = polar(168, angle);
    const [lx, ly] = polar(128, angle);
    ticks.append(svg('line', { x1, y1, x2, y2, class: 'tick' }));
    ticks.append(svg('text', { x: lx, y: ly, class: 'tick-label' }, i));
  }
}

/* ------------------------------ status bars */
function buildArmor() {
  const bar = $('armor-bar');
  for (let i = 0; i < 5; i++) bar.append(document.createElement('i'));
}

function setArmor(value) {
  [...$('armor-bar').children].forEach((segment, i) => {
    const fill = Math.max(0, Math.min(1, (value - i * 20) / 20)) * 100;
    segment.style.setProperty('--fill', `${fill}%`);
  });
  setText($('armor-value'), Math.round(value));
}

function setPlayer(data) {
  setArmor(data.armor);
  setText($('health-value'), Math.round(data.health));
  $('health-bar').style.width = `${data.health}%`;
  $('health-bar').parentElement.parentElement.classList.toggle('low', data.health <= 25);

  for (const name of ['hunger', 'thirst', 'stress', 'stamina']) {
    const bar = $(`${name}-bar`);
    bar.style.height = `${data[name]}%`;
    const low = name === 'stress' ? data[name] >= 75 : name !== 'stamina' && data[name] <= 15;
    bar.closest('.need').classList.toggle('alert', low);
  }

  $('voice').classList.toggle('talking', data.talking);
  // pma-voice ranges are 3, 8 and 15 metres by default
  const level = data.voiceRange <= 0 ? 0 : data.voiceRange <= 3 ? 1 : data.voiceRange <= 8 ? 2 : 3;
  [...$('voice-range').children].forEach((dot, i) => dot.classList.toggle('on', i < level));
}

function buildVoice() {
  const peaks = [35, 60, 85, 50, 100, 70, 40, 90, 55, 75, 30, 65];
  peaks.forEach((peak, i) => {
    const bar = document.createElement('i');
    bar.style.setProperty('--peak', `${peak}%`);
    bar.style.animationDelay = `${-i * 0.11}s`;
    $('wave').append(bar);
  });
  for (let i = 0; i < 3; i++) $('voice-range').append(document.createElement('i'));
}

/* ------------------------------ indicators */
function setIndicator(el, state) {
  if (el.dataset.state !== state) {
    el.dataset.state = state;
    el.className = `indicator ${state}`;
  }
}

function levelState(value, warnBelow, badBelow) {
  if (value < badBelow) return 'bad';
  return value < warnBelow ? 'warn' : 'ok';
}

/* ------------------------------ car */
function setCar(data) {
  setText($('speed'), Math.round(data.speed));
  setText($('unit'), data.unit);

  const rpm = Math.max(0, Math.min(1, data.rpm));
  setArc($('rpm-arc'), rpm * 100);
  $('rpm-arc').classList.toggle('red', rpm > 0.9);

  setArc($('fuel-arc'), data.fuel);
  $('fuel-arc').classList.toggle('low', data.fuel < 20);

  $('bolt').classList.toggle('on', data.running);
  $('flame').classList.toggle('on', rpm > 0.9);

  setIndicator($('ind-fuel'), levelState(data.fuel, 20, 8));
  setIndicator($('ind-eng'), data.running ? levelState(data.engine, 50, 25) : 'off');
  setIndicator($('ind-seat'), !data.hasBelt ? 'off' : data.belt ? 'ok' : 'warn');
  setIndicator($('ind-light'), data.lights ? 'ok' : 'off');
}

/* ------------------------------ flight instruments */
const PITCH_PX = 5.5; // ADI units per degree of pitch
const TAPE_HALF_PX = 120;

function buildAdi() {
  const ladder = $('ladder');
  for (const deg of [-30, -20, -10, 10, 20, 30]) {
    const y = -deg * PITCH_PX;
    const half = Math.abs(deg) % 20 === 0 ? 50 : 30;
    ladder.append(svg('line', { x1: -half, x2: half, y1: y, y2: y, class: 'ladder-line' }));
    ladder.append(svg('text', { x: -half - 16, y, class: 'ladder-label' }, Math.abs(deg)));
    ladder.append(svg('text', { x: half + 16, y, class: 'ladder-label' }, Math.abs(deg)));
  }
  const bank = $('adi-bank');
  for (const deg of [-60, -45, -30, -20, -10, 10, 20, 30, 45, 60]) {
    const rad = (deg - 90) * Math.PI / 180;
    const inner = Math.abs(deg) % 30 === 0 ? 108 : 116;
    bank.append(svg('line', {
      x1: inner * Math.cos(rad), y1: inner * Math.sin(rad),
      x2: 126 * Math.cos(rad), y2: 126 * Math.sin(rad),
      class: 'bank-tick',
    }));
  }
}

// Draws only the ticks in view, so the tape can cover any range
function renderTape(id, value, labelStep, minorStep, pxPerUnit) {
  const tape = $(id);
  const range = TAPE_HALF_PX / pxPerUnit;
  const first = Math.ceil(Math.max(0, value - range) / minorStep) * minorStep;
  let html = '';
  for (let v = first; v <= value + range; v += minorStep) {
    const major = v % labelStep === 0;
    const y = (value - v) * pxPerUnit + TAPE_HALF_PX;
    html += `<div class="tape-row${major ? ' major' : ''}" style="top:calc(var(--u)*${y.toFixed(1)})">`
      + (major ? `<span>${v}</span>` : '') + '</div>';
  }
  tape.innerHTML = `${html}<div class="tape-value">${Math.round(value)}</div>`;
}

function setAir(data) {
  renderTape('speed-tape', Math.max(0, data.speed), 10, 2, 5);
  renderTape('altitude-tape', Math.max(0, data.altitude), 100, 20, 0.5);
  setText($('agl-value'), Math.round(Math.max(0, data.agl)));

  const world = `rotate(${-data.roll}) translate(0 ${data.pitch * PITCH_PX})`;
  $('adi-world').setAttribute('transform', world);
  $('adi-bank').setAttribute('transform', `rotate(${-data.roll})`);

  setIndicator($('ind-gear'), { down: 'ok', up: 'off', moving: 'warn', none: 'off' }[data.gear]);
  setIndicator($('ind-air-eng'), data.running ? levelState(data.engine, 50, 25) : 'off');
}

/* ------------------------------ messages from client.lua */
const handlers = {
  visible: (data) => $('hud').classList.toggle('hidden', !data.show),
  mode: (data) => {
    $('speedo').classList.toggle('panel-hidden', data.mode !== 'car');
    $('flight').classList.toggle('panel-hidden', data.mode !== 'air');
  },
  anchor: (data) => {
    const stats = $('stats').style;
    stats.setProperty('--map-left', `${data.left * 100}vw`);
    stats.setProperty('--map-width', `${data.width * 100}vw`);
    stats.setProperty('--map-bottom', `${data.bottom * 100}vh`);
  },
  player: setPlayer,
  car: setCar,
  air: setAir,
  location: (data) => {
    setText($('direction'), data.direction);
    setText($('street'), data.street);
    setText($('area'), data.area);
  },
};

window.addEventListener('message', (event) => {
  const handler = handlers[event.data.action];
  if (handler) handler(event.data);
});

buildGauge();
buildArmor();
buildVoice();
buildAdi();

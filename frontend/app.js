const icons = {
  search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 4 4"/>',
  pin: '<path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>',
  heart: '<path d="M20.8 5.9a5 5 0 0 0-7 0L12 7.7l-1.8-1.8a5 5 0 1 0-7 7l8.8 8.4 8.8-8.4a5 5 0 0 0 0-7Z"/>',
  home: '<path d="m3 10 9-7 9 7M5 9v12h14V9M9 21v-7h6v7"/>',
  calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4m10-4v4M3 10h18"/>',
  plus: '<path d="M12 4v16M4 12h16"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  box: '<path d="m3 7 9-4 9 4v10l-9 4-9-4V7Zm0 0 9 4 9-4m-9 4v10M7.5 5l9 4"/>',
  close: '<path d="m6 6 12 12M18 6 6 18"/>',
};
const icon = name => `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true">${icons[name]}</svg>`;
const html = value => String(value ?? '').replace(/[&<>"']/g, character => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[character]));
const labels = {
  sale: 'For sale', trade: 'Trade', giveaway: 'Free', new: 'New', great: 'Like new',
  good: 'Good', fair: 'Fair', poor: 'Poor', available: 'Available', pending: 'Pending', sold: 'Sold',
};
const samples = [
  ['Retro Runner Sneakers', 120, 'sale', 'great', 'Library lobby', 'Cream and black runners, US 10. Worn twice and includes the original box and spare laces.'],
  ['Workwear Chore Coat', 85, 'sale', 'good', 'Corner café', 'Rust canvas chore coat with three front pockets. Size medium.'],
  ['Compact Digital Camera', 65, 'sale', 'good', 'Transit hub', 'Pocket-sized point-and-shoot camera with a battery, charger and SD card.'],
  ['Canvas Daypack', 0, 'trade', 'great', 'Community center', 'Forest green canvas daypack with a padded laptop sleeve. Open to trading for a small duffel.'],
  ['Mushroom Table Lamp', 35, 'sale', 'great', 'Library lobby', 'Warm orange table lamp in working condition. A bulb is included.'],
  ['Steel Field Watch', 0, 'giveaway', 'fair', 'Corner café', 'Stainless steel field watch with a black dial. It needs a fresh battery.'],
].map(([title, price, type, condition, spot, description], index) => ({
  id: `sample-${index + 1}`, title, price, type, condition, spot, description,
  status: 'available', photos: [`/assets/item-${index + 1}.jpg`],
}));
const spots = ['Library lobby', 'Corner café', 'Transit hub', 'Community center'];
const demo = new URLSearchParams(location.search).get('demo') === '1';
const main = document.querySelector('#main');
const dialog = document.querySelector('#dialog');
const account = document.querySelector('#account');
const toast = document.querySelector('#toast');
const read = (key, fallback, storage = localStorage) => {
  try { return JSON.parse(storage.getItem(`listings:${key}`)) ?? fallback; }
  catch { return fallback; }
};
function write(key, value, storage = localStorage) {
  storage.setItem(`listings:${key}`, JSON.stringify(value));
}
const state = {
  user: demo ? null : read('user', null, sessionStorage),
  saved: new Set(read('saved', [])),
  plans: read('plans', []),
  listings: demo ? samples : [],
  busy: !demo,
  offline: false,
  filter: 'all',
  query: '',
  sort: 'newest',
};
let navigation = 0;
let toastTimer;
let loadVersion = 0;
let activeDialog;

async function api(path, options) {
  let response;
  try { response = await fetch(`/v1${path}`, { ...options, cache: 'no-store' }); }
  catch { throw new Error('Could not reach the listings API. Try again.'); }
  if (response.status === 204) return;
  const result = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(result.error || 'The listings API could not complete the request.');
  return result.data;
}

async function loadListings() {
  const version = ++loadVersion;
  state.busy = true;
  if (route().name !== 'item') render();
  try {
    const listings = await api('/listings');
    if (version !== loadVersion) return;
    state.listings = listings;
    state.offline = false;
  } catch {
    if (version !== loadVersion) return;
    state.offline = true;
    state.listings = samples;
  } finally {
    if (version === loadVersion) {
      state.busy = false;
      if (route().name !== 'item') render();
    }
  }
}

function route() {
  const [name, id] = location.hash.slice(1).split('/');
  try { return { name: name || 'browse', id: decodeURIComponent(id || '') }; }
  catch { return { name: 'browse' }; }
}
function note(message) {
  toast.textContent = message;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { toast.textContent = ''; }, 3600);
}
function media(item, index = 0, badge = false) {
  let photo = item.photos?.[index];
  if (photo) {
    try {
      const url = new URL(photo, location.origin);
      // Use the same-origin proxy for Go photo URLs, including absolute URLs.
      photo = url.pathname.startsWith('/v1/photos/') || url.pathname.startsWith('/assets/') ? url.pathname : '';
    } catch { photo = ''; }
  }
  return `<div class="media">${icon('box')}
    ${photo ? `<img src="${html(photo)}" alt="${html(item.title)}" ${badge ? 'loading="lazy"' : ''}>` : ''}
    ${badge ? `<span class="badge">${html(labels[item.status === 'available' ? item.type : item.status])}</span>` : ''}
  </div>`;
}
function saveButton(item, text = false) {
  const saved = state.saved.has(item.id);
  return `<button class="${text ? 'button' : 'icon-button'} save" data-action="save" data-id="${html(item.id)}" aria-pressed="${saved}" aria-label="${saved ? 'Remove from saved' : 'Save listing'}">${icon('heart')}${text ? (saved ? 'Saved' : 'Save') : ''}</button>`;
}
function card(item) {
  return `<article class="card">
    <a class="card-link" href="#item/${html(encodeURIComponent(item.id))}">
      ${media(item, 0, true)}
      <div class="card-copy">
        ${item.price ? `<strong class="card-price">$${item.price}</strong>` : ''}
        <h3>${html(item.title)}</h3>
        <p>${html(labels[item.condition])}${item.spot ? ` · ${html(item.spot)}` : ''}</p>
      </div>
    </a>${saveButton(item)}
  </article>`;
}
function empty(title, copy, action = '') {
  return `<div class="empty"><h3>${title}</h3><p>${copy}</p>${action}</div>`;
}
function notice() {
  if (state.busy) return '<div class="notice" role="status">Loading listings…</div>';
  if (demo) return '<div class="notice">Demo mode · Sample listings <a class="text-button" href="/#browse">Open live marketplace</a></div>';
  if (state.offline) return '<div class="notice" role="status">The API is offline. Showing sample listings. <button data-action="retry">Retry connection</button></div>';
  return '';
}
function chips() {
  return [['all', 'All listings'], ['sale', 'For sale'], ['trade', 'Trades'], ['giveaway', 'Free']]
    .map(([value, label]) => `<button class="chip" data-action="filter" data-value="${value}" aria-pressed="${state.filter === value}">${label}</button>`).join('');
}
function results() {
  const query = state.query.trim().toLowerCase();
  const items = state.listings.filter(item => (state.filter === 'all' || item.type === state.filter)
    && `${item.title} ${item.description ?? ''} ${item.spot ?? ''}`.toLowerCase().includes(query));
  if (state.sort === 'title') items.sort((a, b) => a.title.localeCompare(b.title));
  if (state.sort === 'oldest') items.reverse();
  return `<div class="section-head"><h2>Fresh finds</h2><p class="count" aria-live="polite">${items.length} ${items.length === 1 ? 'listing' : 'listings'}</p></div>
    ${items.length ? `<div class="grid">${items.map(card).join('')}</div>`
      : state.busy ? '' : empty('No listings found', 'Try another search or browse all listings.', '<button class="button" data-action="reset">Clear filters</button>')}`;
}
function browse() {
  return `<section class="hero">
    <div class="hero-copy">
      <div class="kicker">${icon('pin')} The local marketplace</div>
      <h1>Find it. Meet up.<br>Done.</h1>
      <p>Buy, trade, and give things away in person.</p>
      <form class="search" id="search" role="search">
        ${icon('search')}<input aria-label="Search listings" name="query" type="search" placeholder="Search listings" value="${html(state.query)}">
        <button class="button dark" type="submit">Search</button>
      </form>
    </div>
    <div class="hero-art" aria-hidden="true">
      <svg viewBox="0 0 420 340" fill="none" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="226" cy="171" rx="153" ry="123" fill="#ffe771" transform="rotate(-17 226 171)"/>
        <path d="M28 270c60-36 99-1 155-49s-24-116 56-145c46-17 86 18 147-29" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-dasharray="3 9"/>
        <path d="M111 105 216 70l95 52-104 38-96-55Z" fill="#fff9d8" stroke="currentColor" stroke-width="3" stroke-linejoin="round"/>
        <path d="M111 105v101l96 58V160l-96-55Z" fill="#edab2e" stroke="currentColor" stroke-width="3" stroke-linejoin="round"/>
        <path d="M207 160v104l104-39V122l-104 38Z" fill="#fbc84a" stroke="currentColor" stroke-width="3" stroke-linejoin="round"/>
        <path d="m152 91 97 54v33l24-9v-33l-96-54M134 202l44 26" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
        <path d="M355 154c-18 0-33 14-33 32 0 25 33 51 33 51s33-26 33-51c0-18-15-32-33-32Z" fill="currentColor"/>
        <circle cx="355" cy="186" r="12" fill="#ffe771"/>
        <path d="M82 64v28m-14-14h28m229-40v25m-12.5-12.5h25M306 274v28m-14-14h28" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
      </svg>
    </div>
  </section>
  <div class="browse-controls"><div class="chips" aria-label="Listing type">${chips()}</div>
    <select class="select" id="sort" aria-label="Sort listings">
      ${[['newest', 'Newest first'], ['oldest', 'Oldest first'], ['title', 'Title A–Z']].map(([value, label]) => `<option value="${value}" ${state.sort === value ? 'selected' : ''}>${label}</option>`).join('')}
    </select>
  </div>
  ${notice()}
  <section id="results" aria-label="Listings">${results()}</section>`;
}
function detail(item, index = 0) {
  const owner = state.user?.id && item.user_id === state.user.id;
  return `<section class="page">
    <a class="text-button" href="#browse">Back to explore</a>
    <div class="detail">
      <div>
        <div id="detail-photo">${media(item, index)}</div>
        ${item.photos?.length > 1 ? `<div class="thumbs">${item.photos.map((_, i) =>
          `<button class="thumb" data-action="photo" data-index="${i}" aria-label="Photo ${i + 1}" aria-pressed="${i === index}">${media(item, i)}</button>`).join('')}</div>` : ''}
      </div>
      <div class="detail-copy">
        <span class="badge">${item.id.startsWith('sample-') ? 'Sample listing' : html(labels[item.status])}</span>
        <h1 class="page-title">${html(item.title)}</h1>
        ${item.price ? `<strong class="card-price">$${item.price}</strong>` : ''}
        <p class="muted">${html(labels[item.type])} · ${html(labels[item.condition])}${item.spot ? ` · ${html(item.spot)}` : ''}</p>
        <h2>About this item</h2>
        <p class="description">${html(item.description || 'No description provided.')}</p>
        <div class="row-actions">
          ${owner ? '<button class="button dark" data-action="edit">Edit listing</button><button class="button" data-action="delete">Delete</button>'
            : item.status === 'available' ? `<button class="button yellow" data-action="plan">${icon('calendar')} Plan a meetup</button>` : ''}
          ${saveButton(item, true)}
        </div>
      </div>
    </div>
  </section>`;
}
let currentItem;
function render() {
  const { name, id } = route();
  const version = ++navigation;
  currentItem = null;
  account.textContent = state.user ? 'My account' : 'Sign in';
  document.querySelector('#mobile-nav').innerHTML = [
    ['browse', 'Explore', 'home'], ['saved', 'Saved', 'heart'], ['sell', 'Sell', 'plus'],
    ['meetups', 'Meetups', 'calendar'], ['account', 'Account', 'user'],
  ].map(([key, title, symbol]) => key === 'sell' || key === 'account'
    ? `<button data-action="${key}">${icon(symbol)}${title}</button>`
    : `<a href="#${key}" ${name === key ? 'aria-current="page"' : ''}>${icon(symbol)}${title}</a>`).join('');
  for (const link of document.querySelectorAll('.desktop-nav a')) {
    if (link.hash === `#${name}`) link.setAttribute('aria-current', 'page');
    else link.removeAttribute('aria-current');
  }
  if (name === 'item') {
    const sample = samples.find(item => item.id === id);
    if (sample && (demo || state.offline || state.busy)) {
      currentItem = sample;
      main.innerHTML = detail(sample);
      return;
    }
    main.innerHTML = '<section class="page" role="status">Loading listing…</section>';
    api(`/listings/${encodeURIComponent(id)}`).then(item => {
      if (version !== navigation) return;
      currentItem = item;
      main.innerHTML = detail(item);
    }).catch(error => {
      if (version === navigation) main.innerHTML = `<section class="page">${empty('Listing unavailable', html(error.message), '<a class="button" href="#browse">Back to explore</a>')}</section>`;
    });
    return;
  }
  if (name === 'saved' || name === 'mine') {
    const mine = name === 'mine';
    const items = mine ? state.listings.filter(item => state.user && item.user_id === state.user.id)
      : state.listings.filter(item => state.saved.has(item.id));
    main.innerHTML = `<section class="page"><h1 class="page-title">${mine ? 'My listings' : 'Saved listings'}</h1>
      ${notice()}${items.length ? `<div class="grid">${items.map(card).join('')}</div>` : empty(
        mine ? 'No listings yet' : 'No saved listings yet',
        mine ? 'Post an item to start selling, trading, or giving it away.' : 'Tap the heart on a listing to save it on this device.',
        mine ? '<button class="button dark" data-action="sell">Post listing</button>' : '<a class="button" href="#browse">Explore listings</a>',
      )}</section>`;
    return;
  }
  if (name === 'meetups') {
    main.innerHTML = `<section class="page"><h1 class="page-title">Meetup plans</h1>
      <p class="muted">Plans are saved on this device. Arrange the meetup with the seller separately.</p>
      ${state.plans.length ? state.plans.map(plan => `<article class="meetup-card">
        <div><h3>${html(plan.title)}</h3><p>${html(new Date(plan.when).toLocaleString())} · ${html(plan.spot)}</p></div>
        <button class="button" data-action="remove-plan" data-id="${html(plan.id)}">Remove</button>
      </article>`).join('') : `<div class="section-head"></div>${empty('No meetup plans yet', 'Open an available listing to make a plan.', '<a class="button" href="#browse">Explore listings</a>')}`}
    </section>`;
    return;
  }
  main.innerHTML = browse();
}
function modal(title, body, submit) {
  activeDialog = { submit };
  dialog.innerHTML = `<div class="dialog-head"><h2 id="dialog-title">${title}</h2>
    <button class="icon-button" data-action="close" aria-label="Close">${icon('close')}</button></div>${body}`;
  if (!dialog.open) dialog.showModal();
}
function closeModal() {
  activeDialog = null;
  dialog.close();
}
function form(fields, button) {
  return `<form class="stack">${fields}<p class="form-error" role="alert"></p>
    <button class="button dark" type="submit">${button}</button></form>`;
}
function auth(register = false, after) {
  if (demo || state.offline) {
    modal('Account access', `<p class="muted">The live API is needed to sign in, register, and publish listings.</p>
      <div class="section-head">${demo ? '<a class="button dark" href="/#browse">Open live marketplace</a>' : '<button class="button dark" data-action="retry">Retry connection</button>'}</div>`);
    return;
  }
  const heading = register ? 'Create an account' : 'Sign in';
  modal(heading, form(`
    <label>Email<input type="email" name="email" autocomplete="email" required></label>
    <label>Password<input type="password" name="password" autocomplete="${register ? 'new-password' : 'current-password'}" ${register ? 'minlength="8" maxlength="72"' : ''} required></label>
    <button type="button" class="text-button" data-action="${register ? 'signin' : 'register'}">${register ? 'Already registered? Sign in' : 'New here? Create an account'}</button>`, heading), async data => {
    const user = await api(register ? '/users' : '/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(Object.fromEntries(data)),
    });
    state.user = { id: user.id, email: user.email };
    write('user', state.user, sessionStorage);
    closeModal();
    render();
    note(register ? 'Account created' : 'Signed in');
    after?.();
  });
  activeDialog.afterAuth = after;
}
function showAccount() {
  if (!state.user) return auth();
  modal('My account', `<p class="description">${html(state.user.email)}</p><div class="row-actions">
    <a href="#mine" class="button dark" data-action="my-listings">My listings</a>
    <button class="button" data-action="signout">Sign out</button></div>`);
}
function selectField(label, name, values, selected) {
  return `<label>${label}<select class="select" name="${name}">${values.map(value =>
    `<option value="${value}" ${value === selected ? 'selected' : ''}>${labels[value]}</option>`).join('')}</select></label>`;
}
function listingEditor(item) {
  if (!state.user || demo || state.offline) return auth(false, () => listingEditor(item));
  const edit = Boolean(item);
  modal(edit ? 'Edit listing' : 'New listing', form(`
    <label>Title<input name="title" value="${html(item?.title)}" required></label>
    <div class="form-row">
      ${selectField('Listing type', 'type', ['sale', 'trade', 'giveaway'], item?.type)}
      ${selectField('Condition', 'condition', ['new', 'great', 'good', 'fair', 'poor'], item?.condition || 'good')}
    </div>
    <label>Description<textarea name="description">${html(item?.description)}</textarea></label>
    ${selectField('Status', 'status', ['available', 'pending', 'sold'], item?.status)}
    <label>${edit ? 'Replace photos' : 'Photos'}<input name="photos" type="file" accept="image/jpeg,.jpg,.jpeg" multiple aria-describedby="photo-hint"></label>
    <p class="muted" id="photo-hint">Up to 5 JPEG photos, 10 MB each.${edit ? ' Leave blank to keep existing photos.' : ''}</p>
    ${edit && item.photos?.length ? '<label class="check"><input type="checkbox" name="clear_photos" value="true">Remove existing photos</label>' : ''}
  `, edit ? 'Save changes' : 'Publish listing'), async data => {
    const photos = data.getAll('photos').filter(file => file.name);
    if (photos.length > 5 || photos.some(file => file.size > 10 * 1024 * 1024)) {
      throw new Error('Choose up to 5 photos, each 10 MB or smaller.');
    }
    if (photos.length && data.has('clear_photos')) throw new Error('Choose whether to replace or remove the photos.');
    data.delete('photos');
    photos.forEach(file => data.append('photos', file));
    if (!edit) data.set('user_id', state.user.id);
    const saved = await api(edit ? `/listings/${encodeURIComponent(item.id)}` : '/listings', {
      method: edit ? 'PUT' : 'POST', body: data,
    });
    closeModal();
    note(edit ? 'Listing updated' : 'Listing published');
    const target = `#item/${encodeURIComponent(saved.id)}`;
    if (location.hash === target) render();
    else location.hash = target;
    void loadListings();
  });
}
function deleteListing(item) {
  modal('Delete listing?', form(`<p>“${html(item.title)}” and its photos will be removed.</p>`, 'Delete listing'), async () => {
    await api(`/listings/${encodeURIComponent(item.id)}`, { method: 'DELETE' });
    state.saved.delete(item.id);
    write('saved', [...state.saved]);
    closeModal();
    note('Listing deleted');
    location.hash = '#mine';
    void loadListings();
  });
}
function planMeetup(item) {
  modal('Plan a meetup', form(`
    <p><strong>${html(item.title)}</strong></p>
    <p class="muted">Save a date and public meeting spot on this device. Contact the seller separately to confirm.</p>
    <label>Date and time<input name="when" type="datetime-local" required></label>
    <label>Meeting spot<select class="select" name="spot">${spots.map(spot =>
      `<option ${spot === item.spot ? 'selected' : ''}>${spot}</option>`).join('')}</select></label>
  `, 'Save meetup plan'), async data => {
    const when = new Date(data.get('when'));
    if (!(when.getTime() > Date.now())) throw new Error('Choose a date and time in the future.');
    state.plans = [...state.plans, { id: crypto.randomUUID(), title: item.title, when: when.toISOString(), spot: data.get('spot') }];
    write('plans', state.plans);
    closeModal();
    location.hash = '#meetups';
    note('Meetup plan saved');
  });
}
function updateResults() {
  const target = document.querySelector('#results');
  if (target) target.innerHTML = results();
}
document.addEventListener('error', event => {
  if (event.target instanceof HTMLImageElement) event.target.hidden = true;
}, true);
document.addEventListener('input', event => {
  if (event.target.form?.id !== 'search') return;
  state.query = event.target.value;
  updateResults();
});
document.addEventListener('change', event => {
  if (event.target.id !== 'sort') return;
  state.sort = event.target.value;
  updateResults();
});
document.addEventListener('submit', async event => {
  if (event.target.id === 'search') {
    event.preventDefault();
    updateResults();
    return;
  }
  if (!dialog.contains(event.target) || !activeDialog?.submit) return;
  event.preventDefault();
  const button = event.target.querySelector('[type=submit]');
  if (button.disabled) return;
  const operation = activeDialog;
  const error = event.target.querySelector('.form-error');
  error.textContent = '';
  button.disabled = true;
  try { await operation.submit(new FormData(event.target)); }
  catch (failure) { error.textContent = failure.message; }
  finally { button.disabled = false; }
});
dialog.addEventListener('cancel', event => {
  event.preventDefault();
  if (!dialog.querySelector('[type=submit]:disabled')) closeModal();
});
document.addEventListener('click', event => {
  if (event.target.closest('#account')) return showAccount();
  const button = event.target.closest('[data-action]');
  if (!button) return;
  if (dialog.contains(button) && dialog.querySelector('[type=submit]:disabled')) return;
  const { action, id, value, index } = button.dataset;
  switch (action) {
    case 'close': case 'my-listings': closeModal(); break;
    case 'account': showAccount(); break;
    case 'signin': case 'register': auth(action === 'register', activeDialog?.afterAuth); break;
    case 'signout':
      state.user = null;
      write('user', null, sessionStorage);
      closeModal();
      if (route().name === 'mine') location.hash = '#browse';
      else render();
      note('Signed out');
      break;
    case 'sell': listingEditor(); break;
    case 'edit': if (currentItem && currentItem.user_id === state.user?.id && state.user) listingEditor(currentItem); break;
    case 'delete': if (currentItem && currentItem.user_id === state.user?.id && state.user) deleteListing(currentItem); break;
    case 'plan': if (currentItem) planMeetup(currentItem); break;
    case 'retry': if (dialog.open) closeModal(); void loadListings(); break;
    case 'filter':
      state.filter = value;
      for (const chip of document.querySelectorAll('[data-action=filter]')) {
        chip.setAttribute('aria-pressed', String(chip === button));
      }
      updateResults();
      break;
    case 'reset':
      state.query = '';
      state.filter = 'all';
      render();
      document.querySelector('#search input')?.focus();
      break;
    case 'photo':
      if (!currentItem) break;
      document.querySelector('#detail-photo').innerHTML = media(currentItem, Number(index));
      for (const thumb of document.querySelectorAll('.thumb')) thumb.setAttribute('aria-pressed', String(thumb === button));
      break;
    case 'save': {
      const saved = !state.saved.has(id);
      if (saved) state.saved.add(id);
      else state.saved.delete(id);
      write('saved', [...state.saved]);
      if (route().name === 'saved') render();
      else {
        button.setAttribute('aria-pressed', String(saved));
        button.setAttribute('aria-label', saved ? 'Remove from saved' : 'Save listing');
        if (button.classList.contains('button')) button.innerHTML = icon('heart') + (saved ? 'Saved' : 'Save');
      }
      note(saved ? 'Listing saved' : 'Removed from saved');
      break;
    }
    case 'remove-plan':
      state.plans = state.plans.filter(plan => plan.id !== id);
      write('plans', state.plans);
      render();
      note('Meetup plan removed');
      break;
  }
});
window.addEventListener('hashchange', () => {
  render();
  window.scrollTo(0, 0);
});
render();
if (!demo) void loadListings();

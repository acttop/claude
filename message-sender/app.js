(() => {
  'use strict';

  /* ============================== 저장소 ============================== */
  const STORE = {
    recipients: 'msg_recipients_v1',
    templates: 'msg_templates_v1',
    history: 'msg_history_v1',
  };

  function load(key, fallback) {
    try {
      const raw = localStorage.getItem(key);
      return raw ? JSON.parse(raw) : fallback;
    } catch (e) {
      return fallback;
    }
  }

  function save(key, value) {
    localStorage.setItem(key, JSON.stringify(value));
  }

  function uid() {
    return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  }

  const DEFAULT_TEMPLATES = [
    { title: '안부 인사', category: '일상', body: '{이름}님, 안녕하세요! 잘 지내고 계신가요? 😊' },
    { title: '약속 리마인드', category: '약속', body: '{이름}님, 오늘 약속 시간과 장소 다시 확인 부탁드려요!' },
    { title: '늦음 안내', category: '약속', body: '죄송해요, 조금 늦을 것 같아요! 10분 정도만 기다려주세요 🙏' },
    { title: '도착 알림', category: '일상', body: '저 방금 도착했어요 😊' },
    { title: '확인 답장', category: '업무', body: '네, 확인했습니다. 감사합니다!' },
    { title: '회신 예정', category: '업무', body: '지금 회의 중이라 확인 후 다시 연락드리겠습니다.' },
    { title: '축하 인사', category: '감사/축하', body: '{이름}님, 진심으로 축하드려요! 🎉' },
    { title: '감사 인사', category: '감사/축하', body: '{이름}님 덕분에 큰 도움이 됐어요. 정말 감사합니다!' },
  ];

  function seedTemplates() {
    return DEFAULT_TEMPLATES.map(t => ({
      id: uid(),
      title: t.title,
      body: t.body,
      category: t.category,
      favorite: false,
      useCount: 0,
    }));
  }

  let recipients = load(STORE.recipients, []);
  let templates = load(STORE.templates, null);
  if (!templates) {
    templates = seedTemplates();
    save(STORE.templates, templates);
  }
  let history = load(STORE.history, []);

  const CATEGORIES = ['일상', '업무', '약속', '감사/축하', '기타'];

  /* ============================== 상태 ============================== */
  const state = {
    selectedRecipientIds: new Set(),
    recipientSearch: '',
    composeCategoryFilter: '전체',
    manageCategoryFilter: '전체',
    recipientListSearch: '',
    templateListSearch: '',
    recipientEditingId: null,
    templateEditingId: null,
    lastUsedTemplateId: null,
    queue: null, // { targets: [recipient|null], index, channel }
  };

  /* ============================== 유틸 ============================== */
  function $(sel) { return document.querySelector(sel); }
  function $all(sel) { return Array.from(document.querySelectorAll(sel)); }
  function el(tag, cls, html) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html !== undefined) e.innerHTML = html;
    return e;
  }
  function esc(str) {
    return String(str ?? '').replace(/[&<>"']/g, c => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[c]));
  }

  let toastTimer = null;
  function toast(msg) {
    const t = $('#toast');
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.remove('show'), 2600);
  }

  function isIOS() {
    return /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
  }

  async function copyText(text) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch (e) {
      try {
        const ta = document.createElement('textarea');
        ta.value = text;
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.focus();
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
        return true;
      } catch (e2) {
        return false;
      }
    }
  }

  function byteLength(str) {
    let bytes = 0;
    for (const ch of str) {
      bytes += ch.codePointAt(0) > 0x7f ? 2 : 1;
    }
    return bytes;
  }

  function fillVars(body, name) {
    return body.replaceAll('{이름}', name || '');
  }

  function cleanPhone(phone) {
    return (phone || '').replace(/[^\d+]/g, '');
  }

  function formatPhoneDisplay(phone) {
    const digits = cleanPhone(phone).replace('+', '');
    if (/^01\d{8,9}$/.test(digits)) {
      return digits.length === 10
        ? digits.replace(/(\d{3})(\d{3})(\d{4})/, '$1-$2-$3')
        : digits.replace(/(\d{3})(\d{4})(\d{4})/, '$1-$2-$3');
    }
    return phone;
  }

  /* ============================== 탭 전환 ============================== */
  function switchTab(screenId) {
    $all('.screen').forEach(s => s.classList.toggle('active', s.id === screenId));
    $all('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.screen === screenId));
  }

  $('#tab-bar').addEventListener('click', e => {
    const btn = e.target.closest('.tab-btn');
    if (!btn) return;
    switchTab(btn.dataset.screen);
  });

  /* ============================== 수신자: 렌더 ============================== */
  function sortedRecipients(list) {
    return [...list].sort((a, b) => {
      if (a.favorite !== b.favorite) return a.favorite ? -1 : 1;
      if (b.useCount !== a.useCount) return b.useCount - a.useCount;
      return (b.lastUsed || 0) - (a.lastUsed || 0);
    });
  }

  function renderQuickRecipients() {
    const box = $('#quick-recipients');
    box.innerHTML = '';
    const q = state.recipientSearch.trim().toLowerCase();
    let list = sortedRecipients(recipients);
    if (q) {
      list = list.filter(r => r.name.toLowerCase().includes(q) || cleanPhone(r.phone).includes(q));
    }
    $('#recipients-empty-hint').style.display = recipients.length ? 'none' : 'block';

    list.forEach(r => {
      const chip = el('div', 'chip' + (r.favorite ? ' star' : '') + (state.selectedRecipientIds.has(r.id) ? ' selected' : ''));
      chip.innerHTML = `${esc(r.name)} <span class="chip-sub">${esc(formatPhoneDisplay(r.phone))}</span>`;
      chip.addEventListener('click', () => {
        if (state.selectedRecipientIds.has(r.id)) state.selectedRecipientIds.delete(r.id);
        else state.selectedRecipientIds.add(r.id);
        renderQuickRecipients();
        renderSelectedRecipients();
      });
      box.appendChild(chip);
    });
  }

  function renderSelectedRecipients() {
    const box = $('#selected-recipients');
    box.innerHTML = '';
    const selected = recipients.filter(r => state.selectedRecipientIds.has(r.id));
    selected.forEach(r => {
      const chip = el('div', 'chip selected');
      chip.innerHTML = `${esc(r.name)} <span class="remove-x">✕</span>`;
      chip.addEventListener('click', () => {
        state.selectedRecipientIds.delete(r.id);
        renderQuickRecipients();
        renderSelectedRecipients();
      });
      box.appendChild(chip);
    });
    $('#selected-count').textContent = `${selected.length}명 선택`;
    $('#individual-queue-card').style.display = state.queue ? 'block' : 'none';
  }

  /* ============================== 문구: 렌더 ============================== */
  function renderCategoryFilter(containerSel, activeCat, onSelect) {
    const box = $(containerSel);
    box.innerHTML = '';
    ['전체', ...CATEGORIES].forEach(cat => {
      const chip = el('div', 'filter-chip' + (activeCat === cat ? ' active' : ''), esc(cat));
      chip.addEventListener('click', () => onSelect(cat));
      box.appendChild(chip);
    });
  }

  function sortedTemplates(list) {
    return [...list].sort((a, b) => {
      if (a.favorite !== b.favorite) return a.favorite ? -1 : 1;
      return b.useCount - a.useCount;
    });
  }

  function renderQuickTemplates() {
    renderCategoryFilter('#template-category-filter', state.composeCategoryFilter, cat => {
      state.composeCategoryFilter = cat;
      renderQuickTemplates();
    });

    const box = $('#quick-templates');
    box.innerHTML = '';
    let list = sortedTemplates(templates);
    if (state.composeCategoryFilter !== '전체') {
      list = list.filter(t => t.category === state.composeCategoryFilter);
    }
    $('#templates-empty-hint').style.display = templates.length ? 'none' : 'block';

    list.forEach(t => {
      const chip = el('div', 'chip' + (t.favorite ? ' star' : ''));
      chip.innerHTML = `${esc(t.title)}`;
      chip.title = t.body;
      chip.addEventListener('click', () => {
        const body = $('#message-body');
        body.value = body.value.trim() ? body.value : t.body;
        if (!body.value.trim()) body.value = t.body;
        state.lastUsedTemplateId = t.id;
        updateCharCounter();
        body.focus();
      });
      box.appendChild(chip);
    });
  }

  /* ============================== 글자수 카운터 ============================== */
  function updateCharCounter() {
    const text = $('#message-body').value;
    const chars = Array.from(text).length;
    const bytes = byteLength(text);
    const counter = $('#char-counter');
    let label;
    if (bytes === 0) label = 'SMS 단문';
    else if (bytes <= 80) label = `SMS 단문 (${bytes}/80byte)`;
    else if (bytes <= 2000) label = `LMS 장문 (${bytes}/2000byte)`;
    else label = `⚠ ${bytes}byte - 2000byte 초과`;
    counter.textContent = `${chars}자 · ${label}`;
    counter.classList.toggle('warn', bytes > 2000);
  }

  $('#message-body').addEventListener('input', updateCharCounter);

  $('#btn-insert-name').addEventListener('click', () => {
    const body = $('#message-body');
    const start = body.selectionStart ?? body.value.length;
    const end = body.selectionEnd ?? body.value.length;
    body.value = body.value.slice(0, start) + '{이름}' + body.value.slice(end);
    body.focus();
    updateCharCounter();
  });

  $('#btn-clear-body').addEventListener('click', () => {
    $('#message-body').value = '';
    state.lastUsedTemplateId = null;
    updateCharCounter();
  });

  /* ============================== 연락처 가져오기 ============================== */
  async function pickContacts() {
    if (!('contacts' in navigator && 'ContactsManager' in window)) {
      toast('이 브라우저에서는 연락처 가져오기를 지원하지 않아요 (Android Chrome 권장)');
      return;
    }
    try {
      const contacts = await navigator.contacts.select(['name', 'tel'], { multiple: true });
      let added = 0;
      contacts.forEach(c => {
        const name = (c.name && c.name[0]) || '이름없음';
        const tel = (c.tel && c.tel[0]) || '';
        if (!tel) return;
        const dup = recipients.find(r => cleanPhone(r.phone) === cleanPhone(tel));
        if (dup) return;
        recipients.push({ id: uid(), name, phone: tel, favorite: false, useCount: 0, lastUsed: 0 });
        added++;
      });
      save(STORE.recipients, recipients);
      renderAllRecipients();
      toast(added ? `${added}명을 가져왔어요` : '새로 추가된 연락처가 없어요');
    } catch (e) {
      /* 사용자 취소 */
    }
  }

  $('#btn-pick-contact').addEventListener('click', pickContacts);
  $('#btn-pick-contact-2').addEventListener('click', pickContacts);

  $('#recipient-search').addEventListener('input', e => {
    state.recipientSearch = e.target.value;
    renderQuickRecipients();
  });

  /* ============================== 발송 로직 ============================== */
  function smsUri(numbers, body) {
    const nums = numbers.filter(Boolean).map(cleanPhone).join(',');
    const sep = isIOS() ? '&' : '?';
    return `sms:${nums}${sep}body=${encodeURIComponent(body)}`;
  }

  function doSms(numbers, body) {
    window.location.href = smsUri(numbers, body);
  }

  async function doKakao(body) {
    if (navigator.share) {
      try {
        await navigator.share({ text: body });
        return;
      } catch (e) {
        if (e && e.name === 'AbortError') return;
      }
    }
    await copyText(body);
    toast('카카오톡 공유가 지원되지 않아 메시지를 복사했어요. 카카오톡에서 붙여넣어 주세요.');
  }

  function bumpRecipientUsage(r) {
    if (!r) return;
    r.useCount = (r.useCount || 0) + 1;
    r.lastUsed = Date.now();
  }

  function recordHistory(channel, targets, body) {
    const names = targets.filter(Boolean).map(t => t.name);
    history.unshift({ id: uid(), channel, recipientNames: names, body, timestamp: Date.now() });
    history = history.slice(0, 60);
    save(STORE.history, history);
    renderHistory();
  }

  function afterSendCommit(targets) {
    targets.forEach(bumpRecipientUsage);
    save(STORE.recipients, recipients);
    if (state.lastUsedTemplateId) {
      const tpl = templates.find(t => t.id === state.lastUsedTemplateId);
      if (tpl) { tpl.useCount = (tpl.useCount || 0) + 1; save(STORE.templates, templates); }
    }
    renderQuickRecipients();
  }

  function updateQueueUI() {
    const card = $('#individual-queue-card');
    if (!state.queue) { card.style.display = 'none'; return; }
    card.style.display = 'block';
    const { targets, index } = state.queue;
    $('#queue-progress').textContent = `${index + 1} / ${targets.length}`;
    $('#queue-current-name').textContent = `다음: ${targets[index]?.name || '(수신자 없음)'}`;
  }

  $('#btn-queue-skip').addEventListener('click', () => {
    if (!state.queue) return;
    state.queue.index++;
    if (state.queue.index >= state.queue.targets.length) {
      state.queue = null;
      toast('개별 발송을 종료했어요');
    }
    updateQueueUI();
  });

  function getRawBody() {
    return $('#message-body').value;
  }

  async function handleSend(channel) {
    const errorEl = $('#compose-error');
    errorEl.textContent = '';
    const raw = getRawBody();
    if (!raw.trim()) {
      errorEl.textContent = '보낼 메시지 내용을 입력해주세요.';
      return;
    }

    const selected = recipients.filter(r => state.selectedRecipientIds.has(r.id));
    const targets = selected.length ? selected : [null];
    const individualMode = $('#mode-individual').checked && targets.length > 1;

    if (individualMode) {
      if (!state.queue || state.queue.channel !== channel) {
        state.queue = { targets, index: 0, channel };
      }
      const current = state.queue.targets[state.queue.index];
      const body = fillVars(raw, current?.name);

      if (channel === 'sms') doSms([current?.phone], body);
      else await doKakao(body);

      recordHistory(channel, [current], body);
      afterSendCommit([current]);

      state.queue.index++;
      if (state.queue.index >= state.queue.targets.length) {
        state.queue = null;
        toast('모든 수신자에게 발송을 완료했어요');
      } else {
        toast('다음 수신자로 계속 진행해주세요');
      }
      updateQueueUI();
      renderSelectedRecipients();
      return;
    }

    // 그룹 발송 (한 번에)
    const singleName = targets.length === 1 ? targets[0]?.name : null;
    const body = fillVars(raw, singleName);

    if (channel === 'sms') {
      doSms(targets.map(t => t?.phone), body);
    } else {
      await doKakao(body);
    }
    recordHistory(channel, targets, body);
    afterSendCommit(targets);
  }

  $('#btn-send-sms').addEventListener('click', () => handleSend('sms'));
  $('#btn-send-kakao').addEventListener('click', () => handleSend('kakao'));

  $('#btn-copy').addEventListener('click', async () => {
    const raw = getRawBody();
    if (!raw.trim()) {
      $('#compose-error').textContent = '복사할 메시지 내용을 입력해주세요.';
      return;
    }
    const selected = recipients.filter(r => state.selectedRecipientIds.has(r.id));
    const body = fillVars(raw, selected.length === 1 ? selected[0].name : null);
    const ok = await copyText(body);
    toast(ok ? '메시지를 복사했어요' : '복사에 실패했어요');
  });

  /* ============================== 수신자 관리 ============================== */
  function resetRecipientForm() {
    $('#new-recipient-name').value = '';
    $('#new-recipient-phone').value = '';
    state.recipientEditingId = null;
    $('#btn-add-recipient').textContent = '추가';
    $('#recipient-form-error').textContent = '';
  }

  $('#btn-add-recipient').addEventListener('click', () => {
    const name = $('#new-recipient-name').value.trim();
    const phone = $('#new-recipient-phone').value.trim();
    const err = $('#recipient-form-error');
    err.textContent = '';
    if (!name || !phone) {
      err.textContent = '이름과 전화번호를 모두 입력해주세요.';
      return;
    }
    if (state.recipientEditingId) {
      const r = recipients.find(x => x.id === state.recipientEditingId);
      if (r) { r.name = name; r.phone = phone; }
    } else {
      recipients.push({ id: uid(), name, phone, favorite: false, useCount: 0, lastUsed: 0 });
    }
    save(STORE.recipients, recipients);
    resetRecipientForm();
    renderAllRecipients();
    toast('수신자를 저장했어요');
  });

  function renderRecipientManageList() {
    const box = $('#recipient-list');
    box.innerHTML = '';
    const q = state.recipientListSearch.trim().toLowerCase();
    let list = sortedRecipients(recipients);
    if (q) list = list.filter(r => r.name.toLowerCase().includes(q) || cleanPhone(r.phone).includes(q));

    $('#recipient-total-count').textContent = `${recipients.length}명`;

    list.forEach(r => {
      const item = el('div', 'entity-item');
      item.innerHTML = `
        <div class="entity-info">
          <div class="entity-title">${esc(r.name)}${r.favorite ? ' ⭐' : ''}</div>
          <div class="entity-sub">${esc(formatPhoneDisplay(r.phone))} · ${r.useCount || 0}회 발송</div>
        </div>
        <div class="entity-actions">
          <button class="icon-btn fav${r.favorite ? ' active' : ''}" data-act="fav" title="즐겨찾기">⭐</button>
          <a class="icon-btn" href="tel:${esc(cleanPhone(r.phone))}" title="전화">📞</a>
          <button class="icon-btn" data-act="edit" title="수정">✏️</button>
          <button class="icon-btn danger" data-act="del" title="삭제">🗑️</button>
        </div>
      `;
      item.querySelector('[data-act="fav"]').addEventListener('click', () => {
        r.favorite = !r.favorite;
        save(STORE.recipients, recipients);
        renderAllRecipients();
      });
      item.querySelector('[data-act="edit"]').addEventListener('click', () => {
        $('#new-recipient-name').value = r.name;
        $('#new-recipient-phone').value = r.phone;
        state.recipientEditingId = r.id;
        $('#btn-add-recipient').textContent = '수정 완료';
        window.scrollTo({ top: 0, behavior: 'smooth' });
      });
      item.querySelector('[data-act="del"]').addEventListener('click', () => {
        if (!confirm(`'${r.name}'을(를) 삭제할까요?`)) return;
        recipients = recipients.filter(x => x.id !== r.id);
        state.selectedRecipientIds.delete(r.id);
        save(STORE.recipients, recipients);
        renderAllRecipients();
      });
      box.appendChild(item);
    });
  }

  $('#recipient-list-search').addEventListener('input', e => {
    state.recipientListSearch = e.target.value;
    renderRecipientManageList();
  });

  function renderAllRecipients() {
    renderQuickRecipients();
    renderSelectedRecipients();
    renderRecipientManageList();
  }

  /* ============================== 문구 관리 ============================== */
  function resetTemplateForm() {
    $('#new-template-title').value = '';
    $('#new-template-body').value = '';
    $('#new-template-category').value = '일상';
    state.templateEditingId = null;
    $('#btn-add-template').textContent = '추가';
    $('#template-form-error').textContent = '';
  }

  $('#btn-add-template').addEventListener('click', () => {
    const title = $('#new-template-title').value.trim();
    const body = $('#new-template-body').value.trim();
    const category = $('#new-template-category').value;
    const err = $('#template-form-error');
    err.textContent = '';
    if (!title || !body) {
      err.textContent = '제목과 내용을 모두 입력해주세요.';
      return;
    }
    if (state.templateEditingId) {
      const t = templates.find(x => x.id === state.templateEditingId);
      if (t) { t.title = title; t.body = body; t.category = category; }
    } else {
      templates.push({ id: uid(), title, body, category, favorite: false, useCount: 0 });
    }
    save(STORE.templates, templates);
    resetTemplateForm();
    renderAllTemplates();
    toast('문구를 저장했어요');
  });

  function renderTemplateManageList() {
    renderCategoryFilter('#template-manage-category-filter', state.manageCategoryFilter, cat => {
      state.manageCategoryFilter = cat;
      renderTemplateManageList();
    });

    const box = $('#template-list');
    box.innerHTML = '';
    const q = state.templateListSearch.trim().toLowerCase();
    let list = sortedTemplates(templates);
    if (state.manageCategoryFilter !== '전체') list = list.filter(t => t.category === state.manageCategoryFilter);
    if (q) list = list.filter(t => t.title.toLowerCase().includes(q) || t.body.toLowerCase().includes(q));

    $('#template-total-count').textContent = `${templates.length}개`;

    list.forEach(t => {
      const item = el('div', 'entity-item');
      item.innerHTML = `
        <div class="entity-info">
          <div class="entity-title">${esc(t.title)}${t.favorite ? ' ⭐' : ''} <span class="entity-tag">${esc(t.category)}</span></div>
          <div class="entity-sub">${esc(t.body)}</div>
        </div>
        <div class="entity-actions">
          <button class="icon-btn fav${t.favorite ? ' active' : ''}" data-act="fav" title="즐겨찾기">⭐</button>
          <button class="icon-btn" data-act="edit" title="수정">✏️</button>
          <button class="icon-btn danger" data-act="del" title="삭제">🗑️</button>
        </div>
      `;
      item.querySelector('[data-act="fav"]').addEventListener('click', () => {
        t.favorite = !t.favorite;
        save(STORE.templates, templates);
        renderAllTemplates();
      });
      item.querySelector('[data-act="edit"]').addEventListener('click', () => {
        $('#new-template-title').value = t.title;
        $('#new-template-body').value = t.body;
        $('#new-template-category').value = t.category;
        state.templateEditingId = t.id;
        $('#btn-add-template').textContent = '수정 완료';
        window.scrollTo({ top: 0, behavior: 'smooth' });
      });
      item.querySelector('[data-act="del"]').addEventListener('click', () => {
        if (!confirm(`'${t.title}' 문구를 삭제할까요?`)) return;
        templates = templates.filter(x => x.id !== t.id);
        save(STORE.templates, templates);
        renderAllTemplates();
      });
      box.appendChild(item);
    });
  }

  $('#template-list-search').addEventListener('input', e => {
    state.templateListSearch = e.target.value;
    renderTemplateManageList();
  });

  function renderAllTemplates() {
    renderQuickTemplates();
    renderTemplateManageList();
  }

  /* ============================== 기록 ============================== */
  const CHANNEL_LABEL = { sms: '📱 문자', kakao: '💬 카카오톡' };

  function timeAgo(ts) {
    const diff = Date.now() - ts;
    const min = Math.floor(diff / 60000);
    if (min < 1) return '방금 전';
    if (min < 60) return `${min}분 전`;
    const hr = Math.floor(min / 60);
    if (hr < 24) return `${hr}시간 전`;
    const day = Math.floor(hr / 24);
    if (day < 7) return `${day}일 전`;
    return new Date(ts).toLocaleDateString('ko-KR');
  }

  function renderHistory() {
    const box = $('#history-list');
    box.innerHTML = '';
    $('#history-empty-hint').style.display = history.length ? 'none' : 'block';

    history.forEach(h => {
      const item = el('div', 'entity-item');
      const who = h.recipientNames.length ? h.recipientNames.join(', ') : '(수신자 미지정)';
      item.innerHTML = `
        <div class="entity-info">
          <div class="entity-title">${CHANNEL_LABEL[h.channel] || h.channel} · ${esc(who)}</div>
          <div class="entity-sub">${esc(h.body)}</div>
          <div class="entity-sub">${timeAgo(h.timestamp)}</div>
        </div>
        <div class="entity-actions">
          <button class="icon-btn" data-act="reuse" title="다시 보내기">↩️</button>
          <button class="icon-btn danger" data-act="del" title="삭제">🗑️</button>
        </div>
      `;
      item.querySelector('[data-act="reuse"]').addEventListener('click', () => {
        $('#message-body').value = h.body;
        updateCharCounter();
        switchTab('compose-screen');
        toast('메시지를 불러왔어요');
      });
      item.querySelector('[data-act="del"]').addEventListener('click', () => {
        history = history.filter(x => x.id !== h.id);
        save(STORE.history, history);
        renderHistory();
      });
      box.appendChild(item);
    });
  }

  $('#btn-clear-history').addEventListener('click', () => {
    if (!history.length) return;
    if (!confirm('보낸 기록을 모두 삭제할까요?')) return;
    history = [];
    save(STORE.history, history);
    renderHistory();
  });

  /* ============================== 초기화 ============================== */
  function renderAll() {
    renderAllRecipients();
    renderAllTemplates();
    renderHistory();
    updateCharCounter();
  }

  if (!('contacts' in navigator && 'ContactsManager' in window)) {
    $('#btn-pick-contact').style.display = 'none';
  }

  renderAll();
})();

(() => {
  'use strict';

  /* ============================== 저장소 ============================== */
  const STORE = {
    recipients: 'msg_recipients_v1',
    templates: 'msg_templates_v1',
    history: 'msg_history_v1',
    rules: 'msg_rules_v1',
    seedVersion: 'msg_seed_version_v1',
    pendingFires: 'msg_pending_fires_v1',
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

  const SEED_VERSION = 2;
  const AUDIENCES = ['공통', '친구', '가족', '선배', '상사'];
  const CATEGORIES = ['일상', '업무', '약속', '감사/축하', '기타'];

  const DEFAULT_TEMPLATES = [
    // 공통
    { title: '안부 인사', audience: '공통', category: '일상', body: '{이름}님, 안녕하세요! 잘 지내고 계신가요? 😊' },
    { title: '약속 리마인드', audience: '공통', category: '약속', body: '{이름}님, 오늘 약속 시간과 장소 다시 확인 부탁드려요!' },
    { title: '늦음 안내', audience: '공통', category: '약속', body: '죄송해요, 조금 늦을 것 같아요! 10분 정도만 기다려주세요 🙏' },
    { title: '도착 알림', audience: '공통', category: '일상', body: '저 방금 도착했어요 😊' },
    { title: '확인 답장', audience: '공통', category: '업무', body: '네, 확인했습니다. 감사합니다!' },
    { title: '회신 예정', audience: '공통', category: '업무', body: '지금 회의 중이라 확인 후 다시 연락드리겠습니다.' },
    { title: '축하 인사', audience: '공통', category: '감사/축하', body: '{이름}님, 진심으로 축하드려요! 🎉' },
    { title: '감사 인사', audience: '공통', category: '감사/축하', body: '{이름}님 덕분에 큰 도움이 됐어요. 정말 감사합니다!' },
    // 친구 (반말, 편한 톤)
    { title: '오랜만에 안부', audience: '친구', category: '일상', body: '야 오랜만이다ㅎㅎ 요즘 어떻게 지내? 조만간 얼굴 한번 보자!' },
    { title: '약속 재확인', audience: '친구', category: '약속', body: '우리 몇 시에 어디서 보기로 했지? 헷갈려서 다시 물어봐ㅋㅋ' },
    { title: '축하해', audience: '친구', category: '감사/축하', body: '야 완전 축하해!! 진짜 잘됐다 🎉 오늘 내가 쏜다' },
    { title: '부탁 있어', audience: '친구', category: '기타', body: '혹시 지금 잠깐 통화 가능해? 부탁할 게 있어서ㅠㅠ' },
    { title: '미안해', audience: '친구', category: '기타', body: '미안, 내가 깜빡했다ㅠㅠ 다음엔 진짜 안 그럴게' },
    // 가족 (따뜻하고 다정한 톤)
    { title: '부모님께 안부', audience: '가족', category: '일상', body: '엄마 아빠, 밥은 잘 챙겨 드시고 계세요? 저는 잘 지내고 있어요 :)' },
    { title: '형제·자매 안부', audience: '가족', category: '일상', body: '별일 없지? 요즘 통 연락을 못 했네, 시간 될 때 통화하자!' },
    { title: '감사 인사', audience: '가족', category: '감사/축하', body: '항상 감사하고 사랑해요. 다음에 뵐 때 맛있는 거 사드릴게요!' },
    { title: '날씨 챙기기', audience: '가족', category: '일상', body: '오늘 날씨 많이 추운데 옷 따뜻하게 입고 다니세요!' },
    { title: '도착 알림', audience: '가족', category: '일상', body: '저 잘 도착했어요, 걱정 마세요~' },
    // 선배 (존댓말이지만 친근한 톤)
    { title: '안부 인사', audience: '선배', category: '일상', body: '선배님, 잘 지내고 계신가요? 오랜만에 인사드립니다 :)' },
    { title: '식사 제안', audience: '선배', category: '약속', body: '선배님, 이번 주에 시간 괜찮으신 날 있으실까요? 식사 한번 대접하고 싶어서요.' },
    { title: '감사 인사', audience: '선배', category: '감사/축하', body: '그때 챙겨주셔서 정말 감사했습니다. 덕분에 큰 도움이 됐어요!' },
    { title: '조언 요청', audience: '선배', category: '업무', body: '선배님, 여쭤보고 싶은 게 있는데 잠깐 시간 내주실 수 있을까요?' },
    { title: '축하 인사', audience: '선배', category: '감사/축하', body: '선배님 소식 들었어요! 진심으로 축하드립니다 🎉' },
    // 상사 (격식 있는 비즈니스 톤)
    { title: '업무 보고', audience: '상사', category: '업무', body: '안녕하십니까, {이름}입니다. 요청하신 자료 확인 후 회신드리겠습니다.' },
    { title: '지각 안내', audience: '상사', category: '업무', body: '죄송합니다, 오늘 개인 사정으로 30분 정도 늦을 것 같습니다. 양해 부탁드립니다.' },
    { title: '휴가 보고', audience: '상사', category: '업무', body: '금일 연차 사용하겠습니다. 업무는 사전에 인수인계 완료했습니다.' },
    { title: '명절 인사', audience: '상사', category: '감사/축하', body: '다가오는 명절 잘 보내시길 바랍니다. 항상 감사드립니다.' },
    { title: '회신 요청', audience: '상사', category: '업무', body: '바쁘신 중에 죄송하지만, 검토 부탁드린 건 확인 부탁드립니다.' },
  ];

  function makeTemplate(t) {
    return {
      id: uid(),
      title: t.title,
      body: t.body,
      category: t.category,
      audience: t.audience || '공통',
      favorite: false,
      useCount: 0,
    };
  }

  let recipients = load(STORE.recipients, []);
  let templates = load(STORE.templates, null);
  if (!templates) {
    templates = DEFAULT_TEMPLATES.map(makeTemplate);
    save(STORE.templates, templates);
    localStorage.setItem(STORE.seedVersion, String(SEED_VERSION));
  } else {
    templates.forEach(t => { if (!t.audience) t.audience = '공통'; });
    const storedVersion = Number(localStorage.getItem(STORE.seedVersion) || '1');
    if (storedVersion < SEED_VERSION) {
      const existingTitles = new Set(templates.map(t => t.title));
      DEFAULT_TEMPLATES.forEach(t => {
        if (!existingTitles.has(t.title)) templates.push(makeTemplate(t));
      });
      localStorage.setItem(STORE.seedVersion, String(SEED_VERSION));
    }
    save(STORE.templates, templates);
  }
  let history = load(STORE.history, []);
  let rules = load(STORE.rules, []);
  let pendingRuleFires = load(STORE.pendingFires, []);

  /* ============================== 상태 ============================== */
  const state = {
    selectedRecipientIds: new Set(),
    recipientSearch: '',
    composeCategoryFilter: '전체',
    composeAudienceFilter: '전체',
    manageCategoryFilter: '전체',
    manageAudienceFilter: '전체',
    recipientListSearch: '',
    templateListSearch: '',
    recipientEditingId: null,
    templateEditingId: null,
    lastUsedTemplateId: null,
    queue: null, // { targets: [recipient|null], index, channel }
    ruleType: 'time',
    ruleSelectedRecipientIds: new Set(),
    ruleEditingId: null,
    ruleCapturedLoc: null,
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

    const hint = $('#kakao-target-hint');
    if (selected.length) {
      const names = selected.map(r => r.name).join(', ');
      hint.innerHTML = `카카오톡은 보안정책상 앱이 특정 대화상대를 자동으로 지정할 수 없어요. 공유 창이 뜨면 <b>${esc(names)}</b>와의 대화방을 직접 선택해주세요.`;
    } else {
      hint.innerHTML = '카카오톡은 보안정책상 앱이 특정 대화상대를 자동으로 지정할 수 없어요. 공유 창이 뜨면 <b>보낼 대화상대를 직접 선택</b>해주세요.';
    }
  }

  /* ============================== 문구: 렌더 ============================== */
  function renderChipFilter(containerSel, options, activeVal, onSelect) {
    const box = $(containerSel);
    box.innerHTML = '';
    options.forEach(opt => {
      const chip = el('div', 'filter-chip' + (activeVal === opt ? ' active' : ''), esc(opt));
      chip.addEventListener('click', () => onSelect(opt));
      box.appendChild(chip);
    });
  }

  function sortedTemplates(list) {
    return [...list].sort((a, b) => {
      if (a.favorite !== b.favorite) return a.favorite ? -1 : 1;
      return b.useCount - a.useCount;
    });
  }

  function applyTemplate(t) {
    $('#message-body').value = t.body;
    state.lastUsedTemplateId = t.id;
    updateCharCounter();
    $('#message-body').focus();
  }

  function renderQuickTemplates() {
    const box = $('#quick-templates');
    box.innerHTML = '';
    const list = sortedTemplates(templates).slice(0, 12);
    $('#templates-empty-hint').style.display = templates.length ? 'none' : 'block';

    list.forEach(t => {
      const chip = el('div', 'chip' + (t.favorite ? ' star' : ''));
      chip.innerHTML = `${esc(t.title)} <span class="chip-sub">${esc(t.audience)}</span>`;
      chip.title = t.body;
      chip.addEventListener('click', () => applyTemplate(t));
      box.appendChild(chip);
    });
  }

  /* ============================== 문구 선택 모달 (전체 보기) ============================== */
  function openTemplatePicker() {
    $('#template-picker-modal').classList.add('show');
    $('#template-picker-search').value = '';
    renderTemplatePicker();
    setTimeout(() => $('#template-picker-search').focus(), 50);
  }

  function closeTemplatePicker() {
    $('#template-picker-modal').classList.remove('show');
  }

  function renderTemplatePicker() {
    renderChipFilter('#picker-audience-filter', ['전체', ...AUDIENCES], state.composeAudienceFilter, aud => {
      state.composeAudienceFilter = aud;
      renderTemplatePicker();
    });
    renderChipFilter('#picker-category-filter', ['전체', ...CATEGORIES], state.composeCategoryFilter, cat => {
      state.composeCategoryFilter = cat;
      renderTemplatePicker();
    });

    const box = $('#picker-template-list');
    box.innerHTML = '';
    const q = $('#template-picker-search').value.trim().toLowerCase();
    let list = sortedTemplates(templates);
    if (state.composeAudienceFilter !== '전체') list = list.filter(t => t.audience === state.composeAudienceFilter);
    if (state.composeCategoryFilter !== '전체') list = list.filter(t => t.category === state.composeCategoryFilter);
    if (q) list = list.filter(t => t.title.toLowerCase().includes(q) || t.body.toLowerCase().includes(q));

    list.forEach(t => {
      const item = el('div', 'entity-item');
      item.style.cursor = 'pointer';
      item.innerHTML = `
        <div class="entity-info">
          <div class="entity-title">${esc(t.title)}${t.favorite ? ' ⭐' : ''} <span class="entity-tag audience">${esc(t.audience)}</span> <span class="entity-tag">${esc(t.category)}</span></div>
          <div class="entity-sub">${esc(t.body)}</div>
        </div>
      `;
      item.addEventListener('click', () => {
        applyTemplate(t);
        closeTemplatePicker();
      });
      box.appendChild(item);
    });

    if (!list.length) {
      box.appendChild(el('p', 'empty-hint', '조건에 맞는 문구가 없어요.'));
    }
  }

  $('#btn-open-template-picker').addEventListener('click', openTemplatePicker);
  $('#btn-close-template-picker').addEventListener('click', closeTemplatePicker);
  $('#template-picker-modal').addEventListener('click', e => {
    if (e.target.id === 'template-picker-modal') closeTemplatePicker();
  });
  $('#template-picker-search').addEventListener('input', renderTemplatePicker);

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

  /* ============================== vCard 가져오기 (iOS 등) ============================== */
  function unfoldVCardLines(text) {
    return text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').replace(/\n[ \t]/g, '');
  }

  function parseVCards(text) {
    const unfolded = unfoldVCardLines(text);
    const blocks = unfolded.split(/BEGIN:VCARD/i).slice(1);
    const results = [];
    blocks.forEach(block => {
      const lines = block.split('\n');
      let fn = '';
      let nName = '';
      let tel = '';
      lines.forEach(rawLine => {
        const line = rawLine.trim();
        if (!line || /^END:VCARD/i.test(line)) return;
        const idx = line.indexOf(':');
        if (idx === -1) return;
        const rawKey = line.slice(0, idx);
        const value = line.slice(idx + 1).trim();
        const key = rawKey.split(';')[0].toUpperCase();
        if (key === 'FN' && !fn) fn = value;
        else if (key === 'N' && !nName) {
          const parts = value.split(';').filter(Boolean);
          nName = parts.reverse().join(' ').trim();
        } else if (key === 'TEL' && !tel) {
          tel = value;
        }
      });
      const name = fn || nName || '이름없음';
      if (tel) results.push({ name, phone: tel });
    });
    return results;
  }

  function importVCardText(text) {
    const parsed = parseVCards(text);
    let added = 0, skipped = 0;
    parsed.forEach(p => {
      const phone = cleanPhone(p.phone);
      if (!phone) return;
      const dup = recipients.find(r => cleanPhone(r.phone) === phone);
      if (dup) { skipped++; return; }
      recipients.push({ id: uid(), name: p.name, phone: p.phone, favorite: false, useCount: 0, lastUsed: 0 });
      added++;
    });
    if (added) {
      save(STORE.recipients, recipients);
      renderAllRecipients();
    }
    return { added, skipped, total: parsed.length };
  }

  $('#btn-vcard-file').addEventListener('click', () => $('#vcard-file-input').click());

  $('#vcard-file-input').addEventListener('change', async e => {
    const files = Array.from(e.target.files || []);
    const err = $('#vcard-error');
    err.textContent = '';
    if (!files.length) return;
    try {
      let allText = '';
      for (const f of files) allText += (await f.text()) + '\n';
      const result = importVCardText(allText);
      if (!result.total) {
        err.textContent = '올바른 vCard 파일이 아니에요. 연락처 앱에서 내보낸 .vcf 파일인지 확인해주세요.';
      } else {
        toast(`${result.added}명 추가${result.skipped ? `, ${result.skipped}명 중복 제외` : ''}`);
      }
    } catch (ex) {
      err.textContent = '파일을 읽는 중 문제가 발생했어요.';
    }
    e.target.value = '';
  });

  $('#btn-vcard-paste-toggle').addEventListener('click', () => {
    const box = $('#vcard-paste-box');
    box.style.display = box.style.display === 'none' ? 'block' : 'none';
  });

  $('#btn-vcard-paste-import').addEventListener('click', () => {
    const text = $('#vcard-paste-text').value;
    const err = $('#vcard-error');
    err.textContent = '';
    if (!text.trim()) { err.textContent = 'vCard 텍스트를 입력해주세요.'; return; }
    const result = importVCardText(text);
    if (!result.total) {
      err.textContent = 'vCard 형식을 인식하지 못했어요. BEGIN:VCARD 로 시작하는지 확인해주세요.';
    } else {
      toast(`${result.added}명 추가${result.skipped ? `, ${result.skipped}명 중복 제외` : ''}`);
      $('#vcard-paste-text').value = '';
      $('#vcard-paste-box').style.display = 'none';
    }
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
        if (e && e.name === 'AbortError') return; // 사용자가 공유 창을 취소함
        await copyText(body);
        toast(`공유 창을 열지 못했어요 (${e && e.name ? e.name : '알 수 없는 오류'}). 메시지를 복사했으니 카카오톡에 붙여넣어 주세요.`);
        return;
      }
    }
    await copyText(body);
    toast('이 브라우저는 공유 기능을 지원하지 않아 메시지를 복사했어요. 카카오톡에서 붙여넣어 주세요.');
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
    // 문자는 기기/통신사마다 다중 수신자 sms: 링크 처리가 불안정해서 항상 한 명씩 순서대로 보낸다.
    const individualMode = targets.length > 1 && (channel === 'sms' || $('#mode-individual').checked);

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
    renderRuleRecipients();
  }

  /* ============================== 문구 관리 ============================== */
  function resetTemplateForm() {
    $('#new-template-title').value = '';
    $('#new-template-body').value = '';
    $('#new-template-category').value = '일상';
    $('#new-template-audience').value = '공통';
    state.templateEditingId = null;
    $('#btn-add-template').textContent = '추가';
    $('#template-form-error').textContent = '';
  }

  $('#btn-add-template').addEventListener('click', () => {
    const title = $('#new-template-title').value.trim();
    const body = $('#new-template-body').value.trim();
    const category = $('#new-template-category').value;
    const audience = $('#new-template-audience').value;
    const err = $('#template-form-error');
    err.textContent = '';
    if (!title || !body) {
      err.textContent = '제목과 내용을 모두 입력해주세요.';
      return;
    }
    if (state.templateEditingId) {
      const t = templates.find(x => x.id === state.templateEditingId);
      if (t) { t.title = title; t.body = body; t.category = category; t.audience = audience; }
    } else {
      templates.push({ id: uid(), title, body, category, audience, favorite: false, useCount: 0 });
    }
    save(STORE.templates, templates);
    resetTemplateForm();
    renderAllTemplates();
    toast('문구를 저장했어요');
  });

  function renderTemplateManageList() {
    renderChipFilter('#template-manage-audience-filter', ['전체', ...AUDIENCES], state.manageAudienceFilter, aud => {
      state.manageAudienceFilter = aud;
      renderTemplateManageList();
    });
    renderChipFilter('#template-manage-category-filter', ['전체', ...CATEGORIES], state.manageCategoryFilter, cat => {
      state.manageCategoryFilter = cat;
      renderTemplateManageList();
    });

    const box = $('#template-list');
    box.innerHTML = '';
    const q = state.templateListSearch.trim().toLowerCase();
    let list = sortedTemplates(templates);
    if (state.manageAudienceFilter !== '전체') list = list.filter(t => t.audience === state.manageAudienceFilter);
    if (state.manageCategoryFilter !== '전체') list = list.filter(t => t.category === state.manageCategoryFilter);
    if (q) list = list.filter(t => t.title.toLowerCase().includes(q) || t.body.toLowerCase().includes(q));

    $('#template-total-count').textContent = `${templates.length}개`;

    list.forEach(t => {
      const item = el('div', 'entity-item');
      item.innerHTML = `
        <div class="entity-info">
          <div class="entity-title">${esc(t.title)}${t.favorite ? ' ⭐' : ''} <span class="entity-tag audience">${esc(t.audience)}</span> <span class="entity-tag">${esc(t.category)}</span></div>
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
        $('#new-template-audience').value = t.audience;
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

  /* ============================== 예약 규칙: 폼 ============================== */
  const DAY_LABELS = ['일', '월', '화', '수', '목', '금', '토'];

  function renderRuleRecipients() {
    const box = $('#rule-recipients');
    box.innerHTML = '';
    sortedRecipients(recipients).forEach(r => {
      const chip = el('div', 'chip' + (state.ruleSelectedRecipientIds.has(r.id) ? ' selected' : ''), esc(r.name));
      chip.addEventListener('click', () => {
        if (state.ruleSelectedRecipientIds.has(r.id)) state.ruleSelectedRecipientIds.delete(r.id);
        else state.ruleSelectedRecipientIds.add(r.id);
        renderRuleRecipients();
      });
      box.appendChild(chip);
    });
  }

  function renderRuleTemplateQuick() {
    const box = $('#rule-template-quick');
    box.innerHTML = '';
    sortedTemplates(templates).slice(0, 14).forEach(t => {
      const chip = el('div', 'filter-chip', esc(t.title));
      chip.title = t.body;
      chip.addEventListener('click', () => { $('#rule-body').value = t.body; });
      box.appendChild(chip);
    });
  }

  $('#rule-type-tabs').addEventListener('click', e => {
    const chip = e.target.closest('.filter-chip');
    if (!chip || !chip.dataset.type) return;
    $all('#rule-type-tabs .filter-chip').forEach(c => c.classList.toggle('active', c === chip));
    state.ruleType = chip.dataset.type;
    $('#rule-time-fields').style.display = state.ruleType === 'time' ? 'block' : 'none';
    $('#rule-location-fields').style.display = state.ruleType === 'location' ? 'block' : 'none';
  });

  $('#rule-repeat-mode').addEventListener('change', e => {
    const once = e.target.value === 'once';
    $('#rule-days-row').style.display = once ? 'none' : 'flex';
    $('#rule-once-date').style.display = once ? 'block' : 'none';
  });

  $('#rule-days-row').addEventListener('click', e => {
    const chip = e.target.closest('.day-chip');
    if (!chip) return;
    chip.classList.toggle('active');
  });

  $('#btn-capture-location').addEventListener('click', () => {
    if (!navigator.geolocation) {
      $('#rule-location-status').textContent = '이 브라우저에서는 위치 서비스를 사용할 수 없어요.';
      return;
    }
    $('#rule-location-status').textContent = '위치 확인 중...';
    navigator.geolocation.getCurrentPosition(
      pos => {
        state.ruleCapturedLoc = { lat: pos.coords.latitude, lng: pos.coords.longitude };
        $('#rule-location-status').textContent = `현재 위치가 저장됐어요 (오차 ±${Math.round(pos.coords.accuracy)}m)`;
      },
      () => {
        $('#rule-location-status').textContent = '위치를 가져오지 못했어요. 위치 권한을 허용했는지 확인해주세요.';
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  });

  function resetRuleForm() {
    $('#rule-label').value = '';
    $('#rule-time').value = '09:00';
    $('#rule-repeat-mode').value = 'days';
    $all('.day-chip').forEach(c => c.classList.remove('active'));
    $('#rule-days-row').style.display = 'flex';
    $('#rule-once-date').style.display = 'none';
    $('#rule-once-date').value = '';
    $('#rule-loc-condition').value = 'enter';
    $('#rule-loc-radius').value = '300';
    $('#rule-location-status').textContent = '아직 위치가 저장되지 않았어요. 등록하려는 장소에 실제로 계실 때 버튼을 눌러주세요.';
    state.ruleCapturedLoc = null;
    state.ruleSelectedRecipientIds = new Set();
    $('#rule-body').value = '';
    $('#rule-channel').value = 'sms';
    state.ruleEditingId = null;
    state.ruleType = 'time';
    $('#btn-add-rule').textContent = '규칙 저장';
    $('#rule-form-error').textContent = '';
    $all('#rule-type-tabs .filter-chip').forEach(c => c.classList.toggle('active', c.dataset.type === 'time'));
    $('#rule-time-fields').style.display = 'block';
    $('#rule-location-fields').style.display = 'none';
    renderRuleRecipients();
  }

  $('#btn-add-rule').addEventListener('click', () => {
    const err = $('#rule-form-error');
    err.textContent = '';

    const body = $('#rule-body').value.trim();
    const recipientIds = Array.from(state.ruleSelectedRecipientIds);
    const channel = $('#rule-channel').value;
    const label = $('#rule-label').value.trim() || (state.ruleType === 'time' ? '예약 메시지' : '위치 메시지');

    if (!body) { err.textContent = '보낼 메시지 내용을 입력해주세요.'; return; }
    if (!recipientIds.length) { err.textContent = '수신자를 한 명 이상 선택해주세요.'; return; }

    const rule = {
      id: state.ruleEditingId || uid(),
      label,
      enabled: true,
      type: state.ruleType,
      recipientIds,
      body,
      channel,
      lastFiredKey: state.ruleEditingId ? undefined : null,
    };

    if (state.ruleType === 'time') {
      const timeVal = $('#rule-time').value;
      if (!timeVal) { err.textContent = '시각을 선택해주세요.'; return; }
      rule.timeHHMM = timeVal;
      rule.repeatMode = $('#rule-repeat-mode').value;
      if (rule.repeatMode === 'days') {
        rule.days = $all('.day-chip.active').map(c => Number(c.dataset.day));
        if (!rule.days.length) { err.textContent = '반복할 요일을 하나 이상 선택해주세요.'; return; }
      } else {
        rule.onceDate = $('#rule-once-date').value;
        if (!rule.onceDate) { err.textContent = '날짜를 선택해주세요.'; return; }
      }
    } else {
      if (!state.ruleCapturedLoc) { err.textContent = "'지금 있는 곳으로 저장' 버튼으로 위치를 먼저 등록해주세요."; return; }
      rule.lat = state.ruleCapturedLoc.lat;
      rule.lng = state.ruleCapturedLoc.lng;
      rule.radiusM = Number($('#rule-loc-radius').value);
      rule.locCondition = $('#rule-loc-condition').value;
    }

    if (state.ruleEditingId) {
      const idx = rules.findIndex(r => r.id === state.ruleEditingId);
      if (idx !== -1) {
        rule.lastFiredKey = rules[idx].lastFiredKey;
        rule.locState = rules[idx].locState;
        rules[idx] = rule;
      }
    } else {
      rules.push(rule);
    }
    save(STORE.rules, rules);
    resetRuleForm();
    renderRuleList();
    toast('규칙을 저장했어요');
    ensureWatchers();
  });

  function describeRule(rule) {
    if (rule.type === 'time') {
      if (rule.repeatMode === 'once') return `${rule.onceDate} ${rule.timeHHMM} (한 번)`;
      const days = (rule.days || []).slice().sort().map(d => DAY_LABELS[d]).join(',');
      return `매주 ${days} ${rule.timeHHMM}`;
    }
    const condLabel = rule.locCondition === 'enter' ? '도착 시' : '벗어날 시';
    return `등록 장소 ${rule.radiusM}m 이내 ${condLabel}`;
  }

  function loadRuleIntoForm(rule) {
    state.ruleEditingId = rule.id;
    $('#rule-label').value = rule.label;
    $('#btn-add-rule').textContent = '수정 완료';
    state.ruleType = rule.type;
    $all('#rule-type-tabs .filter-chip').forEach(c => c.classList.toggle('active', c.dataset.type === rule.type));
    $('#rule-time-fields').style.display = rule.type === 'time' ? 'block' : 'none';
    $('#rule-location-fields').style.display = rule.type === 'location' ? 'block' : 'none';

    if (rule.type === 'time') {
      $('#rule-time').value = rule.timeHHMM;
      $('#rule-repeat-mode').value = rule.repeatMode;
      const once = rule.repeatMode === 'once';
      $('#rule-days-row').style.display = once ? 'none' : 'flex';
      $('#rule-once-date').style.display = once ? 'block' : 'none';
      $all('.day-chip').forEach(c => c.classList.toggle('active', (rule.days || []).includes(Number(c.dataset.day))));
      $('#rule-once-date').value = rule.onceDate || '';
    } else {
      state.ruleCapturedLoc = { lat: rule.lat, lng: rule.lng };
      $('#rule-location-status').textContent = '기존에 저장된 위치를 사용 중이에요. 다시 저장하려면 버튼을 눌러주세요.';
      $('#rule-loc-condition').value = rule.locCondition;
      $('#rule-loc-radius').value = String(rule.radiusM);
    }

    state.ruleSelectedRecipientIds = new Set(rule.recipientIds);
    renderRuleRecipients();
    $('#rule-body').value = rule.body;
    $('#rule-channel').value = rule.channel;
  }

  function renderRuleList() {
    const box = $('#rule-list');
    box.innerHTML = '';
    $('#rule-total-count').textContent = `${rules.length}개`;
    $('#rule-empty-hint').style.display = rules.length ? 'none' : 'block';

    rules.forEach(rule => {
      const names = recipients.filter(r => rule.recipientIds.includes(r.id)).map(r => r.name);
      const item = el('div', 'entity-item');
      item.innerHTML = `
        <div class="entity-info">
          <div class="entity-title">${rule.type === 'time' ? '⏰' : '📍'} ${esc(rule.label)} <span class="entity-tag${rule.enabled ? '' : ' audience'}">${rule.enabled ? '켜짐' : '꺼짐'}</span></div>
          <div class="entity-sub">${esc(describeRule(rule))} · ${esc(names.join(', ') || '수신자 없음')}</div>
          <div class="entity-sub">${esc(rule.body)}</div>
        </div>
        <div class="entity-actions">
          <button class="icon-btn" data-act="toggle" title="켜기/끄기">${rule.enabled ? '🔔' : '🔕'}</button>
          <button class="icon-btn" data-act="edit" title="수정">✏️</button>
          <button class="icon-btn danger" data-act="del" title="삭제">🗑️</button>
        </div>
      `;
      item.querySelector('[data-act="toggle"]').addEventListener('click', () => {
        rule.enabled = !rule.enabled;
        save(STORE.rules, rules);
        renderRuleList();
        ensureWatchers();
      });
      item.querySelector('[data-act="edit"]').addEventListener('click', () => {
        loadRuleIntoForm(rule);
        window.scrollTo({ top: 0, behavior: 'smooth' });
      });
      item.querySelector('[data-act="del"]').addEventListener('click', () => {
        if (!confirm(`'${rule.label}' 규칙을 삭제할까요?`)) return;
        rules = rules.filter(r => r.id !== rule.id);
        save(STORE.rules, rules);
        renderRuleList();
        ensureWatchers();
      });
      box.appendChild(item);
    });
  }

  /* ============================== 예약 규칙: 알림 권한 ============================== */
  function updateNotifyStatus() {
    const box = $('#notify-status');
    if (!('Notification' in window)) { box.textContent = '이 브라우저는 알림을 지원하지 않아요.'; return; }
    if (Notification.permission === 'granted') box.textContent = '✅ 알림이 허용되어 있어요.';
    else if (Notification.permission === 'denied') box.textContent = '❌ 알림이 차단되어 있어요. 브라우저/설정 앱에서 허용해주세요.';
    else box.textContent = '';
  }

  $('#btn-enable-notify').addEventListener('click', async () => {
    if (!('Notification' in window)) {
      $('#notify-status').textContent = '이 브라우저는 알림을 지원하지 않아요.';
      return;
    }
    try {
      await Notification.requestPermission();
    } catch (e) { /* ignore */ }
    updateNotifyStatus();
  });

  /* ============================== 예약 규칙: 발송 엔진 ============================== */
  function afterSendCommitPlain(targets) {
    targets.forEach(bumpRecipientUsage);
    save(STORE.recipients, recipients);
    renderQuickRecipients();
  }

  async function executeRuleSend(rule) {
    const targets = recipients.filter(r => rule.recipientIds.includes(r.id));
    if (!targets.length) return;
    const singleName = targets.length === 1 ? targets[0].name : null;
    const body = fillVars(rule.body, singleName);
    if (rule.channel === 'sms') {
      doSms(targets.map(t => t.phone), body);
    } else {
      await doKakao(body);
    }
    recordHistory(rule.channel, targets, body);
    afterSendCommitPlain(targets);
  }

  let bannerQueue = [];
  let bannerShowing = false;

  function drainBannerQueue() {
    if (!bannerQueue.length) { bannerShowing = false; return; }
    bannerShowing = true;
    const rule = bannerQueue.shift();
    const banner = $('#autosend-banner');
    const names = recipients.filter(r => rule.recipientIds.includes(r.id)).map(r => r.name).join(', ') || '(수신자 없음)';
    banner.innerHTML = `
      <div class="ab-title">${rule.type === 'time' ? '⏰' : '📍'} 예약 메시지: ${esc(rule.label)}</div>
      <div class="ab-body">${esc(names)}\n${esc(rule.body)}</div>
      <div class="ab-actions">
        <button type="button" class="ab-send">지금 보내기</button>
        <button type="button" class="ab-skip">건너뛰기</button>
      </div>
    `;
    banner.classList.add('show');
    banner.querySelector('.ab-send').addEventListener('click', () => {
      executeRuleSend(rule);
      toast('예약 메시지를 보냈어요');
      banner.classList.remove('show');
      setTimeout(drainBannerQueue, 300);
    });
    banner.querySelector('.ab-skip').addEventListener('click', () => {
      banner.classList.remove('show');
      setTimeout(drainBannerQueue, 300);
    });
  }

  function showAutosendBanner(rule) {
    bannerQueue.push(rule);
    if (!bannerShowing) drainBannerQueue();
  }

  function savePendingFires() {
    save(STORE.pendingFires, pendingRuleFires);
  }

  async function notifyRule(rule) {
    const names = recipients.filter(r => rule.recipientIds.includes(r.id)).map(r => r.name).join(', ') || '수신자 없음';
    const title = `⏰ ${rule.label}`;
    const bodyText = `${names}에게 보낼까요?\n${rule.body}`;
    if ('serviceWorker' in navigator && 'Notification' in window && Notification.permission === 'granted') {
      try {
        const reg = await navigator.serviceWorker.ready;
        await reg.showNotification(title, {
          body: bodyText,
          tag: 'autosend-' + rule.id,
          icon: 'icons/icon-192.png',
          requireInteraction: true,
          data: { ruleId: rule.id },
          actions: [
            { action: 'send', title: '지금 보내기' },
            { action: 'skip', title: '건너뛰기' },
          ],
        });
        return;
      } catch (e) { /* fall through to pending queue */ }
    }
    if (!pendingRuleFires.includes(rule.id)) {
      pendingRuleFires.push(rule.id);
      savePendingFires();
    }
  }

  function triggerRule(rule) {
    if (document.visibilityState === 'visible') {
      showAutosendBanner(rule);
    } else {
      notifyRule(rule);
    }
  }

  function todayDateStr(d) {
    const y = d.getFullYear(), m = String(d.getMonth() + 1).padStart(2, '0'), day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  function checkTimeRules() {
    const now = new Date();
    const dateStr = todayDateStr(now);
    const weekday = now.getDay();
    const nowMinutes = now.getHours() * 60 + now.getMinutes();
    let changed = false;
    rules.forEach(rule => {
      if (!rule.enabled || rule.type !== 'time') return;
      const [h, m] = rule.timeHHMM.split(':').map(Number);
      const targetMinutes = h * 60 + m;
      // 정확히 그 분에 앱이 켜져 있어야만 발동하면 백그라운드 탭 스로틀링 때문에
      // 거의 항상 놓친다. 그 날 target 시각을 이미 지났고 아직 안 울렸으면 지금 발동한다.
      if (nowMinutes < targetMinutes) return;
      if (rule.repeatMode === 'once') {
        if (rule.onceDate !== dateStr || rule.lastFiredKey === 'fired') return;
        rule.lastFiredKey = 'fired';
        rule.enabled = false;
        changed = true;
        triggerRule(rule);
      } else {
        if (!(rule.days || []).includes(weekday) || rule.lastFiredKey === dateStr) return;
        rule.lastFiredKey = dateStr;
        changed = true;
        triggerRule(rule);
      }
    });
    if (changed) { save(STORE.rules, rules); renderRuleList(); }
  }

  function haversineMeters(lat1, lng1, lat2, lng2) {
    const R = 6371000;
    const toRad = d => (d * Math.PI) / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  function checkLocationRules(pos) {
    const { latitude, longitude } = pos.coords;
    let changed = false;
    rules.forEach(rule => {
      if (!rule.enabled || rule.type !== 'location' || rule.lat == null) return;
      const dist = haversineMeters(latitude, longitude, rule.lat, rule.lng);
      const isInside = dist <= rule.radiusM;
      const prev = rule.locState;
      if (prev === undefined) {
        rule.locState = isInside ? 'inside' : 'outside';
        changed = true;
        return;
      }
      if (isInside && prev !== 'inside') {
        rule.locState = 'inside';
        changed = true;
        if (rule.locCondition === 'enter') triggerRule(rule);
      } else if (!isInside && prev !== 'outside') {
        rule.locState = 'outside';
        changed = true;
        if (rule.locCondition === 'exit') triggerRule(rule);
      }
    });
    if (changed) save(STORE.rules, rules);
  }

  let timeWatchStarted = false;
  let locationWatchId = null;

  function ensureWatchers() {
    if (!timeWatchStarted) {
      timeWatchStarted = true;
      setInterval(checkTimeRules, 20000);
    }
    const hasLocationRule = rules.some(r => r.type === 'location' && r.enabled);
    if (hasLocationRule && navigator.geolocation) {
      if (locationWatchId == null) {
        locationWatchId = navigator.geolocation.watchPosition(checkLocationRules, () => {}, {
          enableHighAccuracy: false,
          maximumAge: 30000,
          timeout: 20000,
        });
      }
    } else if (locationWatchId != null) {
      navigator.geolocation.clearWatch(locationWatchId);
      locationWatchId = null;
    }
  }

  function flushPendingFires() {
    if (!pendingRuleFires.length) return;
    const ids = [...pendingRuleFires];
    pendingRuleFires = [];
    savePendingFires();
    ids.forEach(id => {
      const rule = rules.find(r => r.id === id);
      if (rule) showAutosendBanner(rule);
    });
  }

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      checkTimeRules();
      flushPendingFires();
    }
  });

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', event => {
      const msg = event.data;
      if (!msg || msg.type !== 'autosend-action') return;
      const rule = rules.find(r => r.id === msg.ruleId);
      if (!rule) return;
      if (msg.action === 'send') {
        executeRuleSend(rule);
        toast('예약 메시지를 보냈어요');
      }
    });
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
    renderRuleTemplateQuick();
    renderRuleList();
    updateNotifyStatus();
    updateCharCounter();
  }

  if (!('contacts' in navigator && 'ContactsManager' in window)) {
    $('#btn-pick-contact').style.display = 'none';
  }

  renderAll();
  ensureWatchers();
  checkTimeRules();
  flushPendingFires();
})();

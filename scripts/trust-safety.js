/* Venturify trust & safety controls. Requires the trust-safety migration to be applied first. */
(function () {
  if (window.__venturifySafetyLoaded) return;
  window.__venturifySafetyLoaded = true;
  const client = window.venturifySupabaseClient;
  if (!client) return;

  const css = document.createElement('style');
  css.textContent = `
    #ventSafetyLauncher{position:fixed;right:16px;bottom:16px;z-index:1000;border:1px solid #cbd8c2;border-radius:999px;padding:11px 15px;background:#183326;color:#f5f8ee;font:700 12px system-ui;box-shadow:0 5px 22px #0002;cursor:pointer}
    #ventSafetyPanel{position:fixed;right:16px;bottom:66px;z-index:1001;width:min(350px,calc(100vw - 32px));max-height:calc(100dvh - 88px);overflow:auto;background:#fffefa;border:1px solid #dce4d6;border-radius:14px;padding:17px;box-shadow:0 14px 48px #0003;color:#243126;font:12px system-ui}
    #ventSafetyPanel[hidden]{display:none}#ventSafetyPanel h3{margin:0 0 8px;font:600 21px Georgia,serif}
    #ventSafetyPanel p{color:#6b776f;line-height:1.5}#ventSafetyPanel label{display:block;font-weight:700;margin:10px 0 5px}
    #ventSafetyPanel input,#ventSafetyPanel select,#ventSafetyPanel textarea{width:100%;box-sizing:border-box;border:1px solid #dce4d6;border-radius:7px;padding:9px;background:white;font:12px system-ui}
    #ventSafetyPanel textarea{min-height:64px;resize:vertical}#ventSafetyPanel .ventSafetyActions{display:flex;gap:8px;margin-top:12px;flex-wrap:wrap}
    #ventSafetyPanel button{border:1px solid #dce4d6;border-radius:7px;padding:9px 11px;background:#edf4e5;color:#31553a;font-weight:750;cursor:pointer}
    #ventSafetyPanel button:disabled{opacity:.55;cursor:wait}#ventSafetyStatus{font-size:11px;line-height:1.5;margin-top:9px;color:#526352}
    @media(max-width:480px){#ventSafetyLauncher{right:10px;bottom:10px}#ventSafetyPanel{right:10px;bottom:58px}}
  `;
  document.head.appendChild(css);
  const panel = document.createElement('section');
  panel.id = 'ventSafetyPanel';
  panel.hidden = true;
  panel.innerHTML = `
    <h3>Safety & reporting</h3>
    <p>Report a profile or post, or block an account. Select a profile or post on the page first, or paste its ID below. You can also manage accounts you have blocked.</p>
    <label for="ventSafetyTargetType">What are you reporting?</label>
    <select id="ventSafetyTargetType"><option value="user">Founder profile</option><option value="post">Post</option></select>
    <label for="ventSafetyTargetId">Profile or post ID</label>
    <input id="ventSafetyTargetId" autocomplete="off" placeholder="Select a profile/post or paste its ID">
    <label for="ventSafetyReason">Reason</label>
    <select id="ventSafetyReason"><option value="spam">Spam</option><option value="harassment">Harassment</option><option value="fake_or_misleading">Fake or misleading</option><option value="scam">Scam</option><option value="privacy">Privacy concern</option><option value="inappropriate_content">Inappropriate content</option><option value="other">Other</option></select>
    <label for="ventSafetyDetails">Details (optional)</label>
    <textarea id="ventSafetyDetails" maxlength="1000" placeholder="Share enough context for a reviewer"></textarea>
    <div class="ventSafetyActions"><button id="ventSafetyReport" type="button">Submit report</button><button id="ventSafetyBlock" type="button">Block profile</button><button id="ventSafetyManageBlocks" type="button">Manage blocked accounts</button><button id="ventSafetyModerator" type="button">Moderator review</button><button id="ventSafetyClose" type="button">Close</button></div>
    <div id="ventSafetyBlockedList" hidden></div>
    <div id="ventSafetyReview" hidden></div>
    <div id="ventSafetyStatus" role="status" aria-live="polite"></div>`;
  document.body.appendChild(panel);
  const launcher = document.createElement('button');
  launcher.id = 'ventSafetyLauncher'; launcher.type = 'button'; launcher.textContent = 'Safety';
  launcher.setAttribute('aria-expanded','false'); launcher.setAttribute('aria-controls','ventSafetyPanel');
  document.body.appendChild(launcher);
  const $ = id => document.getElementById(id);
  let currentUser = null;
  client.auth.getUser().then(({data}) => { currentUser = data?.user || null; });
  client.auth.onAuthStateChange((_event, session) => { currentUser = session?.user || null; });
  function status(message) { $('ventSafetyStatus').textContent = message; }
  function open(targetType, targetId) {
    if (targetType) $('ventSafetyTargetType').value = targetType;
    if (targetId) $('ventSafetyTargetId').value = targetId;
    panel.hidden = false; launcher.setAttribute('aria-expanded','true');
  }
  launcher.addEventListener('click', () => {
    if (!panel.hidden) { panel.hidden = true; launcher.setAttribute('aria-expanded','false'); return; }
    const to = new URLSearchParams(location.search).get('to');
    open(to ? 'user' : undefined, to || undefined);
  });
  $('ventSafetyClose').addEventListener('click', () => { panel.hidden = true; launcher.setAttribute('aria-expanded','false'); });
  $('ventSafetyManageBlocks').addEventListener('click', async () => {
    const user = await signedIn(); if (!user) return;
    const list = $('ventSafetyBlockedList');
    list.hidden = false;
    list.replaceChildren();
    const heading = document.createElement('p');
    heading.textContent = 'Accounts you blocked';
    heading.style.fontWeight = '700';
    list.appendChild(heading);
    const {data, error} = await client.from('user_blocks').select('blocked_id, created_at').eq('blocker_id', user.id).order('created_at', {ascending:false}).limit(100);
    if (error) { status('Could not load your blocked accounts. Check that the trust-and-safety migration is applied.'); return; }
    if (!data?.length) {
      const empty = document.createElement('p'); empty.textContent = 'You have not blocked any accounts.'; list.appendChild(empty); status('Blocked-account list loaded.'); return;
    }
    data.forEach(block => {
      const row = document.createElement('div');
      row.style.cssText = 'display:flex;gap:8px;align-items:center;justify-content:space-between;padding:8px 0;border-top:1px solid #e2e6dc;overflow-wrap:anywhere';
      const id = document.createElement('span');
      id.textContent = block.blocked_id;
      id.style.cssText = 'font-size:10px;flex:1;min-width:0';
      const button = document.createElement('button');
      button.type = 'button'; button.textContent = 'Unblock';
      button.addEventListener('click', async () => {
        button.disabled = true;
        const {error: deleteError} = await client.from('user_blocks').delete().eq('blocker_id', user.id).eq('blocked_id', block.blocked_id);
        if (deleteError) { button.disabled = false; status('Could not unblock this account. Please try again.'); return; }
        row.remove(); status('Account unblocked. Refresh the page to reload content.');
        if (!list.querySelector('div')) { const empty = document.createElement('p'); empty.textContent = 'You have not blocked any accounts.'; list.appendChild(empty); }
      });
      row.append(id, button); list.appendChild(row);
    });
    status('Blocked-account list loaded.');
  });
  $('ventSafetyModerator').addEventListener('click', async () => {
    const user = await signedIn(); if (!user) return;
    const review = $('ventSafetyReview');
    review.hidden = false;
    review.replaceChildren();
    const heading = document.createElement('h4');
    heading.textContent = 'Moderator report queue';
    review.appendChild(heading);
    const filter = document.createElement('select');
    filter.setAttribute('aria-label', 'Filter reports by status');
    [['pending','Pending'],['reviewing','Reviewing'],['resolved','Resolved'],['dismissed','Dismissed'],['','All statuses']].forEach(([value,label]) => {
      const option = document.createElement('option'); option.value = value; option.textContent = label; filter.appendChild(option);
    });
    review.appendChild(filter);
    const results = document.createElement('div');
    review.appendChild(results);
    const loadReports = async () => {
      results.replaceChildren();
      const {data, error} = await client.rpc('moderator_list_reports', {
        p_status: filter.value || null, p_limit: 50
      });
      if (error) {
        const message = document.createElement('p');
        message.textContent = error.code === '42501'
          ? 'Moderator access is restricted. If you should have access, ask the project administrator to provision your account.'
          : 'Could not load reports. Confirm the moderator-review migration is applied.';
        results.appendChild(message); return;
      }
      if (!data?.length) {
        const empty = document.createElement('p'); empty.textContent = 'No reports in this queue.'; results.appendChild(empty); return;
      }
      data.forEach(report => {
        const card = document.createElement('article');
        card.style.cssText = 'border-top:1px solid #e2e6dc;padding:12px 0;overflow-wrap:anywhere';
        const title = document.createElement('strong');
        title.textContent = report.reason + ' · ' + report.status;
        const target = document.createElement('p');
        target.textContent = 'Report ID: ' + report.id + ' · Reporter: ' + report.reporter_id;
        const details = document.createElement('p');
        details.textContent = 'Target: ' + (report.reported_user_id || report.post_id || report.comment_id || 'unknown') + ' · ' + (report.details || 'No extra details');
        const statusLabel = document.createElement('label'); statusLabel.textContent = 'Decision';
        const statusSelect = document.createElement('select');
        [['pending','Pending'],['reviewing','Reviewing'],['resolved','Resolved'],['dismissed','Dismissed']].forEach(([value,label]) => {
          const option = document.createElement('option'); option.value = value; option.textContent = label; statusSelect.appendChild(option);
        });
        statusSelect.value = report.status;
        const notesLabel = document.createElement('label'); notesLabel.textContent = 'Private moderator notes';
        const notes = document.createElement('textarea'); notes.maxLength = 2000; notes.value = report.moderator_notes || '';
        const save = document.createElement('button'); save.type = 'button'; save.textContent = 'Save review';
        save.addEventListener('click', async () => {
          save.disabled = true;
          const {error: saveError} = await client.rpc('moderator_update_report', {
            p_report_id: report.id, p_status: statusSelect.value, p_moderator_notes: notes.value
          });
          save.disabled = false;
          if (saveError) { status('Could not save review. Confirm moderator access and try again.'); return; }
          status('Report review saved.'); await loadReports();
        });
        card.append(title, target, details, statusLabel, statusSelect, notesLabel, notes, save);
        results.appendChild(card);
      });
    };
    filter.addEventListener('change', loadReports);
    await loadReports();
  });
  document.addEventListener('click', event => {
    const post = event.target.closest('article[id^="post-"]');
    const profile = event.target.closest('[data-profile]');
    if (post) { $('ventSafetyTargetType').value = 'post'; $('ventSafetyTargetId').value = post.id.slice(5); }
    else if (profile?.dataset.profile) { $('ventSafetyTargetType').value = 'user'; $('ventSafetyTargetId').value = profile.dataset.profile; }
  }, true);
  function validUuid(value) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
  async function signedIn() {
    const {data, error} = await client.auth.getUser();
    if (error || !data?.user) { status('Please sign in to use reporting and blocking.'); return null; }
    currentUser = data.user; return currentUser;
  }
  $('ventSafetyReport').addEventListener('click', async () => {
    const user = await signedIn(); if (!user) return;
    const type = $('ventSafetyTargetType').value, id = $('ventSafetyTargetId').value.trim();
    if (!validUuid(id)) { status('Select a profile or post on the page, or enter a valid ID.'); return; }
    if (type === 'user' && id === user.id) { status('You cannot report your own account.'); return; }
    const payload = {reporter_id:user.id, reason:$('ventSafetyReason').value, details:$('ventSafetyDetails').value.trim()};
    payload[type === 'user' ? 'reported_user_id' : 'post_id'] = id;
    $('ventSafetyReport').disabled = true;
    const {error} = await client.from('content_reports').insert(payload);
    $('ventSafetyReport').disabled = false;
    if (error) { status(error.code === '42P01' || error.code === 'PGRST205' ? 'Reporting is not set up yet. Apply the trust-safety SQL migration first.' : 'Could not submit report. Check that the migration is applied and try again.'); return; }
    $('ventSafetyDetails').value = ''; status('Report submitted privately. Thank you for helping keep Venturify safe.');
  });
  $('ventSafetyBlock').addEventListener('click', async () => {
    const user = await signedIn(); if (!user) return;
    if ($('ventSafetyTargetType').value !== 'user') { status('Choose a founder profile before blocking.'); return; }
    const id = $('ventSafetyTargetId').value.trim();
    if (!validUuid(id)) { status('Select a founder profile on the page or enter a valid profile ID.'); return; }
    if (id === user.id) { status('You cannot block your own account.'); return; }
    if (!confirm('Block this founder? You can unblock them later from your blocked-account settings.')) return;
    $('ventSafetyBlock').disabled = true;
    const {error} = await client.from('user_blocks').upsert({blocker_id:user.id, blocked_id:id}, {onConflict:'blocker_id,blocked_id', ignoreDuplicates:true});
    $('ventSafetyBlock').disabled = false;
    if (error) { status(error.code === '42P01' || error.code === 'PGRST205' ? 'Blocking is not set up yet. Apply the trust-safety SQL migration first.' : 'Could not block this account. Check that the migration is applied and try again.'); return; }
    status('Account blocked. Their profile, posts, and interactions are filtered while you are signed in. Refresh the page to reload visible content.');
  });
})();

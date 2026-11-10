(() => {
  const nav = document.querySelector('.nav.venturify-primary-nav');
  if (!nav) return;
  const account = nav.querySelector('#navAccount');
  const signup = nav.querySelector('#navSignup');
  const client = window.venturifySupabaseClient || (window.supabase && window.supabase.createClient
    ? window.supabase.createClient('https://edyssdvytwdvpqkmalow.supabase.co', 'sb_publishable_Gsv129_4tDStH7xzeirfAQ_LJ8ZSv1W')
    : null);
  let lastUserId = null;
  const applySession = (session) => {
    const user = session && session.user ? session.user : null;
    const authenticated = !!user;
    lastUserId = user ? user.id : null;
    document.body.classList.toggle('authenticated', authenticated);
    if (account) {
      account.textContent = authenticated ? 'Account' : 'Log in';
      account.setAttribute('href', authenticated ? 'settings.html' : '#');
      account.setAttribute('aria-label', authenticated ? 'Account settings' : 'Log in');
    }
    if (signup) {
      signup.hidden = authenticated;
      signup.setAttribute('aria-hidden', authenticated ? 'true' : 'false');
      if (authenticated) signup.setAttribute('tabindex', '-1');
      else signup.removeAttribute('tabindex');
    }
    nav.querySelectorAll('[data-auth-only]').forEach((item) => {
      item.hidden = false;
      item.removeAttribute('aria-hidden');
    });
  };
  const refresh = async () => {
    if (!client || !client.auth) { applySession(null); return; }
    try {
      const result = await client.auth.getSession();
      if (!result.error) applySession(result.data.session);
    } catch (error) {
      console.warn('Could not refresh navigation session state.', error);
    }
  };
  window.venturifyRefreshAuthNavigation = refresh;
  if (client && client.auth) {
    client.auth.onAuthStateChange((_event, session) => applySession(session));
    refresh();
    window.addEventListener('focus', refresh);
    document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
  } else {
    applySession(null);
  }
})();
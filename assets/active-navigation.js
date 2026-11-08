(() => {
  const nav = document.querySelector('.nav.venturify-primary-nav');
  if (!nav) return;

  const normalizePath = (path) => {
    const normalized = path.replace(/\\/+$/, '');
    return normalized || '/';
  };

  const updateActiveNavigation = () => {
    const currentPath = normalizePath(window.location.pathname);
    const currentHash = window.location.hash;
    const links = nav.querySelectorAll('a[href]');

    links.forEach((link) => {
      link.removeAttribute('aria-current');
      let target;
      try {
        target = new URL(link.getAttribute('href'), document.baseURI);
      } catch {
        return;
      }
      if (target.origin !== window.location.origin) return;

      const targetPath = normalizePath(target.pathname);
      const isPeople = link.dataset.appView === 'people';
      const isWorkspaceSection = targetPath.endsWith('/collaborations.html')
        && currentPath.endsWith('/workspace.html');
      const isCurrentPeopleSection = isPeople
        && targetPath === currentPath
        && target.hash === '#founderDiscovery'
        && currentHash === '#founderDiscovery';
      const isCurrentPage = !isPeople
        && targetPath === currentPath
        && !target.hash;
      if (isCurrentPage || isCurrentPeopleSection || isWorkspaceSection) {
        link.setAttribute('aria-current', 'page');
      }
    });

    if (currentPath.endsWith('/notifications.html')) {
      nav.querySelector('#notificationButton')?.setAttribute('aria-current', 'page');
    } else {
      nav.querySelector('#notificationButton')?.removeAttribute('aria-current');
    }
  };

  updateActiveNavigation();
  // Keep in-page destinations synchronized without requiring a full reload.
  window.addEventListener('hashchange', updateActiveNavigation);
  window.addEventListener('popstate', updateActiveNavigation);
})();

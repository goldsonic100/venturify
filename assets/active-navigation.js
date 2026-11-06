(() => {
  const nav = document.querySelector('.nav.venturify-primary-nav');
  if (!nav) return;

  const normalizePath = (path) => {
    const normalized = path.replace(/\/+$/, '');
    return normalized || '/';
  };
  const currentPath = normalizePath(window.location.pathname);
  const currentHash = window.location.hash;
  const links = nav.querySelectorAll('a[href]');

  links.forEach((link) => {
    link.removeAttribute('aria-current');
    const target = new URL(link.getAttribute('href'), document.baseURI);
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
    const notificationButton = nav.querySelector('#notificationButton');
    notificationButton?.setAttribute('aria-current', 'page');
  }
})();

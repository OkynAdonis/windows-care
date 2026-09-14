// Les contenus restent visibles si JavaScript ou les animations sont indisponibles.
(() => {
  'use strict';

  const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
  const revealItems = Array.from(document.querySelectorAll('.reveal'));
  let observer;
  let scoreFrame;
  const score = document.querySelector('[data-score]');
  const target = score ? Number(score.dataset.score) : NaN;

  const showAll = () => {
    if (observer) observer.disconnect();
    document.documentElement.classList.remove('js-motion');
    revealItems.forEach((item) => item.classList.add('is-visible'));
  };

  if ('IntersectionObserver' in window && !motionPreference.matches) {
    try {
      observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        });
      }, { threshold: 0 });
      revealItems.forEach((item, index) => {
        item.style.setProperty('--reveal-delay', `${Math.min(index * 40, 200)}ms`);
        observer.observe(item);
      });
      document.documentElement.classList.add('js-motion');
    } catch {
      showAll();
    }
  } else {
    showAll();
  }

  // Le clavier doit pouvoir atteindre un lien sans attendre le defilement.
  document.addEventListener('focusin', (event) => {
    const section = event.target.closest('.reveal');
    if (section) {
      section.classList.add('is-visible');
      if (observer) observer.unobserve(section);
    }
  });

  if (score && Number.isFinite(target)) {
    if (motionPreference.matches) {
      score.textContent = String(target);
    } else {
      const start = performance.now();
      const updateScore = (now) => {
        const progress = Math.min((now - start) / 1100, 1);
        score.textContent = String(Math.round(target * (1 - Math.pow(1 - progress, 3))));
        if (progress < 1) scoreFrame = window.requestAnimationFrame(updateScore);
      };
      scoreFrame = window.requestAnimationFrame(updateScore);
    }
  }

  const onMotionChange = () => {
    if (!motionPreference.matches) return;
    showAll();
    window.cancelAnimationFrame(scoreFrame);
    if (score && Number.isFinite(target)) score.textContent = String(target);
  };
  if (motionPreference.addEventListener) {
    motionPreference.addEventListener('change', onMotionChange);
  } else {
    motionPreference.addListener(onMotionChange);
  }

  // Un clic demande le telechargement ; son achevement depend du navigateur.
  const resetDownloads = [];
  document.querySelectorAll('[data-download]').forEach((button) => {
    const label = Array.from(button.childNodes).find((node) =>
      node.nodeType === Node.TEXT_NODE && node.nodeValue.trim()
    );
    if (!label) return;
    const original = label.nodeValue;
    const originalAria = button.getAttribute('aria-label');
    let timer;
    const reset = () => {
      window.clearTimeout(timer);
      label.nodeValue = original;
      button.classList.remove('download-started');
      if (originalAria === null) button.removeAttribute('aria-label');
      else button.setAttribute('aria-label', originalAria);
    };
    resetDownloads.push(reset);
    button.addEventListener('click', (event) => {
      if (event.defaultPrevented || event.button !== 0 || event.ctrlKey ||
          event.metaKey || event.shiftKey || event.altKey) return;
      window.clearTimeout(timer);
      label.nodeValue = ' Téléchargement demandé ';
      button.classList.add('download-started');
      button.setAttribute('aria-label', 'Téléchargement demandé');
      timer = window.setTimeout(reset, 1800);
    });
  });

  // Les liens HTML gardent leur navigation native, y compris le retour arriere.
  const actionSearch = document.querySelector('#action-search');
  const cards = Array.from(document.querySelectorAll('.action-card'));
  const status = document.querySelector('#action-search-status');
  const normalize = (value) => value.normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase('fr').trim();
  const searchable = cards.map((card) => normalize(card.textContent));

  const filterActions = () => {
    if (!actionSearch) return;
    const words = normalize(actionSearch.value).split(/\s+/).filter(Boolean);
    let count = 0;
    cards.forEach((card, index) => {
      const match = words.every((word) => searchable[index].includes(word));
      card.hidden = !match;
      if (match) count += 1;
      if (match && words.length) {
        card.classList.add('is-visible');
        if (observer) observer.unobserve(card);
      }
    });
    if (status) {
      status.textContent = count === 0
        ? 'Aucune action trouvée. Essayez un autre mot.'
        : `${count} action${count > 1 ? 's' : ''} affichée${count > 1 ? 's' : ''} sur ${cards.length}.`;
    }
  };
  if (actionSearch) {
    actionSearch.addEventListener('input', filterActions);
    filterActions();
  }
  window.addEventListener('pageshow', () => {
    resetDownloads.forEach((reset) => reset());
    filterActions();
  });
})();

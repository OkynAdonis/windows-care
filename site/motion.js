// Coordonne les animations utiles du site sans mouvement permanent agressif.
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const revealItems = document.querySelectorAll('.reveal');

// Revele les actions dans l ordre pour faciliter la lecture du guide.
revealItems.forEach((item, index) => {
  item.style.setProperty('--reveal-delay', reduceMotion ? '0ms' : `${Math.min(index * 55, 550)}ms`);
});

if ('IntersectionObserver' in window && !reduceMotion) {
  const observer = new IntersectionObserver((entries, currentObserver) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        currentObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.18 });

  revealItems.forEach((item) => observer.observe(item));
} else {
  revealItems.forEach((item) => item.classList.add('is-visible'));
}

// Anime le score demonstratif sans le presenter comme une mesure en temps reel.
const score = document.querySelector('[data-score]');
if (score) {
  const target = Number(score.dataset.score);
  if (reduceMotion) {
    score.textContent = target;
  } else {
    const start = performance.now();
    const duration = 1100;
    const updateScore = (now) => {
      const progress = Math.min((now - start) / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      score.textContent = Math.round(target * eased);
      if (progress < 1) window.requestAnimationFrame(updateScore);
    };
    window.requestAnimationFrame(updateScore);
  }
}

// Confirme visuellement le clic sans empecher le telechargement natif du navigateur.
document.querySelectorAll('[data-download]').forEach((button) => {
  button.addEventListener('click', () => {
    const label = button.firstChild;
    if (!label) return;
    const original = label.nodeValue;
    label.nodeValue = ' Téléchargement lancé ';
    button.classList.add('download-started');
    button.setAttribute('aria-label', 'Téléchargement lancé');
    window.setTimeout(() => {
      label.nodeValue = original;
      button.classList.remove('download-started');
      button.removeAttribute('aria-label');
    }, 1800);
  });
});

// Adoucit le passage entre les pages HTML locales.
document.querySelectorAll('a[href$=".html"]').forEach((link) => {
  link.addEventListener('click', (event) => {
    if (reduceMotion || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    document.body.classList.add('page-leaving');
    window.setTimeout(() => { window.location.href = link.href; }, 180);
  });
});

// Filtre les 21 actions sans recharger la page.
const actionSearch = document.querySelector('#action-search');
if (actionSearch) {
  actionSearch.addEventListener('input', () => {
    const query = actionSearch.value.trim().toLocaleLowerCase();
    document.querySelectorAll('.action-card').forEach((card) => {
      card.classList.toggle('is-filtered', query !== '' && !card.textContent.toLocaleLowerCase().includes(query));
    });
  });
}
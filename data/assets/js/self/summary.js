// Summary page - vanilla JS (no jQuery)
class BlogSummary {
  constructor() {
    this.data = null;
  }

  start() {
    fetch('/payload.json')
      .then(response => response.json())
      .then(data => {
        this.data = data;
        this.startSummary();
        this.calcStats();
      });
  }

  startSummary() {
    document.getElementById('by-land').addEventListener('click', (e) => {
      e.preventDefault();
      this.startSummaryByLand();
    });

    document.getElementById('by-town').addEventListener('click', (e) => {
      e.preventDefault();
      this.startSummaryByTown();
    });

    document.getElementById('by-time').addEventListener('click', (e) => {
      e.preventDefault();
      this.startSummaryByTime();
    });
  }

  calcStats() {
    let doneCount = 0;
    let allCount = 0;

    for (const post of this.data.posts) {
      const isDone = !post.tags.includes('todo');
      if (isDone) doneCount++;
      allCount++;
    }

    document.getElementById('stats-count').textContent = allCount;
    document.getElementById('stats-done-count').textContent = doneCount;
    document.getElementById('stats-done-percent').textContent = Math.floor(100 * doneCount / allCount);
  }

  // Helper to create element with attributes
  createElement(tag, attrs = {}) {
    const el = document.createElement(tag);
    if (attrs.id) el.id = attrs.id;
    if (attrs.class) el.className = attrs.class;
    if (attrs.text) el.textContent = attrs.text;
    if (attrs.title) el.title = attrs.title;
    if (attrs.href) el.href = attrs.href;
    return el;
  }

  // By Town view
  startSummaryByTown() {
    const content = document.getElementById('content');
    content.innerHTML = '';

    const mainObject = this.createElement('ul', { id: 'town-tree', class: 'summary' });
    content.appendChild(mainObject);

    for (const voivodeship of this.data.voivodeships) {
      const voivodeshipObject = this.createElement('li', { id: voivodeship.slug, class: 'summary-voivodeship' });
      mainObject.appendChild(voivodeshipObject);

      const voivodeshipSpan = this.createElement('span', { text: voivodeship.name, title: voivodeship.name });
      voivodeshipObject.appendChild(voivodeshipSpan);

      const voivodeshipContainer = this.createElement('ul', { id: voivodeship.slug, class: 'summary-towns-container' });
      voivodeshipObject.appendChild(voivodeshipContainer);

      for (const town of this.data.towns) {
        if (town.voivodeship === voivodeship.slug) {
          const townObject = this.createElement('li', { id: town.slug, class: 'summary-town' });
          voivodeshipContainer.appendChild(townObject);

          const townLink = this.createElement('a', { text: town.name, title: town.name, href: town.url });
          townObject.appendChild(townLink);

          const postsContainer = this.createElement('ul', { class: 'summary-posts-container' });
          townObject.appendChild(postsContainer);

          for (const post of this.data.posts) {
            if (post.towns.includes(town.slug)) {
              this.insertPost(post, postsContainer);
            }
          }
        }
      }
    }
  }

  // By Time view
  startSummaryByTime() {
    const content = document.getElementById('content');
    content.innerHTML = '';

    const mainObject = this.createElement('ul', { id: 'time-tree', class: 'summary' });
    content.appendChild(mainObject);

    for (const post of this.data.posts) {
      const yearId = 'time-' + post.year;
      const monthId = 'time-' + post.year + '_' + post.month;

      if (!document.getElementById(yearId)) {
        const yearLi = this.createElement('li', { class: 'summary-time-year' });
        mainObject.appendChild(yearLi);

        const yearSpan = this.createElement('span', { text: post.year, title: post.year });
        yearLi.appendChild(yearSpan);

        const yearContainer = this.createElement('ul', { id: yearId, class: 'summary-time-year-container' });
        yearLi.appendChild(yearContainer);
      }

      if (!document.getElementById(monthId)) {
        const monthLi = this.createElement('li', { class: 'summary-time-month' });
        document.getElementById(yearId).appendChild(monthLi);

        const monthSpan = this.createElement('span', { text: post.month, title: post.month });
        monthLi.appendChild(monthSpan);

        const monthContainer = this.createElement('ul', { id: monthId, class: 'summary-time-month-container' });
        monthLi.appendChild(monthContainer);
      }

      this.insertPost(post, document.getElementById(monthId));
    }
  }

  // By Land view
  startSummaryByLand() {
    const content = document.getElementById('content');
    content.innerHTML = '';

    const mainObject = this.createElement('ul', { id: 'land-tree', class: 'summary' });
    content.appendChild(mainObject);

    for (const landType of this.data.land_types) {
      const landTypeObject = this.createElement('li', { id: landType.slug, class: 'summary-land-type' });
      mainObject.appendChild(landTypeObject);

      const landTypeSpan = this.createElement('span', { text: landType.name, title: landType.name });
      landTypeObject.appendChild(landTypeSpan);

      const landTypeContainer = this.createElement('ul', { id: landType.slug, class: 'summary-lands-container' });
      landTypeObject.appendChild(landTypeContainer);

      for (const land of this.data.lands) {
        if (land.type === landType.slug) {
          const landObject = this.createElement('li', { id: land.slug, class: 'summary-land' });
          landTypeContainer.appendChild(landObject);

          const landLink = this.createElement('a', { text: land.name, title: land.name, href: land.url });
          landObject.appendChild(landLink);

          const postsContainer = this.createElement('ul', { class: 'summary-posts-container' });
          landObject.appendChild(postsContainer);

          for (const post of this.data.posts) {
            if (post.lands.includes(land.slug)) {
              this.insertPost(post, postsContainer);
            }
          }
        }
      }
    }
  }

  insertPost(post, postsContainer) {
    const isDone = !post.tags.includes('todo');

    const postElement = this.createElement('li', { class: 'summary-post' });
    if (!isDone) {
      postElement.classList.add('summary-post-todo');
    }
    postsContainer.appendChild(postElement);

    const postLink = this.createElement('a', {
      text: post.date + ' - ' + post.title,
      title: post.date + ' - ' + post.title,
      href: post.url
    });
    postElement.appendChild(postLink);
  }
}

// Auto-initialize on DOM ready
function initSummary() {
  const summary = new BlogSummary();
  summary.start();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initSummary);
} else {
  initSummary();
}

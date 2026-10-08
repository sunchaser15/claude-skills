# Движение, скролл, шейдеры

Основа правил — философия Эмиля Ковальски (скилл `emil-design-eng`) и официальные скиллы GSAP. Для деталей загружай их: `gsap-core`, `gsap-scrolltrigger`, `gsap-timeline`, `gsap-plugins`, `threejs-shaders`, `animation-vocabulary` (чтобы назвать эффект, который описан словами), `fixing-motion-performance` (когда тормозит).

## Решать по порядку

Фильтр antislop (R-19): у каждой анимации записана **цель**, и движение соответствует заявленному dial MOTION (1: только hover; 2: появление и переходы; 3: параллакс, pin, хореография). «Одно и то же появление снизу у каждого блока» это шаблон, а не решение. Применяй появление только там, где оно ведёт взгляд (например, каскад героя), остальное оставляй статичным.

1. **Анимировать ли вообще?** Как часто человек это видит. Сотни раз в день (горячие клавиши, переключатели) — никогда. Десятки (hover, списки) — минимум. Изредка (модалки, тосты) — обычная анимация. Редко (онбординг, первый экран) — можно эффектно.
2. **Зачем?** Допустимые цели: пространственная связность (откуда пришло, туда и уходит), состояние (кнопка стала «готово»), объяснение (как работает), отклик (кнопка сжалась), смягчение резкой смены. «Красиво» для частого элемента — не причина.
3. **Какая кривая?** Появление и уход — **ease-out** (быстрый старт ощущается отзывчивым). Перемещение по экрану — ease-in-out. Цвет и hover — ease. Бесконечное (бегущая строка) — linear. **ease-in для интерфейса не использовать.** Встроенные кривые CSS слабоваты, бери свои.
4. **Как быстро?** Нажатие 100–160 мс, подсказки 125–200, выпадающие 150–250, модалки и шторки 200–500. **Интерфейс укладывается в 300 мс.** Маркетинговое и объясняющее может быть дольше (600–1200 мс).

```css
:root {
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);      /* появление, отклик */
  --ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);  /* движение по экрану */
  --ease-drawer: cubic-bezier(0.32, 0.72, 0, 1);   /* шторки, как в iOS */
  --dur-press: 120ms; --dur-fast: 180ms; --dur-base: 240ms; --dur-slow: 480ms; --dur-hero: 900ms;
}
```

Правила мелочей: ничего не появляется из «нуля» — старт с `scale(.95)` + `opacity: 0`, а не `scale(0)`; поповер масштабируется из точки триггера (`transform-origin`), модалка из центра; на кнопке `:active { transform: scale(.97) }`; никогда `transition: all` — перечисляй свойства; задержки между элементами в каскаде 40–80 мс и суммарно не дольше ~600 мс.

## Движение должно уважать пользователя

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: .01ms !important; animation-iteration-count: 1 !important; transition-duration: .01ms !important; scroll-behavior: auto !important; }
}
```
В JS (GSAP) делай `gsap.matchMedia()` и вместо параллакса, скраба и больших смещений оставляй мгновенное состояние или простое появление.

## Каталог приёмов с рабочим кодом

### Появление при скролле (без библиотек)
```js
const io = new IntersectionObserver((entries) => {
  for (const e of entries) if (e.isIntersecting) { e.target.classList.add('is-in'); io.unobserve(e.target); }
}, { threshold: 0.15, rootMargin: '0px 0px -8% 0px' });
document.querySelectorAll('[data-reveal]').forEach((el) => io.observe(el));
```
```css
[data-reveal] { opacity: 0; transform: translateY(16px); transition: opacity var(--dur-slow) var(--ease-out), transform var(--dur-slow) var(--ease-out); transition-delay: calc(var(--i, 0) * 60ms); }
[data-reveal].is-in { opacity: 1; transform: none; }
```
`--i` задаёт порядок в каскаде (`style="--i:2"`). Без JS контент должен быть виден: добавь `<noscript><style>[data-reveal]{opacity:1;transform:none}</style></noscript>`.

### Скролл по CSS (без JS, Chrome/Edge/Safari 26+; в Firefox как улучшение)
```css
@supports (animation-timeline: view()) {
  .card { animation: rise linear both; animation-timeline: view(); animation-range: entry 0% cover 30%; }
  @keyframes rise { from { opacity: 0; transform: translateY(40px) scale(.97); } to { opacity: 1; transform: none; } }
}
```

### Плавный скролл + ScrollTrigger (Lenis + GSAP, правильная связка)
```js
import Lenis from 'lenis'; import gsap from 'gsap'; import { ScrollTrigger } from 'gsap/ScrollTrigger';
gsap.registerPlugin(ScrollTrigger);
const lenis = new Lenis({ lerp: 0.1 });
lenis.on('scroll', ScrollTrigger.update);
gsap.ticker.add((t) => lenis.raf(t * 1000));
gsap.ticker.lagSmoothing(0);
```
Без сборки: `https://cdn.jsdelivr.net/npm/gsap@3/dist/gsap.min.js`, `.../gsap@3/dist/ScrollTrigger.min.js`, `https://cdn.jsdelivr.net/npm/lenis@1/dist/lenis.min.js` (глобальный `Lenis`). Плавный скролл отключай при reduced-motion и на тач-устройствах, если нет причины его держать; не ломай якоря и клавиатуру.

### Каскад заголовка и секций (GSAP)
```js
gsap.matchMedia().add('(prefers-reduced-motion: no-preference)', () => {
  gsap.from('.hero [data-split] > *', { y: 24, opacity: 0, duration: .9, ease: 'power3.out', stagger: .07 });
  gsap.utils.toArray('.section').forEach((s) => gsap.from(s.querySelectorAll('[data-reveal]'), {
    y: 32, opacity: 0, duration: .8, ease: 'power3.out', stagger: .08,
    scrollTrigger: { trigger: s, start: 'top 80%', once: true } }));
});
```

### Закреплённый рассказ (pin + scrub)
```js
const tl = gsap.timeline({ scrollTrigger: { trigger: '.story', start: 'top top', end: '+=300%', pin: true, scrub: 0.6 } });
tl.from('.story .a', { opacity: 0, y: 40 }).to('.story .a', { opacity: 0 }, '+=0.6').from('.story .b', { opacity: 0, y: 40 });
```
Не злоупотреблять: две-три таких секции на страницу, на телефоне упрощать до обычных блоков.

### Разбивка текста по буквам/словам
Плагин `SplitText` из GSAP теперь бесплатный; для простого случая достаточно обернуть слова в `<span>` скриптом и анимировать `translateY(100%)` внутри `overflow: hidden` (эффект «выезжает из-под линии»). Сохраняй читаемость для скринридера: оригинальный текст в `aria-label`, куски `aria-hidden`.

### Магнитная кнопка и подсветка под курсором
```js
document.querySelectorAll('[data-glow]').forEach((el) => el.addEventListener('pointermove', (e) => {
  const r = el.getBoundingClientRect(); el.style.setProperty('--mx', `${e.clientX - r.left}px`); el.style.setProperty('--my', `${e.clientY - r.top}px`); }));
```
```css
[data-glow] { position: relative; background: radial-gradient(240px circle at var(--mx, 50%) var(--my, 0%), rgb(255 255 255 / .08), transparent 60%), var(--surface); }
```
Только при `@media (hover: hover) and (pointer: fine)`.

### Бегущая строка (логотипы, ключевые слова)
Дублируй содержимое дважды и двигай контейнер `translateX(-50%)` линейно бесконечно (`animation: marquee 30s linear infinite`); пауза по `:hover`, остановка при reduced-motion. Градиентная маска по краям: `mask-image: linear-gradient(90deg, transparent, #000 10%, #000 90%, transparent)`.

### Переходы между страницами
```css
@view-transition { navigation: auto; }  /* междокументные переходы, Chrome/Safari; остальные просто без анимации */
::view-transition-old(root), ::view-transition-new(root) { animation-duration: .35s; animation-timing-function: var(--ease-out); }
```
Для SPA — `document.startViewTransition(() => обновитьDOM())`.

### Счётчики и цифры
Анимируй от 0 к значению один раз при появлении (`gsap.to(obj, { val, duration: 1.4, ease: 'power2.out', onUpdate })`), `tabular-nums`, а итоговое число кладите в DOM сразу для скринридера и поисковиков.

## Шейдеры на сайте

Когда уместны: фон героя (мягкий текучий градиент, шум, «жидкое стекло»), искажение картинки при наведении, переход между секциями, 3D-объект как визуальный якорь. Когда нет: где достаточно CSS-градиента, на каждой странице приложения, на слабых телефонах без запасного варианта.

**Выбор инструмента**
- Один фон-шейдер: чистый WebGL (60 строк, см. `templates/shader-bg.js`) — ноль зависимостей, ~2 КБ.
- Несколько эффектов над картинками/текстами: **OGL** (~30 КБ) или Three.js с `ShaderMaterial` (скилл `threejs-shaders`).
- Реактивное 3D, модели: Three.js / React Three Fiber (`threejs-fundamentals`, `threejs-animation`).

**Дисциплина**
- Один полноэкранный шейдер на страницу; DPR ≤ 1,5; сложный шум (fbm) — 3–4 октавы, не 8.
- Пауза вне экрана и на скрытой вкладке; при `prefers-reduced-motion` — один кадр и без движения.
- Запасной вариант: CSS-градиент того же цвета под канвасом и до первого кадра, `try/catch` на получении контекста.
- Цвета берём из CSS-переменных, чтобы шейдер совпадал с палитрой темы.
- Текст поверх шейдера держит контраст ≥ 4,5:1 в **самой светлой** точке фона: затемни область под текстом слоем-подложкой.
- Проверяй на реальном телефоне, а не только на ноутбуке. Если кадров меньше 50 в секунду — упрощай шейдер или снижай разрешение рендера (`scale 0.5–0.75`).

**Готовая библиотека: Shaders** (`github.com/shader-effects-inc/shaders`, npm `shaders`, движок и компоненты MIT). 199 эффектов слоями: генераторы (MeshGradient, Aurora, Godrays, Beam, StudioBackground), эффекты формы по SDF или своему SVG (Glass, Chrome, Obsidian, LiquidMetal, LightEdge, Neon), стилизация (FilmGrain, LensFlare, LightLeak, Glow, Vignette), переходы и курсорные эффекты. Подключается в React, Vue, Svelte, Solid и чистом JS (`createShader(canvas,{components:[...]})`); визуальный редактор на shaders.com отдаёт готовый код.
- **Главное ограничение: только WebGPU, запасного WebGL нет.** Для сервиса, куда приходят с телефонов и из встроенного браузера Telegram, это значит: эффект только как украшение поверх CSS-фона, никогда не как носитель смысла. Если сцена несёт бренд (вступление, знак), бери Three.js/WebGL.
- Справочник для агента: `https://shaders.com/llms-full.txt` (все компоненты, пропсы, диапазоны), страница компонента в markdown: `https://shaders.com/docs/components/<Name>` с заголовком `Accept: text/markdown`. Пресеты и секции платные (Pro), обходить это не надо.
- Их скилл и MCP (`npx shaders connect`, `npx shaders install-mcp`) **не установлены**: `connect` ставит пакет в проект, входит в аккаунт через браузер и пишет конфиг; ставить только в проект, где библиотека реально нужна, и с согласия владельца.
- Полезно подсмотреть как приёмы и перенести в свой WebGL: `Godrays` (лучи из точки: шум по углу в полярных координатах, два слоя), `LightEdge` (бегущие пятна света по контуру любой формы через её SDF), `FilmGrain`, `LensFlare`.

**Контровой свет за знаком (рецепт сайта EgrVPN, 08.10.2026, работает)**: знак выдавлен в Three.js (`ExtrudeGeometry` + фаска), материал почти чёрный, `roughness` ≈ 0,5 (глянец ниже 0,3 даёт резкие прямоугольные блики на стенках вырезов); за знаком плоскость с аддитивным свечением, посчитанным формулой в шейдере (сумма спадов `1/(1+(r/R)²)^k`, без текстуры, иначе виден край диска); точечный свет сзади даёт кромку на фаске; bloom с порогом ≈ 0,78 и силой 0,15–0,35 (ниже порога он заливает знак молоком); зерно и виньетка в последнем проходе. Камера облетает (азимут −38° → 0°) и подъезжает, источник уходит за знак и там усиливается. Цикл рисования останавливается после финального кадра. Ошибки, которые уже сделаны: спрайты-текстуры для свечения (видна граница диска), сильный `RoomEnvironment` (лицо становится серым металлом), источник прямо за вырезами (горят пятна на стенках). Код: `server-repos/egrvpn/site/hero.js`.

**Идеи эффектов для героя**: текучий градиент из 3–4 цветов палитры (domain warping на fbm); зернистый «плёночный» шум поверх; сетка точек, реагирующая на курсор; металлическая/стеклянная капля (Three, `MeshPhysicalMaterial`); искажение изображения волной при hover (displacement map + `uProgress`).

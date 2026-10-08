/* Шейдерный фон без зависимостей (~2 КБ): текучий градиент из цветов палитры + зерно.
   Подключение:  <canvas id="bg" aria-hidden="true"></canvas>  <script src="shader-bg.js"></script>
                 <script>initShaderBg(document.getElementById('bg'));</script>
   Цвета берутся из CSS-переменных --bg, --primary, --accent на :root, так что фон совпадает с темой.
   Правила: пауза вне экрана и на скрытой вкладке, DPR ≤ 1.5, один кадр при prefers-reduced-motion,
   запасной вариант — класс .no-webgl на canvas (нарисуй CSS-градиент под ним). */
(function () {
  var VERT = 'attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}';
  var FRAG = [
    'precision mediump float;',
    'uniform vec2 u_res,u_mouse;uniform float u_time;uniform vec3 u_bg,u_c1,u_c2,u_c3;',
    'float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}',
    'float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);',
    ' return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}',
    'float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<4;i++){v+=a*n(p);p*=2.;a*=.5;}return v;}',
    'void main(){',
    ' vec2 uv=gl_FragCoord.xy/u_res;vec2 p=uv*vec2(u_res.x/u_res.y,1.)*1.6;float t=u_time*.06;',
    ' vec2 q=vec2(fbm(p+t),fbm(p+vec2(5.2,1.3)-t));',
    ' vec2 r=vec2(fbm(p+3.*q+vec2(1.7,9.2)+t*1.3),fbm(p+3.*q+vec2(8.3,2.8)-t));',
    ' float f=fbm(p+3.*r);',
    ' vec3 c=mix(u_bg,u_c1,smoothstep(.2,.8,f));',
    ' c=mix(c,u_c2,smoothstep(.45,.95,length(q))*.6);',
    ' c=mix(c,u_c3,smoothstep(.55,1.,r.x)*.4);',
    ' c+=u_c1*.10*smoothstep(.4,0.,distance(uv,u_mouse));',
    ' c=mix(u_bg,c,smoothstep(1.25,.15,distance(uv,vec2(.5,.35))));',
    ' c+=(h(gl_FragCoord.xy+fract(u_time))-.5)*.03;',
    ' gl_FragColor=vec4(c,1.);}'
  ].join('\n');

  function parseColor(v) {
    v = (v || '').trim();
    if (v[0] === '#') {
      if (v.length === 4) v = '#' + v[1] + v[1] + v[2] + v[2] + v[3] + v[3];
      return [1, 3, 5].map(function (i) { return parseInt(v.slice(i, i + 2), 16) / 255; });
    }
    var m = v.match(/[\d.]+/g);
    return m ? m.slice(0, 3).map(function (x) { return +x / 255; }) : [0, 0, 0];
  }
  function mix(a, b, t) { return a.map(function (x, i) { return x + (b[i] - x) * t; }); }

  window.initShaderBg = function (canvas, opts) {
    opts = opts || {};
    var cs = getComputedStyle(document.documentElement);
    var bg = parseColor(cs.getPropertyValue('--bg'));
    var primary = parseColor(cs.getPropertyValue('--primary'));
    var accent = parseColor(cs.getPropertyValue('--accent'));
    // приглушаем: фон — подложка под текст, а не главный герой
    var c1 = mix(bg, primary, opts.strength || 0.28);
    var c2 = mix(bg, accent, (opts.strength || 0.28) * 1.1);
    var c3 = mix(bg, primary, (opts.strength || 0.28) * 0.7);

    var gl;
    try { gl = canvas.getContext('webgl', { antialias: false, alpha: false, powerPreference: 'low-power' }); } catch (e) {}
    if (!gl) { canvas.classList.add('no-webgl'); return; }

    function sh(type, src) { var s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); return s; }
    var prog = gl.createProgram();
    gl.attachShader(prog, sh(gl.VERTEX_SHADER, VERT));
    gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, FRAG));
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) { canvas.classList.add('no-webgl'); return; }
    gl.useProgram(prog);
    var buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    var loc = gl.getAttribLocation(prog, 'p');
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

    var U = {};
    ['u_res', 'u_mouse', 'u_time', 'u_bg', 'u_c1', 'u_c2', 'u_c3'].forEach(function (k) { U[k] = gl.getUniformLocation(prog, k); });
    gl.uniform3fv(U.u_bg, bg); gl.uniform3fv(U.u_c1, c1); gl.uniform3fv(U.u_c2, c2); gl.uniform3fv(U.u_c3, c3);

    var reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
    var scale = opts.scale || 0.75;                       // рендер в 75% разрешения — хватает для мягкого фона
    var dpr = Math.min(window.devicePixelRatio || 1, 1.5);
    var mouse = [0.5, 0.5], target = [0.5, 0.5];
    var visible = true, raf = 0, start = performance.now();

    function resize() {
      var w = Math.max(1, Math.round(canvas.clientWidth * dpr * scale));
      var h = Math.max(1, Math.round(canvas.clientHeight * dpr * scale));
      if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
      gl.viewport(0, 0, w, h);
      gl.uniform2f(U.u_res, w, h);
    }
    function frame(now) {
      raf = 0;
      resize();
      mouse[0] += (target[0] - mouse[0]) * 0.06; mouse[1] += (target[1] - mouse[1]) * 0.06;
      gl.uniform2f(U.u_mouse, mouse[0], mouse[1]);
      gl.uniform1f(U.u_time, reduced ? 12.0 : (now - start) / 1000);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      if (!reduced && visible && !document.hidden) raf = requestAnimationFrame(frame);
    }
    function kick() { if (!raf) raf = requestAnimationFrame(frame); }

    if (!reduced) {
      window.addEventListener('pointermove', function (e) {
        var r = canvas.getBoundingClientRect();
        target = [(e.clientX - r.left) / r.width, 1 - (e.clientY - r.top) / r.height];
      }, { passive: true });
      new IntersectionObserver(function (es) { visible = es[0].isIntersecting; if (visible) kick(); }).observe(canvas);
      document.addEventListener('visibilitychange', function () { if (!document.hidden) kick(); });
    }
    new ResizeObserver(function () { kick(); }).observe(canvas);
    kick();
  };
})();

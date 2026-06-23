import Foundation

/// The phone-facing looper remote page. Big tap targets, dark DL4-green theme.
enum LooperPage {
    static let html = """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
    <title>DL4 Looper</title>
    <style>
      :root { color-scheme: dark; }
      * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
      body {
        margin: 0; min-height: 100vh; background: #0d0f0e; color: #e8efe9;
        font: 600 16px/1.2 -apple-system, system-ui, sans-serif;
        display: flex; flex-direction: column; gap: 14px; padding: 18px;
      }
      h1 { font-size: 14px; letter-spacing: .16em; text-transform: uppercase;
           color: #5bbf73; margin: 4px 2px 0; }
      .grid, .row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
      button {
        appearance: none; border: 1px solid #1f2a22; border-radius: 16px;
        background: #141a16; color: #e8efe9; font: inherit; font-size: 17px;
        padding: 22px 12px; transition: transform .05s, background .1s;
      }
      button:active { transform: scale(.96); background: #1d2620; }
      button.rec { border-color: #6a1f1f; color: #ff6b6b; }
      button.go  { border-color: #1f5a2e; color: #5bbf73; }
      button.wide { grid-column: 1 / -1; }
      .stat { font-size: 12px; letter-spacing: .08em; color: #6f7d73;
              text-align: center; min-height: 16px; }
    </style>
    </head>
    <body>
      <h1>DL4 Looper</h1>
      <div class="grid">
        <button class="rec" onclick="cmd('record')">&#9679; Record</button>
        <button onclick="cmd('overdub')">&#8853; Overdub</button>
        <button class="go" onclick="cmd('play')">&#9654; Play</button>
        <button onclick="cmd('stop')">&#9632; Stop</button>
        <button class="wide" onclick="cmd('once')">&#9654;| Play Once</button>
      </div>
      <div class="row">
        <button onclick="cmd('undo')">&#8630; Undo</button>
        <button onclick="cmd('redo')">&#8631; Redo</button>
        <button onclick="cmd('reverse')">&#9664; Reverse</button>
        <button onclick="cmd('forward')">&#9654; Forward</button>
        <button onclick="cmd('half')">&frac12;&times; Half</button>
        <button onclick="cmd('full')">1&times; Full</button>
      </div>
      <div class="stat" id="stat">ready</div>
      <script>
        async function cmd(a) {
          const s = document.getElementById('stat');
          try {
            const r = await fetch('/cmd?a=' + a);
            const j = await r.json();
            s.textContent = j.ok ? a + ' \\u2713' : a + ' \\u2717';
          } catch (e) { s.textContent = 'no connection'; }
        }
      </script>
    </body>
    </html>
    """
}

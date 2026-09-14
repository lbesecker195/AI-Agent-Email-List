defmodule EmailProviderWeb.AdminHTML do
  @moduledoc """
  The operator dashboard.

  The page itself carries no figures. It is served without a token and fetches
  `/admin/stats` with one, so the HTML can never leak a count to somebody who
  guessed the URL.

  ## Why so few charts

  Almost everything here is a single current value: how many accounts, how many
  bounces, how many messages yesterday. Those are read one at a time, not
  compared against each other, and a bar chart of "accounts vs domains vs
  messages" would put three different units on one scale and mean nothing. So
  they are stat tiles, with one hero figure for the number the page leads with.

  The warmup ladder is the exception and gets bars: domains per rung is a real
  magnitude comparison across an ordered category. One hue, because length
  already carries the magnitude and a second encoding in colour would only
  invite reading meaning into the hues.

  Long textual lists — busiest domains, newest accounts — are tables. Past a
  handful of classes a table beats any chart.
  """

  @doc "The dashboard shell."
  def index do
    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex">
    <title>Agent Email List — operator</title>
    <style>
      :root {
        color-scheme: light dark;
        --bg: #fbfbfa; --fg: #1a1a18; --muted: #6b6b66; --faint: #93938c;
        --line: #e4e4e0; --accent: #1a5c3a; --track: #dfe9e2;
        --field: #fff; --err: #9b2c2c; --warn: #8a5a12;
      }
      @media (prefers-color-scheme: dark) {
        :root {
          --bg: #16161a; --fg: #e8e8e4; --muted: #9a9a94; --faint: #74746e;
          --line: #2c2c32; --accent: #7bc79a; --track: #263029;
          --field: #1e1e24; --err: #f08a8a; --warn: #d8b070;
        }
      }
      * { box-sizing: border-box; }
      body { margin: 0; background: var(--bg); color: var(--fg);
        font: 16px/1.6 ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        -webkit-font-smoothing: antialiased; }
      main { max-width: 60rem; margin: 0 auto; padding: 3rem 1.5rem 6rem; }
      a { color: var(--accent); }
      h1 { font-size: 1.4rem; letter-spacing: -0.02em; margin: 0 0 0.25rem; }
      h2 { font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.08em;
        color: var(--muted); font-weight: 600; margin: 2.75rem 0 0.9rem; }
      .sub { color: var(--muted); margin: 0 0 2rem; font-size: 0.95rem; }

      /* Hero: the one number the page leads with. Proportional figures, because
         tabular-nums gives every digit the width of a zero and reads loose at
         display size. */
      .hero { margin: 0 0 0.2rem; font-size: 3.25rem; line-height: 1.05;
        font-weight: 600; letter-spacing: -0.03em; }
      .hero-label { color: var(--muted); margin: 0 0 1rem; }

      .tiles { display: grid; gap: 0.75rem;
        grid-template-columns: repeat(auto-fit, minmax(9.5rem, 1fr)); }
      .tile { border: 1px solid var(--line); border-radius: 8px; padding: 0.85rem 0.95rem; }
      .tile .label { color: var(--muted); font-size: 0.82rem; margin: 0 0 0.3rem; }
      .tile .value { font-size: 1.5rem; font-weight: 600; letter-spacing: -0.02em; }
      .tile .note { color: var(--faint); font-size: 0.78rem; margin-top: 0.15rem; }

      /* Bars: one hue. Length carries the magnitude; a second encoding in colour
         would only invite reading meaning into the hues. */
      .bars { display: grid; gap: 0.55rem; }
      .bar-row { display: grid; grid-template-columns: 8.5rem 1fr 3rem; align-items: center; gap: 0.7rem; }
      .bar-label { color: var(--muted); font-size: 0.85rem; }
      .bar-track { background: var(--track); border-radius: 4px; height: 0.7rem; overflow: hidden; }
      .bar-fill { background: var(--accent); height: 100%; border-radius: 4px; min-width: 2px; }
      .bar-value { text-align: right; font-size: 0.85rem; font-variant-numeric: tabular-nums; color: var(--muted); }

      /* A five-column table does not fit a phone. It scrolls inside its own box
         rather than making the whole page scroll sideways, which would drag the
         stat tiles and the hero figure off-screen with it. */
      .scroll { overflow-x: auto; -webkit-overflow-scrolling: touch; }
      table { width: 100%; border-collapse: collapse; font-size: 0.88rem; min-width: 30rem; }
      th { text-align: left; color: var(--muted); font-weight: 500; font-size: 0.76rem;
        text-transform: uppercase; letter-spacing: 0.05em;
        padding: 0.4rem 0.6rem 0.4rem 0; border-bottom: 1px solid var(--line); }
      td { padding: 0.5rem 0.6rem 0.5rem 0; border-bottom: 1px solid var(--line); }
      /* tabular-nums only here: columns of figures have to line up vertically.
         Gap on the left, not zero padding on the right: a right-aligned number
         in a middle column otherwise butts straight into the next column and
         "1" and "9/14/2026" read as one value. */
      td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; padding-left: 1.4rem; }
      th:last-child, td:last-child { padding-right: 0; }
      td.mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.82rem; }

      .pill { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.06em;
        padding: 0.1rem 0.45rem; border-radius: 99px; border: 1px solid var(--line); color: var(--muted); }
      .pill.active { color: var(--accent); border-color: var(--accent); }

      label { display: block; font-size: 0.85rem; color: var(--muted); margin: 0 0 0.3rem; }
      input { width: 100%; max-width: 26rem; padding: 0.6rem 0.7rem; font: inherit; font-size: 0.95rem;
        background: var(--field); color: var(--fg); border: 1px solid var(--line);
        border-radius: 6px; margin: 0 0 1rem; }
      button { font: inherit; font-size: 0.95rem; padding: 0.55rem 1.1rem; cursor: pointer;
        background: var(--accent); color: var(--bg); border: 0; border-radius: 6px; font-weight: 500; }
      button.link { background: none; color: var(--accent); padding: 0; font-weight: 400;
        text-decoration: underline; }
      .msg { padding: 0.7rem 0.85rem; border: 1px solid var(--err); color: var(--err);
        border-radius: 6px; margin: 0 0 1.25rem; font-size: 0.92rem; }
      .caveat { border-left: 2px solid var(--warn); color: var(--muted); padding: 0 0 0 0.85rem;
        margin: 0.9rem 0 0; font-size: 0.88rem; }
      footer { margin-top: 3rem; padding-top: 1.25rem; border-top: 1px solid var(--line);
        color: var(--muted); font-size: 0.85rem; display: flex; justify-content: space-between; gap: 1rem; }
      [hidden] { display: none !important; }
    </style>
    </head>
    <body>
    <main>
      <h1>Operator</h1>
      <p class="sub">Every account on this service.</p>

      <div id="message" class="msg" hidden></div>

      <section id="gate">
        <form id="form-token">
          <label for="token">Admin token</label>
          <input id="token" type="password" autocomplete="off" required>
          <button type="submit">Open</button>
        </form>
        <p class="caveat">Set as <code>ADMIN_TOKEN</code> in the environment file.
        With none set the dashboard stays closed rather than open.</p>
      </section>

      <section id="dash" hidden></section>
    </main>

    <script>
    (function () {
      "use strict";
      var KEY = "ael_admin";
      var $ = function (id) { return document.getElementById(id); };
      var token = null;
      try { token = sessionStorage.getItem(KEY); } catch (e) {}

      function say(text) {
        var el = $("message");
        el.textContent = text || "";
        el.hidden = !text;
      }

      // Compact only above 10,000, so ordinary counts stay exact. "1.2K
      // accounts" is a worse answer than "1,204" when the reader is deciding
      // whether a number changed.
      function num(n) {
        if (n === null || n === undefined) return "0";
        if (typeof n !== "number") return String(n);
        if (n >= 1000000) return (n / 1000000).toFixed(1).replace(/\\.0$/, "") + "M";
        if (n >= 10000) return (n / 1000).toFixed(1).replace(/\\.0$/, "") + "K";
        return n.toLocaleString();
      }

      function el(tag, cls, text) {
        var e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined && text !== null) e.textContent = text;
        return e;
      }

      function tile(label, value, note) {
        var t = el("div", "tile");
        t.appendChild(el("div", "label", label));
        t.appendChild(el("div", "value", num(value)));
        if (note) t.appendChild(el("div", "note", note));
        return t;
      }

      function tiles(items) {
        var g = el("div", "tiles");
        items.forEach(function (i) { g.appendChild(tile(i[0], i[1], i[2])); });
        return g;
      }

      function section(title) { return el("h2", null, title); }

      function table(headers, rows) {
        var wrap = el("div", "scroll");
        var t = el("table");
        var head = el("tr");
        headers.forEach(function (h) {
          var th = el("th", h.num ? "num" : null, h.label);
          head.appendChild(th);
        });
        t.appendChild(head);
        rows.forEach(function (r) {
          var tr = el("tr");
          r.forEach(function (c, i) {
            var td = el("td", [headers[i].num ? "num" : "", headers[i].mono ? "mono" : ""].join(" ").trim());
            if (c && c.node) { td.appendChild(c.node); } else { td.textContent = c; }
            tr.appendChild(td);
          });
          t.appendChild(tr);
        });
        wrap.appendChild(t);
        return wrap;
      }

      function bars(rows) {
        var max = Math.max.apply(null, rows.map(function (r) { return r.value; }).concat([1]));
        var g = el("div", "bars");
        rows.forEach(function (r) {
          var row = el("div", "bar-row");
          row.appendChild(el("div", "bar-label", r.label));
          var track = el("div", "bar-track");
          var fill = el("div", "bar-fill");
          fill.style.width = Math.round((r.value / max) * 100) + "%";
          track.appendChild(fill);
          row.appendChild(track);
          row.appendChild(el("div", "bar-value", num(r.value)));
          g.appendChild(row);
        });
        return g;
      }

      async function load() {
        say("");
        var res = await fetch("/admin/stats", {
          headers: { "accept": "application/json", "x-admin-token": token }
        });
        if (!res.ok) {
          var body = null;
          try { body = await res.json(); } catch (e) {}
          throw new Error((body && body.message) || ("Request failed (" + res.status + ")"));
        }
        render(await res.json());
      }

      function render(d) {
        var dash = $("dash");
        dash.textContent = "";
        dash.hidden = false;
        $("gate").hidden = true;

        var m = d.messages, a = d.accounts, dom = d.domains, s = d.suppressions, mod = d.moderation;

        // Exactly one hero figure: the number this page is about.
        dash.appendChild(el("div", "hero", num(m.total)));
        dash.appendChild(el("p", "hero-label", "messages handled, in and out"));

        dash.appendChild(section("Accounts"));
        dash.appendChild(tiles([
          ["Accounts", a.total, a.suspended ? a.suspended + " suspended" : null],
          ["New this week", a.new_this_week],
          ["New this month", a.new_this_month],
          ["API keys", a.api_keys],
          ["With a profile", a.with_profiles]
        ]));

        dash.appendChild(section("Domains"));
        dash.appendChild(tiles([
          ["Domains", dom.total],
          ["Verified", dom.active],
          ["Awaiting DNS", dom.unverified],
          ["Added this week", dom.new_this_week],
          ["Have sent", dom.has_sent]
        ]));

        dash.appendChild(section("Mail"));
        dash.appendChild(tiles([
          ["Outbound", m.outbound],
          ["Inbound", m.inbound],
          ["Delivered", m.delivered],
          ["Failed", m.failed],
          ["Waiting to go", m.queued + m.scheduled],
          ["Last 24 hours", m.last_24h],
          ["Last 7 days", m.last_7d],
          ["Test mode", m.test_mode, "never sent"]
        ]));

        dash.appendChild(section("Suppressed addresses"));
        dash.appendChild(tiles([
          ["Hard bounces", s.bounces],
          ["Unsubscribes", s.unsubscribes],
          ["Complaints", s.complaints]
        ]));

        dash.appendChild(section("Screening"));
        dash.appendChild(tiles([
          ["Screened", mod.screened],
          ["Unscreened", mod.unscreened, "no API key at the time"],
          ["Flagged", mod.flagged],
          ["Filed as spam", mod.filed_spam, "inbound"]
        ]));
        if (mod.outbound_refusals_recorded === false) {
          var c = el("p", "caveat",
            "Outbound messages refused by screening are not counted here. They are " +
            "rejected before anything is stored, so they leave no row and no event.");
          dash.appendChild(c);
        }

        if (d.warmup && d.warmup.length) {
          dash.appendChild(section("Verified domains by warmup rung"));
          dash.appendChild(bars(d.warmup.map(function (w) {
            return { label: "Rung " + w.stage + " · " + w.daily_limit + "/day", value: w.domains };
          })));
        }

        var ev = Object.keys(d.events || {});
        if (ev.length) {
          dash.appendChild(section("Events"));
          dash.appendChild(table(
            [{ label: "Event" }, { label: "Count", num: true }],
            ev.sort().map(function (k) { return [k, num(d.events[k])]; })
          ));
        }

        if (d.busiest_domains && d.busiest_domains.length) {
          dash.appendChild(section("Busiest domains"));
          dash.appendChild(table(
            [{ label: "Domain", mono: true }, { label: "State" },
             { label: "Messages", num: true }, { label: "Inbound", num: true },
             { label: "Lifetime sent", num: true }],
            d.busiest_domains.map(function (r) {
              var pill = el("span", "pill" + (r.state === "active" ? " active" : ""), r.state);
              return [r.name, { node: pill }, num(r.messages), num(r.inbound), num(r.lifetime_sent)];
            })
          ));
        }

        if (d.recent_accounts && d.recent_accounts.length) {
          dash.appendChild(section("Newest accounts"));
          dash.appendChild(table(
            [{ label: "Email", mono: true }, { label: "Status" },
             { label: "Domains", num: true }, { label: "Joined" }],
            d.recent_accounts.map(function (r) {
              return [r.email, r.status, num(r.domains), new Date(r.joined).toLocaleDateString()];
            })
          ));
        }

        var f = el("footer");
        f.appendChild(el("span", null, "As at " + new Date(d.generated_at).toLocaleString()));
        var out = el("button", "link", "Forget token");
        out.onclick = function () {
          token = null;
          try { sessionStorage.removeItem(KEY); } catch (e) {}
          location.reload();
        };
        f.appendChild(out);
        dash.appendChild(f);
      }

      $("form-token").onsubmit = async function (e) {
        e.preventDefault();
        token = $("token").value.trim();
        try {
          await load();
          try { sessionStorage.setItem(KEY, token); } catch (e2) {}
        } catch (err) { say(err.message); token = null; }
      };

      if (token) {
        load().catch(function (err) {
          say(err.message);
          token = null;
          try { sessionStorage.removeItem(KEY); } catch (e) {}
        });
      }
    })();
    </script>
    </body>
    </html>
    """
  end
end

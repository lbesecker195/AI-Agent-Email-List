defmodule EmailProviderWeb.AppHTML do
  @moduledoc """
  The sign-up and domain dashboard, as one page.

  It talks to the same public JSON API a customer would, from the browser, so
  there is no second implementation of signup or domain handling to keep in step
  with the first. The page is a client of this service exactly as an agent is.

  It holds a **session token**, not an API key. `POST /v1/accounts/login` returns
  one that expires, and it lives in `sessionStorage` so it goes when the tab
  does. An API key is long-lived and fully scoped, and putting one in browser
  storage means any script that ever runs on this origin can send mail as the
  customer forever.
  """

  @doc "The dashboard page."
  def app do
    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Agent Email List — account</title>
    <style>
      :root {
        color-scheme: light dark;
        --bg: #fbfbfa; --fg: #1a1a18; --muted: #6b6b66; --line: #e4e4e0;
        --accent: #1a5c3a; --code-bg: #f2f2ef; --err: #9b2c2c; --ok: #1a5c3a;
        --field: #fff;
      }
      @media (prefers-color-scheme: dark) {
        :root {
          --bg: #16161a; --fg: #e8e8e4; --muted: #9a9a94; --line: #2c2c32;
          --accent: #7bc79a; --code-bg: #1e1e24; --err: #f08a8a; --ok: #7bc79a;
          --field: #1e1e24;
        }
      }
      * { box-sizing: border-box; }
      body { margin: 0; background: var(--bg); color: var(--fg);
        font: 16px/1.6 ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        -webkit-font-smoothing: antialiased; }
      main { max-width: 43rem; margin: 0 auto; padding: 3rem 1.5rem 6rem; }
      a { color: var(--accent); }
      h1 { font-size: 1.5rem; letter-spacing: -0.02em; margin: 0 0 0.3rem; }
      h2 { font-size: 1.05rem; margin: 2.5rem 0 0.75rem; }
      .sub { color: var(--muted); margin: 0 0 2rem; }
      label { display: block; font-size: 0.85rem; color: var(--muted); margin: 0 0 0.3rem; }
      input { width: 100%; padding: 0.6rem 0.7rem; font: inherit; font-size: 0.95rem;
        background: var(--field); color: var(--fg);
        border: 1px solid var(--line); border-radius: 6px; margin: 0 0 1rem; }
      input:focus { outline: 2px solid var(--accent); outline-offset: -1px; }
      button { font: inherit; font-size: 0.95rem; padding: 0.6rem 1.1rem; cursor: pointer;
        background: var(--accent); color: var(--bg); border: 0; border-radius: 6px; font-weight: 500; }
      button:disabled { opacity: 0.55; cursor: default; }
      button.link { background: none; color: var(--accent); padding: 0; font-weight: 400;
        text-decoration: underline; text-underline-offset: 2px; }
      button.small { font-size: 0.85rem; padding: 0.35rem 0.7rem; }
      .tabs { display: flex; gap: 1.25rem; border-bottom: 1px solid var(--line); margin: 0 0 1.75rem; }
      .tabs button { background: none; color: var(--muted); border-radius: 0; padding: 0 0 0.6rem;
        border-bottom: 2px solid transparent; font-weight: 500; }
      .tabs button[aria-selected="true"] { color: var(--fg); border-bottom-color: var(--accent); }
      pre { background: var(--code-bg); border: 1px solid var(--line); border-radius: 6px;
        padding: 0.8rem; overflow-x: auto; margin: 0 0 1rem;
        font: 12.5px/1.6 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
      .msg { padding: 0.7rem 0.85rem; border-radius: 6px; margin: 0 0 1.25rem; font-size: 0.92rem;
        border: 1px solid var(--line); }
      .msg.err { color: var(--err); border-color: var(--err); }
      .msg.ok { color: var(--ok); border-color: var(--ok); }
      .card { border: 1px solid var(--line); border-radius: 8px; padding: 1rem 1.1rem; margin: 0 0 0.85rem; }
      .card h3 { margin: 0 0 0.15rem; font-size: 1rem; font-family: ui-monospace, Menlo, monospace; }
      .row { display: flex; align-items: center; justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
      .pill { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.06em;
        padding: 0.15rem 0.5rem; border-radius: 99px; border: 1px solid var(--line); color: var(--muted); }
      .pill.active { color: var(--ok); border-color: var(--ok); }
      table { width: 100%; border-collapse: collapse; font-size: 0.85rem; margin: 0.75rem 0 0; }
      th { text-align: left; color: var(--muted); font-weight: 500; padding: 0.4rem 0.5rem 0.4rem 0;
        border-bottom: 1px solid var(--line); font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.05em; }
      td { padding: 0.5rem 0.5rem 0.5rem 0; border-bottom: 1px solid var(--line); vertical-align: top;
        font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.78rem; word-break: break-all; }
      .muted { color: var(--muted); }
      .hint { color: var(--muted); font-size: 0.88rem; margin: 0 0 1rem; }
      footer { margin-top: 3rem; padding-top: 1.25rem; border-top: 1px solid var(--line);
        color: var(--muted); font-size: 0.88rem; display: flex; justify-content: space-between; gap: 1rem; }
      [hidden] { display: none !important; }
    </style>
    </head>
    <body>
    <main>
      <h1>Agent Email List</h1>
      <p class="sub">Email sending and receiving, from your own domain.</p>

      <div id="message" class="msg" hidden></div>

      <!-- signed out -->
      <section id="auth">
        <div class="tabs" role="tablist">
          <button id="tab-signup" role="tab" aria-selected="true">Create an account</button>
          <button id="tab-signin" role="tab" aria-selected="false">Sign in</button>
        </div>

        <form id="form-signup">
          <label for="su-email">Email address</label>
          <input id="su-email" type="email" autocomplete="email" required placeholder="you@company.com">
          <label for="su-name">Name <span class="muted">(optional)</span></label>
          <input id="su-name" type="text" autocomplete="name">
          <label for="su-password">Password</label>
          <input id="su-password" type="password" autocomplete="new-password" required minlength="12">
          <p class="hint">At least 12 characters.</p>
          <button type="submit">Create account</button>
        </form>

        <form id="form-signin" hidden>
          <label for="si-email">Email address</label>
          <input id="si-email" type="email" autocomplete="email" required>
          <label for="si-password">Password</label>
          <input id="si-password" type="password" autocomplete="current-password" required>
          <button type="submit">Sign in</button>
        </form>
      </section>

      <!-- shown once, after signup -->
      <section id="newkey" hidden>
        <h2>Your API key</h2>
        <p class="hint"><strong>This is the only time it is shown.</strong> Only a hash of it
        is stored, so it cannot be sent again. Copy it somewhere safe now.</p>
        <pre id="newkey-value"></pre>
        <button class="small" id="copy-key">Copy</button>
        <button class="small link" id="dismiss-key">I have saved it</button>
      </section>

      <!-- signed in -->
      <section id="dash" hidden>
        <h2>Domains</h2>
        <p class="hint">A domain has to be verified in DNS before it can send. Adding one
        gives you the records to publish.</p>
        <div id="domains"></div>

        <form id="form-domain" class="row" style="margin-top:1rem">
          <input id="dom-name" type="text" placeholder="mail.yourcompany.com" required
                 style="flex:1;min-width:14rem;margin:0" pattern="[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}">
          <button type="submit">Add domain</button>
        </form>

        <footer>
          <span id="whoami" class="muted"></span>
          <button class="link" id="signout">Sign out</button>
        </footer>
      </section>

      <p class="hint" style="margin-top:2.5rem">
        Prefer the API? Everything here is <a href="/llms.txt"><code>/llms.txt</code></a>.
      </p>
    </main>

    <script>
    (function () {
      "use strict";
      var TOKEN = "ael_session";
      var $ = function (id) { return document.getElementById(id); };
      var token = null;
      try { token = sessionStorage.getItem(TOKEN); } catch (e) { token = null; }

      function say(text, kind) {
        var el = $("message");
        el.textContent = text;
        el.className = "msg " + (kind || "");
        el.hidden = !text;
        // The banner lives at the top of the page, and the button that triggers
        // it is often well below the fold. Without this a failed verify looks
        // like nothing happened at all.
        if (text) { el.scrollIntoView({ block: "nearest", behavior: "smooth" }); }
      }

      // Every call goes through the same public JSON API a script would use.
      async function api(method, path, body) {
        var headers = { "accept": "application/json" };
        if (body) headers["content-type"] = "application/json";
        if (token) headers["authorization"] = "Bearer " + token;

        var res = await fetch(path, {
          method: method,
          headers: headers,
          body: body ? JSON.stringify(body) : undefined
        });

        var data = null;
        try { data = await res.json(); } catch (e) { data = null; }

        if (!res.ok) {
          // A session expires after twelve hours; say so rather than showing
          // "invalid credentials" to somebody who is looking at their own page.
          if (res.status === 401 && token) { signOut("Your session expired. Sign in again."); }
          throw new Error(errorText(data) || ("Request failed (" + res.status + ")"));
        }
        return data;
      }

      function errorText(data) {
        if (!data) return null;
        if (typeof data.message === "string") return data.message;
        if (data.errors) {
          return Object.keys(data.errors).map(function (k) {
            return k + " " + [].concat(data.errors[k]).join(", ");
          }).join("; ");
        }
        return null;
      }

      function show(which) {
        $("auth").hidden = which !== "auth";
        $("dash").hidden = which !== "dash";
      }

      function busy(form, on) {
        var b = form.querySelector("button[type=submit]");
        if (b) { b.disabled = on; b.dataset.idle = b.dataset.idle || b.textContent;
                 b.textContent = on ? "Working…" : b.dataset.idle; }
      }

      // -- tabs

      function selectTab(name) {
        var signup = name === "signup";
        $("tab-signup").setAttribute("aria-selected", String(signup));
        $("tab-signin").setAttribute("aria-selected", String(!signup));
        $("form-signup").hidden = !signup;
        $("form-signin").hidden = signup;
        say("");
      }
      $("tab-signup").onclick = function () { selectTab("signup"); };
      $("tab-signin").onclick = function () { selectTab("signin"); };

      // -- signup

      $("form-signup").onsubmit = async function (e) {
        e.preventDefault(); say(""); busy(this, true);
        var email = $("su-email").value.trim();
        var password = $("su-password").value;
        try {
          var out = await api("POST", "/v1/accounts", {
            email: email, name: $("su-name").value.trim(), password: password
          });
          $("newkey-value").textContent = out.api_key;
          $("newkey").hidden = false;
          // Sign straight in, so the key is the only thing they have to keep.
          await signIn(email, password);
        } catch (err) { say(err.message, "err"); }
        busy(this, false);
      };

      $("copy-key").onclick = async function () {
        try {
          await navigator.clipboard.writeText($("newkey-value").textContent);
          this.textContent = "Copied";
        } catch (e) { say("Copy failed. Select the key and copy it by hand.", "err"); }
      };
      $("dismiss-key").onclick = function () { $("newkey").hidden = true; };

      // -- signin

      $("form-signin").onsubmit = async function (e) {
        e.preventDefault(); say(""); busy(this, true);
        try { await signIn($("si-email").value.trim(), $("si-password").value); }
        catch (err) { say(err.message, "err"); }
        busy(this, false);
      };

      async function signIn(email, password) {
        var out = await api("POST", "/v1/accounts/login", { email: email, password: password });
        token = out.token;
        try { sessionStorage.setItem(TOKEN, token); } catch (e) {}
        $("whoami").textContent = out.account.email;
        show("dash");
        await loadDomains();
      }

      function signOut(why) {
        token = null;
        try { sessionStorage.removeItem(TOKEN); } catch (e) {}
        show("auth"); selectTab("signin");
        say(why || "Signed out.", why ? "err" : "");
      }
      $("signout").onclick = function () { signOut(); };

      // -- domains

      async function loadDomains() {
        var box = $("domains");
        box.textContent = "Loading…";
        try {
          var out = await api("GET", "/v3/domains");
          box.textContent = "";
          if (!out.items.length) {
            box.innerHTML = '<p class="hint">No domains yet. Add one below.</p>';
            return;
          }
          out.items.forEach(function (d) { box.appendChild(card(d)); });
        } catch (err) { box.textContent = ""; say(err.message, "err"); }
      }

      function card(d) {
        var el = document.createElement("div");
        el.className = "card";

        var head = document.createElement("div");
        head.className = "row";
        var h = document.createElement("h3");
        h.textContent = d.name;
        var pill = document.createElement("span");
        pill.className = "pill" + (d.state === "active" ? " active" : "");
        pill.textContent = d.state;
        head.appendChild(h); head.appendChild(pill);
        el.appendChild(head);

        var limits = document.createElement("p");
        limits.className = "hint";
        limits.style.margin = "0.4rem 0 0";
        var w = d.warmup || {};
        limits.textContent = d.state === "active"
          ? "Sending " + w.sent_today + " of " + w.daily_limit + " today, rung " +
            w.stage + " of " + w.stage_count + "."
          : "Publish the records below, then verify.";
        el.appendChild(limits);

        var actions = document.createElement("p");
        actions.style.margin = "0.75rem 0 0";
        var records = document.createElement("button");
        records.className = "small link";
        records.textContent = "DNS records";
        records.onclick = function () { toggleRecords(d.name, el, records); };
        var verify = document.createElement("button");
        verify.className = "small";
        verify.style.marginLeft = "0.75rem";
        verify.textContent = "Verify";
        verify.onclick = async function () {
          verify.disabled = true; verify.textContent = "Checking…";
          try {
            var out = await api("PUT", "/v3/domains/" + encodeURIComponent(d.name) + "/verify");
            say(out.message, out.domain.state === "active" ? "ok" : "err");
            await loadDomains();
          } catch (err) { say(err.message, "err"); verify.disabled = false; verify.textContent = "Verify"; }
        };
        actions.appendChild(records); actions.appendChild(verify);
        el.appendChild(actions);
        return el;
      }

      async function toggleRecords(name, card, button) {
        var existing = card.querySelector("table");
        if (existing) { existing.remove(); button.textContent = "DNS records"; return; }
        button.textContent = "Hide records";
        try {
          var out = await api("GET", "/v3/domains/" + encodeURIComponent(name));
          var rows = out.domain.sending_dns_records || [];
          var t = document.createElement("table");
          t.innerHTML = "<tr><th>Type</th><th>Name</th><th>Value</th><th>Needed for</th></tr>";
          rows.forEach(function (r) {
            var tr = document.createElement("tr");
            [r.record_type, r.name, r.value, r.required ? "sending" : r.purpose].forEach(function (v) {
              var td = document.createElement("td");
              td.textContent = v;
              tr.appendChild(td);
            });
            t.appendChild(tr);
          });
          card.appendChild(t);
        } catch (err) { say(err.message, "err"); button.textContent = "DNS records"; }
      }

      $("form-domain").onsubmit = async function (e) {
        e.preventDefault(); say("");
        var input = $("dom-name");
        var name = input.value.trim().toLowerCase();
        try {
          var out = await api("POST", "/v3/domains", { name: name });
          input.value = "";
          say("Added " + out.domain.name + ". Publish its DNS records, then verify.", "ok");
          await loadDomains();
        } catch (err) { say(err.message, "err"); }
      };

      // -- start

      if (token) {
        api("GET", "/v3/domains").then(async function () {
          show("dash");
          await loadDomains();
        }).catch(function () { show("auth"); });
      } else {
        show("auth");
      }
    })();
    </script>
    </body>
    </html>
    """
  end
end

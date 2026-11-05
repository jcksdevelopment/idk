// JCKS Anticheat in-game settings panel. Built with DOM APIs only (no innerHTML from data), so
// nothing the server sends can inject markup, and it never adds <script>/<iframe> nodes (the
// sensor in index.html would flag those).
(() => {
  const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "jcks_anticheat";
  const post = (name, body) =>
    fetch(`https://${resource}/${name}`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body || {}) }).catch(() => {});

  let schema = null, config = null, original = "", active = null, root = null, msgEl = null;

  const el = (tag, attrs, ...children) => {
    const n = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (k === "class") n.className = v;
      else if (k.startsWith("on")) n.addEventListener(k.slice(2), v);
      else n.setAttribute(k, v);
    }
    for (const c of children) if (c != null) n.append(c);
    return n;
  };
  const getPath = (obj, path) => path.split(".").reduce((o, k) => (o == null ? undefined : o[k]), obj);
  const setPath = (obj, path, value) => {
    const keys = path.split(".");
    let o = obj;
    for (const k of keys.slice(0, -1)) o = o[k] ??= {};
    o[keys.at(-1)] = value;
  };
  const dirty = () => JSON.stringify(config) !== original;

  function message(text, kind) {
    if (!msgEl) return;
    msgEl.textContent = text || "";
    msgEl.className = "jac-msg" + (kind ? " " + kind : "");
  }

  function input(field) {
    const value = getPath(config, field.key);
    const update = (v) => { setPath(config, field.key, v); message(dirty() ? "Unsaved changes" : "", ""); };
    switch (field.type) {
      case "bool": {
        const c = el("input", { type: "checkbox" });
        c.checked = !!value;
        c.addEventListener("change", () => update(c.checked));
        return c;
      }
      case "number": {
        const i = el("input", { type: "number", min: field.min ?? "", max: field.max ?? "", step: field.step ?? "any" });
        i.value = value ?? "";
        i.addEventListener("input", () => { if (i.value !== "" && !isNaN(+i.value)) update(+i.value); });
        return i;
      }
      case "select": {
        const s = el("select", {});
        for (const o of field.options || []) s.append(el("option", { value: o }, o));
        s.value = value ?? "";
        s.addEventListener("change", () => update(s.value));
        return s;
      }
      case "list":
      case "codes":
      case "numbers": {
        const t = el("textarea", { spellcheck: "false", placeholder: "One per line" });
        t.value = (value || []).join("\n");
        t.addEventListener("input", () => {
          const items = t.value.split(/[\n,]/).map((x) => x.trim()).filter(Boolean);
          update(field.type === "numbers" ? items.map(Number).filter((n) => !isNaN(n)) : field.type === "codes" ? items.map((x) => x.toUpperCase()) : items);
        });
        return t;
      }
      case "map": {
        // CODE=points per line.
        const t = el("textarea", { spellcheck: "false", placeholder: "CODE=points, one per line" });
        t.value = Object.entries(value || {}).map(([k, v]) => `${k}=${v}`).join("\n");
        t.addEventListener("input", () => {
          const out = {};
          for (const line of t.value.split("\n")) {
            const m = line.trim().match(/^([A-Za-z_]+)\s*[=:]\s*(-?\d+(?:\.\d+)?)$/);
            if (m) out[m[1].toUpperCase()] = Math.round(+m[2]);
          }
          update(out);
        });
        return t;
      }
      default: {
        const i = el("input", { type: "text" });
        i.value = value ?? "";
        i.addEventListener("input", () => update(i.value));
        return i;
      }
    }
  }

  function renderSection(body, nav) {
    const section = schema.sections.find((s) => s.id === active) || schema.sections[0];
    active = section.id;
    for (const b of nav.children) b.classList.toggle("active", b.dataset.id === active);
    body.replaceChildren(el("h2", {}, section.title));
    for (const f of section.fields) {
      body.append(el("div", { class: "jac-field" },
        el("div", {}, el("label", {}, f.label), f.help ? el("p", {}, f.help) : null, el("code", {}, f.key)),
        input(f)));
    }
  }

  function build() {
    const body = el("div", { class: "jac-body" });
    const nav = el("nav", { class: "jac-nav" });
    for (const s of schema.sections) {
      const b = el("button", { onclick: () => { active = s.id; renderSection(body, nav); } }, s.title);
      b.dataset.id = s.id;
      nav.append(b);
    }
    msgEl = el("span", { class: "jac-msg" });
    const save = el("button", { class: "jac-btn primary", onclick: () => {
      message("Saving…", "");
      post("jac_panel_save", { config: JSON.stringify(config) });
    } }, "Save & apply");
    const reload = el("button", { class: "jac-btn", title: "Re-read config.json from disk", onclick: () => {
      message("Reloading…", "");
      post("jac_panel_reload");
    } }, "Reload from file");
    const close = el("button", { class: "jac-btn jac-x", onclick: hide }, "Close (Esc)");
    const win = el("div", { class: "jac-win" },
      el("div", { class: "jac-head" }, el("b", {}, "JCKS Anticheat"), el("span", { class: "jac-sub" }, "Live settings"), close),
      nav, body,
      el("div", { class: "jac-foot" }, msgEl, reload, save));
    root.replaceChildren(win);
    renderSection(body, nav);
  }

  function hide() {
    root.classList.remove("open");
    post("jac_panel_close");
  }

  window.addEventListener("message", (e) => {
    const d = e.data;
    if (!d || d.type !== "jac_panel") return;
    try {
      schema = typeof d.schema === "string" ? JSON.parse(d.schema) : d.schema;
      config = typeof d.config === "string" ? JSON.parse(d.config) : d.config;
    } catch { return; }
    original = JSON.stringify(config);
    root = root || document.getElementById("jac-panel");
    build();
    root.classList.add("open");
    if (d.message) message(d.message, d.result === "ok" ? "ok" : "err");
  });

  window.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && root && root.classList.contains("open")) hide();
  });
})();

(() => {
  "use strict";

  const data = window.SCREENBOOK_DATA;
  const manifest = data.manifest;
  const baselineById = new Map((data.baseline.scenarios || []).map(item => [item.id, item]));
  const storageKey = "counting-sheep.screenbook.annotations.v1";
  const decisions = ["open", "approved", "rejected", "needs-discussion"];
  const annotations = loadAnnotations();
  const gallery = document.querySelector("#gallery");
  const dialog = document.querySelector("#detail-dialog");
  const detail = document.querySelector("#detail");
  const search = document.querySelector("#search");
  const journeyFilter = document.querySelector("#journey-filter");
  const stateFilter = document.querySelector("#state-filter");
  const reviewFilter = document.querySelector("#review-filter");
  const changeFilter = document.querySelector("#change-filter");
  const warningFilter = document.querySelector("#warning-filter");
  let currentScenarioId = null;

  function escape(value) {
    return String(value ?? "").replace(/[&<>'"]/g, character => ({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;",'"':"&quot;"}[character]));
  }

  function annotationKey(scenarioId, copyId = "screen") { return `${scenarioId}::${copyId}`; }
  function annotation(scenarioId, copyId = "screen") {
    return annotations[annotationKey(scenarioId, copyId)] || { proposedReplacement: "", editorialNote: "", decision: "open" };
  }
  function loadAnnotations() {
    try { return JSON.parse(localStorage.getItem(storageKey) || "{}"); }
    catch (_error) { return {}; }
  }
  function saveAnnotations() {
    localStorage.setItem(storageKey, JSON.stringify(annotations));
    renderGallery();
  }
  function scenarioReviewStatus(scenario) {
    const records = [annotation(scenario.id), ...scenario.copy.map(item => annotation(scenario.id, item.id))];
    const active = records.filter(item => item.editorialNote || item.proposedReplacement || item.decision !== "open");
    if (!active.length) return "open";
    if (active.some(item => item.decision === "needs-discussion")) return "needs-discussion";
    if (active.some(item => item.decision === "approved")) return "approved";
    if (active.every(item => item.decision === "rejected")) return "rejected";
    return "open";
  }

  function addOptions(select, values) {
    [...new Set(values)].sort().forEach(value => {
      const option = document.createElement("option");
      option.value = value;
      option.textContent = value;
      select.append(option);
    });
  }
  addOptions(journeyFilter, manifest.scenarios.map(item => item.journey));
  addOptions(stateFilter, manifest.scenarios.map(item => item.state));
  addOptions(changeFilter, manifest.scenarios.map(item => item.changeStatus));

  function searchableText(scenario) {
    const notes = Object.entries(annotations)
      .filter(([key]) => key.startsWith(`${scenario.id}::`))
      .flatMap(([, value]) => [value.editorialNote, value.proposedReplacement]);
    return [scenario.id, scenario.title, scenario.description, scenario.journey, scenario.route, scenario.state,
      ...scenario.tags, ...scenario.copy.flatMap(item => [item.id, item.rendered, item.authored]), ...notes].join(" ").toLowerCase();
  }

  function filteredScenarios() {
    const query = search.value.trim().toLowerCase();
    return manifest.scenarios.filter(scenario => {
      if (query && !searchableText(scenario).includes(query)) return false;
      if (journeyFilter.value && scenario.journey !== journeyFilter.value) return false;
      if (stateFilter.value && scenario.state !== stateFilter.value) return false;
      if (reviewFilter.value && scenarioReviewStatus(scenario) !== reviewFilter.value) return false;
      if (changeFilter.value && scenario.changeStatus !== changeFilter.value) return false;
      if (warningFilter.checked && !scenario.warnings.length) return false;
      return true;
    });
  }

  function badge(label, className = "") { return `<span class="badge ${className}">${escape(label)}</span>`; }
  function renderGallery() {
    const scenarios = filteredScenarios();
    document.querySelector("#result-count").textContent = `${scenarios.length} of ${manifest.scenarios.length} scenarios`;
    document.querySelector("#manifest-summary").textContent = `${manifest.captureProfile} · ${manifest.manifestHash.slice(0, 12)}`;
    gallery.innerHTML = scenarios.map(scenario => `
      <button class="card" data-scenario="${escape(scenario.id)}" aria-label="Open ${escape(scenario.title)} details">
        <div class="card-shot"><img src="../${escape(scenario.screenshot.path)}" alt="${escape(scenario.title)} simulator capture" loading="lazy"></div>
        <div class="card-body">
          <p class="eyebrow">${escape(scenario.journey)} · ${escape(scenario.state)}</p>
          <h2>${escape(scenario.title)}</h2>
          <div class="id">${escape(scenario.id)}</div>
          <div class="badges">
            ${badge(scenarioReviewStatus(scenario))}
            ${badge(scenario.changeStatus, scenario.changeStatus === "unchanged" ? "stable" : "changed")}
            ${scenario.warnings.length ? badge(`${scenario.warnings.length} warning`, "warning") : ""}
          </div>
        </div>
      </button>`).join("");
    gallery.querySelectorAll(".card").forEach(card => card.addEventListener("click", () => openDetail(card.dataset.scenario)));
  }

  function reviewFields(scenarioId, copyId, status = "stable") {
    const saved = annotation(scenarioId, copyId);
    const disableApproval = status !== "stable";
    return `<div class="review-fields" data-review-key="${escape(annotationKey(scenarioId, copyId))}" data-status="${escape(status)}">
      <label>Proposed replacement<textarea data-field="proposedReplacement" placeholder="Leave blank to keep the current wording">${escape(saved.proposedReplacement)}</textarea></label>
      <label>Editorial note<textarea data-field="editorialNote" placeholder="Context, concern, or direction">${escape(saved.editorialNote)}</textarea></label>
      <label>Decision<select data-field="decision">
        ${decisions.map(value => `<option value="${value}" ${saved.decision === value ? "selected" : ""} ${disableApproval && value === "approved" ? "disabled" : ""}>${value}</option>`).join("")}
      </select></label>
    </div>`;
  }

  function copyRecord(record, scenarioId) {
    const parameters = Object.keys(record.parameters || {}).length
      ? `<p class="source">Parameters: ${escape(JSON.stringify(record.parameters))}</p>` : "";
    return `<article class="copy-record">
      <div class="copy-head"><div><span class="id">${escape(record.id)}</span></div>${badge(record.status, record.status)}</div>
      <p class="copy-value">${escape(record.rendered)}</p>
      ${record.authored !== record.rendered ? `<p class="source">Authored: ${escape(record.authored)}</p>` : ""}
      ${parameters}
      <p class="source">${escape(record.kind)} · ${escape(record.source.file)} · ${escape(record.source.symbol)}</p>
      ${reviewFields(scenarioId, record.id, record.status)}
    </article>`;
  }

  function screenImages(scenario) {
    const baseline = baselineById.get(scenario.id);
    if (!baseline) return `<div class="screen-frame"><img src="../${escape(scenario.screenshot.path)}" alt="Current ${escape(scenario.title)} capture"></div>`;
    return `<div class="compare">
      <div><p class="compare-label">BASELINE</p><div class="screen-frame"><img src="../${escape(baseline.screenshot.path)}" alt="Baseline ${escape(scenario.title)} capture"></div></div>
      <div><p class="compare-label">CURRENT</p><div class="screen-frame"><img src="../${escape(scenario.screenshot.path)}" alt="Current ${escape(scenario.title)} capture"></div></div>
    </div>`;
  }

  function openDetail(identifier) {
    const scenario = manifest.scenarios.find(item => item.id === identifier);
    if (!scenario) return;
    currentScenarioId = identifier;
    detail.innerHTML = `<div class="detail-grid">
      <aside class="screen-column">${screenImages(scenario)}</aside>
      <section class="detail-copy">
        <p class="eyebrow">${escape(scenario.surface)} · ${escape(scenario.captureProvenance)}</p>
        <h2>${escape(scenario.title)}</h2>
        <p class="id">${escape(scenario.id)}</p>
        <p class="description">${escape(scenario.description)}</p>
        <dl class="meta-grid">
          <div class="meta"><dt>Journey / route</dt><dd>${escape(scenario.journey)} / ${escape(scenario.route)}</dd></div>
          <div class="meta"><dt>State</dt><dd>${escape(scenario.state)}</dd></div>
          <div class="meta"><dt>Fixture</dt><dd>version ${scenario.fixtureVersion}</dd></div>
          <div class="meta"><dt>Profile</dt><dd>${escape(scenario.captureProfile)}</dd></div>
          <div class="meta"><dt>Pixels</dt><dd>${scenario.screenshot.width} × ${scenario.screenshot.height}</dd></div>
          <div class="meta"><dt>Change</dt><dd>${escape(scenario.changeStatus)}</dd></div>
        </dl>
        ${scenario.warnings.map(item => `<p class="warning-box">${escape(item)}</p>`).join("")}
        <section class="review-block"><h3>Screen-level note</h3><p class="source">Use this when feedback is about hierarchy, layout, or the whole state rather than one copy token.</p>${reviewFields(scenario.id, "screen")}</section>
        <h3>Visible copy mapping</h3>
        ${scenario.copy.map(record => copyRecord(record, scenario.id)).join("")}
        <h3>Source dependencies</h3>
        <ul class="dependencies">${scenario.dependencies.map(path => `<li>${escape(path)}</li>`).join("")}</ul>
        <p class="source">Screenshot SHA-256 ${escape(scenario.screenshot.sha256)}<br>Pixel hash ${escape(scenario.screenshot.pixelHash)}<br>Source ${escape(scenario.sourceRevision)}</p>
      </section>
    </div>`;
    bindReviewFields();
    dialog.showModal();
  }

  function bindReviewFields() {
    detail.querySelectorAll("[data-review-key]").forEach(group => {
      group.querySelectorAll("[data-field]").forEach(field => {
        field.addEventListener("input", () => {
          const key = group.dataset.reviewKey;
          const next = annotations[key] || { proposedReplacement: "", editorialNote: "", decision: "open" };
          next[field.dataset.field] = field.value;
          if (group.dataset.status !== "stable" && next.decision === "approved") next.decision = "needs-discussion";
          annotations[key] = next;
          saveAnnotations();
        });
      });
    });
  }

  function reviewItems() {
    const items = [];
    manifest.scenarios.forEach(scenario => {
      const screen = annotation(scenario.id);
      if (screen.proposedReplacement || screen.editorialNote || screen.decision !== "open") {
        items.push({
          reviewId: annotationKey(scenario.id), scenarioId: scenario.id,
          proposedReplacement: screen.proposedReplacement,
          editorialNote: screen.editorialNote, decision: screen.decision,
          sourceManifestHash: manifest.manifestHash
        });
      }
      scenario.copy.forEach(copy => {
        const saved = annotation(scenario.id, copy.id);
        if (!saved.editorialNote && !saved.proposedReplacement && saved.decision === "open") return;
        items.push({
          reviewId: annotationKey(scenario.id, copy.id), scenarioId: scenario.id, copyId: copy.id,
          sourceRendered: copy.rendered, sourceAuthored: copy.authored,
          proposedReplacement: saved.proposedReplacement, editorialNote: saved.editorialNote,
          decision: copy.status === "stable" ? saved.decision : (saved.decision === "approved" ? "needs-discussion" : saved.decision),
          sourceManifestHash: manifest.manifestHash
        });
      });
    });
    return items;
  }

  function exportReview() {
    const review = {
      schemaVersion: 1,
      screenbookManifestHash: manifest.manifestHash,
      createdAt: new Date().toISOString(),
      reviewer: "founder",
      batchTitle: document.querySelector("#batch-title").value.trim() || "Screenbook review",
      items: reviewItems()
    };
    const url = URL.createObjectURL(new Blob([JSON.stringify(review, null, 2) + "\n"], {type: "application/json"}));
    const link = document.createElement("a");
    link.href = url;
    link.download = `counting-sheep-screenbook-review-${new Date().toISOString().slice(0, 10)}.json`;
    link.click();
    URL.revokeObjectURL(url);
    toast(`Exported ${review.items.length} review items.`);
  }

  async function importReview(file) {
    const review = JSON.parse(await file.text());
    if (review.schemaVersion !== 1 || !Array.isArray(review.items)) throw new Error("Unsupported review schema.");
    let imported = 0;
    review.items.forEach(item => {
      const scenario = manifest.scenarios.find(value => value.id === item.scenarioId);
      if (!scenario || !decisions.includes(item.decision)) return;
      const copy = item.copyId ? scenario.copy.find(value => value.id === item.copyId) : null;
      if (item.copyId && !copy) return;
      const stale = item.sourceManifestHash !== manifest.manifestHash || (copy && item.sourceRendered !== copy.rendered);
      annotations[annotationKey(item.scenarioId, item.copyId || "screen")] = {
        proposedReplacement: item.proposedReplacement || "",
        editorialNote: `${item.editorialNote || ""}${stale ? "\n[Imported item is stale and needs discussion.]" : ""}`.trim(),
        decision: stale || (copy && copy.status !== "stable" && item.decision === "approved") ? "needs-discussion" : item.decision
      };
      imported += 1;
    });
    saveAnnotations();
    if (currentScenarioId) openDetail(currentScenarioId);
    toast(`Imported ${imported} review items.`);
  }

  function toast(message) {
    const element = document.querySelector("#toast");
    element.textContent = message;
    element.classList.add("show");
    setTimeout(() => element.classList.remove("show"), 2200);
  }

  [search, journeyFilter, stateFilter, reviewFilter, changeFilter, warningFilter].forEach(element => element.addEventListener("input", renderGallery));
  document.querySelector("#export-review").addEventListener("click", exportReview);
  document.querySelector("#import-review").addEventListener("change", async event => {
    try { if (event.target.files[0]) await importReview(event.target.files[0]); }
    catch (error) { toast(`Import failed: ${error.message}`); }
    event.target.value = "";
  });
  dialog.addEventListener("click", event => {
    const bounds = dialog.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) dialog.close();
  });
  renderGallery();
})();

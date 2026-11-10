/* ==========================================================================
   scripts-hub - Dashboard local (vanilla JS, hors ligne)
   Chargement de l'état, exécution contrôlée, rapports, journaux, toasts.
   ========================================================================== */

(function () {
    'use strict';

    var state = {
        reports: [],
        actions: [],
        logs: [],
        summary: {},
        environment: {}
    };

    var view = {
        term: '',
        sortKey: 'Modified',
        sortDir: 'desc'
    };

    var running = false;
    var pollTimer = null;

    function byId(id) {
        return document.getElementById(id);
    }

    function escapeHtml(value) {
        return String(value === null || value === undefined ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }

    /* ----------------------------------------------------------------------
       Formatage
       ---------------------------------------------------------------------- */

    function formatBytes(bytes) {
        var value = Number(bytes) || 0;
        if (value < 1024) {
            return value + ' o';
        }
        var units = ['Ko', 'Mo', 'Go'];
        var index = -1;
        do {
            value = value / 1024;
            index++;
        } while (value >= 1024 && index < units.length - 1);
        return value.toFixed(1).replace('.', ',') + ' ' + units[index];
    }

    function formatDate(iso) {
        if (!iso) {
            return '—';
        }
        var date = new Date(iso);
        if (isNaN(date.getTime())) {
            return '—';
        }
        return date.toLocaleString('fr-FR', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    function formatTime(iso) {
        var date = iso ? new Date(iso) : new Date();
        if (isNaN(date.getTime())) {
            return '—';
        }
        return date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    }

    function relativeTime(iso) {
        if (!iso) {
            return '—';
        }
        var date = new Date(iso);
        if (isNaN(date.getTime())) {
            return '—';
        }
        var seconds = Math.round((Date.now() - date.getTime()) / 1000);
        if (seconds < 45) {
            return 'à l’instant';
        }
        if (seconds < 3600) {
            return 'il y a ' + Math.round(seconds / 60) + ' min';
        }
        if (seconds < 86400) {
            return 'il y a ' + Math.round(seconds / 3600) + ' h';
        }
        return 'il y a ' + Math.round(seconds / 86400) + ' j';
    }

    function plural(count, singular, pluralForm) {
        return count + ' ' + (count > 1 ? pluralForm : singular);
    }

    /* ----------------------------------------------------------------------
       Toasts
       ---------------------------------------------------------------------- */

    function toast(message, tone, delay) {
        var stack = byId('hub-toast');
        if (!stack) {
            return;
        }
        var node = document.createElement('div');
        node.className = 'toast' + (tone ? ' is-' + tone : '');
        node.setAttribute('role', 'status');
        node.textContent = String(message);
        stack.appendChild(node);
        window.setTimeout(function () {
            if (node.parentNode) {
                node.parentNode.removeChild(node);
            }
        }, delay || 4200);
    }

    /* ----------------------------------------------------------------------
       API
       ---------------------------------------------------------------------- */

    function requestJson(url, options) {
        return fetch(url, options || {}).then(function (response) {
            return response.json().catch(function () {
                return {};
            }).then(function (data) {
                if (!response.ok) {
                    var message = data && data.error ? data.error : ('Erreur HTTP ' + response.status);
                    throw new Error(message);
                }
                return data;
            });
        });
    }

    function postJson(url, payload) {
        return requestJson(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload || {})
        });
    }

    /* ----------------------------------------------------------------------
       KPI
       ---------------------------------------------------------------------- */

    function renderKpis() {
        var container = byId('hub-kpis');
        if (!container) {
            return;
        }

        var summary = state.summary || {};
        var items = [
            { label: 'Rapports', value: summary.Reports || 0, tone: 'primary' },
            { label: 'Rapports HTML', value: summary.Html || 0, tone: 'success' },
            { label: 'Exports CSV', value: summary.Csv || 0, tone: 'warning' },
            { label: 'Exports JSON', value: summary.Json || 0, tone: 'warning' },
            {
                label: 'Scripts prêts',
                value: (summary.Runnable || 0) + ' / ' + (summary.Actions || 0),
                tone: (summary.Runnable || 0) > 0 ? 'success' : 'danger'
            },
            { label: 'Journaux', value: summary.Logs || 0, tone: 'primary' }
        ];

        container.innerHTML = items.map(function (item) {
            return '<article class="kpi kpi-' + item.tone + '">' +
                '<span class="kpi-label">' + escapeHtml(item.label) + '</span>' +
                '<span class="kpi-value tone-' + item.tone + '">' + escapeHtml(item.value) + '</span>' +
                '</article>';
        }).join('');
    }

    /* ----------------------------------------------------------------------
       Actions
       ---------------------------------------------------------------------- */

    function renderActions() {
        var container = byId('hub-actions');
        if (!container) {
            return;
        }

        if (!state.actions.length) {
            container.innerHTML = '<p class="empty">Aucun script disponible.</p>';
            return;
        }

        container.innerHTML = state.actions.map(function (action) {
            var available = Boolean(action.available);
            var badge = available
                ? '<span class="badge badge-ok">Prêt</span>'
                : '<span class="badge badge-warn">Indisponible</span>';
            var note = available ? '' : '<p class="action-note">' + escapeHtml(action.reason || 'Prérequis manquant.') + '</p>';
            var disabled = available ? '' : ' disabled aria-disabled="true"';
            var runningLabel = running ? 'Exécution…' : 'Exécuter';

            return '<article class="action-card' + (available ? '' : ' is-unavailable') + '">' +
                '<div class="action-head">' +
                '<h3>' + escapeHtml(action.name) + '</h3>' + badge +
                '</div>' +
                '<p>' + escapeHtml(action.description) + '</p>' +
                note +
                '<div class="action-foot">' +
                '<code title="' + escapeHtml(action.script) + '">' + escapeHtml(action.script) + '</code>' +
                '<button type="button" class="btn btn-primary" data-run="' + escapeHtml(action.id) + '"' + disabled + '>' + runningLabel + '</button>' +
                '</div>' +
                '</article>';
        }).join('');
    }

    /* ----------------------------------------------------------------------
       Rapports
       ---------------------------------------------------------------------- */

    function compareReports(left, right) {
        var key = view.sortKey;
        var direction = view.sortDir === 'asc' ? 1 : -1;
        var leftValue = left[key];
        var rightValue = right[key];

        if (key === 'Size') {
            return ((Number(leftValue) || 0) - (Number(rightValue) || 0)) * direction;
        }

        if (key === 'Modified' || key === 'Date') {
            return String(leftValue || '').localeCompare(String(rightValue || '')) * direction;
        }

        return String(leftValue || '').localeCompare(String(rightValue || ''), 'fr', { sensitivity: 'base' }) * direction;
    }

    function visibleReports() {
        var term = view.term.toLowerCase();
        var list = state.reports.filter(function (report) {
            if (!term) {
                return true;
            }
            var haystack = [report.name, report.base, report.type, report.date, report.fileName].join(' ').toLowerCase();
            return haystack.indexOf(term) !== -1;
        });
        return list.sort(compareReports);
    }

    function reportActions(report) {
        var open = '';
        if (report.type === 'html') {
            open = '<a class="btn btn-ghost btn-small" href="' + escapeHtml(report.url) + '" target="_blank" rel="noopener">Ouvrir</a>';
        }
        return '<div class="row-actions">' + open +
            '<a class="btn btn-ghost btn-small" href="' + escapeHtml(report.url) + '" download>Télécharger</a>' +
            '</div>';
    }

    function renderReports() {
        var body = byId('hub-reports-body');
        var count = byId('hub-count');
        var hint = byId('hub-reports-hint');
        if (!body) {
            return;
        }

        var list = visibleReports();

        if (!list.length) {
            body.innerHTML = '<tr><td colspan="6" class="empty">' +
                (state.reports.length ? 'Aucun rapport ne correspond au filtre.' : 'Aucun rapport généré. Lancez un script pour commencer.') +
                '</td></tr>';
        }
        else {
            body.innerHTML = list.map(function (report) {
                return '<tr>' +
                    '<td><div class="file-name"><span class="badge badge-' + escapeHtml(report.type) + '">' + escapeHtml(report.type) + '</span>' +
                    '<div><strong>' + escapeHtml(report.name || report.base) + '</strong>' +
                    '<span title="' + escapeHtml(report.fileName) + '">' + escapeHtml(report.fileName) + '</span></div></div></td>' +
                    '<td><span class="badge badge-' + escapeHtml(report.type) + '">' + escapeHtml(report.type) + '</span></td>' +
                    '<td>' + escapeHtml(report.date || '—') + '</td>' +
                    '<td>' + escapeHtml(formatBytes(report.size)) + '</td>' +
                    '<td title="' + escapeHtml(report.modified) + '">' + escapeHtml(formatDate(report.modified)) +
                    ' <span class="hint">(' + escapeHtml(relativeTime(report.modified)) + ')</span></td>' +
                    '<td class="actions-column">' + reportActions(report) + '</td>' +
                    '</tr>';
            }).join('');
        }

        if (count) {
            count.textContent = list.length + ' / ' + plural(state.reports.length, 'rapport', 'rapports');
        }
        if (hint) {
            hint.textContent = state.generatedAt ? ('Actualisé ' + relativeTime(state.generatedAt)) : '';
        }
    }

    function applySortIndicators() {
        var headers = document.querySelectorAll('#hub-reports-table thead th[data-sort-key]');
        Array.prototype.forEach.call(headers, function (header) {
            var key = header.getAttribute('data-sort-key');
            if (key === view.sortKey) {
                header.setAttribute('data-sort', view.sortDir);
                header.setAttribute('aria-sort', view.sortDir === 'asc' ? 'ascending' : 'descending');
            }
            else {
                header.removeAttribute('data-sort');
                header.setAttribute('aria-sort', 'none');
            }
        });
    }

    /* ----------------------------------------------------------------------
       Journaux
       ---------------------------------------------------------------------- */

    function renderLogs() {
        var body = byId('hub-logs-body');
        if (!body) {
            return;
        }

        if (!state.logs.length) {
            body.innerHTML = '<tr><td colspan="4" class="empty">Aucun journal disponible.</td></tr>';
            return;
        }

        body.innerHTML = state.logs.map(function (log) {
            return '<tr>' +
                '<td><div class="file-name"><strong>' + escapeHtml(log.name) + '</strong></div></td>' +
                '<td>' + escapeHtml(formatBytes(log.size)) + '</td>' +
                '<td title="' + escapeHtml(log.modified) + '">' + escapeHtml(formatDate(log.modified)) +
                ' <span class="hint">(' + escapeHtml(relativeTime(log.modified)) + ')</span></td>' +
                '<td class="actions-column"><div class="row-actions">' +
                '<button type="button" class="btn btn-ghost btn-small" data-log="' + escapeHtml(log.name) + '">Voir</button>' +
                '</div></td>' +
                '</tr>';
        }).join('');
    }

    function openLog(name) {
        var viewer = byId('hub-log-viewer');
        var content = byId('hub-log-content');
        var title = byId('hub-log-title');
        if (!viewer || !content) {
            return;
        }

        title.textContent = name;
        content.textContent = 'Chargement…';
        viewer.hidden = false;

        requestJson('/api/log?name=' + encodeURIComponent(name))
            .then(function (data) {
                content.textContent = data.content || '(journal vide)';
            })
            .catch(function (error) {
                content.textContent = 'Erreur : ' + error.message;
            });
    }

    function closeLog() {
        var viewer = byId('hub-log-viewer');
        if (viewer) {
            viewer.hidden = true;
        }
    }

    /* ----------------------------------------------------------------------
       Exécution
       ---------------------------------------------------------------------- */

    function setRunButtonsDisabled(disabled) {
        Array.prototype.forEach.call(document.querySelectorAll('[data-run]'), function (button) {
            if (disabled) {
                button.setAttribute('aria-disabled', 'true');
                button.disabled = true;
                button.textContent = 'Exécution…';
            }
        });
    }

    function showRunPanel(run) {
        var panel = byId('hub-run-panel');
        if (panel) {
            panel.hidden = false;
        }
        renderRun(run);
    }

    function renderRun(run) {
        var status = byId('hub-run-status');
        var meta = byId('hub-run-meta');
        var output = byId('hub-run-output');

        if (status) {
            status.className = 'run-status';
            if (run.state === 'running') {
                status.textContent = 'En cours · ' + Math.round(run.elapsedSeconds || 0) + ' s';
            }
            else if (run.state === 'completed') {
                status.className = 'run-status is-done';
                status.textContent = 'Terminé en ' + (run.durationSeconds || 0).toFixed(1).replace('.', ',') + ' s';
            }
            else if (run.state === 'failed') {
                status.className = 'run-status is-error';
                status.textContent = 'Échec';
            }
            else {
                status.textContent = 'Inactif';
            }
        }

        if (meta) {
            var parts = [];
            if (run.actionName) {
                parts.push('<span>Script : <strong>' + escapeHtml(run.actionName) + '</strong></span>');
            }
            if (run.startedAt) {
                parts.push('<span>Démarré à <strong>' + escapeHtml(formatTime(run.startedAt)) + '</strong></span>');
            }
            if (Array.isArray(run.artifacts) && run.artifacts.length) {
                var links = run.artifacts.map(function (artifact) {
                    return '<a class="btn btn-ghost btn-small" href="' + escapeHtml(artifact.url) + '" target="_blank" rel="noopener">' +
                        escapeHtml(artifact.type.toUpperCase()) + '</a>';
                }).join(' ');
                parts.push('<span>Livrables : ' + links + '</span>');
            }
            if (run.error) {
                parts.push('<span class="tone-danger">' + escapeHtml(run.error) + '</span>');
            }
            meta.innerHTML = parts.join('');
        }

        if (output) {
            output.textContent = run.output || 'Aucune sortie.';
            output.scrollTop = output.scrollHeight;
        }
    }

    function pollRun() {
        requestJson('/api/run/status')
            .then(function (run) {
                if (run.state === 'idle') {
                    running = false;
                    setRunButtonsDisabled(false);
                    renderActions();
                    return;
                }

                showRunPanel(run);
                if (run.state === 'running') {
                    pollTimer = window.setTimeout(pollRun, 900);
                    return;
                }

                running = false;
                pollTimer = null;
                setRunButtonsDisabled(false);
                renderActions();
                renderRun(run);

                if (run.state === 'completed') {
                    toast('Exécution terminée en ' + (run.durationSeconds || 0).toFixed(1).replace('.', ',') + ' s.', 'success');
                }
                else {
                    toast('L’exécution a échoué. Consultez la sortie.', 'error');
                }

                loadState(true);
            })
            .catch(function (error) {
                running = false;
                pollTimer = null;
                setRunButtonsDisabled(false);
                renderActions();
                toast('Suivi impossible : ' + error.message, 'error');
            });
    }

    function startRun(id) {
        if (running) {
            return;
        }

        var action = state.actions.filter(function (item) { return item.id === id; })[0];
        if (!action || !action.available) {
            toast('Ce script n’est pas disponible.', 'warning');
            return;
        }

        running = true;
        setRunButtonsDisabled(true);
        showRunPanel({
            state: 'running',
            actionId: id,
            actionName: action.name,
            startedAt: new Date().toISOString(),
            elapsedSeconds: 0,
            output: 'Lancement de ' + action.script + '…'
        });

        postJson('/api/run', { id: id })
            .then(function () {
                toast('Script lancé : ' + action.name, 'success', 2200);
                pollTimer = window.setTimeout(pollRun, 800);
            })
            .catch(function (error) {
                running = false;
                setRunButtonsDisabled(false);
                renderActions();
                renderRun({ state: 'failed', actionName: action.name, error: error.message, output: error.message });
                toast('Lancement refusé : ' + error.message, 'error');
            });
    }

    /* ----------------------------------------------------------------------
       État global
       ---------------------------------------------------------------------- */

    function renderAll() {
        renderKpis();
        renderActions();
        renderReports();
        renderLogs();
        applySortIndicators();
    }

    function loadState(silent) {
        return requestJson('/api/state')
            .then(function (data) {
                state = data;
                renderAll();
                if (!silent) {
                    toast('État actualisé.', 'success', 1800);
                }
            })
            .catch(function (error) {
                if (!silent) {
                    toast('Actualisation impossible : ' + error.message, 'error');
                }
                var body = byId('hub-reports-body');
                if (body) {
                    body.innerHTML = '<tr><td colspan="6" class="empty">Serveur injoignable : ' + escapeHtml(error.message) + '</td></tr>';
                }
            });
    }

    function resumeRun() {
        requestJson('/api/run/status')
            .then(function (run) {
                if (run.state === 'running') {
                    running = true;
                    setRunButtonsDisabled(true);
                    renderActions();
                    showRunPanel(run);
                    pollTimer = window.setTimeout(pollRun, 900);
                }
                else if (run.state === 'completed' || run.state === 'failed') {
                    showRunPanel(run);
                }
            })
            .catch(function () {
                /* Le serveur peut avoir été arrêté : le chargement de l'état affichera l'erreur. */
            });
    }

    /* ----------------------------------------------------------------------
       Événements
       ---------------------------------------------------------------------- */

    document.addEventListener('click', function (event) {
        var target = event.target;

        var runButton = target.closest ? target.closest('[data-run]') : null;
        if (runButton) {
            startRun(runButton.getAttribute('data-run'));
            return;
        }

        var logButton = target.closest ? target.closest('[data-log]') : null;
        if (logButton) {
            openLog(logButton.getAttribute('data-log'));
            return;
        }

        if (target.id === 'hub-log-close' || target.id === 'hub-log-viewer') {
            closeLog();
        }
    });

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') {
            closeLog();
            var search = byId('hub-search');
            if (search && document.activeElement === search && search.value) {
                search.value = '';
                view.term = '';
                renderReports();
            }
            return;
        }

        var tag = (event.target.tagName || '').toLowerCase();
        if (tag === 'input' || tag === 'textarea' || event.target.isContentEditable) {
            return;
        }

        if (event.key === '/') {
            event.preventDefault();
            var input = byId('hub-search');
            if (input) {
                input.focus();
            }
        }
        else if (event.key === 'r' || event.key === 'R') {
            loadState(false);
        }
    });

    var search = byId('hub-search');
    if (search) {
        search.addEventListener('input', function () {
            view.term = search.value.trim();
            renderReports();
        });
    }

    var reportsTable = byId('hub-reports-table');
    if (reportsTable) {
        Array.prototype.forEach.call(reportsTable.querySelectorAll('thead th[data-sort-key]'), function (header) {
            function activate() {
                var key = header.getAttribute('data-sort-key');
                if (view.sortKey === key) {
                    view.sortDir = view.sortDir === 'asc' ? 'desc' : 'asc';
                }
                else {
                    view.sortKey = key;
                    view.sortDir = key === 'Modified' || key === 'Date' || key === 'Size' ? 'desc' : 'asc';
                }
                applySortIndicators();
                renderReports();
            }

            header.addEventListener('click', activate);
            header.addEventListener('keydown', function (event) {
                if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault();
                    activate();
                }
            });
        });
    }

    var refresh = byId('hub-refresh');
    if (refresh) {
        refresh.addEventListener('click', function () { loadState(false); });
    }

    var stop = byId('hub-stop');
    if (stop) {
        stop.addEventListener('click', function () {
            if (!window.confirm('Arrêter le serveur local du dashboard ?')) {
                return;
            }
            postJson('/api/shutdown', {})
                .then(function () {
                    running = false;
                    var overlay = document.createElement('div');
                    overlay.className = 'log-viewer';
                    overlay.innerHTML = '<div class="log-viewer-box" role="dialog" aria-modal="true">' +
                        '<div class="log-viewer-head"><h2>Serveur arrêté</h2></div>' +
                        '<div class="run-body"><p>Le dashboard local est arrêté. Vous pouvez fermer cet onglet.</p></div>' +
                        '</div>';
                    document.body.appendChild(overlay);
                })
                .catch(function (error) {
                    toast('Arrêt impossible : ' + error.message, 'error');
                });
        });
    }

    /* ----------------------------------------------------------------------
       Démarrage
       ---------------------------------------------------------------------- */

    var host = byId('hub-host');
    if (host) {
        host.textContent = window.location.host;
    }

    loadState(true).then(resumeRun);
})();

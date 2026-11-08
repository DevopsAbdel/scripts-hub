/* ==========================================================================
   scripts-hub - Interactions du rapport (vanilla JS, hors ligne)
   Recherche, tri, export CSV/JSON, impression, graphiques Chart.js.
   ========================================================================== */

(function () {
    'use strict';

    var body = document.body;
    var reportName = (body.getAttribute('data-report-name') || 'report').replace(/[^\w\-]+/g, '_');
    var dateStamp = new Date().toISOString().slice(0, 10);
    var tables = Array.prototype.slice.call(document.querySelectorAll('table[data-sortable]'));
    var palette = {
        primary: '#58A6FF',
        success: '#3FB950',
        warning: '#D29922',
        danger: '#F85149',
        purple: '#A371F7',
        cyan: '#39C5CF',
        text: '#F0F6FC',
        grid: '#30363D',
        muted: '#8B949E'
    };

    /* ----------------------------------------------------------------------
       Téléchargement local (Blob)
       ---------------------------------------------------------------------- */

    function download(filename, mimeType, content) {
        var blob = new Blob([content], { type: mimeType });
        var url = URL.createObjectURL(blob);
        var anchor = document.createElement('a');
        anchor.href = url;
        anchor.download = filename;
        document.body.appendChild(anchor);
        anchor.click();
        window.setTimeout(function () {
            document.body.removeChild(anchor);
            URL.revokeObjectURL(url);
        }, 0);
    }

    function csvEscape(value) {
        var text = String(value === null || value === undefined ? '' : value);
        return '"' + text.replace(/"/g, '""') + '"';
    }

    /* ----------------------------------------------------------------------
       Recherche instantanée
       ---------------------------------------------------------------------- */

    var searchInput = document.getElementById('hub-search');
    var resultCount = document.getElementById('hub-count');

    function rowIsVisible(row) {
        return row.style.display !== 'none';
    }

    function refreshCount() {
        if (!resultCount) {
            return;
        }
        var total = 0;
        var visible = 0;
        tables.forEach(function (table) {
            var rows = Array.prototype.slice.call(table.tBodies[0].rows);
            total += rows.length;
            visible += rows.filter(rowIsVisible).length;
        });
        resultCount.textContent = visible + ' / ' + total + ' ligne(s)';
    }

    function applyFilter() {
        var term = searchInput ? searchInput.value.toLowerCase().trim() : '';
        tables.forEach(function (table) {
            var rows = Array.prototype.slice.call(table.tBodies[0].rows);
            rows.forEach(function (row) {
                var match = term === '' || row.textContent.toLowerCase().indexOf(term) !== -1;
                row.style.display = match ? '' : 'none';
            });
        });
        refreshCount();
    }

    if (searchInput) {
        searchInput.addEventListener('input', applyFilter);
        searchInput.addEventListener('search', applyFilter);
    }

    /* ----------------------------------------------------------------------
       Tri des colonnes
       ---------------------------------------------------------------------- */

    function parseNumber(text) {
        var cleaned = text.replace(/\s/g, '').replace('%', '').replace(',', '.');
        if (cleaned === '' || isNaN(Number(cleaned)) || !/^[+-]?\d+(\.\d+)?$/.test(cleaned)) {
            return null;
        }
        return Number(cleaned);
    }

    function cellText(row, index) {
        var cell = row.cells[index];
        return cell ? cell.textContent.trim() : '';
    }

    function sortTable(table, index, header) {
        var tbody = table.tBodies[0];
        var rows = Array.prototype.slice.call(tbody.rows);
        var ascending = header.getAttribute('data-sort') !== 'asc';

        Array.prototype.forEach.call(table.tHead.rows[0].cells, function (cell) {
            cell.removeAttribute('data-sort');
            cell.setAttribute('aria-sort', 'none');
        });
        header.setAttribute('data-sort', ascending ? 'asc' : 'desc');
        header.setAttribute('aria-sort', ascending ? 'ascending' : 'descending');

        rows.sort(function (left, right) {
            var leftText = cellText(left, index);
            var rightText = cellText(right, index);
            var leftNumber = parseNumber(leftText);
            var rightNumber = parseNumber(rightText);

            if (leftNumber !== null && rightNumber !== null) {
                return ascending ? leftNumber - rightNumber : rightNumber - leftNumber;
            }

            var result = leftText.localeCompare(rightText, 'fr', { numeric: true, sensitivity: 'base' });
            return ascending ? result : -result;
        });

        rows.forEach(function (row) {
            tbody.appendChild(row);
        });
    }

    tables.forEach(function (table) {
        if (!table.tHead || !table.tHead.rows.length) {
            return;
        }
        Array.prototype.forEach.call(table.tHead.rows[0].cells, function (header, index) {
            header.setAttribute('role', 'columnheader');
            header.setAttribute('tabindex', '0');
            header.setAttribute('aria-sort', 'none');
            header.setAttribute('title', 'Cliquer pour trier');
            header.addEventListener('click', function () {
                sortTable(table, index, header);
            });
            header.addEventListener('keydown', function (event) {
                if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault();
                    sortTable(table, index, header);
                }
            });
        });
    });

    /* ----------------------------------------------------------------------
       Export CSV par tableau
       ---------------------------------------------------------------------- */

    document.addEventListener('click', function (event) {
        var button = event.target.closest ? event.target.closest('.export-csv') : null;
        if (!button) {
            return;
        }

        var table = document.getElementById(button.getAttribute('data-table'));
        if (!table) {
            return;
        }

        var lines = [];
        var headers = Array.prototype.map.call(table.tHead.rows[0].cells, function (cell) {
            return csvEscape(cell.textContent.trim());
        });
        lines.push(headers.join(';'));

        Array.prototype.forEach.call(table.tBodies[0].rows, function (row) {
            if (!rowIsVisible(row)) {
                return;
            }
            var cells = Array.prototype.map.call(row.cells, function (cell) {
                return csvEscape(cell.textContent.trim());
            });
            lines.push(cells.join(';'));
        });

        var section = button.getAttribute('data-section') || 'data';
        var safeSection = section.replace(/[^\w\-]+/g, '_');
        download(reportName + '_' + safeSection + '_' + dateStamp + '.csv', 'text/csv;charset=utf-8', '\uFEFF' + lines.join('\r\n'));
    });

    /* ----------------------------------------------------------------------
       Export JSON global
       ---------------------------------------------------------------------- */

    var exportJson = document.getElementById('hub-export-json');
    if (exportJson) {
        exportJson.addEventListener('click', function () {
            var data = document.getElementById('hub-data');
            if (!data) {
                return;
            }
            download(reportName + '_' + dateStamp + '.json', 'application/json;charset=utf-8', '\uFEFF' + data.textContent.trim());
        });
    }

    /* ----------------------------------------------------------------------
       Impression / PDF
       ---------------------------------------------------------------------- */

    var printButton = document.getElementById('hub-print');
    if (printButton) {
        printButton.addEventListener('click', function () {
            window.print();
        });
    }

    /* ----------------------------------------------------------------------
       Graphiques Chart.js
       ---------------------------------------------------------------------- */

    var chartsConfig = document.getElementById('hub-charts-config');
    var definitions = [];

    if (chartsConfig) {
        try {
            definitions = JSON.parse(chartsConfig.textContent || '[]');
        }
        catch (error) {
            definitions = [];
        }
    }

    if (window.Chart && definitions.length) {
        window.Chart.defaults.color = palette.muted;
        window.Chart.defaults.borderColor = palette.grid;
        window.Chart.defaults.font.family = '"Segoe UI", "Inter", Arial, sans-serif';

        definitions.forEach(function (definition) {
            var canvas = document.getElementById(definition.id);
            if (!canvas) {
                return;
            }

            var type = definition.type || 'bar';
            var isCircular = type === 'doughnut' || type === 'pie';
            var color = palette[definition.color] || palette.primary;
            var background = isCircular
                ? [palette.primary, palette.success, palette.warning, palette.danger, palette.purple, palette.cyan]
                : color;

            if (type === 'line') {
                background = 'rgba(88, 166, 255, 0.16)';
            }

            new window.Chart(canvas, {
                type: type,
                data: {
                    labels: definition.labels || [],
                    datasets: [{
                        label: definition.label || '',
                        data: definition.values || [],
                        backgroundColor: background,
                        borderColor: color,
                        borderWidth: type === 'line' ? 2 : 1,
                        tension: 0.3,
                        fill: type === 'line'
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: isCircular,
                            labels: { color: palette.text, boxWidth: 12 }
                        },
                        tooltip: {
                            backgroundColor: palette.card || '#1F2630',
                            borderColor: palette.grid,
                            borderWidth: 1,
                            titleColor: palette.text,
                            bodyColor: palette.text
                        }
                    },
                    scales: isCircular ? {} : {
                        x: {
                            ticks: { color: palette.muted },
                            grid: { color: palette.grid }
                        },
                        y: {
                            beginAtZero: true,
                            ticks: { color: palette.muted },
                            grid: { color: palette.grid }
                        }
                    }
                }
            });
        });
    }

    refreshCount();
})();

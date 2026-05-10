"""UI layout sections for the Dash app."""

from __future__ import annotations

from dash import dash_table, dcc, html

from imos_toolbox.ui.data import parser_options


def build_layout() -> html.Div:
    return html.Div(
        [
            html.H2("IMOS Toolbox - Dash UI (MVP)"),
            dcc.Store(id="ui-config-store"),
            dcc.Store(id="dataset-store"),
            dcc.Tabs(
                id="ui-tabs",
                value="start",
                children=[
                    dcc.Tab(label="Start", value="start", children=[start_page()]),
                    dcc.Tab(label="Dataset Preview", value="preview", children=[dataset_preview_page()]),
                    dcc.Tab(label="Metadata", value="metadata", children=[metadata_editor_page()]),
                    dcc.Tab(label="QC Summary", value="qc-summary", children=[qc_summary_page()]),
                    dcc.Tab(label="Spike Selection", value="spike", children=[spike_selection_page()]),
                    dcc.Tab(label="Manual Flagging", value="manual", children=[manual_flagging_page()]),
                    dcc.Tab(label="Graph Export", value="graph-export", children=[graph_export_page()]),
                    dcc.Tab(label="Export", value="export", children=[export_flow_page()]),
                    dcc.Tab(label="Logs", value="logs", children=[log_diagnostics_page()]),
                ],
            ),
        ],
        style={"padding": "1rem"},
    )


def start_page() -> html.Div:
    return html.Div(
        [
            html.H3("Start Page"),
            html.Label("Mode"),
            dcc.Dropdown(
                id="start-mode",
                options=[
                    {"label": "timeSeries", "value": "timeSeries"},
                    {"label": "profile", "value": "profile"},
                ],
                value="timeSeries",
                clearable=False,
            ),
            html.Label("Data Directory"),
            dcc.Input(id="start-data-dir", type="text", value="", style={"width": "100%"}),
            html.Label("Field Trip"),
            dcc.Input(id="start-field-trip", type="text", value="", style={"width": "100%"}),
            html.Label("DDB Connection"),
            dcc.Input(id="start-ddb", type="text", value="", style={"width": "100%"}),
            html.Hr(),
            html.Label("Parser"),
            dcc.Dropdown(
                id="start-parser",
                options=parser_options(),
                value="sbe37",
                clearable=False,
            ),
            html.Label("Input File(s)"),
            dcc.Textarea(
                id="start-files",
                value="",
                placeholder="Absolute file paths, comma or newline separated",
                style={"width": "100%", "height": 100},
            ),
            html.Br(),
            html.Button("Apply Configuration", id="start-apply", n_clicks=0),
            html.Button("Load Dataset", id="start-load", n_clicks=0, style={"marginLeft": "0.5rem"}),
            html.Div(id="start-status", style={"marginTop": "0.5rem"}),
        ]
    )


def dataset_preview_page() -> html.Div:
    return html.Div(
        [
            html.H3("Dataset Preview"),
            html.P("Data exploration view with summary and sample rows."),
            dcc.Dropdown(id="preview-variable", options=[], value=None, clearable=False),
            dcc.Graph(id="preview-graph"),
            dash_table.DataTable(  # type: ignore[attr-defined]
                id="preview-table",
                columns=[],
                data=[],
                page_size=10,
            ),
        ]
    )


def metadata_editor_page() -> html.Div:
    return html.Div(
        [
            html.H3("Metadata Editor"),
            dash_table.DataTable(  # type: ignore[attr-defined]
                id="metadata-table",
                columns=[
                    {"name": "key", "id": "key", "editable": False},
                    {"name": "value", "id": "value", "editable": True},
                ],
                data=[
                    {"key": "instrument_make", "value": ""},
                    {"key": "instrument_model", "value": ""},
                    {"key": "instrument_serial_no", "value": ""},
                ],
                editable=True,
            ),
            html.Div(id="metadata-dataset-summary", style={"marginTop": "0.5rem"}),
        ]
    )


def qc_summary_page() -> html.Div:
    return html.Div(
        [
            html.H3("QC Summary / Stats"),
            dcc.Graph(id="qc-flag-counts"),
            dcc.Graph(id="qc-time-series"),
        ]
    )


def spike_selection_page() -> html.Div:
    return html.Div(
        [
            html.H3("Spike Selection"),
            html.P("QC interaction view for spike review and candidate flagging."),
            dcc.Dropdown(id="spike-variable", options=[], value=None, clearable=False),
            dcc.Graph(id="spike-graph"),
            html.Label("Threshold"),
            dcc.Slider(id="spike-threshold", min=0.0, max=10.0, step=0.1, value=3.0),
            html.Button("Mark Selected Spikes", id="spike-mark", n_clicks=0),
            html.Div(id="spike-status", style={"marginTop": "0.5rem"}),
        ]
    )


def manual_flagging_page() -> html.Div:
    return html.Div(
        [
            html.H3("Manual Flagging"),
            html.P("QC interaction view for manual point/segment flagging. Use box/lasso selection on the plot."),
            dcc.Dropdown(id="manual-variable", options=[], value=None, clearable=False),
            dcc.Graph(id="manual-flag-graph"),
            dcc.Dropdown(
                id="manual-flag-code",
                options=[
                    {"label": "Good (1)", "value": 1},
                    {"label": "Probably Good (2)", "value": 2},
                    {"label": "Probably Bad (3)", "value": 3},
                    {"label": "Bad (4)", "value": 4},
                ],
                value=3,
                clearable=False,
            ),
            html.Button("Apply Manual Flag", id="manual-flag-apply", n_clicks=0),
            html.Div(id="manual-status", style={"marginTop": "0.5rem"}),
        ]
    )


def graph_export_page() -> html.Div:
    return html.Div(
        [
            html.H3("Graph Export"),
            html.P("Plot export controls for PNG/SVG/HTML outputs."),
            dcc.Dropdown(
                id="graph-export-format",
                options=[
                    {"label": "PNG", "value": "png"},
                    {"label": "SVG", "value": "svg"},
                    {"label": "HTML", "value": "html"},
                ],
                value="png",
                clearable=False,
            ),
            html.Button("Export Current Plot", id="graph-export-button", n_clicks=0),
        ]
    )


def export_flow_page() -> html.Div:
    return html.Div(
        [
            html.H3("Export Flow"),
            html.P("Export workflow for writing processed output files."),
            dcc.Input(id="export-output-dir", type="text", value="", placeholder="Output directory", style={"width": "100%"}),
            dcc.Checklist(
                id="export-options",
                options=[
                    {"label": "Include QC variables", "value": "qc"},
                    {"label": "Include diagnostics", "value": "diag"},
                ],
                value=["qc"],
            ),
            html.Button("Run Export", id="export-run", n_clicks=0),
            html.Div(id="export-status", style={"marginTop": "0.5rem"}),
        ]
    )


def log_diagnostics_page() -> html.Div:
    return html.Div(
        [
            html.H3("Log / Diagnostics"),
            dcc.Textarea(
                id="log-output",
                value="",
                style={"width": "100%", "height": 240},
                readOnly=True,
            ),
        ]
    )

"""Dash application setup for IMOS Toolbox UI."""

from __future__ import annotations

from typing import Any

from dash import Dash, Input, Output, State, no_update
from plotly import graph_objects as go

from imos_toolbox.ui.data import (
    apply_manual_flags,
    dataset_variables,
    load_dataset_state,
    mark_spikes,
    parse_file_list,
)
from imos_toolbox.ui.layout import build_layout
from imos_toolbox.ui.state import UIConfig


def _empty_figure(title: str) -> dict[str, Any]:
    fig = go.Figure()
    fig.update_layout(title=title, template="plotly_white")
    return fig.to_dict()


def _series_for(dataset_state: dict[str, Any] | None, variable: str | None) -> tuple[list[Any], list[Any], list[int]]:
    if not dataset_state or not variable:
        return [], [], []
    x_values = list(dataset_state.get("x", []))
    values = list(dataset_state.get("variables", {}).get(variable, []))
    flags = list(dataset_state.get("qc_flags", {}).get(variable, [1] * len(values)))
    return x_values, values, flags


def _flag_colors(flags: list[int]) -> list[int]:
    return [int(flag) for flag in flags]


def _preview_figure(dataset_state: dict[str, Any] | None, variable: str | None) -> dict[str, Any]:
    x_values, values, flags = _series_for(dataset_state, variable)
    if not x_values or not values:
        return _empty_figure("Dataset Preview")
    state = dataset_state or {}

    fig = go.Figure(
        data=[
            go.Scatter(
                x=x_values,
                y=values,
                mode="markers+lines",
                marker={"size": 6, "color": _flag_colors(flags), "colorscale": "Viridis", "cmin": 1, "cmax": 4},
                name=variable,
            )
        ]
    )
    fig.update_layout(
        title=f"Preview: {variable}",
        xaxis_title=str(state.get("x_name", "x")),
        yaxis_title=variable,
        template="plotly_white",
    )
    return fig.to_dict()


def _preview_table(
    dataset_state: dict[str, Any] | None,
    variable: str | None,
    max_rows: int = 200,
) -> tuple[list[dict[str, str]], list[dict[str, Any]]]:
    x_values, values, flags = _series_for(dataset_state, variable)
    if not x_values or not values:
        return [], []
    state = dataset_state or {}

    x_name = str(state.get("x_name", "x"))
    columns = [
        {"name": x_name, "id": x_name},
        {"name": str(variable), "id": str(variable)},
        {"name": f"{variable}_QC", "id": f"{variable}_QC"},
    ]
    rows: list[dict[str, Any]] = []
    n_rows = min(len(values), len(x_values), max_rows)
    for idx in range(n_rows):
        rows.append(
            {
                x_name: x_values[idx],
                str(variable): values[idx],
                f"{variable}_QC": flags[idx] if idx < len(flags) else 1,
            }
        )
    return columns, rows


def _qc_count_figure(dataset_state: dict[str, Any] | None) -> dict[str, Any]:
    if not dataset_state:
        return _empty_figure("QC Flag Counts")

    counts = {1: 0, 2: 0, 3: 0, 4: 0}
    for flag_list in dataset_state.get("qc_flags", {}).values():
        for flag in flag_list:
            f = int(flag)
            if f in counts:
                counts[f] += 1

    fig = go.Figure(
        data=[go.Bar(x=[str(key) for key in counts.keys()], y=list(counts.values()), marker={"color": list(counts.keys()), "colorscale": "Viridis", "cmin": 1, "cmax": 4})]
    )
    fig.update_layout(title="QC Flag Counts", xaxis_title="Flag Code", yaxis_title="Count", template="plotly_white")
    return fig.to_dict()


def _qc_timeseries_figure(dataset_state: dict[str, Any] | None) -> dict[str, Any]:
    if not dataset_state:
        return _empty_figure("QC Time Series")

    variable = str(dataset_state.get("selected_var") or "")
    if not variable:
        variables = dataset_variables(dataset_state)
        variable = variables[0] if variables else ""
    return _preview_figure(dataset_state, variable)


def _manual_selected_indices(selected_data: dict[str, Any] | None) -> list[int]:
    if not selected_data:
        return []
    points = selected_data.get("points", [])
    indices: list[int] = []
    for point in points:
        point_index = point.get("pointIndex")
        if isinstance(point_index, int):
            indices.append(point_index)
    return indices


def build_app() -> Dash:
    app = Dash(__name__)
    app.layout = build_layout()

    @app.callback(
        Output("ui-config-store", "data"),
        Output("start-status", "children"),
        Input("start-apply", "n_clicks"),
        State("start-mode", "value"),
        State("start-data-dir", "value"),
        State("start-field-trip", "value"),
        State("start-ddb", "value"),
        prevent_initial_call=True,
    )
    def apply_start_config(
        _n_clicks: int,
        mode: str,
        data_dir: str,
        field_trip: str,
        ddb_connection: str,
    ) -> tuple[dict[str, str], str]:
        config = UIConfig(
            mode=mode or "timeSeries",
            data_dir=data_dir or "",
            field_trip=field_trip or "",
            ddb_connection=ddb_connection or "",
        )
        return config.to_dict(), "Configuration updated"

    @app.callback(
        Output("dataset-store", "data"),
        Output("start-status", "children", allow_duplicate=True),
        Input("start-load", "n_clicks"),
        State("start-parser", "value"),
        State("start-files", "value"),
        State("start-mode", "value"),
        prevent_initial_call=True,
    )
    def load_dataset(
        _n_clicks: int,
        parser_name: str,
        files_raw: str,
        mode: str,
    ) -> tuple[dict[str, Any] | None, str]:
        try:
            filenames = parse_file_list(files_raw or "")
            if not filenames:
                return None, "No files provided"
            dataset_state = load_dataset_state(parser_name=parser_name, filenames=filenames, mode=mode or "timeSeries")
            rows = len(dataset_state.get("x", []))
            vars_count = len(dataset_state.get("variables", {}))
            return dataset_state, f"Loaded {len(filenames)} file(s): {rows} rows, {vars_count} variables"
        except Exception as exc:
            return None, f"Load failed: {exc}"

    @app.callback(
        Output("preview-variable", "options"),
        Output("preview-variable", "value"),
        Output("spike-variable", "options"),
        Output("spike-variable", "value"),
        Output("manual-variable", "options"),
        Output("manual-variable", "value"),
        Input("dataset-store", "data"),
    )
    def sync_variable_options(dataset_state: dict[str, Any] | None) -> tuple[list[dict[str, str]], str | None, list[dict[str, str]], str | None, list[dict[str, str]], str | None]:
        vars_list = dataset_variables(dataset_state)
        options = [{"label": name, "value": name} for name in vars_list]
        default_value = vars_list[0] if vars_list else None
        return options, default_value, options, default_value, options, default_value

    @app.callback(
        Output("preview-graph", "figure"),
        Output("preview-table", "columns"),
        Output("preview-table", "data"),
        Input("dataset-store", "data"),
        Input("preview-variable", "value"),
    )
    def update_preview(
        dataset_state: dict[str, Any] | None,
        variable: str | None,
    ) -> tuple[dict[str, Any], list[dict[str, str]], list[dict[str, Any]]]:
        vars_list = dataset_variables(dataset_state)
        preview_var = variable or (vars_list[0] if vars_list else None)
        figure = _preview_figure(dataset_state, preview_var)
        columns, rows = _preview_table(dataset_state, preview_var)
        return figure, columns, rows

    @app.callback(
        Output("spike-graph", "figure"),
        Input("dataset-store", "data"),
        Input("spike-variable", "value"),
    )
    def update_spike_graph(dataset_state: dict[str, Any] | None, variable: str | None) -> dict[str, Any]:
        return _preview_figure(dataset_state, variable)

    @app.callback(
        Output("manual-flag-graph", "figure"),
        Input("dataset-store", "data"),
        Input("manual-variable", "value"),
    )
    def update_manual_graph(dataset_state: dict[str, Any] | None, variable: str | None) -> dict[str, Any]:
        return _preview_figure(dataset_state, variable)

    @app.callback(
        Output("qc-flag-counts", "figure"),
        Output("qc-time-series", "figure"),
        Input("dataset-store", "data"),
    )
    def update_qc_summary(dataset_state: dict[str, Any] | None) -> tuple[dict[str, Any], dict[str, Any]]:
        return _qc_count_figure(dataset_state), _qc_timeseries_figure(dataset_state)

    @app.callback(
        Output("metadata-dataset-summary", "children"),
        Input("dataset-store", "data"),
    )
    def update_metadata_summary(dataset_state: dict[str, Any] | None) -> str:
        if not dataset_state:
            return "No dataset loaded"
        attrs = dataset_state.get("attrs", {})
        if not attrs:
            return "Dataset loaded, no global attributes found"
        preview = ", ".join(f"{k}={v}" for k, v in list(attrs.items())[:5])
        return f"Dataset attributes: {preview}"

    @app.callback(
        Output("dataset-store", "data", allow_duplicate=True),
        Output("spike-status", "children"),
        Input("spike-mark", "n_clicks"),
        State("dataset-store", "data"),
        State("spike-variable", "value"),
        State("spike-threshold", "value"),
        prevent_initial_call=True,
    )
    def apply_spike_flags(
        _n_clicks: int,
        dataset_state: dict[str, Any] | None,
        variable: str | None,
        threshold: float,
    ) -> tuple[dict[str, Any] | Any, str]:
        if not dataset_state or not variable:
            return no_update, "Load data and choose a variable first"
        updated, count = mark_spikes(dataset_state, variable=variable, threshold=float(threshold), flag_code=4)
        return updated, f"Spike flag applied: {count} point(s) marked as Bad (4)"

    @app.callback(
        Output("dataset-store", "data", allow_duplicate=True),
        Output("manual-status", "children"),
        Input("manual-flag-apply", "n_clicks"),
        State("dataset-store", "data"),
        State("manual-variable", "value"),
        State("manual-flag-code", "value"),
        State("manual-flag-graph", "selectedData"),
        prevent_initial_call=True,
    )
    def apply_manual_flag(
        _n_clicks: int,
        dataset_state: dict[str, Any] | None,
        variable: str | None,
        flag_code: int,
        selected_data: dict[str, Any] | None,
    ) -> tuple[dict[str, Any] | Any, str]:
        if not dataset_state or not variable:
            return no_update, "Load data and choose a variable first"
        indices = _manual_selected_indices(selected_data)
        if not indices:
            return no_update, "No points selected on the manual flag plot"
        updated, count = apply_manual_flags(dataset_state, variable=variable, indices=indices, flag_code=int(flag_code))
        return updated, f"Manual flag applied: {count} point(s) set to {flag_code}"

    @app.callback(
        Output("export-status", "children"),
        Input("export-run", "n_clicks"),
        State("export-output-dir", "value"),
        State("export-options", "value"),
        State("dataset-store", "data"),
        prevent_initial_call=True,
    )
    def run_export_stub(
        _n_clicks: int,
        output_dir: str,
        options: list[str],
        dataset_state: dict[str, Any] | None,
    ) -> str:
        opt_list = ", ".join(options or [])
        rows = len(dataset_state.get("x", [])) if dataset_state else 0
        return f"Export queued (stub): rows={rows}, output={output_dir or '<unset>'}, options=[{opt_list}]"

    return app

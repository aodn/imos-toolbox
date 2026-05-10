"""Canonical deployment database schema.

This module captures the inferred DDB schema from ``docs/SCHEMA.md`` once and
derives the formats needed by the Python port:

* SQLAlchemy ``MetaData`` / ``Table`` objects suitable for Alembic-managed DDL
* JSON-serializable schema documents
* database-agnostic DDL text for management/documentation workflows
* JSON Schema documents and validators for row/payload validation
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
import json
from typing import Any, Literal

from jsonschema import Draft202012Validator, FormatChecker
from sqlalchemy import Boolean, Column, Date, DateTime, Float, ForeignKey, MetaData, String, Table
from sqlalchemy.sql.type_api import TypeEngine

LogicalType = Literal["string", "double", "boolean", "date"]
JSONSchemaDict = dict[str, Any]

_NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

_FORMAT_CHECKER = FormatChecker()


@_FORMAT_CHECKER.checks("date")
def _is_iso_date(value: object) -> bool:
    if not isinstance(value, str):
        return True
    try:
        date.fromisoformat(value)
    except ValueError:
        return False
    return True


@_FORMAT_CHECKER.checks("date-time")
def _is_iso_datetime(value: object) -> bool:
    if not isinstance(value, str):
        return True
    normalized = value.replace("Z", "+00:00")
    try:
        datetime.fromisoformat(normalized)
    except ValueError:
        return False
    return True


@dataclass(frozen=True)
class ForeignKeySchema:
    """A single-column foreign-key reference."""

    table: str
    column: str

    def reference(self, schema_name: str | None = None) -> str:
        if schema_name:
            return f"{schema_name}.{self.table}.{self.column}"
        return f"{self.table}.{self.column}"

    def to_dict(self) -> JSONSchemaDict:
        return {"table": self.table, "column": self.column}


@dataclass(frozen=True)
class ColumnSchema:
    """A database column in the canonical DDB model."""

    name: str
    data_type: LogicalType
    description: str
    nullable: bool = True
    primary_key: bool = False
    references: ForeignKeySchema | None = None
    json_format: Literal["date", "date-time"] | None = None

    def __post_init__(self) -> None:
        if self.primary_key and self.nullable:
            object.__setattr__(self, "nullable", False)
        if self.data_type != "date" and self.json_format is not None:
            msg = f"json_format is only valid for date columns: {self.name}"
            raise ValueError(msg)

    @property
    def ddl_type(self) -> str:
        if self.data_type == "string":
            return "VARCHAR"
        if self.data_type == "double":
            return "DOUBLE PRECISION"
        if self.data_type == "boolean":
            return "BOOLEAN"
        if self.data_type == "date":
            if self.json_format == "date-time":
                return "TIMESTAMP"
            return "DATE"
        msg = f"Unsupported logical type: {self.data_type}"
        raise ValueError(msg)

    def sqlalchemy_type(self) -> TypeEngine[Any]:
        if self.data_type == "string":
            return String()
        if self.data_type == "double":
            return Float(asdecimal=False)
        if self.data_type == "boolean":
            return Boolean()
        if self.data_type == "date":
            if self.json_format == "date-time":
                return DateTime()
            return Date()
        msg = f"Unsupported logical type: {self.data_type}"
        raise ValueError(msg)

    def to_sqlalchemy_column(self, schema_name: str | None = None) -> Column[Any]:
        column_args: list[Any] = []
        if self.references is not None:
            column_args.append(ForeignKey(self.references.reference(schema_name=schema_name)))
        return Column(
            self.name,
            self.sqlalchemy_type(),
            *column_args,
            primary_key=self.primary_key,
            nullable=self.nullable,
            comment=self.description,
        )

    def json_schema(self) -> JSONSchemaDict:
        schema: JSONSchemaDict = {
            "description": self.description,
            "x-logical-type": self.data_type,
            "x-ddl-type": self.ddl_type,
        }

        if self.data_type == "string":
            schema["type"] = "string"
        elif self.data_type == "double":
            schema["type"] = "number"
        elif self.data_type == "boolean":
            schema["type"] = "boolean"
        elif self.data_type == "date":
            schema["type"] = "string"
            schema["format"] = self.json_format or "date"
        else:
            msg = f"Unsupported logical type: {self.data_type}"
            raise ValueError(msg)

        if self.references is not None:
            schema["x-foreign-key"] = self.references.to_dict()

        if self.nullable:
            return {
                "anyOf": [
                    schema,
                    {"type": "null"},
                ]
            }

        return schema

    def to_dict(self) -> JSONSchemaDict:
        payload: JSONSchemaDict = {
            "name": self.name,
            "data_type": self.data_type,
            "description": self.description,
            "nullable": self.nullable,
            "primary_key": self.primary_key,
            "ddl_type": self.ddl_type,
        }
        if self.json_format is not None:
            payload["json_format"] = self.json_format
        if self.references is not None:
            payload["references"] = self.references.to_dict()
        return payload


@dataclass(frozen=True)
class TableSchema:
    """A database table in the canonical DDB model."""

    name: str
    description: str
    columns: tuple[ColumnSchema, ...]

    @property
    def primary_key(self) -> tuple[str, ...]:
        return tuple(column.name for column in self.columns if column.primary_key)

    def to_sqlalchemy_table(self, metadata: MetaData, schema_name: str | None = None) -> Table:
        return Table(
            self.name,
            metadata,
            *(column.to_sqlalchemy_column(schema_name=schema_name) for column in self.columns),
            comment=self.description,
        )

    def row_json_schema(self) -> JSONSchemaDict:
        properties = {column.name: column.json_schema() for column in self.columns}
        required = [column.name for column in self.columns if not column.nullable]
        schema: JSONSchemaDict = {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "title": f"{self.name} row",
            "description": self.description,
            "type": "object",
            "properties": properties,
            "additionalProperties": False,
        }
        if required:
            schema["required"] = required
        return schema

    def rows_json_schema(self) -> JSONSchemaDict:
        return {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "title": f"{self.name} rows",
            "type": "array",
            "items": self.row_json_schema(),
        }

    def ddl(self) -> str:
        lines = [f"CREATE TABLE {self.name} ("]
        column_lines = []
        for column in self.columns:
            line = f"    {column.name} {column.ddl_type}"
            if not column.nullable:
                line += " NOT NULL"
            column_lines.append(line)

        if self.primary_key:
            column_lines.append(f"    PRIMARY KEY ({', '.join(self.primary_key)})")

        for column in self.columns:
            if column.references is not None:
                column_lines.append(
                    "    FOREIGN KEY "
                    f"({column.name}) REFERENCES {column.references.table} ({column.references.column})"
                )

        lines.append(",\n".join(column_lines))
        lines.append(");")
        return "\n".join(lines)

    def to_dict(self) -> JSONSchemaDict:
        return {
            "name": self.name,
            "description": self.description,
            "primary_key": list(self.primary_key),
            "columns": [column.to_dict() for column in self.columns],
        }


@dataclass(frozen=True)
class DatabaseSchema:
    """The full canonical DDB schema."""

    name: str
    description: str
    source_document: str
    tables: tuple[TableSchema, ...]

    def table(self, table_name: str) -> TableSchema:
        for table in self.tables:
            if table.name == table_name:
                return table
        msg = f"Unknown table: {table_name}"
        raise KeyError(msg)

    def to_sqlalchemy_metadata(self, schema_name: str | None = None) -> MetaData:
        metadata = MetaData(schema=schema_name, naming_convention=_NAMING_CONVENTION)
        for table in self.tables:
            table.to_sqlalchemy_table(metadata, schema_name=schema_name)
        return metadata

    def to_dict(self) -> JSONSchemaDict:
        return {
            "name": self.name,
            "description": self.description,
            "source_document": self.source_document,
            "tables": [table.to_dict() for table in self.tables],
        }

    def to_json(self, indent: int = 2) -> str:
        return json.dumps(self.to_dict(), indent=indent)

    def database_json_schema(self) -> JSONSchemaDict:
        return {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "title": self.name,
            "description": self.description,
            "type": "object",
            "properties": {
                table.name: {
                    "type": "array",
                    "items": table.row_json_schema(),
                    "description": table.description,
                }
                for table in self.tables
            },
            "additionalProperties": False,
        }

    def ddl(self) -> str:
        return "\n\n".join(table.ddl() for table in self.tables)

    def validate_table_rows(self, table_name: str, rows: list[dict[str, Any]]) -> None:
        validator = Draft202012Validator(
            self.table(table_name).rows_json_schema(),
            format_checker=_FORMAT_CHECKER,
        )
        validator.validate(rows)

    def validate_database_payload(self, payload: dict[str, Any]) -> None:
        validator = Draft202012Validator(
            self.database_json_schema(),
            format_checker=_FORMAT_CHECKER,
        )
        validator.validate(payload)


def _col(
    name: str,
    data_type: LogicalType,
    description: str,
    *,
    nullable: bool = True,
    primary_key: bool = False,
    references: tuple[str, str] | None = None,
    json_format: Literal["date", "date-time"] | None = None,
) -> ColumnSchema:
    ref = None
    if references is not None:
        ref = ForeignKeySchema(table=references[0], column=references[1])
    return ColumnSchema(
        name=name,
        data_type=data_type,
        description=description,
        nullable=nullable,
        primary_key=primary_key,
        references=ref,
        json_format=json_format,
    )


DDB_SCHEMA = DatabaseSchema(
    name="IMOS Toolbox Deployment Database",
    description="Canonical inferred deployment database schema derived from docs/SCHEMA.md.",
    source_document="docs/SCHEMA.md",
    tables=(
        TableSchema(
            name="FieldTrip",
            description="Top-level organisational entity representing a field expedition.",
            columns=(
                _col("FieldTripID", "string", "Primary key – e.g. NRSMAI-2015-06-26", primary_key=True),
                _col("DateStart", "date", "Trip start date", json_format="date"),
                _col("DateEnd", "date", "Trip end date", json_format="date"),
                _col("FieldDescription", "string", "Free-text description"),
            ),
        ),
        TableSchema(
            name="DeploymentData",
            description="One row per instrument deployment (time-series / mooring workflow).",
            columns=(
                _col("EndFieldTrip", "string", "FK → FieldTrip.FieldTripID", references=("FieldTrip", "FieldTripID")),
                _col("Site", "string", "FK → Sites.Site", references=("Sites", "Site")),
                _col("Station", "string", "Station identifier"),
                _col("InstrumentID", "string", "FK → Instruments.InstrumentID", references=("Instruments", "InstrumentID")),
                _col("InstrumentDepth", "double", "Nominal depth (m)"),
                _col("FileName", "string", "Raw data filename"),
                _col("DeploymentType", "string", "e.g. Mooring, BurstInterval"),
                _col("TimeZone", "string", "UTC offset or timezone code"),
                _col("Comment", "string", "Free-text comment"),
                _col("TimeSwitchOn", "date", "Instrument powered on", json_format="date-time"),
                _col("TimeFirstWet", "date", "Instrument first wet", json_format="date-time"),
                _col("TimeFirstInPos", "date", "First in-position time", json_format="date-time"),
                _col("TimeFirstGoodData", "date", "Start of good data window", json_format="date-time"),
                _col("TimeLastGoodData", "date", "End of good data window", json_format="date-time"),
                _col("TimeLastInPos", "date", "Last in-position time", json_format="date-time"),
                _col("TimeOnDeck", "date", "Instrument back on deck", json_format="date-time"),
                _col("TimeSwitchOff", "date", "Instrument powered off", json_format="date-time"),
                _col("StartOffset", "double", "Clock offset at start (seconds)"),
                _col("EndOffset", "double", "Clock offset at end (seconds)"),
                _col("TimeDriftInstrument", "date", "Instrument time at drift check", json_format="date-time"),
                _col("TimeDriftGPS", "date", "GPS time at drift check", json_format="date-time"),
                _col("DepthTxt", "string", "Textual depth label"),
                _col("PersonnelDownload", "string", "FK → Personnel.StaffID", references=("Personnel", "StaffID")),
            ),
        ),
        TableSchema(
            name="CTDData",
            description="One row per CTD profile cast (profile workflow).",
            columns=(
                _col("FieldTrip", "string", "FK → FieldTrip.FieldTripID", references=("FieldTrip", "FieldTripID")),
                _col("Site", "string", "FK → Sites.Site", references=("Sites", "Site")),
                _col("Station", "string", "Station identifier"),
                _col("InstrumentID", "string", "FK → Instruments.InstrumentID", references=("Instruments", "InstrumentID")),
                _col("InstrumentDepth", "double", "Nominal depth (m)"),
                _col("FileName", "string", "Raw data filename"),
                _col("TimeZone", "string", "UTC offset or timezone code"),
                _col("Comment", "string", "Free-text comment"),
                _col("DateFirstInPos", "date", "Date portion – first in position", json_format="date"),
                _col("TimeFirstInPos", "date", "Time portion – first in position", json_format="date-time"),
                _col("DateLastInPos", "date", "Date portion – last in position", json_format="date"),
                _col("TimeLastInPos", "date", "Time portion – last in position", json_format="date-time"),
                _col("Latitude", "double", "Latitude (decimal degrees)"),
                _col("Longitude", "double", "Longitude (decimal degrees)"),
            ),
        ),
        TableSchema(
            name="Sites",
            description="Deployment site registry.",
            columns=(
                _col("Site", "string", "Short site code", primary_key=True),
                _col("SiteName", "string", "Full site name"),
                _col("Description", "string", "Site description"),
                _col("Latitude", "double", "Latitude (decimal degrees)"),
                _col("Longitude", "double", "Longitude (decimal degrees)"),
                _col("ResearchActivity", "string", "Research-activity tag"),
            ),
        ),
        TableSchema(
            name="Instruments",
            description="Instrument registry.",
            columns=(
                _col("InstrumentID", "string", "Unique instrument identifier", primary_key=True),
                _col("Make", "string", "Manufacturer"),
                _col("Model", "string", "Instrument model"),
                _col("SerialNumber", "string", "Serial number"),
            ),
        ),
        TableSchema(
            name="Sensors",
            description="Sensor registry.",
            columns=(
                _col("SensorID", "string", "Unique sensor identifier", primary_key=True),
                _col("Parameter", "string", "Comma-delimited parameter list"),
                _col("SerialNumber", "string", "Sensor serial number"),
            ),
        ),
        TableSchema(
            name="InstrumentSensorConfig",
            description="Junction table linking instruments to sensors with temporal validity.",
            columns=(
                _col("InstrumentID", "string", "FK → Instruments.InstrumentID", references=("Instruments", "InstrumentID")),
                _col("SensorID", "string", "FK → Sensors.SensorID", references=("Sensors", "SensorID")),
                _col("StartConfig", "date", "Config validity start", json_format="date"),
                _col("EndConfig", "date", "Config validity end", json_format="date"),
                _col("CurrentConfig", "boolean", "Is current config flag"),
            ),
        ),
        TableSchema(
            name="Personnel",
            description="Personnel registry.",
            columns=(
                _col("StaffID", "string", "Staff identifier", primary_key=True),
                _col("Organisation", "string", "Organisation / institution"),
                _col("FirstName", "string", "First name"),
                _col("LastName", "string", "Last name"),
            ),
        ),
    ),
)

DDB_METADATA = DDB_SCHEMA.to_sqlalchemy_metadata()


def render_ddl() -> str:
    """Render the canonical DDB schema as database-agnostic DDL."""

    return DDB_SCHEMA.ddl()


def validate_table_rows(table_name: str, rows: list[dict[str, Any]]) -> None:
    """Validate table rows against the generated JSON Schema."""

    DDB_SCHEMA.validate_table_rows(table_name, rows)


def validate_database_payload(payload: dict[str, Any]) -> None:
    """Validate a table-bucketed database payload against the generated JSON Schema."""

    DDB_SCHEMA.validate_database_payload(payload)

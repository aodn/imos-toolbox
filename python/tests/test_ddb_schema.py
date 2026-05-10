"""Tests for the canonical deployment database schema."""

from __future__ import annotations

import json

import pytest
from jsonschema.exceptions import ValidationError
from sqlalchemy import Date, DateTime

from imos_toolbox.ddb import DDB_METADATA, DDB_SCHEMA, render_ddl, validate_database_payload, validate_table_rows


def test_metadata_contains_expected_tables_and_foreign_keys() -> None:
    assert set(DDB_METADATA.tables) == {
        "CTDData",
        "DeploymentData",
        "FieldTrip",
        "InstrumentSensorConfig",
        "Instruments",
        "Personnel",
        "Sensors",
        "Sites",
    }

    deployment = DDB_METADATA.tables["DeploymentData"]
    assert "EndFieldTrip" in deployment.c
    assert "PersonnelDownload" in deployment.c
    assert any(fk.target_fullname == "FieldTrip.FieldTripID" for fk in deployment.c.EndFieldTrip.foreign_keys)
    assert any(fk.target_fullname == "Personnel.StaffID" for fk in deployment.c.PersonnelDownload.foreign_keys)
    assert isinstance(deployment.c.TimeSwitchOn.type, DateTime)

    field_trip = DDB_METADATA.tables["FieldTrip"]
    assert isinstance(field_trip.c.DateStart.type, Date)
    assert field_trip.primary_key.columns.keys() == ["FieldTripID"]


def test_schema_serializes_to_json() -> None:
    document = DDB_SCHEMA.to_dict()
    encoded = DDB_SCHEMA.to_json()

    assert document["source_document"] == "docs/SCHEMA.md"
    assert len(document["tables"]) == 8
    assert json.loads(encoded)["name"] == "IMOS Toolbox Deployment Database"


def test_render_ddl_contains_expected_constraints() -> None:
    ddl = render_ddl()

    assert "CREATE TABLE FieldTrip" in ddl
    assert "PRIMARY KEY (FieldTripID)" in ddl
    assert "CREATE TABLE DeploymentData" in ddl
    assert "FOREIGN KEY (EndFieldTrip) REFERENCES FieldTrip (FieldTripID)" in ddl
    assert "FOREIGN KEY (PersonnelDownload) REFERENCES Personnel (StaffID)" in ddl


def test_table_row_validation_enforces_primary_key_and_formats() -> None:
    validate_table_rows(
        "FieldTrip",
        [
            {
                "FieldTripID": "NRSMAI-2015-06-26",
                "DateStart": "2015-06-26",
                "DateEnd": "2015-07-03",
                "FieldDescription": "Example voyage",
            }
        ],
    )

    with pytest.raises(ValidationError):
        validate_table_rows(
            "FieldTrip",
            [
                {
                    "DateStart": "2015-06-26",
                    "DateEnd": "2015-07-03",
                }
            ],
        )

    with pytest.raises(ValidationError):
        validate_table_rows(
            "DeploymentData",
            [
                {
                    "TimeSwitchOn": "not-a-timestamp",
                }
            ],
        )


def test_database_payload_validation_uses_bucketed_table_arrays() -> None:
    validate_database_payload(
        {
            "FieldTrip": [
                {
                    "FieldTripID": "NRSMAI-2015-06-26",
                }
            ],
            "Sites": [
                {
                    "Site": "NRSMAI",
                }
            ],
        }
    )

    with pytest.raises(ValidationError):
        validate_database_payload(
            {
                "FieldTrip": [{"FieldTripID": "NRSMAI-2015-06-26"}],
                "Unexpected": [],
            }
        )

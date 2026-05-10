"""Parser registry and instrument mapping support."""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Type

from imos_toolbox.parsers.base import BaseParser


def _norm(value: str) -> str:
    return " ".join(value.strip().upper().split())


def load_instrument_parser_map(path: str | Path) -> Dict[tuple[str, str], str]:
    mapping: Dict[tuple[str, str], str] = {}
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    data_lines = [line for line in lines if line.strip() and not line.strip().startswith("%")]
    reader = csv.reader(data_lines, skipinitialspace=True)
    for row in reader:
        if len(row) < 3:
            continue
        make = _norm(row[0])
        model = _norm(row[1])
        parser_name = row[2].strip()
        mapping[(make, model)] = parser_name
    return mapping


@dataclass
class ParserRegistry:
    """Runtime registry for parser classes and make/model mappings."""

    parser_classes: Dict[str, Type[BaseParser]]
    instrument_mapping: Dict[tuple[str, str], str]

    def __init__(self) -> None:
        self.parser_classes = {}
        self.instrument_mapping = {}

    def register(self, name: str, parser_class: Type[BaseParser]) -> None:
        self.parser_classes[name.strip()] = parser_class

    def register_many(self, parser_classes: Iterable[Type[BaseParser]]) -> None:
        for parser_class in parser_classes:
            self.register(getattr(parser_class, "parser_name", parser_class.__name__), parser_class)

    def load_instruments(self, path: str | Path) -> None:
        self.instrument_mapping = load_instrument_parser_map(path)

    def parser_name_for(self, make: str, model: str) -> str | None:
        return self.instrument_mapping.get((_norm(make), _norm(model)))

    def parser_for(self, make: str, model: str) -> BaseParser:
        parser_name = self.parser_name_for(make, model)
        if parser_name is None:
            raise KeyError(f"No parser mapping found for make={make!r}, model={model!r}")
        parser_class = self.parser_classes.get(parser_name)
        if parser_class is None:
            raise KeyError(f"Parser {parser_name!r} is not registered")
        return parser_class()

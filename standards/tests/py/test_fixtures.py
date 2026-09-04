"""Round-trips every fixture in standards/fixtures/ through its generated
Pydantic model. Mirrors home/spec's proof: these schemas are consumed
cross-repo (home/spec imports error-entry and privacy-row), so both
generated model sets have to actually work.
"""

import json
from pathlib import Path

import pytest
from pydantic import ValidationError

from gen.py.budget_schema import Budget
from gen.py.error_entry_schema import ErrorEntry
from gen.py.logging_line_schema import LoggingLine
from gen.py.privacy_row_schema import PrivacyRow
from gen.py.trace_span_schema import TraceSpan

FIXTURES_DIR = Path(__file__).resolve().parents[2] / "fixtures"


def load_fixture(name: str) -> dict:
    return json.loads((FIXTURES_DIR / name).read_text())


def test_error_entry_fixture():
    ErrorEntry.model_validate(load_fixture("error-entry.example.json"))


def test_logging_line_fixture():
    LoggingLine.model_validate(load_fixture("logging-line.example.json"))


def test_trace_span_fixture():
    TraceSpan.model_validate(load_fixture("trace-span.example.json"))


def test_budget_fixture():
    Budget.model_validate(load_fixture("budget.example.json"))


def test_privacy_row_fixture():
    PrivacyRow.model_validate(load_fixture("privacy-row.example.json"))


def test_privacy_row_missing_who_is_rejected():
    bad = load_fixture("privacy-row.example.json")
    del bad["who"]
    with pytest.raises(ValidationError):
        PrivacyRow.model_validate(bad)

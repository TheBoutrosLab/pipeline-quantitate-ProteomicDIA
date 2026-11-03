#!/usr/bin/env python3
"""Add and validate DIA-NN fragment annotations in an EasyPQP TSV library."""

import argparse
import csv
import re
from pathlib import Path


# EasyPQP's b/y annotations use the fragment ordinal and explicit charge.
# Common neutral losses can follow the charge, e.g. y9^2-H2O.
ANNOTATION = re.compile(r"([abcxyz])([1-9][0-9]*)\^([1-9][0-9]*)(?:-(H2O|NH3|CO|H3PO4))?")


def prepare_library(source: Path, destination: Path) -> int:
    """Write a validated DIA-NN TSV and return the number of fragment rows."""
    if source.resolve() == destination.resolve():
        raise ValueError("The DIA-NN library destination must differ from the source library")

    with source.open("r", encoding="utf-8", newline="") as input_handle:
        reader = csv.DictReader(input_handle, delimiter="\t")
        fields = reader.fieldnames
        if not fields or len(fields) != len(set(fields)) or "Annotation" not in fields:
            raise ValueError("EasyPQP library needs unique columns including Annotation")
        annotations = ("FragmentType", "FragmentSeriesNumber", "FragmentCharge", "FragmentLossType")
        output_fields = [*fields, *(name for name in annotations if name not in fields)]
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = destination.with_name(destination.name + ".tmp")
        count = 0
        try:
            with temporary.open("w", encoding="utf-8", newline="") as output_handle:
                writer = csv.DictWriter(
                    output_handle, fieldnames=output_fields, delimiter="\t", lineterminator="\n"
                )
                writer.writeheader()
                for row in reader:
                    if None in row or any(value is None for value in row.values()):
                        raise ValueError(f"Malformed TSV row at line {reader.line_num}")
                    annotation = row["Annotation"].strip()
                    match = ANNOTATION.fullmatch(annotation)
                    if not match:
                        raise ValueError(
                            f"Cannot determine fragment type, series number, and charge from Annotation {annotation!r} "
                            f"at line {reader.line_num}"
                        )
                    expected = {
                        "FragmentType": match.group(1),
                        "FragmentSeriesNumber": match.group(2),
                        "FragmentCharge": match.group(3),
                        "FragmentLossType": match.group(4) or "noloss",
                    }
                    for name, value in expected.items():
                        if name in fields and row[name].strip() != value:
                            raise ValueError(
                                f"{name} {row[name]!r} disagrees with "
                                f"Annotation {annotation!r} at line {reader.line_num}"
                            )
                        row[name] = value
                    writer.writerow(row)
                    count += 1
            if count == 0:
                raise ValueError("EasyPQP library has no fragment rows")
            temporary.replace(destination)
        finally:
            temporary.unlink(missing_ok=True)
    return count


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    count = prepare_library(args.input, args.output)
    print(f"Validated fragment annotations for {count} EasyPQP library rows")


if __name__ == "__main__":
    main()

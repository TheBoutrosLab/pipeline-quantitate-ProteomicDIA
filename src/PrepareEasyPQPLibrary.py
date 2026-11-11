#!/usr/bin/env python3
"""Add and validate DIA-NN fragment annotations in an EasyPQP TSV library."""

import argparse
import csv
import re
from pathlib import Path


# EasyPQP's b/y annotations use the fragment ordinal and explicit charge.
# Common neutral losses can follow the charge, e.g. y9^2-H2O.
ANNOTATION = re.compile(r"([abcxyz])([1-9][0-9]*)\^([1-9][0-9]*)(?:-(H2O|NH3|CO|H3PO4))?")


def prepare_library(source: Path, destination: Path, fraction_id: str | None = None) -> int:
    """Write a validated DIA-NN TSV and return the number of fragment rows."""
    if source.resolve() == destination.resolve():
        raise ValueError("The DIA-NN library destination must differ from the source library")

    with source.open("r", encoding="utf-8", newline="") as input_handle:
        reader = csv.DictReader(input_handle, delimiter="\t")
        fields = reader.fieldnames
        if not fields or len(fields) != len(set(fields)) or "Annotation" not in fields:
            raise ValueError("EasyPQP library needs unique columns including Annotation")
        has_fraction = "fraction_id" in fields
        if fraction_id and not has_fraction:
            raise ValueError("Fractionated input requires a fraction_id library column")
        if has_fraction and not fraction_id:
            raise ValueError("Annotated library requires a matching fraction_id")
        annotations = ("FragmentType", "FragmentSeriesNumber", "FragmentCharge", "FragmentLossType")
        output_fields = [*(name for name in fields if name != "fraction_id"),
                         *(name for name in annotations if name not in fields)]
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
                    if has_fraction:
                        if row["fraction_id"].strip() != fraction_id:
                            continue
                        del row["fraction_id"]
                    annotation = row["Annotation"].strip()
                    match = ANNOTATION.fullmatch(annotation)
                    if not match:
                        raise ValueError(
                            "Cannot determine fragment type, series number, and charge from "
                            f"Annotation {annotation!r} at line {reader.line_num}"
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
    """Parse command-line arguments and prepare the EasyPQP library."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--fraction-id")
    args = parser.parse_args()
    count = prepare_library(args.input, args.output, args.fraction_id)
    print(f"Validated fragment annotations for {count} EasyPQP library rows")


if __name__ == "__main__":
    main()

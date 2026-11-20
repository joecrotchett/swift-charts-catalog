#!/usr/bin/env python3
"""Extract the code regions that "See Code" shows.

Usage: extract_snippets.py <sources directory> <output json>

In any Swift file under the sources directory, the lines between

    // snippet:<name>
    ...
    // end

are one snippet. The shared indentation is removed and the result is written as JSON:
{"<name>": {"code": "...", "file": "<path relative to the sources directory>"}}.

The build fails (exit 1) on a region that is not closed, an `// end` with no open region, a
region inside another, an empty region, a malformed marker, or a name used twice.
"""

import json
import pathlib
import re
import sys
import textwrap

START = re.compile(r"^\s*// snippet:([A-Za-z0-9][A-Za-z0-9-]*)\s*$")
LOOSE_START = re.compile(r"^\s*//\s*snippet\b")
END = re.compile(r"^\s*// end\s*$")


class SnippetError(Exception):
    pass


def extract_from_text(text, file_name):
    """Return {name: code} for one file's text."""
    snippets = {}
    name = None
    start_line = 0
    lines = []
    for number, line in enumerate(text.splitlines(), start=1):
        start = START.match(line)
        if start:
            if name is not None:
                raise SnippetError(f"{file_name}:{number}: snippet '{start.group(1)}' opened inside '{name}'")
            name, start_line, lines = start.group(1), number, []
            if name in snippets:
                raise SnippetError(f"{file_name}:{number}: snippet '{name}' defined twice in this file")
        elif LOOSE_START.match(line):
            raise SnippetError(f"{file_name}:{number}: malformed snippet marker: {line.strip()}")
        elif END.match(line):
            if name is None:
                raise SnippetError(f"{file_name}:{number}: '// end' with no open snippet")
            code = textwrap.dedent("\n".join(lines)).strip("\n")
            if not code.strip():
                raise SnippetError(f"{file_name}:{start_line}: snippet '{name}' is empty")
            snippets[name] = code
            name = None
        elif name is not None:
            lines.append(line.rstrip())
    if name is not None:
        raise SnippetError(f"{file_name}:{start_line}: snippet '{name}' is never closed with '// end'")
    return snippets


def extract_from_directory(sources):
    """Return {name: {"code": ..., "file": ...}} for every Swift file under `sources`."""
    sources = pathlib.Path(sources)
    result = {}
    for path in sorted(sources.rglob("*.swift")):
        relative = str(path.relative_to(sources))
        for name, code in extract_from_text(path.read_text(encoding="utf-8"), relative).items():
            if name in result:
                raise SnippetError(f"{relative}: snippet '{name}' is also defined in {result[name]['file']}")
            result[name] = {"code": code, "file": relative}
    return result


def main(arguments):
    if len(arguments) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        snippets = extract_from_directory(arguments[1])
    except SnippetError as error:
        # Xcode shows lines in this form as build errors.
        print(f"error: {error}", file=sys.stderr)
        return 1
    output = pathlib.Path(arguments[2])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(snippets, indent=2, sort_keys=True, ensure_ascii=False), encoding="utf-8")
    print(f"{len(snippets)} snippets written to {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

#!/usr/bin/env python3
from pathlib import Path






def main(path: Path):
    """
    Generate plots and tables for all log files in given path.
    """
    print(path)




# maybe todo choose plots/tables to generate?

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('folders', metavar='FOLDER', type=Path, nargs='*', help="List of directories to run the "
                                                                                "plotting for.")
    args = parser.parse_args()
    folders = args.folders

    if len(folders) == 0:
        # no arg given - do for all todo let choose and not just all
        for path in Path("analysis/input").iterdir():
            if path.is_dir():
                folders.append(path)
    else:
        for path in folders:
            if not path.is_dir():
                raise NotADirectoryError(path)

    for path in folders:
        main(path)

#!/usr/bin/env python3
from pathlib import Path

import lib.filter as filter
import seaborn as sb
from lib.stats import Vmstat, Mpstat, CpuIO, DiskIO, DockerStats


def main(path: Path):
    """
    Generate plots and tables for all log files in given path.
    """
    sb.set()
    sb.set_style("whitegrid")
    sb.set_context("talk")

    vmstat = Vmstat(path)
    vmstat.cpu_utilization(filter.instances).cpu_utilization(filter.client, "client")
    #vmstat.io(filter.instances).io(filter.client, "client")
    #vmstat.interrupts(filter.instances).interrupts(filter.client, "client")

    cio = CpuIO(path)
    dio = DiskIO(path)
    mpstat = Mpstat(path)
    docker = DockerStats(path)

    for scenario in vmstat.scenarios:
        vmstat.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")
        cio.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")
        dio.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")
        mpstat.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")
        docker.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")


def folder_selection() -> [Path]:
    print("Available folders to analyze:")
    i = 0
    choices = []
    folders = []
    for path in Path("input").iterdir():
        if path.is_dir():
            choices.append(path)
            print(f'[{i}]\t{path}')
            i += 1
    choice = input("Choose one or more of the above by index seperated by spaces: ")
    for index in [int(strindex) for strindex in choice.split(" ")]:
        print("choice: ", index)
        folders.append(choices[index])
    return folders


if __name__ == "__main__":
    # maybe todo choose plots/tables to generate?
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('folders', metavar='FOLDER', type=Path, nargs='*', help="List of directories to run the "
                                                                                "plotting for.")
    args = parser.parse_args()
    folders = args.folders

    if len(folders) == 0:
        folders = folder_selection()
    else:
        for path in folders:
            if not path.is_dir():
                raise NotADirectoryError(path)

    for path in folders:
        main(path)

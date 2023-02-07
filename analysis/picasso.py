#!/usr/bin/env python3
import os
from pathlib import Path

import lib.filter as filter
import seaborn as sb
from lib.stats import Vmstat, Mpstat, CpuIO, DiskIO, DockerStats, Ping


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
    docker = DockerStats(path).memory()
    ping = Ping(path).lineplot()

    for scenario in vmstat.scenarios:
        vmstat.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")
        cio.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")
        dio.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")
        mpstat.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")
        docker.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario) \
            .quick_stats(filter.client, f"{scenario}_client") \
            .lineplot("cpu_pct", filter.scenario(scenario), scenario) \
            .lineplot("mem_pct", filter.scenario(scenario), scenario) \
            .lineplot("net_input", filter.scenario(scenario), scenario, True) \
            .lineplot("net_output", filter.scenario(scenario), scenario, True) \
            .lineplot("block_input", filter.scenario(scenario), scenario, True) \
            .lineplot("block_output", filter.scenario(scenario), scenario, True)


def folder_selection() -> [Path]:
    print("Available folders to analyze:")
    i = 0
    choices = sorted([str(path.path) for path in os.scandir("input") if path.is_dir()], reverse=True)
    folders = []

    for path in choices:
        print(f'[{i}]\t{path}')
        i += 1
    choice = input("Choose one or more of the above by index seperated by spaces: (default: 0)")
    if len(choice) == 0:
        return [Path(choices[0])]
    for index in [int(strindex) for strindex in choice.split(" ")]:
        print("choice: ", index)
        folders.append(Path(choices[index]))
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

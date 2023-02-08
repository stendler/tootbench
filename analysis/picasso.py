#!/usr/bin/env python3
import os
from pathlib import Path

import lib.filter as filter
import lib.window as window
import seaborn as sb
from lib.stats import Vmstat, Mpstat, CpuIO, DiskIO, DockerStats, Ping, Tootbench


def main(path: Path):
    """
    Generate plots and tables for all log files in given path.
    """
    sb.set()
    sb.set_style("whitegrid")
    sb.set_context("talk")

    vmstat = Vmstat(path)
    vmstat.cpu_sum(window.tumble(["scenario", "run"]))
    #vmstat.cpu_utilization(filter.instances).cpu_utilization(filter.client, "client")
    vmstat.cpu_utilization(filter.of(filter.instances, window.tumble()), "windowed")\
        .cpu_utilization(filter.of(filter.client, window.tumble()), "windowed_client")
    #vmstat.io(filter.of(filter.instances, window-tumble()).io(filter.of(filter.client, window.tumble()), "client")
    #vmstat.interrupts(filter.of(filter.instances, window.tumble()).interrupts(filter.of(filter.client, window.tumble()), "client")

    cio = CpuIO(path)
    dio = DiskIO(path)
    mpstat = Mpstat(path)
    docker = DockerStats(path).memory(window.tumble()).mem_sum(window.tumble())
    ping = Ping(path).lineplot(window.tumble(["scenario", "run", "host", "target", "ip"], func=window.max))
    client_data_window = window.tumble(["scenario", "run", "message_type", "same_host"], time_column="time_delta", unit="m")
    toot = Tootbench(path)\
        .post_tx(client_data_window)\
        .post_rx(client_data_window)\
        .post_txack(client_data_window)
#        .post_e2e_latency(window.tumble(["scenario", "run", "message_type", "same_host", "sender_domain", "sender_username", "sender_username"], time_column="time_delta", unit="m"))

    for scenario in vmstat.scenarios:
        print(f"Total messages Sent in {scenario}: ", filter.of(filter.column("message_type", "post"), filter.scenario(scenario))(toot.df).groupby(by="run").count())
        print(f"Total messages Received in {scenario}: ", filter.of(filter.column("message_type", "status"), filter.scenario(scenario))(toot.df).groupby(by="run").count())
        vmstat.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")
        cio.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")
        dio.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")
        mpstat.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario)\
            .quick_stats(filter.client, f"{scenario}_client")
 #       docker.quick_stats(filter.of(filter.instances, filter.scenario(scenario)), scenario) \
 #           .quick_stats(filter.client, f"{scenario}_client") \
 #           .lineplot("cpu_pct", filter.scenario(scenario), scenario) \
 #           .lineplot("mem_pct", filter.scenario(scenario), scenario) \
 #           .lineplot("net_input", filter.scenario(scenario), scenario, True) \
 #           .lineplot("net_output", filter.scenario(scenario), scenario, True) \
 #           .lineplot("block_input", filter.scenario(scenario), scenario, True) \
 #           .lineplot("block_output", filter.scenario(scenario), scenario, True)


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

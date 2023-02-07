from abc import ABC, abstractmethod
from pathlib import Path
from typing import Callable

import lib.filter as filter
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sb


class Stats(ABC):

    @abstractmethod
    def __init__(self, stat: str, path: Path, save: bool = True, timestamp: str = "timestamp"):
        print("initializing", stat)
        self.stat = stat
        self.path = path
        self.save = save
        self.save_path = Path(str(self.path).replace("input", "output"))
        self.df = pd.read_csv(path.joinpath(stat + ".log.gz")).sort_values(by=timestamp)
        self.scenarios = self.df["scenario"].unique()
        self.runs = self.df["run"].unique()

        if timestamp == "timestamp":  # tootbench logs differ here
            self.t_lowest = self.df[["scenario", "run", timestamp]].groupby(by=["scenario", "run"]).min()
            # normalize timestamps by lowest one
            for i, group in self.df.groupby(by=["scenario", "run"]):
                self.df.loc[group.index, 'time'] = group[timestamp] - self.t_lowest[timestamp][i]
        print("initialized.", stat)

    def _save_plot(self, filename: str, close: bool = True):
        plt.tight_layout(pad=0.5)
        if not self.save:
            plt.show(block=False)
        else:
            Path(self.save_path, "pdf").mkdir(parents=True, exist_ok=True)
            Path(self.save_path, "svg").mkdir(parents=True, exist_ok=True)
            Path(self.save_path, "png").mkdir(parents=True, exist_ok=True)
            plt.savefig(Path(self.save_path, "pdf", filename + ".pdf"))
            plt.savefig(Path(self.save_path, "svg", filename + ".svg"))
            plt.savefig(Path(self.save_path, "png", filename + ".png"))
        if close:
            plt.close("all")

    def _save_table(self, df: pd.DataFrame, filename: str, close: bool = True):
        Path(self.save_path, "csv").mkdir(parents=True, exist_ok=True)
        Path(self.save_path, "table").mkdir(parents=True, exist_ok=True)
        df.to_csv(Path(self.save_path, "csv", filename + ".csv"))

        fig, ax = plt.subplots(figsize=(19, 5))
        plt.tight_layout(pad=0.5)
        # fig.set_frameon(False)
        plt.tight_layout()
        ax.xaxis.set_visible(False)
        ax.yaxis.set_visible(False)
        pd.plotting.table(ax, df, loc='center')
        plt.savefig(Path(self.save_path, "table", filename + ".png"))
        if close:
            plt.close(fig)


class Vmstat(Stats):

    def __init__(self, path: Path, save: bool = True):
        super().__init__("vmstat", path, save)
        self.df["cpu"] = 100 - self.df["idle"]
        self.df["user+kernel"] = self.df["user_time"] + self.df["kernel_time"]

    def cpu_utilization(self, filter: Callable[[pd.DataFrame], pd.DataFrame], name: str = "mastodon") -> "Vmstat":
        # vmstat cpu util
        df = filter(self.df)
        fig, ax = plt.subplots(figsize=(20, 10), dpi=100)
        ax.set_xlabel("Time in seconds")
        ax.set_ylabel("CPU utilisation percentage")
        sb.lineplot(x="time", y="cpu", hue="scenario", data=df, ax=ax)
        self._save_plot("vmstat-cpu-utilization_" + name, close=True)
        fig, ax = plt.subplots(figsize=(20, 10), dpi=100)
        ax.set_xlabel("Time in seconds")
        ax.set_ylabel("CPU user & system utilisation percentage")
        sb.lineplot(x="time", y="user_time", hue="scenario", data=df, ax=ax, linestyle="dashed", legend=True)
        # self._save_plot("vmstat-user-utilization_" + name, close=True)
        sb.lineplot(x="time", y="user+kernel", hue="scenario", data=df, ax=ax, linestyle="dotted", legend=False)
        self._save_plot("vmstat-kernel-utilization_" + name)
        return self

    def io(self, filter: Callable[[pd.DataFrame], pd.DataFrame], name: str = "mastodon") -> "Vmstat":
        # vmstat io
        df = filter(self.df)
        fig, (ax0, ax1) = plt.subplots(2, figsize=(20, 10), dpi=100, sharex='all')
        sb.lineplot(x="time", y="blocks_received", hue="scenario", data=df, ax=ax0)
        ax0.set_xlabel("Time in seconds")
        ax0.set_ylabel("Blocks per second received from block device")
        sb.lineplot(x="time", y="blocks_sent", hue="scenario", data=df, ax=ax1)
        ax1.set_xlabel("Time in seconds")
        ax1.set_ylabel("Blocks per second sent to block device")
        self._save_plot("vmstat-io_" + name)
        return self

    def interrupts(self, filter: Callable[[pd.DataFrame], pd.DataFrame], name: str = "mastodon") -> "Vmstat":
        # vmstat interrupts
        df = filter(self.df)
        fig, (ax0, ax1) = plt.subplots(2, figsize=(20, 10), dpi=100, sharex='all')
        sb.lineplot(x="time", y="interrupts", hue="scenario", data=df, ax=ax0)
        ax0.set_xlabel("Time in seconds")
        ax0.set_ylabel("Interrupts per second")
        sb.lineplot(x="time", y="context_switches", hue="scenario", data=df, ax=ax1)
        ax1.set_xlabel("Time in seconds")
        ax1.set_ylabel("Context switches per second")
        self._save_plot("vmstat-interrupts_" + name)
        return self

    def quick_stats(self, filter: Callable[[pd.DataFrame], pd.DataFrame], name: str = "mastodon") -> "Vmstat":
        df = filter(self.df)
        df_qvmstat = df[df.columns[4:]]
        vsstats_quickstats = pd.DataFrame(data={"max": df_qvmstat.max()})
        vsstats_quickstats["mean"] = df_qvmstat.mean(numeric_only=True)
        vsstats_quickstats["median"] = df_qvmstat.median(numeric_only=True)
        vsstats_quickstats["sum"] = df_qvmstat.sum(numeric_only=True)
        self._save_table(vsstats_quickstats, "quickstats_vmstat_" + name)
        return self


class DiskIO(Stats):

    def __init__(self, path: Path):
        super().__init__("iostat-disk", path)

    def quick_stats(self, filter: Callable[[pd.DataFrame], pd.DataFrame], name: str = "mastodon") -> "DiskIO":
        df = filter(self.df)
        df_qdiskio = df[df.columns[5:]]
        diskio_quickstats = pd.DataFrame(data={"max": df_qdiskio.max()})
        diskio_quickstats["mean"] = df_qdiskio.mean(numeric_only=True)
        diskio_quickstats["median"] = df_qdiskio.median(numeric_only=True)
        diskio_quickstats["sum"] = df_qdiskio.sum(numeric_only=True)
        self._save_table(diskio_quickstats, "quickstats_diskio_" + name)
        return self


class CpuIO(Stats):

    def __init__(self, path: Path):
        super().__init__("iostat-cpu", path)

    def quick_stats(self, filter: Callable[[pd.DataFrame], pd.DataFrame], name: str = "mastodon") -> "CpuIO":
        df = filter(self.df)
        df_qcpuio = df[df.columns[4:]]
        cpuio_quickstats = pd.DataFrame(data={"max": df_qcpuio.max()})
        cpuio_quickstats["min"] = df_qcpuio.min(numeric_only=True)
        cpuio_quickstats["mean"] = df_qcpuio.mean(numeric_only=True)
        cpuio_quickstats["median"] = df_qcpuio.median(numeric_only=True)
        cpuio_quickstats["sum"] = df_qcpuio.sum(numeric_only=True)
        self._save_table(cpuio_quickstats, "quickstats_cpuio_" + name)
        return self


class Mpstat(Stats):
    def __init__(self, path: Path):
        super().__init__("mpstat", path)

    def quick_stats(self, filter: Callable[[pd.DataFrame], pd.DataFrame], name: str = "mastodon") -> "Mpstat":
        df = filter(self.df)
        df_qmpstat = df[df.columns[4:]]
        mpstat_quickstats = pd.DataFrame(data={"max": df_qmpstat.max()})
        mpstat_quickstats["mean"] = df_qmpstat.mean(numeric_only=True)
        mpstat_quickstats["median"] = df_qmpstat.median(numeric_only=True)
        mpstat_quickstats["sum"] = df_qmpstat.sum(numeric_only=True)
        self._save_table(mpstat_quickstats, "quickstats_mpstat_" + name)
        return self


def clean_docker_stats_units(x: str) -> np.float64:
    """
    Remove the unit suffix of the given string value and normalize the value to KB.
    """
    if x.endswith("kB"):
        return np.float64(x.removesuffix("kB"))
    if x.endswith("KiB"):
        return np.float64(x.removesuffix("KiB"))
    if x.endswith("MB"):
        return np.divide(np.float64(x.removesuffix("MB")), 1000)
    if x.endswith("MiB"):
        return np.divide(np.float64(x.removesuffix("MiB")), 1024)
    if x.endswith("GB"):
        return np.divide(np.float64(x.removesuffix("GB")), 1_000_000)
    if x.endswith("GiB"):
        return np.divide(np.float64(x.removesuffix("GiB")), 1024 * 1024)
    if x.endswith("B"):
        return np.multiply(np.float64(x.removesuffix("B")), 1000)


class DockerStats(Stats):

    def __init__(self, path: Path):
        super().__init__("docker-stats", path)
        self.df["net_input"] = self.df["net_input"].map(clean_docker_stats_units)
        self.df["net_output"] = self.df["net_output"].map(clean_docker_stats_units)
        self.df["block_input"] = self.df["block_input"].map(clean_docker_stats_units)
        self.df["block_output"] = self.df["block_output"].map(clean_docker_stats_units)
        self.df["mem_usage"] = self.df["mem_usage"].map(clean_docker_stats_units)
        self.df["mem_limit"] = self.df["mem_limit"].map(clean_docker_stats_units)
        self.df["container_name"] = self.df["name"].map(lambda s: s[:-2])  # strip replica number from name
        self.df_container = self.df[
            ["scenario", "run", "timestamp", "time", "host", "cpu_pct", "mem_pct", "net_input",
             "net_output", "block_input", "block_output", "container_name"]] \
            .groupby(by=["scenario", "run", "timestamp", "time", "host", "container_name"], as_index=False).mean()

    def lineplot(self, column: str, filter_fun: Callable[[pd.DataFrame], pd.DataFrame] = filter.none,
                 name: str = "mastodon", log: bool = False) -> "DockerStats":
        df = filter_fun(self.df_container)
        fig, ax = plt.subplots(figsize=(20, 10), dpi=100)
        ax.set_xlabel("Time in seconds")
        ax.set_ylabel(column)
        if log:
            ax.set_yscale("log", base=10)
        sb.lineplot(x="time", y=column, hue="container_name", data=df, ax=ax)
        self._save_plot(f"docker_{column}_{name}", close=True)
        return self

    def memory(self, filter_fun: Callable[[pd.DataFrame], pd.DataFrame] = filter.none,
               name: str = "mastodon",):
        df = filter_fun(self.df).groupby(by=["scenario", "run", "timestamp", "time", "host"], as_index=False).sum()
        fig, ax = plt.subplots(figsize=(20, 10), dpi=100)
        ax.set_xlabel("Time in seconds")
        ax.set_ylabel("Memory utilization of all containers")
        sb.lineplot(x="time", y="mem_pct", hue="scenario", style="host", data=df, ax=ax)
        self._save_plot(f"docker_mem_all_{name}", close=True)
        return self


    def quick_stats(self, filter_fun: Callable[[pd.DataFrame], pd.DataFrame] = filter.none,
                    name: str = "mastodon") -> "DockerStats":
        df = filter_fun(self.df)
        containers = sorted(df["name"].map(lambda s: s[:-2]).unique())
        for container in containers:
            df_qdocker = filter.column("name", container)(df)[df.columns[4:]]
            docker_quickstats = pd.DataFrame(data={"max": df_qdocker.max()})
            docker_quickstats["min"] = df_qdocker.min(numeric_only=True)
            docker_quickstats["mean"] = df_qdocker.mean(numeric_only=True)
            docker_quickstats["median"] = df_qdocker.median(numeric_only=True)
            docker_quickstats["sum"] = df_qdocker.sum(numeric_only=True)
            self._save_table(docker_quickstats, f"quickstats_docker_{container}_{name}")
        return self



class Ping(Stats):

    def __init__(self, path: Path):
        super().__init__("ping", path)

    def lineplot(self, filter_fun: Callable[[pd.DataFrame], pd.DataFrame] = filter.none,
                 name: str = "mastodon", log: bool = False) -> "Ping":
        df = filter_fun(self.df)
        fig, ax = plt.subplots(figsize=(20, 10), dpi=100)
        ax.set_xlabel("Time in seconds")
        ax.set_ylabel("Ping latency in ms")
        if log:
            ax.set_yscale("log", base=10)
        sb.lineplot(x="time", y="time", hue="host", style="target", data=df, ax=ax)
        self._save_plot(f"ping_{name}", close=True)
        return self


class Tootbench(Stats):

    def __init__(self, path: Path):
        super().__init__("tootbench", path, timestamp="timestamp_iso")

from pathlib import Path
import pandas as pd
import seaborn as sb
import matplotlib.pyplot as plt
from abc import ABC, abstractmethod
import numpy as np


class Stats(ABC):

    @abstractmethod
    def __init__(self, stat: str, path: Path):
        print("initializing", stat)
        self.stat = stat
        self.path = path
        self.save_path = Path(str(self.path).replace("input", "output"))
        self.df = pd.read_csv(path.joinpath(stat + ".log.gz")).sort_values(by="timestamp")

        self.t_lowest = self.df[["scenario", "run", "timestamp"]].groupby(by=["scenario", "run"]).min()
        # normalize timestamps by lowest one
        for i, group in self.df.groupby(by=["scenario", "run"]):
            self.df.loc[group.index, 'time'] = group['timestamp'] - self.t_lowest['timestamp'][i]
        # override this
        print("initialized.", stat)

    def _save_plot(self, filename: str):
        plt.tight_layout(pad=0.5)
        Path(self.save_path, "pdf").mkdir(parents=True, exist_ok=True)
        Path(self.save_path, "svg").mkdir(parents=True, exist_ok=True)
        Path(self.save_path, "png").mkdir(parents=True, exist_ok=True)
        plt.savefig(Path(self.save_path, "pdf", filename + ".pdf"))
        plt.savefig(Path(self.save_path, "svg", filename + ".svg"))
        plt.savefig(Path(self.save_path, "png", filename + ".png"))
        plt.close("all")

    def _save_table(self, df: pd.DataFrame, filename: str):
        Path(self.save_path, "csv").mkdir(parents=True, exist_ok=True)
        Path(self.save_path, "table").mkdir(parents=True, exist_ok=True)
        df.to_csv(Path(self.save_path, "csv", filename + ".csv"))

        fig, ax = plt.subplots(figsize=(19, 5))
        plt.tight_layout(pad=0.5)
        #fig.set_frameon(False)
        plt.tight_layout()
        ax.xaxis.set_visible(False)
        ax.yaxis.set_visible(False)
        pd.plotting.table(ax, df, loc='center')
        plt.savefig(Path(self.save_path, "table", filename + ".png"))


class Vmstat(Stats):

    def __init__(self, path: Path):
        super().__init__("vmstat", path)
        self.df["cpu"] = 100 - self.df["idle"]

    def cpu_utilization(self) -> "Vmstat":
        # vmstat cpu util
        df = self.df[self.df["host"] != "client"]
        fig, ax = plt.subplots(figsize=(20, 10), dpi=100)
        sb.lineplot(x="time", y="cpu", hue="scenario", data=df, ax=ax, legend=False)
        sb.lineplot(x="time", y="user_time", hue="scenario", data=df, ax=ax, linestyle="dashed", legend=False)
        sb.lineplot(x="time", y="kernel_time", hue="scenario", data=df, ax=ax, linestyle="dotted")

        ax.set_xlabel("Time in seconds")
        ax.set_ylabel("CPU utilisation percentage")
        self._save_plot("vmstat-cpu-utilization")
        return self

    def io(self) -> "Vmstat":
        # vmstat io
        df = self.df[self.df["host"] != "client"]
        fig, (ax0, ax1) = plt.subplots(2, figsize=(20, 10), dpi=100, sharex='all')
        sb.lineplot(x="time", y="blocks_received", hue="scenario", data=df, ax=ax0)
        ax0.set_xlabel("Time in seconds")
        ax0.set_ylabel("Blocks per second received from block device")
        sb.lineplot(x="time", y="blocks_sent", hue="scenario", data=df, ax=ax1)
        ax1.set_xlabel("Time in seconds")
        ax1.set_ylabel("Blocks per second sent to block device")
        self._save_plot("vmstat-io")
        return self

    def interrupts(self) -> "Vmstat":
        # vmstat interrupts
        df = self.df[self.df["host"] != "client"]
        fig, (ax0, ax1) = plt.subplots(2, figsize=(20, 10), dpi=100, sharex='all')
        sb.lineplot(x="time", y="interrupts", hue="scenario", data=df, ax=ax0)
        ax0.set_xlabel("Time in seconds")
        ax0.set_ylabel("Interrupts per second")
        sb.lineplot(x="time", y="context_switches", hue="scenario", data=df, ax=ax1)
        ax1.set_xlabel("Time in seconds")
        ax1.set_ylabel("Context switches per second")
        self._save_plot("vmstat-interrupts")
        return self

    def quick_stats(self) -> "Vmstat":
        df = self.df[self.df["host"] != "client"]
        df_qvmstat = df[df.columns[4:]]
        vsstats_quickstats = pd.DataFrame(data={"max": df_qvmstat.max()})
        vsstats_quickstats["mean"] = df_qvmstat.mean(numeric_only=True)
        vsstats_quickstats["median"] = df_qvmstat.median(numeric_only=True)
        vsstats_quickstats["sum"] = df_qvmstat.sum(numeric_only=True)
        self._save_table(vsstats_quickstats, "quickstats_vmstat")
        return self

class DiskIO(Stats):

    def __init__(self, path: Path):
        super().__init__("iostat-disk", path)

    def quick_stats(self) -> "DiskIO":
        df = self.df[self.df["host"] != "client"]
        df_qdiskio = df[df.columns[5:]]
        diskio_quickstats = pd.DataFrame(data={"max": df_qdiskio.max()})
        diskio_quickstats["mean"] = df_qdiskio.mean(numeric_only=True)
        diskio_quickstats["median"] = df_qdiskio.median(numeric_only=True)
        diskio_quickstats["sum"] = df_qdiskio.sum(numeric_only=True)
        self._save_table(diskio_quickstats, "quickstats_diskio")
        return self


class CpuIO(Stats):

    def __init__(self, path: Path):
        super().__init__("iostat-cpu", path)

    def quick_stats(self) -> "CpuIO":
        df = self.df[self.df["host"] != "client"]
        df_qcpuio = df[df.columns[4:]]
        cpuio_quickstats = pd.DataFrame(data={"max": df_qcpuio.max()})
        cpuio_quickstats["min"] = df_qcpuio.min(numeric_only=True)
        cpuio_quickstats["mean"] = df_qcpuio.mean(numeric_only=True)
        cpuio_quickstats["median"] = df_qcpuio.median(numeric_only=True)
        self._save_table(cpuio_quickstats, "quickstats_cpuio")
        return self


class Mpstat(Stats):
    def __init__(self, path: Path):
        super().__init__("mpstat", path)

    def quick_stats(self) -> "Mpstat":
        df = self.df[self.df["host"] != "client"]
        df_qmpstat = df[df.columns[4:]]
        mpstat_quickstats = pd.DataFrame(data={"max": df_qmpstat.max()})
        mpstat_quickstats["min"] = df_qmpstat.min(numeric_only=True)
        mpstat_quickstats["mean"] = df_qmpstat.mean(numeric_only=True)
        mpstat_quickstats["median"] = df_qmpstat.median(numeric_only=True)
        self._save_table(mpstat_quickstats, "quickstats_mpstat")
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
        return np.divide(np.float64(x.removesuffix("GiB")), 1024*1024)
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

    def quick_stats(self) -> "DockerStats":
        df = self.df[self.df["host"] != "client"]
        df_qdocker = df[df.columns[4:]]
        docker_quickstats = pd.DataFrame(data={"max": df_qdocker.max()})
        docker_quickstats["min"] = df_qdocker.min(numeric_only=True)
        docker_quickstats["mean"] = df_qdocker.mean(numeric_only=True)
        docker_quickstats["median"] = df_qdocker.median(numeric_only=True)
        docker_quickstats["sum"] = df_qdocker.sum(numeric_only=True)
        self._save_table(docker_quickstats, "quickstats_docker")
        return self


class Tootbench(Stats):

    def __init__(self, path: Path):
        super().__init__("tootbench", path)

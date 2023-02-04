from pathlib import Path
import pandas as pd
import seaborn as sb
import matplotlib.pyplot as plt
from abc import ABC, abstractmethod
import numpy as np


class Stats(ABC):

    @abstractmethod
    def __init__(self, stat: str, path: Path):
        self.stat = stat
        self.path = path
        self.save_path = str(self.path).replace("input", "output")
        self.df = pd.read_csv(str(path) + stat + ".log.gz").sort_values(by="timestamp")
        self.t_lowest = min(self.df["timestamp"])
        # normalize timestamps by lowest one
        self.df.loc["time"] = self.df["timestamp"] - self.t_lowest
        # override this

    def save_plot(self, filename: str):
        Path(self.save_path + "/pdf").mkdir(parents=True, exist_ok=True)
        Path(self.save_path + "/svg").mkdir(parents=True, exist_ok=True)
        Path(self.save_path + "/png").mkdir(parents=True, exist_ok=True)
        plt.savefig("{}/{}.pdf".format(self.save_path + "/pdf", filename), format='pdf')
        plt.savefig("{}/{}.svg".format(self.save_path + "/svg", filename), format='svg')
        plt.savefig("{}/{}.png".format(self.save_path + "/png", filename), format='png')
        plt.close("all")

    def save_table(self, df: pd.DataFrame, filename: str):
        Path(self.save_path + "/csv").mkdir(parents=True, exist_ok=True)
        Path(self.save_path + "/table").mkdir(parents=True, exist_ok=True)
        df.to_csv("{}/{}/{}.csv", self.save_path, "csv", filename)

        fig, ax = plt.subplots(figsize=(20, 10), dpi=100, frame_on=False)
        ax.xaxis.set_visible(False)
        ax.yaxis.set_visible(False)
        pd.plotting.table(ax, df)
        plt.savefig("{}/{}.png".format(self.save_path + "/table", filename), format='png')



class Vmstat(Stats):

    def __init__(self, path: Path):
        super().__init__("vmstat", path)
        self.df["cpu"] = 100 - self.df["idle"]

    def cpu_utilization(self):
        # vmstat cpu util
        df = self.df[self.df["host"] != "client"]
        fig, ax = plt.subplots(figsize=(20, 10), dpi=100)
        sb.lineplot(x="timestamp", y="util", hue="scenario", data=df, ax=ax, legend=False)
        sb.lineplot(x="timestamp", y="user_time", hue="scenario", data=df, ax=ax, linestyle="dashed", legend=False)
        sb.lineplot(x="timestamp", y="kernel_time", hue="scenario", data=df, ax=ax, linestyle="dotted")

        ax.set_xlabel("Time in seconds")
        ax.set_ylabel("CPU utilisation percentage")
        self.save_plot("vmstat-cpu-utilization")

    def io(self):
        # vmstat io
        df = self.df[self.df["host"] != "client"]
        fig, (ax0, ax1) = plt.subplots(2, figsize=(20, 10), dpi=100, sharex='all')
        sb.lineplot(x="timestamp", y="blocks_received", hue="scenario", data=df, ax=ax0)
        ax0.set_xlabel("Time in seconds")
        ax0.set_ylabel("Blocks per second received from block device")
        sb.lineplot(x="timestamp", y="blocks_sent", hue="scenario", data=df, ax=ax1)
        ax1.set_xlabel("Time in seconds")
        ax1.set_ylabel("Blocks per second sent to block device")
        self.save_plot("vmstat-io")

    def interrupts(self):
        # vmstat interrupts
        df = self.df[self.df["host"] != "client"]
        fig, (ax0, ax1) = plt.subplots(2, figsize=(20, 10), dpi=100, sharex='all')
        sb.lineplot(x="timestamp", y="interrupts", hue="scenario", data=df, ax=ax0)
        ax0.set_xlabel("Time in seconds")
        ax0.set_ylabel("Interrupts per second")
        sb.lineplot(x="timestamp", y="context_switches", hue="scenario", data=df, ax=ax1)
        ax1.set_xlabel("Time in seconds")
        ax1.set_ylabel("Context switches per second")
        self.save_plot("vmstat-interrupts")

    def quick_stats(self):
        df = self.df[self.df["host"] != "client"]
        df_qvmstat = df[df.columns[4:]]
        vsstats_quickstats = pd.DataFrame(data={"max": df_qvmstat.max()})
        vsstats_quickstats["mean"] = df_qvmstat.mean(numeric_only=True)
        vsstats_quickstats["median"] = df_qvmstat.median(numeric_only=True)
        vsstats_quickstats["sum"] = df_qvmstat.sum(numeric_only=True)
        self.save_table(df, "quickstats_vmstat")

class DiskIO(Stats):

    def __init__(self, path: Path):
        super().__init__("iostat-disk", path)

    def quick_stats(self):
        df = self.df[self.df["host"] != "client"]
        df_qdiskio = df[df.columns[5:]]
        diskio_quickstats = pd.DataFrame(data={"max": df_qdiskio.max()})
        diskio_quickstats["mean"] = df_qdiskio.mean(numeric_only=True)
        diskio_quickstats["median"] = df_qdiskio.median(numeric_only=True)
        diskio_quickstats["sum"] = df_qdiskio.sum(numeric_only=True)
        self.save_table(df, "quickstats_diskio")


class CpuIO(Stats):

    def __init__(self, path: Path):
        super().__init__("iostat-cpu", path)

    def quick_stats(self):
        df = self.df[self.df["host"] != "client"]
        df_qcpuio = df[df.columns[4:]]
        cpuio_quickstats = pd.DataFrame(data={"max": df_qcpuio.max()})
        cpuio_quickstats["min"] = df_qcpuio.min(numeric_only=True)
        cpuio_quickstats["mean"] = df_qcpuio.mean(numeric_only=True)
        cpuio_quickstats["median"] = df_qcpuio.median(numeric_only=True)
        self.save_table(df, "quickstats_cpuio")


class Mpstat(Stats):
    def __init__(self, path: Path):
        super().__init__("mpstat", path)

    def quick_stats(self):
        df = self.df[self.df["host"] != "client"]
        df_qmpstat = df[df.columns[4:]]
        mpstat_quickstats = pd.DataFrame(data={"max": df_qmpstat.max()})
        mpstat_quickstats["min"] = df_qmpstat.min(numeric_only=True)
        mpstat_quickstats["mean"] = df_qmpstat.mean(numeric_only=True)
        mpstat_quickstats["median"] = df_qmpstat.median(numeric_only=True)
        self.save_table(df, "quickstats_mpstat")


def clean_docker_stats_units(x: str) -> np.float64:
    """
    Remove the unit suffix of the given string value and normalize the value to KB.
    """
    if "KB" in x:
        return np.float64(x.removesuffix("KB"))
    if x.endswith("MB"):
        return np.divide(np.float64(x.removesuffix("MB")), 1000)
    if x.endswith("B"):
        return np.multiply(np.float64(x.removesuffix("B")), 1000)

class DockerStats(Stats):

    def __init__(self, path: Path):
        super().__init__("docker-stats", path)
        self.df.applymap(clean_docker_stats_units, inplace=True)

    def quick_stats(self):
        df = self.df[self.df["host"] != "client"]
        df_qdocker = df[df.columns[4:]]
        docker_quickstats = pd.DataFrame(data={"max": df_qdocker.max()})
        docker_quickstats["min"] = df_qdocker.min(numeric_only=True)
        docker_quickstats["mean"] = df_qdocker.mean(numeric_only=True)
        docker_quickstats["median"] = df_qdocker.median(numeric_only=True)
        docker_quickstats["sum"] = df_qdocker.sum(numeric_only=True)
        self.save_table(df, "quickstats_docker")
